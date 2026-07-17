# nowcast
A mid-2026 commission

## What is this app?

Nowcast helps you monitor current weather conditions, extreme-heat risk in your area, and share location-tagged updates with other users. It combines:

- **Live weather & forecast** for your current location
- **A heat-index chart** showing how temperature, humidity, and related factors evolve over the next few hours
- **An interactive map** of crowd-sourced heat-index readings near you
- **A community feed** where signed-in users can post short updates, optionally tagged with their location

## Getting Started

1. Open the app and it will ask for permission to access your **location** — allow this so the app can show weather and heat data for where you are.
2. The **Home** tab loads automatically and shows current conditions.
3. Use the bottom/side navigation tabs to move between sections: **Home**, **Heat Data**, **Map**, **Community**, and **Profile**.
4. Tap the reload icon at any time to refresh the current page's data.

## Features

### Home
Shows the current weather condition, temperature, your city (reverse-geocoded from your GPS coordinates), and an hourly forecast strip with icons and temperatures for the next few hours.

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

You can also tap anywhere on the map to request a heat-index reading for that spot. A loading marker appears while the app analyzes the location; once done, it turns into a colored marker you can tap for details. Note: some locations may not return a value due to data availability restrictions in that area.

### Community
A public feed of short text posts from other users, newest first. Each post shows the author's name, avatar, how long ago it was posted, and — if the author chose to share it — the location it was posted from (tap the location to view it on the map).

- **Signed-in users** see a **New Post** button to share an update.
- When creating a post, you can optionally check **"Include my location"** to attach your current address to the post.
- Tap any post to view it in full, including a **Delete** button if you are the author.

### Profile
- If you're **not signed in**, you'll see a **Login** button. Signing in uses your Google account — you'll be redirected to Google to approve access, then returned to the app.
- If you **are signed in**, you'll see your name and avatar (pulled from your Google account) along with a **Logout** option.

You must be signed in to create or delete posts. Viewing weather, heat data, the map, and the community feed does not require signing in.

## Privacy Notes

- Your device location is used to fetch weather/heat data for your area and is sent to the app's server each time a location-based page loads.
- Sharing your location on a community post is optional and only happens if you explicitly check the location box before posting.
- Signing in uses Google OAuth; the app stores your name, email, and profile picture to display on your posts and profile page.

## Troubleshooting

- **Nothing loads / stuck on "Loading geolocation":** Make sure you've granted the app location permission in your browser or device settings.
- **Heat index shows as unavailable on the map:** Some areas may not have underlying weather data available for that exact location.
- **Can't post or delete:** You need to be signed in. Go to the Profile tab and log in with Google.

# Nowcast API — Technical Documentation

Backend for a weather / heat-index monitoring and community-posting app. PHP + SQLite3, proxying Google Weather, Geocoding, and OAuth APIs.

## Architecture Overview

```
api/
├── common.php    # Shared helpers: HTTP client (fetch) and SQLite prepared-query helper
├── config.php    # Not included in this repo — must define API credentials (see below)
├── index.php     # Main JSON API router, dispatched by ?action=
└── action.php    # Non-JSON redirect endpoints for Google OAuth login/callback/logout
```

Data store: a single SQLite3 database file `database.db` (path relative to `api/`), opened fresh on every request in `index.php` and `action.php`.

## Required configuration (`api/config.php`)

This file must define the following variables in the global scope:

| Variable | Purpose |
|---|---|
| `$GOOGLE_API_KEY` | API key for Google Weather API and Geocoding API |
| `$CLIENT_ID` | OAuth 2.0 client ID for Google Sign-In |
| `$CLIENT_SECRET` | OAuth 2.0 client secret for Google Sign-In |
| `$REDIRECT_URI` | OAuth redirect URI, must point to `action.php?method=callback` |

## Database schema

### `users`
| Column | Type (inferred) | Notes |
|---|---|---|
| `id` | INTEGER PK | Auto-increment |
| `email` | TEXT | Unique, used to find/create a user on OAuth callback |
| `name` | TEXT | From Google `userinfo` |
| `avatar` | TEXT | Base64 data URI of the user's Google profile picture (fetched and inlined server-side) |
| `session` | TEXT | Current session token (opaque, `uniqid("session-")`), stored as a cookie |
| `time` | INTEGER | Unix timestamp |

### `posts`
| Column | Type (inferred) | Notes |
|---|---|---|
| `id` | INTEGER PK | Auto-increment |
| `user_id` | INTEGER FK → `users.id` | |
| `content` | TEXT | Post body |
| `address` | TEXT, nullable | Reverse-geocoded address, only set if the user opted in |
| `latitude` | REAL, nullable | |
| `longitude` | REAL, nullable | |
| `time` | INTEGER | Unix timestamp, used for expiry |

Posts older than 24 hours (`time < now - 86400`) are deleted whenever `getPosts` is called.

### `heat_locations`
| Column | Type (inferred) | Notes |
|---|---|---|
| `heat_index` | REAL, nullable | Degrees Celsius |
| `latitude` | REAL | |
| `longitude` | REAL | |
| `time` | INTEGER | Unix timestamp, used for expiry |

Rows are deleted when older than 1 hour, when `heat_index IS NULL`, or when a new reading is submitted within ~0.001° (~100 m) of an existing point (i.e., readings are deduplicated per approximate location, keeping only the latest).

## `api/common.php`

### `fetch(string $url, array $options = []): array`
A cURL-based HTTP client wrapper.

- Supports `method`, `headers`, `body` (auto JSON-encoded if `Content-Type: application/json` and body is an array), `timeout`.
- Returns `status`, `ok`, parsed `headers`, raw `body`, and JSON-decoded `json`.

### `executePreparedQuery(SQLite3 $db, string $query, array $values = []): SQLite3Result|false`
Thin wrapper around `SQLite3::prepare()` + `bindValue()` + `execute()`, using named placeholders. All application queries use this, which mitigates SQL injection as long as all user-supplied values are passed via `$values`.

## `api/index.php` — Main API

Entry point for all data operations. Reads the JSON request body into `$data`, opens `database.db`, and dispatches on `$_GET["action"]`. Response content type is always `application/json`.

| `action` | Method | Auth required | Request body | Description |
|---|---|---|---|---|
| `weather` | POST | No | `{ latitude, longitude }` | Proxies Google Weather API `currentConditions:lookup`, returns raw JSON response |
| `geocode` | POST | No | `{ latitude, longitude }` | Proxies Google Geocoding API `v4/geocode/location`, returns raw JSON response |
| `forecast` | POST | No | `{ latitude, longitude }` | Proxies Google Weather API `forecast/hours:lookup` (fixed `hours=6`), returns raw JSON response |
| `analyze_heat_location` | POST | No | `{ latitude, longitude }` | Fetches current heat index for a point from Google Weather, upserts it into `heat_locations` (dedup within ~100 m, purges stale/null rows), returns `{ heatIndex, latitude, longitude, time }` |
| `get_heat_locations` | POST | No | `{}` | Purges stale/null rows from `heat_locations`, returns all remaining rows as a JSON array |
| `profile` | GET | Cookie `session` | — | Returns the current user record, or `false` (HTTP 401) if not authenticated |
| `newPost` | POST | Cookie `session` | `{ content, address?, latitude?, longitude? }` | Inserts a post for the authenticated user. 401 if not authenticated |
| `getPosts` | GET | No | — | Purges posts older than 24h, returns all remaining posts with embedded `user` object |
| `getPost` | POST | No | `{ id }` | Returns a single post with embedded `user` object |
| `deletePost` | POST | Cookie `session` | `{ id }` | Deletes a post if it belongs to the authenticated user. 401 if unauthenticated or not the owner, 404 if the post doesn't exist |
| *(default)* | any | — | — | Returns HTTP 404 `{ "details": "Action not found." }` |

## `api/action.php` — Google OAuth flow

Handles the three-step Google Sign-In flow via `$_GET["method"]`:

| `method` | Behavior |
|---|---|
| `login` | Redirects (`302`) to Google's OAuth consent screen (`accounts.google.com/o/oauth2/v2/auth`) requesting `email profile` scopes |
| `callback` | Exchanges the returned `code` for an access token, fetches the user's Google profile (`email`, `name`, `picture`), downloads and inlines the avatar as a base64 data URI, upserts the `users` row, issues a new opaque session token, sets it as a cookie (`session`, 24h expiry), and redirects to `../app.php?page=profile` |
| `logout` | Clears the `session` cookie (sets an empty value with a past expiry) and redirects to `../app.php?page=profile` |

## External dependencies

- **Google Weather API** (`weather.googleapis.com`) — current conditions and hourly forecast
- **Google Geocoding API** (`geocode.googleapis.com`) — reverse geocoding of lat/lng to address
- **Google OAuth 2.0 / People-ish userinfo** (`accounts.google.com`, `oauth2.googleapis.com`, `www.googleapis.com/oauth2/v1/userinfo`) — map rendering and `AdvancedMarkerElement` markers
- **Chart.js** — heat-data line chart
- **SQLite3** (PHP extension `sqlite3`) — persistence