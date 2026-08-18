# Nowcast — Flutter 3 Mobile App Build Prompt

You are building the **frontend** for **Nowcast**, a weather / extreme-heat monitoring and community-posting app. It is a **Flutter 3** app for **Android and iOS**. It consumes the Laravel 13 headless API (see `docs/server.md`) as a separate, independently-hosted service — the app is a decoupled client and does not assume it shares an origin with the API. Follow the specifications exactly.

Build strategy (applies everywhere in this document):
- Single codebase, single behavior path. Do not branch app logic on platform, form factor, or build target — there is one implementation, not several.
- No conditional platform checks anywhere in the app (no `kIsWeb`, no `Platform.isAndroid` / `Platform.isIOS`, no equivalent). Every screen, adapter, and service has exactly one code path.
- All capabilities described below (including the high-heat notification service) are core, always-on features of the app — not optional add-ons gated by build target.

## 1. Project setup
- Create a Flutter 3 project targeting `android` and `ios`.
- Add dependencies: `http` (or `dio`), `google_maps_flutter`, `fl_chart` (or `charts_flutter`) for the heat chart, `geolocator` for device location, `flutter_secure_storage` for the auth token, `flutter_local_notifications` for notifications, and a background-location/foreground-service plugin (e.g. `flutter_background_geolocation` or manual background handling — see §11). `google_sign_in` is **not** required — use the server-side OAuth redirect flow from §6/§3.
- Use the central `ApiClient` (§5) so networking and storage are handled in one place.

### Adapters (must implement)
Create thin adapters so the rest of the code stays clean and swappable, independent of the concerns above:
- **Base URL adapter** — property `baseUrl` pointing at the API's absolute URL, e.g. `https://yourdomain.com/api`, overridable via `--dart-define=API_BASE_URL=...` / `String.fromEnvironment('API_BASE_URL')` for different environments (dev/staging/prod). The app is a standalone client to a remote API — never assume a shared origin or a proxy path.
- **Auth store adapter** — unified interface `getToken()/setToken()/clearToken()` backed by `flutter_secure_storage`.
- **Maps adapter** — a build-time client-side Google Maps API key, provided separately from the server's `GOOGLE_MAPS_KEY` (that server key must never be compiled into the app). See §3 (Map).
- **OAuth return adapter** — resolves the redirect/callback via a custom URL scheme (see §3 Profile).
- **Notification service adapter** — see §11.

## 2. App structure
- Bottom navigation with 5 tabs: **Home**, **Heat Data**, **Map**, **Community**, **Profile**.
- A top app bar with the current page title, a **profile button** (person icon), and a **reload button** (refresh icon) that re-fetches/re-renders the current page. The active tab is highlighted with the theme color.
- A **full-page loading overlay** shown while a page loads, with a spinner and a progress label (e.g., "Loading geolocation... (1/4)") that updates as each sequential step completes.
- **Cancel stale requests** whenever the user navigates away or presses Reload (`CancelToken`); ignore the results of cancelled calls.
- A global **alert dialog** component for errors/messages.
- **Deep-linking** via a custom URL scheme (e.g., `com.yourcompany.nowcast:/oauth2callback`) or a universal link; the app intercepts the link to extract the Sanctum token (§3 Profile).

## 3. Screens
### Home
- Request device location (geolocation permission), then sequentially fetch current weather, reverse-geocoded city, and 6h forecast — updating the progress label each step.
- `POST /api/weather` → show weather condition description, the icon SVG from `iconBaseUri`, and temperature in °C.
- `POST /api/geocode` → show the formatted address as the city.
- `POST /api/forecast` → render a horizontally scrollable strip of forecast cards, each showing:
  - Hour in **12-hour AM/PM format** (e.g., "3PM") via a `convertHour` helper.
  - Weather icon (dark variant `_dark.svg`).
  - Temperature in °C.

### Heat Data
- Request location, fetch 6h forecast.
- Render a **line chart** titled **"Hourly Temperature Forecast"** with x-axis = hour labels (`HH:00`) and y-axis = Temperature (°C). Plot **six series** over the forecast hours:
  1. Temperature (`#e53935`)
  2. Feels-like (`#fb8c00`)
  3. Dew Point (`#1e88e5`)
  4. Heat Index (`#8e24aa`)
  5. Wind Chill (`#00897b`)
  6. Wet-bulb Temperature (`#3949ab`)
- Legend at bottom; tooltips show `Label: X.X °C`; crosshair interaction mode (`index`, `intersect: false`); smooth lines with a slight tension.

### Map
- Use `google_maps_flutter` centered on the user's location (zoom ~13).
- **Setup (client-facing Maps SDK key):** you need a build-time **client** Google Maps API key, distinct from the server's `GOOGLE_MAPS_KEY` (the server key goes through the API proxy and must **never** be compiled into the app). Configure it in Android `<meta-data>` (`AndroidManifest.xml`) and iOS `AppDelegate`. Pass it via `--dart-define=GOOGLE_MAPS_CLIENT_KEY=...` and initialize `GoogleMapsPlatform` accordingly.
- Fetch heat locations (`POST /api/heat-locations`) and render colored **circular markers**: 20px diameter, white 3px border, drop shadow, filled with the heat-index color.
- Tap a marker → **info window** with the heat index (°C) and the recorded timestamp.
- Tap anywhere on the map → **analyze that spot**: pan to the point, show a spinner **loading marker**, call `POST /api/analyze-heat-location`, then replace it with a colored heat-index marker and open its info window. If `heatIndex` is `null`, remove the marker and show the alert: *"Heat index could not be calculated for this location. (Maybe due to data license restrictions and local market protections.)"*
- Support opening with **optional target coordinates** (e.g., from a post's tapped location) to pan there.

**Heat-index color scale** — linear interpolation between stops (see Shared utilities for `getHeatIndexColor`):

| Heat Index (°C) | Color |
|---|---|
| ≤ 20 | Green `rgb(76, 175, 80)` |
| 28 | Yellow `rgb(255, 235, 59)` |
| 34 | Orange `rgb(255, 167, 38)` |
| 40 | Red `rgb(244, 67, 54)` |
| 46 | Dark Red `rgb(183, 28, 28)` |
| ≥ 55 | Purple `rgb(74, 20, 140)` |

Clamp below the minimum to green, above the maximum to purple; interpolate RGB linearly between the surrounding stops.

### Community
- Fetch profile (`GET /api/profile`) to determine if signed in; if signed in, show a **New Post** floating button (bottom-right).
- Fetch posts (`GET /api/posts`), newest first. Each post card: circular author avatar, name, relative time via a `timeAgo` helper ("just now", "5 minutes ago", "2 hours ago"), content (clamped to 3 lines with ellipsis, line breaks preserved), and — if present — the location address (tap → open Map centered there).
- Tap a post → full post view.

### New Post
- Text area (placeholder "What's on your mind?") and a **Post** button.

## 4. State management
- Use a simple, predictable state management approach (e.g., `Provider` or `Riverpod`).
- Maintain an `AuthState` (token, current user) persisted via the **auth-store adapter** (§1).
- Maintain per-screen loading and error states.
- Maintain notification service state (running/toggled) via the notification service (§11).
- Cancel stale in-flight requests when switching pages or pressing Reload.

## 5. API client
- A central `ApiClient` that:
  - Uses the **base-URL adapter** (§1) to talk to the API as a separate, independently-hosted service.
  - Adds `Content-Type: application/json`.
  - Attaches `Authorization: Bearer <token>` when authenticated (token obtained via the auth-store adapter, §1).
  - Handles 401 (clear token, redirect to Profile), 404, and network errors with user-friendly messages.
  - Configures CORS-safe headers as needed for the decoupled API (the API is not same-origin with the app).
- Typed models for: Weather, ForecastHour, HeatLocation, Post, User.

## 6. Shared utilities
Port these helpers:
- `convertHour(hour24)` → 12-hour AM/PM string (e.g., 15 → "3PM").
- `getHeatIndexColor(heatIndex)` → interpolated RGB color from the heat scale (table in Map section).
- `timeAgo(unixTimestamp)` → relative time string ("just now", "5 minutes ago", "2 hours ago", ...).
- `escapeHtml` → escape user-generated content before rendering (keep for any raw-HTML rendering).

The **heat-index color scale** is the single source of truth for map marker colors (see Map section).

## 7. Visual design
Reproduce the original look and feel:
- **Theme color:** `#0af` (light blue); header bar uses the theme color with white text/icons.
- **Background:** light blue-grey (`#eef`) for the content area; white for the bottom nav and cards.
- **Typography:** system sans-serif; bold page titles; muted grey (`#555`) secondary text.
- **Cards:** white background, `1rem` rounded corners, 1px theme-colored border.
- **Buttons:** theme-colored background, white text, `1rem` rounded corners.
- **Icons:** Material-style SVG icons (person, refresh, home, chart, map, community, edit, send, delete, logout, close).
- **Toggle switch:** iOS-style slider switch for "Include my current location".
- **Google Sign-In button:** official Google-branded styling.
- **Loading spinner:** animated ring.

## 8. Error handling
- **Geolocation denied/failed:** prompt the user to grant location permission rather than hanging on "Loading geolocation".
- **Heat index unavailable** on the map → show the data-unavailable alert.
- **Unauthenticated post/delete:** prompt the user to sign in.
- **401** from any API call: clear the token (via auth-store adapter) and redirect to Profile.
- **Network errors:** show a user-friendly message; cancel stale requests on navigation.
- **Notification permission denied:** fall back to an in-app alert and inform the user the background service is unavailable until permission is granted.

## 9. Verification
- `flutter build apk` and `flutter build ios` succeed.
- All 5 tabs load data correctly against the Laravel API.
- Map markers, color scale, heat analysis, post creation/deletion, and Google sign-in all work end-to-end.
- Sign-in returns via the custom-scheme deep link and stores the token in secure storage.
- High-heat notifications (§11) work.

## 10. High-heat notification (foreground service)
Implements the requested feature: **notify the user when their location detects a high heat index**, delivered via a persistent notification backed by a foreground service.

**Platform config**
- A foreground service keeping an ongoing low-importance notification is required on Android so the OS does not kill the location watcher; on iOS, register background modes (location) and use `UNUserNotificationCenter`.

**Dependencies & platform config**
- `flutter_local_notifications` (or native notification API) for the persistent notification.
- A background-location / foreground-service plugin (e.g. `flutter_background_geolocation`) or a custom Kotlin `Service` / Swift background task that keeps sampling location in the background.
- Android manifest:
  - Permissions: `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `POST_NOTIFICATIONS`.
  - A notification channel for the ongoing service notification (low importance, non-dismissible).
- iOS `Info.plist`: background mode `location`, `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription`, and notification permission request.

**Behavior**
- When the user enables the feature, request notification permission and background-location permission, start the foreground service, and show the ongoing notification that the service is running (user can stop it to end monitoring — this also acts as the exit affordance Android requires for a background task).
- The service periodically fetches the current heat index for the user's location. Use the existing heat-index calculation path (via `GoogleWeatherService` / the same proxy endpoint the map uses — `POST /api/analyze-heat-location`, or a compatible current-conditions call) to compute the heat index server-side; the client does not need a separate live key.
- When the heat index crosses the configured **high threshold** (e.g. ≥ 40 °C, consistent with the red stop in the heat scale in §3 Map), raise a **high-priority notification** with an alert sound/vibration: e.g. *"High heat detected: X °C at your location."* Include the temperature, location, and a recommended action (stay hydrated, avoid peak sun).
- Avoid spamming: re-alert at most once per cooldown window (e.g. hourly) while conditions remain high, or only on a rising edge.
- Cooldown, threshold, and interval are configurable; persist on/off state.
- If notification or background-location permission is denied, fall back to a foreground in-app alert on the Home screen while the app is open (§8).

Keep the notification service behind the adapter in §1 (`NotificationServiceAdapter`) so the rest of the app depends on a stable interface.