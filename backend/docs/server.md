# Nowcast — Laravel 13 Headless API Build Prompt

You are building the **backend** for **Nowcast**, a weather / extreme-heat monitoring and community-posting app. This is a **headless JSON API** built with **Laravel 13** (PHP 8.3+). It proxies Google Weather, Geocoding, and OAuth APIs, and persists users, posts, and crowd-sourced heat-index readings. The Flutter client (native Android/iOS and web/PWA) consumes this API. Follow the specifications exactly.

## 0. Project overview
**Nowcast** is a mobile-first weather-health app. It combines **live weather & 6h forecast**, a **heat-index chart**, an **interactive map** of crowd-sourced heat-index readings, and a **community feed** of location-tagged posts. Viewing weather/heat/map/feed requires no auth; creating/deleting posts requires **Google sign-in**. The API proxies Google Weather/Geocoding and performs a server-side Google OAuth flow.

> **Platform note (important):** This spec is **transport-agnostic**. The API blueprint below works identically for a native Flutter app and a web/PWA, because the client never holds the `GOOGLE_API_KEY` / `GOOGLE_MAPS_KEY` — all Google calls go through these server endpoints. No changes are needed here to support a native mobile client; all platform differences (base URL, secure storage, OAuth return URI) live on the client side (see `docs/client.md`).

Core rules to implement everywhere they apply:
- **Posts** are public and expire after **24 hours**.
- **Heat locations** are public, expire after **1 hour**, purge NULL readings, and dedupe within ~**0.001° (~100 m)** keeping the latest.
- All upstream Google calls go through a single service so error handling is uniform.

## 1. Project setup
- Create a fresh Laravel 13 application.
- Use **SQLite** as the database (`database/database.sqlite`).
- Install **Laravel Sanctum** for API token authentication.
- Configure `.env` with: `GOOGLE_API_KEY`, `GOOGLE_MAPS_KEY`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` (must point to the API's OAuth callback route). Never hard-code these.
- Enable CORS for the same origin used by the web build (reverse proxy serves the Flutter web build and the API under `/api`). Native app requests do not send a browser `Origin`, so they are not subject to CORS — ensure the CORS middleware allows requests with no `Origin` (or the native calls through the proxy) so native mobile clients are not blocked.

## 2. Database schema (migrations)
### `users`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK auto | |
| name | string | From Google userinfo |
| email | string | Unique |
| avatar | text | Base64 data URI of Google profile picture (inlined server-side) |
| time | timestamp | Created at |

### `posts`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK auto | |
| user_id | FK → users.id | |
| content | text | Post body |
| address | string nullable | Reverse-geocoded, only if user opted in |
| latitude | decimal nullable | |
| longitude | decimal nullable | |
| time | timestamp | Used for 24h expiry |

### `heat_locations`
| Column | Type | Notes |
|---|---|---|
| id | bigint PK auto | |
| heat_index | decimal nullable | Degrees Celsius |
| latitude | decimal | |
| longitude | decimal | |
| time | timestamp | Used for 1h expiry |

### `personal_access_tokens` (Sanctum)
- Standard Sanctum table for Bearer token auth.

## 3. Models & relationships
- `User` — `hasMany(Post)`. Uses Sanctum `HasApiTokens`.
- `Post` — `belongsTo(User)`. `$fillable`: content, address, latitude, longitude.
- `HeatLocation` — no relationships. `$fillable`: heat_index, latitude, longitude.

## 4. Services (Google API proxying)
Create a `GoogleWeatherService` (or similar) with an HTTP client (Laravel `Http` facade) that calls:
- **Current conditions**: `GET https://weather.googleapis.com/v1/currentConditions:lookup?key={KEY}&location.latitude={lat}&location.longitude={lng}`
- **Hourly forecast**: `GET https://weather.googleapis.com/v1/forecast/hours:lookup?key={KEY}&location.latitude={lat}&location.longitude={lng}&hours=6`
- **Reverse geocode**: `GET https://geocode.googleapis.com/v4/geocode/location?location.latitude={lat}&location.longitude={lng}&key={KEY}`
Return the raw JSON payloads. Handle upstream errors gracefully (return a 502 with a clear message if Google is unreachable).

## 5. API routes & controllers
All routes are under the `/api` prefix. Public routes need no auth; protected routes require a valid Sanctum Bearer token.

| Method | URI | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/api/weather` | No | `{latitude, longitude}` | Raw Google current-conditions JSON |
| POST | `/api/geocode` | No | `{latitude, longitude}` | Raw Google geocode JSON |
| POST | `/api/forecast` | No | `{latitude, longitude}` | Raw Google 6h forecast JSON |
| POST | `/api/analyze-heat-location` | No | `{latitude, longitude}` | `{heatIndex, latitude, longitude, time}` |
| POST | `/api/heat-locations` | No | `{}` | Array of heat_locations rows |
| GET | `/api/profile` | Yes | — | Current user record, or 401 |
| POST | `/api/posts` | Yes | `{content, address?, latitude?, longitude?}` | 201 on create |
| GET | `/api/posts` | No | — | Array of posts with embedded `user` |
| GET | `/api/posts/{id}` | No | — | Single post with embedded `user` |
| DELETE | `/api/posts/{id}` | Yes | — | 200/401/404 |
| GET | `/api/auth/google/redirect` | No | — | 302 to Google consent screen |
| GET | `/api/auth/google/callback` | No | `?code=` | Exchanges code, issues token, redirects to app |
| POST | `/api/logout` | Yes | — | Revokes current token |

**Status-code / contract notes** (mirroring the legacy API):
- `401` ⇒ `{"details": "Unauthorized."}` (or `false` for `profile`).
- `404` ⇒ `{"details": "Post not found."}` for a missing post; `{"details": "Action not found."}` for an unknown route/method.
- `201` on successful post creation.

### Behavior details
- **`analyze-heat-location`**: fetch current heat index for the point; **delete** existing rows within ~0.001° (~100 m) of the point, rows older than 1 hour, and rows with NULL heat_index; **insert** the new reading; return `{heatIndex, latitude, longitude, time}`.
- **`heat-locations` (GET)**: purge rows older than 1 hour or with NULL heat_index; return all remaining rows.
- **`posts` (GET)**: purge posts older than 24 hours; return all remaining posts, each with an embedded `user` object (id, name, avatar).
- **`posts/{id}` (GET)**: return the post with embedded `user`.
- **`posts/{id}` (DELETE)**: 401 if unauthenticated or not the owner; 404 if the post doesn't exist; 200 on success.
- **`profile` (GET)**: return the authenticated user, or 401.

## 6. Google OAuth flow (server-side)
- **Redirect**: build the Google consent URL (`accounts.google.com/o/oauth2/v2/auth`) with `client_id`, `redirect_uri`, `response_type=code`, `scope=email profile`. Redirect the browser.
- **Callback**: exchange `code` for an access token via `oauth2.googleapis.com/token` (POST, form-encoded, with client_id/client_secret/redirect_uri/grant_type=authorization_code). Fetch userinfo from `www.googleapis.com/oauth2/v1/userinfo?access_token={token}`. Download the `picture`, inline it as a base64 data URI (`data:{mime};base64,...`). Upsert the user by email. Issue a **Sanctum token** and return it to the client (e.g., redirect to the app with the token in the URL fragment or a dedicated exchange endpoint). The client app stores the token securely.
- **Redirect URI varies by platform (config-driven, never hard-coded):**
  - **Web/PWA:** `redirect_uri` is the web app page URL, and the client reads the token from the URL fragment after the callback redirect.
  - **Android / iOS (native):** `redirect_uri` is a **custom scheme or universal link** (e.g. `com.yourcompany.nowcast:/oauth2callback`). Register these URIs in the Google Cloud console's authorized redirect URIs. The API's callback accepts these and redirects back to that scheme with the token (fragment/query), which the native app intercepts via deep-link handling.
  - Make `GOOGLE_REDIRECT_URI` configurable per environment so web and native callback URIs can coexist under one server.

## 7. Validation & error handling
- Validate all request bodies with Form Requests (latitude/longitude required and numeric; content required string; id required integer).
- Return consistent JSON error shape: `{"message": "..."}` with appropriate HTTP status codes (400 validation, 401 unauthorized, 404 not found, 502 upstream).
- Use Laravel's exception handler for a uniform JSON error response.

## 8. Security
- Use parameterized queries / Eloquent (no raw SQL injection).
- Never log or expose API keys.
- Sanctum tokens for all authenticated routes.
- Rate-limit public proxy endpoints to prevent abuse of the Google API key.

## 9. Verification
- `php artisan migrate` runs cleanly.
- All endpoints return correct JSON and status codes (test with curl/Postman).
- OAuth callback issues a token and upserts the user.
- Expiry/dedup logic works (posts >24h, heat_locations >1h/NULL, ~100 m dedup).