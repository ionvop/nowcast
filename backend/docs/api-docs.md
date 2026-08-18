# Nowcast API Reference

This document is the authoritative reference for the **Nowcast** backend API. It is intended to be used as the contract when building the Flutter client (Android, iOS, and web/PWA).

The backend is a **headless JSON API** built with Laravel 13 + Sanctum. It proxies Google Weather, Geocoding, and OAuth APIs, and persists users, posts, and crowd-sourced heat-index readings.

---

## 1. Overview

- **Base path:** all endpoints are prefixed with `/api`.
- **Format:** JSON request/response bodies (`Content-Type: application/json`).
- **Authentication:** optional for most endpoints; required for creating/deleting posts, viewing the profile, and logging out. Uses **Laravel Sanctum** Bearer tokens.
- **Rate limiting:** all routes are wrapped in the `throttle:api` middleware.
- **CORS:** `allowed_origins => ['*']`. Native clients send no browser `Origin` header and are not subject to CORS; the web build is served from the same origin behind a reverse proxy.

### Base URL per platform

| Platform | Base URL |
|---|---|
| Web / PWA | `/api` (reverse proxy serves the Flutter build and the API under `/api`) |
| Android emulator | `http://10.0.2.2:8000/api` |
| iOS simulator / real device / production | `https://yourdomain.com/api` |

---

## 2. Authentication

Authentication uses **Laravel Sanctum** personal access tokens.

- Obtain a token via the **Google OAuth flow** (see [§6 OAuth](#6-google-oauth-flow)).
- Send the token on every authenticated request as a Bearer token:

```
Authorization: Bearer <sanctum-token>
```

- On **401**, the client should clear the stored token and redirect the user to the Profile screen.

---

## 3. Common Conventions

### 3.1 Error response shape

All error responses use the same shape:

```json
{ "message": "..." }
```

### 3.2 HTTP status codes

| Status | Meaning |
|---|---|
| `200` | Success |
| `201` | Resource created (post creation) |
| `302` | Redirect (OAuth) |
| `400` | Validation error — `{"message": "..."}` |
| `401` | Unauthenticated / not the owner — `{"message": "Unauthorized."}` |
| `404` | Not found — `{"message": "Post not found."}` for a missing post, `{"message": "Action not found."}` for an unknown route/method |
| `502` | Upstream Google service unreachable or errored — `{"message": "..."}` |

### 3.3 Coordinate validation

Endpoints that accept a coordinate validate:

| Field | Rules |
|---|---|
| `latitude` | required, numeric, between `-90` and `90` |
| `longitude` | required, numeric, between `-180` and `180` |

---

## 4. Data Models

### 4.1 User

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `name` | string | From Google userinfo |
| `email` | string | Unique |
| `avatar` | string \| null | Base64 data URI of the Google profile picture (inlined server-side) |
| `created_at` | string (ISO 8601) | |
| `updated_at` | string (ISO 8601) | |

### 4.2 Post

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `user_id` | integer | FK → users.id |
| `content` | string | Post body |
| `address` | string \| null | Reverse-geocoded, only if the user opted in |
| `latitude` | decimal (7 dp) \| null | Serialized as a JSON number |
| `longitude` | decimal (7 dp) \| null | Serialized as a JSON number |
| `created_at` | string (ISO 8601) | Used for 24h expiry |
| `updated_at` | string (ISO 8601) | |
| `user` | object | Embedded author: `{ id, name, avatar }` (only when loaded) |

**Expiry:** posts older than **24 hours** are purged before listing.

### 4.3 HeatLocation

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `heat_index` | decimal (2 dp) \| null | Degrees Celsius; serialized as a JSON number |
| `latitude` | decimal (7 dp) | Serialized as a JSON number |
| `longitude` | decimal (7 dp) | Serialized as a JSON number |
| `created_at` | string (ISO 8601) | Used for 1h expiry |
| `updated_at` | string (ISO 8601) | |

**Expiry / dedup:** rows older than **1 hour** or with a **NULL** `heat_index` are purged. Readings within ~**0.001° (~100 m)** of a new point are replaced (deduplicated).

---

## 5. Endpoints

### 5.1 Weather — Current Conditions

Returns the raw Google current-conditions payload for a coordinate. The payload
is the **raw Google Weather API response** and may vary; the client should treat
it as opaque and read the fields it needs defensively. The example below shows
the real Google shape (see `docs/endpoint-responses.md`).

```
POST /api/weather
```

**Auth:** none

**Request body:**

```json
{
  "latitude": 40.7128,
  "longitude": -74.0060
}
```

**Success — `200`:** raw Google current-conditions JSON. Key fields the client
may read (all within the raw payload):

```json
{
  "currentTime": "2025-01-28T22:04:12.025273178Z",
  "timeZone": { "id": "America/Los_Angeles" },
  "isDaytime": true,
  "weatherCondition": {
    "iconBaseUri": "https://maps.gstatic.com/weather/v1/sunny",
    "description": { "text": "Sunny", "languageCode": "en" },
    "type": "CLEAR"
  },
  "temperature": { "degrees": 28.5, "unit": "CELSIUS" },
  "feelsLikeTemperature": { "degrees": 31.2, "unit": "CELSIUS" },
  "dewPoint": { "degrees": 22.1, "unit": "CELSIUS" },
  "relativeHumidity": 65,
  "heatIndex": { "degrees": 33.0, "unit": "CELSIUS" },
  "wind": {
    "direction": { "degrees": 180, "cardinal": "SOUTH" },
    "speed": { "value": 12.3, "unit": "KILOMETERS_PER_HOUR" },
    "gust": { "value": 20.1, "unit": "KILOMETERS_PER_HOUR" }
  },
  "windChill": { "degrees": 28.0, "unit": "CELSIUS" },
  "visibility": { "distance": 16, "unit": "KILOMETERS" },
  "cloudCover": 10,
  "precipitation": {
    "probability": { "percent": 0, "type": "RAIN" },
    "qpf": { "quantity": 0, "unit": "MILLIMETERS" }
  }
}
```

**Errors:** `400` validation, `502` upstream.

---

### 5.2 Weather — Hourly Forecast

Returns the raw Google hourly forecast payload for a coordinate. The payload is
the **raw Google Weather API response** and may vary; the client should treat it
as opaque. The example below shows the real Google shape (see
`docs/endpoint-responses.md`).

```
POST /api/forecast
```

**Auth:** none

**Request body:**

```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "hours": 6
}
```

**Parameters:**

- `latitude` *(required, number, -90 to 90)*
- `longitude` *(required, number, -180 to 180)*
- `hours` *(optional, integer, 1 to 360)* — the number of hours to forecast.
  When omitted, the Google API default of **6 hours** is used.

**Success — `200`:** raw Google forecast JSON with a `forecastHours` array. The
client renders the six series (temperature, feels-like, dew point, heat index,
wind chill, wet-bulb) from the fields it needs:

**Success — `200`:** raw Google forecast JSON with a `forecastHours` array. The
client renders the six series (temperature, feels-like, dew point, heat index,
wind chill, wet-bulb) from the fields it needs:

```json
{
  "forecastHours": [
    {
      "interval": { "startTime": "2025-02-05T23:00:00Z", "endTime": "2025-02-06T00:00:00Z" },
      "displayDateTime": { "year": 2025, "month": 2, "day": 5, "hours": 15, "utcOffset": "-28800s" },
      "isDaytime": true,
      "weatherCondition": {
        "iconBaseUri": "https://maps.gstatic.com/weather/v1/sunny",
        "description": { "text": "Sunny", "languageCode": "en" },
        "type": "CLEAR"
      },
      "temperature": { "degrees": 28.5, "unit": "CELSIUS" },
      "feelsLikeTemperature": { "degrees": 31.2, "unit": "CELSIUS" },
      "dewPoint": { "degrees": 22.1, "unit": "CELSIUS" },
      "windChill": { "degrees": 28.0, "unit": "CELSIUS" },
      "heatIndex": { "degrees": 33.0, "unit": "CELSIUS" },
      "wetBulbTemperature": { "degrees": 26.4, "unit": "CELSIUS" },
      "relativeHumidity": 51,
      "precipitation": {
        "probability": { "percent": 0, "type": "RAIN" },
        "qpf": { "quantity": 0, "unit": "MILLIMETERS" }
      },
      "wind": {
        "direction": { "degrees": 335, "cardinal": "NORTH_NORTHWEST" },
        "speed": { "value": 10, "unit": "KILOMETERS_PER_HOUR" },
        "gust": { "value": 19, "unit": "KILOMETERS_PER_HOUR" }
      },
      "cloudCover": 0
    }
  ],
  "timeZone": { "id": "America/Los_Angeles" }
}
```

**Errors:** `400` validation, `502` upstream.

---

### 5.3 Weather — Reverse Geocode

Returns the raw Google geocode payload for a coordinate (used to derive a human-readable address/city).

```
POST /api/geocode
```

**Auth:** none

**Request body:**

```json
{
  "latitude": 40.7128,
  "longitude": -74.0060
}
```

**Success — `200`:** raw Google geocode JSON. The formatted address is typically available under the results array.

**Errors:** `400` validation, `502` upstream.

---

### 5.4 Weather — Icon Proxy

Proxies a weather icon image from the Google static CDN. The client passes the
absolute icon URL (the `iconBaseUri` from a weather/forecast payload, with the
`.svg` / `_dark.svg` suffix appended) as a query parameter, and receives the raw
image body with its original `Content-Type`. Only `maps.gstatic.com` hosts are
accepted, so the endpoint cannot be abused as an open proxy.

```
GET /api/weather/icon?iconBaseUri=https://maps.gstatic.com/weather/v1/sunny.svg
```

**Auth:** none

**Query parameters:**

| Parameter | Type | Notes |
|---|---|---|
| `iconBaseUri` | string (URL) | Required. Absolute icon URL; host must be `maps.gstatic.com`. |

**Success — `200`:** the raw image body (e.g. `image/svg+xml`) with the matching
`Content-Type` header.

**Errors:**

| Status | Meaning |
|---|---|
| `400` | Missing `iconBaseUri` or host not on the allow-list — `{"message": "..."}` |
| `502` | Upstream Google CDN unreachable or errored — `{"message": "..."}` |

---

### 5.5 Heat Locations — Analyze

Fetches the current heat index for a coordinate, replaces any nearby reading, and returns the stored reading.

```
POST /api/analyze-heat-location
```

**Auth:** none

**Request body:**

```json
{
  "latitude": 40.7128,
  "longitude": -74.0060
}
```

**Behavior:**
1. Fetch the current conditions for the point.
2. Extract the heat index (uses `feelsLikeTemperature.degrees`, falling back to `temperature.degrees` — the real Google shape).
3. Purge rows older than 1 hour or with a NULL heat index.
4. Delete existing rows within ~0.001° (~100 m) of the point.
5. Insert the new reading.

**Success — `200`:**

```json
{
  "heatIndex": 33.0,
  "latitude": 40.7128,
  "longitude": -74.0060,
  "createdAt": "2026-08-12T12:00:00.000000Z"
}
```

> `heatIndex`, `latitude`, and `longitude` are serialized as JSON **numbers**. `heatIndex` may be `null` when the heat index cannot be calculated (e.g. data license restrictions / local market protections). The client should handle this case (remove the marker and show an alert).

**Errors:** `400` validation, `502` upstream.

---

### 5.6 Heat Locations — List

Returns all current heat-location readings.

```
POST /api/heat-locations
```

**Auth:** none

**Request body:** none (empty `{}`).

**Behavior:** rows older than 1 hour or with a NULL heat index are purged first.

**Success — `200`:** array of `HeatLocation` objects (`heat_index`, `latitude`, `longitude` are JSON numbers):

```json
[
  {
    "id": 1,
    "heat_index": 33.0,
    "latitude": 40.7128,
    "longitude": -74.006,
    "created_at": "2026-08-12T12:00:00.000000Z",
    "updated_at": "2026-08-12T12:00:00.000000Z"
  }
]
```

**Errors:** `502` upstream (unlikely; no coordinate required).

---

### 5.7 Posts — List

Returns all current posts, newest first, each with its embedded author.

```
GET /api/posts
```

**Auth:** none

**Behavior:** posts older than 24 hours are purged first.

**Success — `200`:** array of `Post` objects with embedded `user`:

```json
[
  {
    "id": 10,
    "user_id": 3,
    "content": "Stay hydrated out there!",
    "address": "New York, NY, USA",
    "latitude": 40.7128,
    "longitude": -74.006,
    "created_at": "2026-08-12T11:30:00.000000Z",
    "updated_at": "2026-08-12T11:30:00.000000Z",
    "user": {
      "id": 3,
      "name": "Jane Doe",
      "avatar": "data:image/jpeg;base64,..."
    }
  }
]
```

**Errors:** none expected.

---

### 5.8 Posts — Show

Returns a single post with its embedded author.

```
GET /api/posts/{id}
```

**Auth:** none

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | Post ID |

**Success — `200`:** a single `Post` object with embedded `user` (same shape as one item in [§5.6](#56-posts--list)).

**Errors:**
- `404` — `{"message": "Post not found."}`

---

### 5.9 Posts — Create

Creates a new post for the authenticated user.

```
POST /api/posts
```

**Auth:** required (Bearer token)

**Request body:**

```json
{
  "content": "What's on your mind?",
  "address": "New York, NY, USA",
  "latitude": 40.7128,
  "longitude": -74.0060
}
```

| Field | Type | Rules |
|---|---|---|
| `content` | string | required |
| `address` | string \| null | optional |
| `latitude` | number \| null | optional, between `-90` and `90` |
| `longitude` | number \| null | optional, between `-180` and `180` |

**Success — `201`:** the created `Post` with embedded `user`:

```json
{
  "id": 11,
  "user_id": 3,
  "content": "What's on your mind?",
  "address": "New York, NY, USA",
  "latitude": 40.7128,
  "longitude": -74.006,
  "created_at": "2026-08-12T12:00:00.000000Z",
  "updated_at": "2026-08-12T12:00:00.000000Z",
  "user": {
    "id": 3,
    "name": "Jane Doe",
    "avatar": "data:image/jpeg;base64,..."
  }
}
```

**Errors:**
- `400` — validation error
- `401` — `{"message": "Unauthorized."}`

---

### 5.10 Posts — Delete

Deletes a post owned by the authenticated user.

```
DELETE /api/posts/{id}
```

**Auth:** required (Bearer token)

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | Post ID |

**Success — `200`:**

```json
{ "message": "Post deleted." }
```

**Errors:**
- `401` — `{"message": "Unauthorized."}` (unauthenticated, or not the owner)
- `404` — `{"message": "Post not found."}`

---

### 5.11 Profile

Returns the currently authenticated user's profile.

```
GET /api/profile
```

**Auth:** required (Bearer token)

**Success — `200`:** the current `User` object:

```json
{
  "id": 3,
  "name": "Jane Doe",
  "email": "jane@example.com",
  "avatar": "data:image/jpeg;base64,...",
  "created_at": "2026-08-12T10:00:00.000000Z",
  "updated_at": "2026-08-12T10:00:00.000000Z"
}
```

**Errors:**
- `401` — `{"message": "Unauthorized."}`

---

### 5.12 Logout

Revokes the current Sanctum token and signs the user out.

```
POST /api/logout
```

**Auth:** required (Bearer token)

**Success — `200`:**

```json
{ "message": "Logged out." }
```

**Errors:**
- `401` — `{"message": "Unauthorized."}`

---

## 6. Google OAuth Flow

Authentication is handled **server-side**. The client never holds the Google OAuth credentials; it only redirects the browser to the consent screen and later receives a Sanctum token.

### 6.1 Redirect to Google consent screen

```
GET /api/auth/google/redirect?returnTo=<target>
```

**Auth:** none

**Query parameters:**

| Param | Type | Notes |
|---|---|---|
| `returnTo` | string \| optional | Where the callback should send the browser (and the issued token) afterwards. Carried through the OAuth `state` parameter. Only the configured web origin and the native custom scheme (`GOOGLE_NATIVE_SCHEME`, default `nowcast`) are allowed; any other value falls back to the web origin (prevents open redirects). |

**Success — `302`:** redirects the browser to the Google consent screen (`accounts.google.com/o/oauth2/v2/auth`).

### 6.2 OAuth callback

```
GET /api/auth/google/callback?code=<code>&state=<returnTo>
```

**Auth:** none

**Query parameters:**

| Param | Type | Notes |
|---|---|---|
| `code` | string | The authorization code from Google |
| `state` | string | The original `returnTo` target (echoed back by Google) |

**Behavior:**
1. Exchange `code` for an access token (`oauth2.googleapis.com/token`).
2. Fetch userinfo (`www.googleapis.com/oauth2/v1/userinfo`).
3. Download the profile `picture` and inline it as a base64 data URI.
4. Upsert the user by email.
5. Issue a Sanctum token.

**Success — `302`:** redirects the browser to the `returnTo` target with the token in the URL **fragment**:

```
<returnTo>#token=<sanctum-token>
```

**Failure — `302`:** redirects with an error fragment:

```
<returnTo>#error=1
```

### 6.3 Client handling

- **Web / PWA:** the `redirect_uri` is the web app page URL; the client reads the token from the URL fragment after the callback redirect.
- **Android / iOS (native):** the `redirect_uri` is a **custom scheme / universal link** (e.g. `com.yourcompany.nowcast:/oauth2callback`). The native app intercepts the deep link, extracts the token from the fragment, and stores it securely.

The client should:
1. Store the token via the auth-store adapter (secure storage on native, localStorage on web).
2. Attach it as `Authorization: Bearer <token>` on authenticated requests.
3. On `#error=1`, show a sign-in failure message.

---

## 7. Client Integration Checklist (Flutter)

- [ ] Central `ApiClient` with the platform base-URL adapter (`/api` on web, absolute URL on native).
- [ ] `Content-Type: application/json` on all requests.
- [ ] Attach `Authorization: Bearer <token>` when authenticated.
- [ ] Handle `401` (clear token, redirect to Profile), `404`, and network errors with user-friendly messages.
- [ ] Typed models for `Weather`, `ForecastHour`, `HeatLocation`, `Post`, `User`.
- [ ] Cancel stale in-flight requests when navigating away or pressing Reload.
- [ ] Handle `heatIndex: null` from `analyze-heat-location` (data-unavailable alert).
- [ ] OAuth deep-link interception on native; fragment token reading on web.

---

## 8. Quick Reference Table

| Method | URI | Auth | Request | Success |
|---|---|---|---|---|
| POST | `/api/weather` | No | `{latitude, longitude}` | `200` raw current conditions |
| POST | `/api/forecast` | No | `{latitude, longitude}` | `200` raw 6h forecast |
| POST | `/api/geocode` | No | `{latitude, longitude}` | `200` raw geocode |
| POST | `/api/analyze-heat-location` | No | `{latitude, longitude}` | `200` `{heatIndex, latitude, longitude, createdAt}` |
| POST | `/api/heat-locations` | No | `{}` | `200` array of heat locations |
| GET | `/api/posts` | No | — | `200` array of posts + user |
| GET | `/api/posts/{id}` | No | — | `200` post + user |
| POST | `/api/posts` | Yes | `{content, address?, latitude?, longitude?}` | `201` post + user |
| DELETE | `/api/posts/{id}` | Yes | — | `200` / `401` / `404` |
| GET | `/api/profile` | Yes | — | `200` user / `401` |
| POST | `/api/logout` | Yes | — | `200` |
| GET | `/api/auth/google/redirect` | No | `?returnTo=` | `302` to Google |
| GET | `/api/auth/google/callback` | No | `?code=&state=` | `302` with `#token=` or `#error=` |
