# Nowcast — Laravel 13 + React Rebuild Build Prompt

> **Purpose:** This document is the authoritative reference for rebuilding the **Nowcast** app. It captures the complete design, functionality, data model, API surface, and UX of the existing PHP + vanilla-JS implementation so it can be faithfully recreated as a modern **Laravel 13 (backend/API) + React (frontend)** application.

---

## 1. Project Overview

**Nowcast** is a mobile-first, installable (PWA) weather-health monitoring app. It combines:

- **Live weather & hourly forecast** for the user's current location.
- **A heat-index chart** showing how temperature, humidity, and related metrics evolve over the next few hours.
- **An interactive map** of crowd-sourced heat-index readings near the user.
- **A community feed** where signed-in users post short, location-tagged updates.

The app is **location-driven**: it requests the user's geolocation and uses it to fetch weather/heat data and to center the map. Viewing weather, heat data, the map, and the community feed does **not** require sign-in. Creating/deleting posts **requires** Google sign-in.

---

## 2. Target Tech Stack

| Layer | Technology |
|---|---|
| Backend / API | **Laravel 13** (PHP), RESTful JSON API |
| Database | **MySQL** (or SQLite for local dev) via Laravel Eloquent + migrations |
| Frontend | **React** (with Vite), TypeScript recommended |
| State / Data fetching | React Query (TanStack Query) or equivalent |
| Routing | React Router (client-side) |
| Styling | CSS Modules / Tailwind / styled-components — must reproduce the existing visual design |
| Maps | **Google Maps JavaScript API** (`AdvancedMarkerElement`, `InfoWindow`) |
| Charts | **Chart.js** (via `react-chartjs-2`) |
| Auth | **Google OAuth 2.0** (Laravel Socialite or manual OAuth flow) |
| PWA | Service worker + Web App Manifest (installable, standalone) |
| HTTP client (server→Google) | Laravel HTTP Client (`Illuminate\Support\Facades\Http`) |

---

## 3. Functional Requirements

### 3.1 App Shell & Navigation

- The app is a **single-page application** with a persistent **top header bar** and a **bottom navigation bar** with 5 tabs: **Home**, **Heat Data**, **Map**, **Community**, **Profile**.
- **Header bar** (left → right):
  - **Profile button** (person icon) → navigates to Profile.
  - **Panel title** (centered) — shows the current page name.
  - **Reload button** (refresh icon) → re-fetches/re-renders the current page's data.
- **Bottom nav** (5 equal columns): Home, Heat Data, Map, Community, Profile. The active tab is highlighted with the theme color.
- A **full-page loading overlay** with a spinner and a progress label (e.g., "Loading geolocation... (1/4)") is shown while a page loads.
- The app supports **deep-linking** via a `page` query parameter (e.g., `?page=profile`).

### 3.2 Home Page

On load, sequentially (with progress labels):
1. **Geolocation** — request the user's position via the browser Geolocation API.
2. **Current weather** — fetch current conditions for the coordinates. Display:
   - Weather condition description text.
   - Weather condition icon (SVG from `iconBaseUri`).
   - Current temperature in °C.
3. **City / address** — reverse-geocode the coordinates and display the formatted address.
4. **Hourly forecast** — fetch a 6-hour forecast. Render a horizontally scrollable strip of forecast cards, each showing:
   - Hour (12-hour format with AM/PM, e.g., "3PM").
   - Weather icon (dark variant `_dark.svg`).
   - Temperature in °C.

### 3.3 Heat Data Page

- Fetch the 6-hour forecast for the user's location.
- Render a **line chart** (Chart.js) titled **"Hourly Temperature Forecast"** with the x-axis = hour labels (`HH:00`) and y-axis = Temperature (°C).
- Plot **six series** simultaneously:
  1. Temperature
  2. Feels-like temperature
  3. Dew point
  4. Heat index
  5. Wind chill
  6. Wet-bulb temperature
- Each series has a distinct color; legend at bottom; tooltips show `Label: X.X °C`; crosshair interaction mode (`index`, `intersect: false`).

### 3.4 Map Page

- Load the Google Maps JS library (marker library) and center the map on the user's location (zoom ~13).
- **Fetch all crowd-sourced heat-index readings** (`get_heat_locations`) and render each as a circular marker:
  - Marker color = heat-index color scale (see §6).
  - White 3px border, 20px diameter, drop shadow.
  - Clicking a marker opens an **InfoWindow** showing the heat index (°C) and the recorded timestamp.
- **Tap anywhere on the map** to request a heat-index reading for that spot:
  1. Pan the map to the clicked point.
  2. Show a **loading marker** (spinner) at that point.
  3. Call `analyze_heat_location` with the coordinates.
  4. Replace the loading marker with a colored heat-index marker and open its InfoWindow.
  5. If the returned heat index is `null` (data unavailable), remove the marker and show an alert: *"Heat index could not be calculated for this location. (Maybe due to data license restrictions and local market protections.)"*
- The map can be opened with **optional target coordinates** (e.g., when tapping a post's location) to pan to that point.

### 3.5 Community Page

- **Public feed** of posts, newest first.
- Each post card shows:
  - Author avatar (circular), author name, relative time ("just now", "5 minutes ago", "2 hours ago", etc.).
  - Post content (clamped to 3 lines with ellipsis; full text preserved with line breaks).
  - If the post has a location: the address text; tapping it opens the Map page centered on that location.
- **New Post** button (floating, bottom-right) is shown **only when signed in**.
- Tapping a post opens the **Post detail** page.

### 3.6 New Post Page

- A textarea ("What's on your mind?") and a **Post** button.
- A toggle switch labeled **"Include my current location"**.
- If the toggle is on, on submit:
  1. Get the user's geolocation.
  2. Reverse-geocode it to an address.
  3. Attach `content`, `address`, `latitude`, `longitude` to the post.
- On success, return to the Community feed.

### 3.7 Post Detail Page

- Shows the full post: avatar, author name, relative time, full content, and (if present) the location address (tap → open Map).
- A **Delete** button is shown **only if the signed-in user is the post's author**. Deleting requires a confirmation dialog ("Are you sure you want to delete this post?").

### 3.8 Profile Page

- **Not signed in:** show a **"Sign in with Google"** button (official Google-branded button). Clicking redirects to the Google OAuth consent screen, then returns to the app.
- **Signed in:** show the user's avatar (circular), name, and a **Logout** button.

---

## 4. Data Model (Database Schema)

### 4.1 `users`
| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | Auto-increment |
| `name` | string | From Google userinfo |
| `email` | string | **Unique**; used to find/create the user on OAuth callback |
| `avatar` | text | Base64 data URI of the user's Google profile picture (fetched and inlined server-side) |
| `session` | string | Opaque session token (e.g., `uniqid("session-")`), stored as a cookie |
| `created_at` | timestamp | Creation time |
| `updated_at` | timestamp | Last update time |

### 4.2 `posts`
| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | Auto-increment |
| `user_id` | FK → `users.id` | Author |
| `content` | text | Post body |
| `address` | string, nullable | Reverse-geocoded address, only if user opted in |
| `latitude` | decimal, nullable | |
| `longitude` | decimal, nullable | |
| `created_at` | timestamp | Used for expiry |
| `updated_at` | timestamp | Last update time |

**Expiry rule:** Posts older than **24 hours** are deleted whenever the post list is fetched.

### 4.3 `heat_locations`
| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | Auto-increment |
| `heat_index` | decimal, nullable | Degrees Celsius |
| `latitude` | decimal | |
| `longitude` | decimal | |
| `created_at` | timestamp | Used for expiry |
| `updated_at` | timestamp | Last update time |

**Expiry / dedup rules:**
- Rows are deleted when older than **1 hour**.
- Rows with `heat_index IS NULL` are deleted.
- When a new reading is submitted within ~0.001° (~100 m) of an existing point, the old row is removed (deduplicated per approximate location, keeping only the latest).

---

## 5. API Endpoints (REST)

The backend exposes a JSON API. Map the existing `?action=` endpoints to REST routes. All responses are JSON.

| Method | Route | Auth | Request body | Description |
|---|---|---|---|---|
| POST | `/api/weather` | No | `{ latitude, longitude }` | Proxy Google Weather API `currentConditions:lookup`; return raw JSON |
| POST | `/api/geocode` | No | `{ latitude, longitude }` | Proxy Google Geocoding API `v4/geocode/location`; return raw JSON |
| POST | `/api/forecast` | No | `{ latitude, longitude }` | Proxy Google Weather API `forecast/hours:lookup` (fixed `hours=6`); return raw JSON |
| POST | `/api/heat-locations/analyze` | No | `{ latitude, longitude }` | Fetch current heat index for a point from Google Weather; upsert into `heat_locations` (dedup ~100 m, purge stale/null); return `{ heatIndex, latitude, longitude, time }` |
| GET | `/api/heat-locations` | No | — | Purge stale/null rows; return all remaining rows as a JSON array |
| GET | `/api/profile` | Cookie `session` | — | Return current user record, or `401` if not authenticated |
| POST | `/api/posts` | Cookie `session` | `{ content, address?, latitude?, longitude? }` | Create a post for the authenticated user; `401` if unauthenticated |
| GET | `/api/posts` | No | — | Purge posts older than 24h; return all posts with embedded `user` object |
| GET | `/api/posts/{id}` | No | — | Return a single post with embedded `user` object |
| DELETE | `/api/posts/{id}` | Cookie `session` | — | Delete a post if it belongs to the authenticated user; `401` if unauthenticated/not owner, `404` if not found |

**Auth semantics:** The `session` cookie identifies the user. `401` → `false` (profile) or `{ "details": "Unauthorized." }` (posts). `404` → `{ "details": "Post not found." }`. Unknown route → `404 { "details": "Action not found." }`.

---

## 6. Heat-Index Color Scale

Map a heat index (in °C) to a color via **linear interpolation** between stops:

| Heat Index (°C) | Color |
|---|---|
| ≤ 20 | Green `rgb(76, 175, 80)` |
| 28 | Yellow `rgb(255, 235, 59)` |
| 34 | Orange `rgb(255, 167, 38)` |
| 40 | Red `rgb(244, 67, 54)` |
| 46 | Dark Red `rgb(183, 28, 28)` |
| ≥ 55 | Purple `rgb(74, 20, 140)` |

Values below the min clamp to green; above the max clamp to purple; in between, interpolate RGB linearly between the surrounding stops.

---

## 7. Authentication (Google OAuth 2.0)

Three-step flow (server-side redirect):

1. **Login** — Redirect the user to Google's OAuth consent screen (`accounts.google.com/o/oauth2/v2/auth`) requesting `email profile` scopes, with `client_id`, `redirect_uri`, `response_type=code`.
2. **Callback** —
   - Exchange the returned `code` for an access token (`oauth2.googleapis.com/token`, `grant_type=authorization_code`).
   - Fetch the user's Google profile (`email`, `name`, `picture`) from `www.googleapis.com/oauth2/v1/userinfo`.
   - Download the profile picture and **inline it as a base64 data URI** (with its detected MIME type).
   - **Upsert** the `users` row by email.
   - Issue a new opaque session token, store it as a cookie (`session`, 24h expiry).
   - Redirect back to the app's Profile page.
3. **Logout** — Clear the `session` cookie (empty value, past expiry) and redirect to the Profile page.

> **Laravel note:** Prefer **Laravel Socialite** for the OAuth dance, but preserve the exact behavior: upsert by email, inline the avatar as a base64 data URI, and issue a session cookie. Use Laravel's built-in session/auth or a custom token-based session as appropriate.

---

## 8. External Integrations

| Service | Endpoint(s) | Purpose |
|---|---|---|
| **Google Weather API** | `weather.googleapis.com/v1/currentConditions:lookup`, `weather.googleapis.com/v1/forecast/hours:lookup?hours=6` | Current conditions + hourly forecast |
| **Google Geocoding API** | `geocode.googleapis.com/v4/geocode/location` | Reverse geocoding lat/lng → address |
| **Google OAuth 2.0** | `accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com/oauth2/v1/userinfo` | Sign-in |
| **Google Maps JS API** | Maps + `AdvancedMarkerElement` + `InfoWindow` | Map rendering & markers |
| **Chart.js** | Client-side | Heat-data line chart |

**Configuration (env):** `GOOGLE_API_KEY`, `GOOGLE_MAPS_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`. These must live in Laravel's `.env` / config, never hard-coded.

---

## 9. Frontend Pages / Components (React)

| Route | Component | Notes |
|---|---|---|
| `/` | `HomePage` | Current weather, city, hourly forecast strip |
| `/heat` | `HeatDataPage` | Chart.js multi-series line chart |
| `/map` | `MapPage` | Google Map + heat markers + tap-to-analyze |
| `/community` | `CommunityPage` | Post feed + New Post FAB (if authed) |
| `/community/new` | `NewPostPage` | Textarea + location toggle + Post |
| `/community/:id` | `PostDetailPage` | Full post + conditional Delete |
| `/profile` | `ProfilePage` | Login (Google) or user info + Logout |
| — | `AppShell` | Header + bottom nav + loading overlay |

**Shared utilities to port:**
- `convertHour(hour24)` → 12-hour AM/PM string.
- `getHeatIndexColor(heatIndex)` → color interpolation (§6).
- `timeAgo(unixTimestamp)` → relative time string.
- `escapeHtml` → HTML escaping for user content (React auto-escapes, but keep for any raw HTML).
- Loading overlay with progress labels.
- AbortController-based cancellation of in-flight requests when switching pages.

---

## 10. PWA Requirements

- **Web App Manifest** (`manifest.json`): name "Nowcast", `display: standalone`, portrait orientation, background `#FFFFFF`, theme `#EEEEFF`, 256×256 icon.
- **Service worker**: cache the app shell; network-first with cache fallback; clean up old caches on activate.
- **Install flow**: `index.html` redirects to `app.php` when running standalone, otherwise to an **install page** that registers the service worker and shows an **Install** button when the `beforeinstallprompt` event fires.
- The install page includes a short app description.

---

## 11. Visual Design / UI

Reproduce the existing look and feel:

- **Theme color:** `--theme: #0af` (light blue). Header bar uses the theme color with white text/icons.
- **Background:** light blue-grey (`#eef`) for the content area; white for the bottom nav and cards.
- **Typography:** system `sans-serif`; bold page titles; muted grey (`#555`) secondary text.
- **Cards:** white background, rounded corners (`1rem`), 1px theme-colored border.
- **Buttons:** theme-colored background, white text, rounded (`1rem`).
- **Icons:** Material-style SVG icons (person, refresh, home, chart, map, community, profile, edit, send, delete, logout, close).
- **Toggle switch:** iOS-style slider switch for "Include my current location".
- **Google Sign-In button:** official Google-branded button styling.
- **Loading spinner:** animated SVG ring.

---

## 12. Non-Functional Requirements

- **Mobile-first** responsive layout; bottom nav on mobile.
- **Security:** all user-supplied values passed via parameterized queries / Eloquent bindings (no string interpolation). Escape user content on render. Validate/authorize all post mutations.
- **Privacy:** device location is sent to the server only when a location-based page loads; location on posts is opt-in only.
- **Error handling:** graceful handling of geolocation denial ("stuck on Loading geolocation" → prompt to grant permission); heat index unavailable on map → alert; unauthenticated post/delete → prompt to sign in.
- **Performance:** cancel stale requests when navigating; cache where appropriate.

---

## 13. Acceptance Criteria

1. App installs as a PWA and opens standalone with the 5-tab shell.
2. Home shows current weather, city, and a 6-hour forecast strip for the user's location.
3. Heat Data renders a 6-series Chart.js line chart from the forecast.
4. Map shows crowd-sourced heat markers colored by the heat scale; tapping the map analyzes that location and adds a marker (or shows the data-unavailable alert).
5. Community shows the public feed newest-first with avatars, names, relative times, and optional location links.
6. Signed-in users can create posts (optionally location-tagged) and delete their own posts; unsigned users see the Google login on Profile.
7. Google OAuth login/logout works end-to-end and persists via a session cookie.
8. Posts expire after 24h; heat locations expire after 1h and are deduplicated within ~100 m.
9. All API endpoints match the contract in §5 with correct status codes.
