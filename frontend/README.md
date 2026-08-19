# Nowcast

**A weather and heat-health monitoring app.**

Nowcast helps you monitor current weather conditions, extreme-heat risk in your area, and share location-tagged updates with other users. It combines:

- **Live weather & forecast** for your current location
- **A heat-index chart** showing how temperature, humidity, and related factors evolve over the next few hours
- **An interactive map** of crowd-sourced heat-index readings near you
- **A community feed** where signed-in users can post short updates, optionally tagged with their location
- **Heat alerts** — a background service that notifies you when the heat index crosses a danger threshold you set

This repository is the **Flutter client** (Android, iOS, and web/PWA). It talks to a headless **Laravel 13 + Sanctum** JSON API that proxies Google Weather, Geocoding, and OAuth. See [`docs/api-docs.md`](docs/api-docs.md) for the API contract.

---

## Features

The app is organized around five tabs in a persistent bottom navigation bar: **Home**, **Heat Data**, **Map**, **Community**, and **Profile**.

### Home
Shows the current weather condition, temperature, your city (reverse-geocoded from your GPS coordinates), and an hourly forecast strip with icons and temperatures for the next few hours.

It also includes a **Heat Alert** card: a danger-threshold slider (default **32 °C**) and an on/off toggle that starts/stops a background notification service. When enabled, the app keeps a persistent status notification and alerts you when the current heat index — or any hour in the forecast — exceeds your threshold.

### Heat Data
Displays a line chart comparing several heat-related metrics over the next several hours for your location:

- Temperature
- Feels-like temperature
- Dew point
- Heat index
- Wind chill
- Wet bulb temperature

This helps you understand not just how hot it is, but how dangerous the heat may feel.

### Map
An interactive map centered on your location showing colored markers for recent heat-index readings nearby (green = mild, moving through yellow/orange/red to purple = extreme). Tap any marker to see its exact heat index and when it was recorded.

You can also tap anywhere on the map to request a heat-index reading for that spot. A loading marker appears while the app analyzes the location; once done, it turns into a colored marker you can tap for details. Note: some locations may not return a value due to data-availability restrictions in that area.

### Community
A public feed of short text posts from other users, newest first. Each post shows the author's name, avatar, how long ago it was posted, and — if the author chose to share it — the location it was posted from (tap the location to view it on the map).

- **Signed-in users** see a **New Post** button to share an update.
- When creating a post, you can optionally check **"Include my location"** to attach your current address to the post.
- Tap any post to view it in full, including a **Delete** button if you are the author.

### Profile
- If you're **not signed in**, you'll see a **Login** button. Signing in uses your Google account — you'll be redirected to Google to approve access, then returned to the app.
- If you **are signed in**, you'll see your name and avatar (pulled from your Google account) along with a **Logout** option.

You must be signed in to create or delete posts. Viewing weather, heat data, the map, and the community feed does not require signing in.

---

## Tech Stack

- **Flutter / Dart** — cross-platform client (Android, iOS, web/PWA, plus desktop targets).
- **Laravel 13 + Sanctum** — headless JSON backend that proxies Google Weather, Geocoding, and OAuth APIs and persists users, posts, and crowd-sourced heat-index readings.
- **Google OAuth** — sign-in via the backend's redirect endpoint; the Sanctum token is delivered back to the app through a `nowcast://auth` deep link and persisted locally.

Key packages (`pubspec.yaml`):

| Package | Purpose |
|---|---|
| `http` | Networking against the Laravel proxy API |
| `geolocator` | Device location for the Home page |
| `flutter_svg` | SVG rendering for weather icons |
| `fl_chart` | Line chart for the Heat Data page |
| `google_maps_flutter` | Interactive map for the Heat Map page |
| `shared_preferences` | Local token / settings persistence |
| `url_launcher` | Opens the external browser for the Google consent screen |
| `app_links` | Intercepts the OAuth callback deep link |
| `flutter_background_service` | Long-running background isolate for the heat-alert service |
| `flutter_local_notifications` | Persistent local notifications for heat-alert status |

---

## Prerequisites

- **Flutter SDK** (Dart SDK `^3.12.2`).
- The **Nowcast backend** running locally (default `http://localhost:8000/api`) or reachable at a configured URL.
- A **Google Maps client key** for the Map tab (injected at build time — see below).

---

## Setup

Install dependencies:

```bash
flutter pub get
```

### Configuration

The app is configured at build time via `--dart-define` flags:

| Flag | Default | Purpose |
|---|---|---|
| `API_BASE_URL` | `http://localhost:8000/api` | Absolute base URL of the Laravel proxy API |
| `GOOGLE_MAPS_CLIENT_KEY` | *(none)* | Client Google Maps API key for the Map tab |

For example, to point at a local dev server on the Android emulator:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

> **Note:** The Maps key is a build-time **client** key, distinct from the server's `GOOGLE_MAPS_KEY` (which goes through the API proxy and must never be compiled into the app).

---

## Running

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web / PWA (with Maps key)
flutter run -d web-server --web-port 8080 \
  --dart-define=GOOGLE_MAPS_CLIENT_KEY=YOUR_API_KEY
```

See [`docs/commands.md`](docs/commands.md) for additional run commands.

---

## Testing

```bash
flutter test
```

The test suite covers authentication, the community feed, heat-alert status logic, and widget smoke tests:

- `test/auth_test.dart`
- `test/community_test.dart`
- `test/heat_alert_test.dart`
- `test/widget_test.dart`

---

## Project Structure

```
lib/
├── main.dart                 # App entry point; wires up auth + heat-alert services
└── src/
    ├── api/                  # ApiClient (HTTP against the Laravel proxy)
    ├── auth/                 # AuthController (Google OAuth + token persistence)
    ├── config/               # AppConfig, MapsConfig (build-time configuration)
    ├── models/               # Weather, ForecastHour, HeatLocation, Post, User
    ├── screens/              # Home, Heat Data, Map, Community, Profile + post screens
    ├── services/             # Heat-alert background service + controller
    ├── shell/                # AppShell (bottom navigation + IndexedStack)
    ├── theme/                # AppTheme
    ├── utils/                # Geolocation, formatting, heat colors, map focus, etc.
    └── widgets/              # Reusable UI widgets (post card, weather icon, etc.)
```

---

## Documentation

- [`docs/api-docs.md`](docs/api-docs.md) — authoritative reference for the backend API contract.
- [`docs/commands.md`](docs/commands.md) — run commands.
- [`docs/endpoint-responses.md`](docs/endpoint-responses.md) — example endpoint responses.

---

## Privacy Notes

- Your device location is used to fetch weather/heat data for your area and is sent to the app's server each time a location-based page loads.
- Sharing your location on a community post is optional and only happens if you explicitly check the location box before posting.
- Signing in uses Google OAuth; the app stores your name, email, and profile picture to display on your posts and profile page.

---

## Troubleshooting

- **Nothing loads / stuck on "Loading geolocation":** Make sure you've granted the app location permission in your browser or device settings.
- **Heat index shows as unavailable on the map:** Some areas may not have underlying weather data available for that exact location.
- **Can't post or delete:** You need to be signed in. Go to the Profile tab and log in with Google.
