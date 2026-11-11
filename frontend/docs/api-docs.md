# Nowcast API Reference

This document is the authoritative reference for the **Nowcast** backend API. It is intended to be used as the contract when building the Flutter client (Android and iOS).

The backend is a **headless JSON API** built with Laravel 13 + Sanctum. It proxies Google Weather, Geocoding, and OAuth APIs, and persists users, posts, and crowd-sourced weather readings.

---

## 1. Overview

- **Base path:** all endpoints are prefixed with `/api`.
- **Format:** JSON request/response bodies (`Content-Type: application/json`).
- **Authentication:** optional for most endpoints; required for creating/deleting posts, viewing the profile, and logging out. Uses **Laravel Sanctum** Bearer tokens.
- **Rate limiting:** all routes are wrapped in the `throttle:api` middleware.
- **CORS:** `allowed_origins => ['*']`. Native clients send no browser `Origin` header and are not subject to CORS.

### Base URL per platform

| Platform | Base URL |
|---|---|
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

### 4.3 Comment

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `post_id` | integer | FK → posts.id |
| `user_id` | integer | FK → users.id |
| `content` | string | Comment body |
| `created_at` | string (ISO 8601) | |
| `updated_at` | string (ISO 8601) | |
| `user` | object | Embedded author: `{ id, name, avatar }` (only when loaded) |

**Expiry:** none — comments persist indefinitely.

### 4.4 HeatLocation

> **DEPRECATED** — This model is superseded by [WeatherLocation](#44-weatherlocation), which stores the entire weather payload instead of only the heat index. It is kept for backward compatibility and will be removed in a future release. New clients should use the weather-location endpoints (§5.8, §5.9).

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `heat_index` | decimal (2 dp) \| null | Degrees Celsius; serialized as a JSON number |
| `latitude` | decimal (7 dp) | Serialized as a JSON number |
| `longitude` | decimal (7 dp) | Serialized as a JSON number |
| `created_at` | string (ISO 8601) | Used for 1h expiry |
| `updated_at` | string (ISO 8601) | |

**Expiry / dedup:** rows older than **1 hour** or with a **NULL** `heat_index` are purged. Readings within ~**0.001° (~100 m)** of a new point are replaced (deduplicated).

### 4.4 WeatherLocation

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `data` | object | The **entire** Google current-conditions payload (see §5.1 for the shape). Stored as JSON; the client reads any weather field it needs (temperature, feels-like, heat index, humidity, wind, etc.) |
| `latitude` | decimal (7 dp) | Serialized as a JSON number |
| `longitude` | decimal (7 dp) | Serialized as a JSON number |
| `created_at` | string (ISO 8601) | Used for 1h expiry |
| `updated_at` | string (ISO 8601) | |

**Expiry / dedup:** rows older than **1 hour** are purged. Readings within ~**0.001° (~100 m)** of a new point are replaced (deduplicated).

### 4.5 HealthProfile

One row per user, storing the personal and health details used to personalize the heat-risk assessment (§5.24). Only `age` and `biologicalSex` are required; everything else is optional so the user can share as much or as little as they are comfortable with. Missing values are treated by the model as "unknown", not as "no risk".

| Field | Type | Notes |
|---|---|---|
| `id` | integer | |
| `user_id` | integer | FK → users.id, unique |
| `age` | integer | 1–120 |
| `biologicalSex` | string | one of `male`, `female`, `other` |
| `heightCm` | number \| null | 50–250 |
| `weightKg` | number \| null | 20–300 |
| `activityLevel` | string \| null | one of `sedentary`, `light`, `moderate`, `active`, `very_active` |
| `conditions` | array of strings | chronic conditions; see §5.23 for the allowed values |
| `medications` | array of strings | medication classes; see §5.23 |
| `lifestyle` | array of strings | behavioural modifiers; see §5.23 |
| `created_at` | string (ISO 8601) | |
| `updated_at` | string (ISO 8601) | |

**Expiry / dedup:** none — the profile persists until the user clears it.

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
  When omitted, the server API default of **6 hours** is used.

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

### 5.3 Weather — Daily Forecast

Returns the raw Google daily forecast payload for a coordinate. The payload is
the **raw Google Weather API response** and may vary; the client should treat it
as opaque. The example below shows the real Google shape (see
`docs/endpoint-responses.md`).

```
POST /api/forecast/daily
```

**Auth:** none

**Request body:**

```json
{
  "latitude": 40.7128,
  "longitude": -74.0060,
  "days": 7
}
```

**Parameters:**

- `latitude` *(required, number, -90 to 90)*
- `longitude` *(required, number, -180 to 180)*
- `days` *(optional, integer, 1 to 14)* — the number of days to forecast.
  When omitted, the server default of **7 days** is used.

**Success — `200`:** raw Google forecast JSON with a `forecastDays` array. Each
entry carries a `displayDate`, `daytimeForecast` / `nighttimeForecast` blocks,
`maxTemperature` / `minTemperature`, `sunEvents`, and `moonEvents`:

```json
{
  "forecastDays": [
    {
      "interval": { "startTime": "2025-02-10T15:00:00Z", "endTime": "2025-02-11T15:00:00Z" },
      "displayDate": { "year": 2025, "month": 2, "day": 10 },
      "daytimeForecast": {
        "interval": { "startTime": "2025-02-10T15:00:00Z", "endTime": "2025-02-11T03:00:00Z" },
        "weatherCondition": {
          "iconBaseUri": "https://maps.gstatic.com/weather/v1/partly_cloudy",
          "description": { "text": "Partly sunny", "languageCode": "en" },
          "type": "PARTLY_CLOUDY"
        },
        "relativeHumidity": 54,
        "uvIndex": 3,
        "precipitation": {
          "probability": { "percent": 5, "type": "RAIN" },
          "qpf": { "quantity": 0, "unit": "MILLIMETERS" }
        },
        "thunderstormProbability": 0,
        "wind": {
          "direction": { "degrees": 280, "cardinal": "WEST" },
          "speed": { "value": 6, "unit": "KILOMETERS_PER_HOUR" },
          "gust": { "value": 14, "unit": "KILOMETERS_PER_HOUR" }
        },
        "cloudCover": 53
      },
      "nighttimeForecast": {
        "interval": { "startTime": "2025-02-11T03:00:00Z", "endTime": "2025-02-11T15:00:00Z" },
        "weatherCondition": {
          "iconBaseUri": "https://maps.gstatic.com/weather/v1/partly_clear",
          "description": { "text": "Partly cloudy", "languageCode": "en" },
          "type": "PARTLY_CLOUDY"
        },
        "relativeHumidity": 85,
        "uvIndex": 0,
        "precipitation": {
          "probability": { "percent": 10, "type": "RAIN_AND_SNOW" },
          "qpf": { "quantity": 0, "unit": "MILLIMETERS" }
        },
        "thunderstormProbability": 0,
        "wind": {
          "direction": { "degrees": 201, "cardinal": "SOUTH_SOUTHWEST" },
          "speed": { "value": 6, "unit": "KILOMETERS_PER_HOUR" },
          "gust": { "value": 14, "unit": "KILOMETERS_PER_HOUR" }
        },
        "cloudCover": 70
      },
      "maxTemperature": { "degrees": 13.3, "unit": "CELSIUS" },
      "minTemperature": { "degrees": 1.5, "unit": "CELSIUS" },
      "feelsLikeMaxTemperature": { "degrees": 13.3, "unit": "CELSIUS" },
      "feelsLikeMinTemperature": { "degrees": 1.5, "unit": "CELSIUS" },
      "sunEvents": {
        "sunriseTime": "2025-02-10T15:02:35.703929582Z",
        "sunsetTime": "2025-02-11T01:43:00.762932858Z"
      },
      "moonEvents": {
        "moonPhase": "WAXING_GIBBOUS",
        "moonriseTimes": ["2025-02-10T23:54:17.713157984Z"],
        "moonsetTimes": ["2025-02-10T14:13:58.625181191Z"]
      },
      "maxHeatIndex": { "degrees": 13.3, "unit": "CELSIUS" },
      "iceThickness": { "thickness": 0, "unit": "MILLIMETERS" }
    }
  ],
  "timeZone": { "id": "America/Los_Angeles" }
}
```

**Errors:** `400` validation, `502` upstream.

---

### 5.4 Weather — Reverse Geocode

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

### 5.5 Weather — Icon Proxy

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

### 5.6 Heat Locations — Analyze

> **DEPRECATED** — Superseded by [Weather Locations — Analyze](#58-weather-locations--analyze), which returns the full weather payload. Kept for backward compatibility; will be removed in a future release.

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

### 5.7 Heat Locations — List

> **DEPRECATED** — Superseded by [Weather Locations — List](#59-weather-locations--list). Kept for backward compatibility; will be removed in a future release.

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

### 5.8 Weather Locations — Analyze

Fetches the full current weather payload for a coordinate, replaces any nearby reading, and returns the stored reading.

```
POST /api/analyze-weather-location
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
2. Purge rows older than 1 hour.
3. Delete existing rows within ~0.001° (~100 m) of the point.
4. Insert the new reading with the **entire** current-conditions payload.

**Success — `200`:**

```json
{
  "data": {
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
    "heatIndex": { "degrees": 33.0, "unit": "CELSIUS" },
    "relativeHumidity": 65
  },
  "latitude": 40.7128,
  "longitude": -74.0060,
  "createdAt": "2026-08-12T12:00:00.000000Z"
}
```

> `data` is the **raw Google current-conditions payload** (see §5.1) and may vary; the client should treat it as opaque and read the fields it needs defensively. `latitude` and `longitude` are serialized as JSON **numbers**. The heat index, when needed, is read from `data.heatIndex.degrees` (falling back to `data.feelsLikeTemperature.degrees` / `data.temperature.degrees`), and may be absent when the heat index cannot be calculated.

**Errors:** `400` validation, `502` upstream.

---

### 5.9 Weather Locations — List

Returns all current weather-location readings.

```
POST /api/weather-locations
```

**Auth:** none

**Request body:** none (empty `{}`).

**Behavior:** rows older than 1 hour are purged first.

**Success — `200`:** array of `WeatherLocation` objects (`data` is the full payload; `latitude`, `longitude` are JSON numbers):

```json
[
  {
    "id": 1,
    "data": {
      "temperature": { "degrees": 28.5, "unit": "CELSIUS" },
      "feelsLikeTemperature": { "degrees": 31.2, "unit": "CELSIUS" },
      "heatIndex": { "degrees": 33.0, "unit": "CELSIUS" }
    },
    "latitude": 40.7128,
    "longitude": -74.006,
    "created_at": "2026-08-12T12:00:00.000000Z",
    "updated_at": "2026-08-12T12:00:00.000000Z"
  }
]
```

**Errors:** `502` upstream (unlikely; no coordinate required).

---

### 5.10 Posts — List

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

### 5.11 Posts — Show

Returns a single post with its embedded author.

```
GET /api/posts/{id}
```

**Auth:** none

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | Post ID |

**Success — `200`:** a single `Post` object with embedded `user` (same shape as one item in [§5.10](#510-posts--list)).

**Errors:**
- `404` — `{"message": "Post not found."}`

---

### 5.12 Posts — Create

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

### 5.13 Posts — Delete

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

### 5.14 Profile

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

### 5.15 Logout

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

### 5.16 Posts — By User

Returns all current posts by a specified user, newest first, each with its
embedded author. Posts older than 24 hours are purged first.

```
GET /api/users/{id}/posts
```

**Auth:** none

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | User ID |

**Success — `200`:** array of `Post` objects with embedded `user` (same shape
as one item in [§5.10](#510-posts--list)):

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

Returns an empty array (`[]`) when the user exists but has no current posts.

**Errors:**
- `404` — `{"message": "User not found."}`

---

### 5.17 Comments — List

Returns all comments on a post, newest first, each with its embedded author.

```
GET /api/posts/{id}/comments
```

**Auth:** none

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | Post ID |

**Success — `200`:** array of `Comment` objects with embedded `user`:

```json
[
  {
    "id": 21,
    "post_id": 10,
    "user_id": 5,
    "content": "Stay hydrated out there!",
    "created_at": "2026-08-12T11:30:00.000000Z",
    "updated_at": "2026-08-12T11:30:00.000000Z",
    "user": {
      "id": 5,
      "name": "Jane Doe",
      "avatar": "data:image/jpeg;base64,..."
    }
  }
]
```

Returns an empty array (`[]`) when the post exists but has no comments.

**Errors:**
- `404` — `{"message": "Post not found."}`

---

### 5.18 Comments — Create

Creates a new comment on a post for the authenticated user.

```
POST /api/posts/{id}/comments
```

**Auth:** required (Bearer token)

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | Post ID |

**Request body:**

```json
{
  "content": "Stay hydrated out there!"
}
```

| Field | Type | Rules |
|---|---|---|
| `content` | string | required |

**Success — `201`:** the created `Comment` with embedded `user`:

```json
{
  "id": 21,
  "post_id": 10,
  "user_id": 5,
  "content": "Stay hydrated out there!",
  "created_at": "2026-08-12T11:30:00.000000Z",
  "updated_at": "2026-08-12T11:30:00.000000Z",
  "user": {
    "id": 5,
    "name": "Jane Doe",
    "avatar": "data:image/jpeg;base64,..."
  }
}
```

**Errors:**
- `400` — validation error
- `401` — `{"message": "Unauthorized."}`
- `404` — `{"message": "Post not found."}`

---

### 5.19 Comments — Delete

Deletes a comment owned by the authenticated user.

```
DELETE /api/comments/{id}
```

**Auth:** required (Bearer token)

**Path parameters:**

| Param | Type | Notes |
|---|---|---|
| `id` | integer | Comment ID |

**Success — `200`:**

```json
{ "message": "Comment deleted." }
```

**Errors:**
- `401` — `{"message": "Unauthorized."}` (unauthenticated, or not the owner)
- `404` — `{"message": "Comment not found."}`

---

### 5.20 AI Summary

Generates a short AI analysis of the current conditions and forecast payloads,
a short paragraph of health advice based on the conditions, and a single link to
an article recommended by the AI for the user to read.

The client supplies the weather payloads it already fetched (via §5.1, §5.2,
§5.3) in the request body; the server does **not** call Google again. The payloads
are sent to an LLM hosted on OpenRouter (model `deepseek/deepseek-v4-flash-0731:online`
by default, overridable with `OPENROUTER_MODEL`) which returns structured JSON.

```
POST /api/ai/summary
```

**Auth:** none

**Request body:**

```json
{
  "currentConditions": {
    "temperature": { "degrees": 33.0, "unit": "CELSIUS" },
    "feelsLikeTemperature": { "degrees": 38.0, "unit": "CELSIUS" },
    "heatIndex": { "degrees": 41.0, "unit": "CELSIUS" },
    "relativeHumidity": 70,
    "weatherCondition": { "description": { "text": "Sunny" }, "type": "CLEAR" }
  },
  "hourlyForecast": {
    "forecastHours": [ /* ... */ ]
  },
  "dailyForecast": {
    "forecastDays": [ /* ... */ ]
  }
}
```

| Field | Type | Rules |
|---|---|---|
| `currentConditions` | object | required — the raw Google current-conditions payload |
| `hourlyForecast` | object | optional — the raw Google hourly forecast payload |
| `dailyForecast` | object | optional — the raw Google daily forecast payload |

**Success — `200`:**

```json
{
  "summary": "Hot and humid with a heat index of 41°C; sunshine continues into the afternoon before showers arrive tonight.",
  "healthAdvice": "Heat is the main risk. Limit strenuous outdoor activity, drink water, and take breaks in the shade or air conditioning during peak hours.",
  "articleUrl": "https://www.cdc.gov/heat-health/about/index.html"
}
```

**Errors:**
- `400` — validation error (`currentConditions` required)
- `502` — OpenRouter unreachable, errored, unconfigured API key, or returned a malformed/empty response

---

### 5.21 AI Activities

Recommends nearby places and activities that fit the current weather. The model
uses OpenRouter's `openrouter:web_search` server tool to look up real, nearby
places, then returns structured suggestions matched to the conditions.

As with §5.20, the client supplies the weather payloads it already fetched (via
§5.1, §5.2, §5.3) plus the location; the server does **not** call Google again.

```
POST /api/ai/activities
```

**Auth:** none

**Request body:**

```json
{
  "currentConditions": {
    "temperature": { "degrees": 18.0, "unit": "CELSIUS" },
    "weatherCondition": { "description": { "text": "Partly cloudy" }, "type": "CLOUDY" }
  },
  "hourlyForecast": {
    "forecastHours": [ /* ... */ ]
  },
  "dailyForecast": {
    "forecastDays": [ /* ... */ ]
  },
  "latitude": 37.7749,
  "longitude": -122.4194,
  "placeName": "San Francisco"
}
```

| Field | Type | Rules |
|---|---|---|
| `currentConditions` | object | required — the raw Google current-conditions payload |
| `hourlyForecast` | object | optional — the raw Google hourly forecast payload |
| `dailyForecast` | object | optional — the raw Google daily forecast payload |
| `latitude` | number | required — between -90 and 90 |
| `longitude` | number | required — between -180 and 180 |
| `placeName` | string | optional — a human-readable place name (e.g. from §5.4 geocoding) used to bias the web search |

**Success — `200`:**

```json
{
  "suggestions": [
    {
      "name": "Golden Gate Park",
      "category": "outdoor",
      "description": "A large urban park with gardens and trails.",
      "reason": "Mild temperatures make a stroll comfortable.",
      "url": "https://www.goldengatepark.org/"
    },
    {
      "name": "SFMOMA",
      "category": "cultural",
      "description": "A modern art museum in downtown San Francisco.",
      "reason": "Rain is expected, so an indoor activity fits."
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `suggestions` | array | 3–6 entries (max 8) |
| `suggestions[].name` | string | name of the place or activity |
| `suggestions[].category` | string | one of `outdoor`, `indoor`, `food`, `cultural`, `sports`, `family`, `other` |
| `suggestions[].description` | string | one or two sentences describing the place or activity |
| `suggestions[].reason` | string | why it suits the current weather |
| `suggestions[].url` | string \| omitted | a real URL found via web search; omitted when the model found none (never fabricated) |

**Errors:**
- `400` — validation error (`currentConditions`, `latitude`, or `longitude` required)
- `502` — OpenRouter unreachable, errored, unconfigured API key, or returned a malformed/empty response

---

### 5.22 Health Profile — Show

Returns the authenticated user's health profile, or `null` when they have not
entered one yet.

```
GET /api/profile/health
```

**Auth:** required (Bearer token)

**Success — `200` (profile saved):**

```json
{
  "profile": {
    "age": 68,
    "biologicalSex": "female",
    "heightCm": 162.5,
    "weightKg": 61.0,
    "activityLevel": "light",
    "conditions": ["cardiovascular", "diabetes"],
    "medications": ["beta_blockers"],
    "lifestyle": ["acclimatized"],
    "updatedAt": "2026-11-11T09:12:00.000000Z"
  }
}
```

**Success — `200` (no profile yet):**

```json
{ "profile": null }
```

**Errors:**
- `401` — `{"message": "Unauthorized."}`

---

### 5.23 Health Profile — Update / Delete

Creates or replaces the authenticated user's health profile. The profile is a
single row per user, so submitting the form again overwrites the previous
values. `DELETE` removes it.

```
PUT /api/profile/health
DELETE /api/profile/health
```

**Auth:** required (Bearer token)

**Request body (PUT):**

```json
{
  "age": 68,
  "biologicalSex": "female",
  "heightCm": 162.5,
  "weightKg": 61.0,
  "activityLevel": "light",
  "conditions": ["cardiovascular", "diabetes"],
  "medications": ["beta_blockers"],
  "lifestyle": ["acclimatized"]
}
```

| Field | Type | Rules |
|---|---|---|
| `age` | integer | required — 1–120 |
| `biologicalSex` | string | required — `male`, `female`, or `other` |
| `heightCm` | number | optional — 50–250 |
| `weightKg` | number | optional — 20–300 |
| `activityLevel` | string | optional — `sedentary`, `light`, `moderate`, `active`, `very_active` |
| `conditions` | array | optional — max 10, each one of `cardiovascular`, `diabetes`, `respiratory`, `kidney`, `pregnancy`, `neurological`, `obesity` |
| `medications` | array | optional — max 10, each one of `diuretics`, `beta_blockers`, `anticholinergics`, `antipsychotics`, `stimulants`, `antihistamines` |
| `lifestyle` | array | optional — max 10, each one of `acclimatized`, `alcohol`, `dehydrated`, `outdoor_worker`, `high_fitness`, `limited_mobility` |

**Success — `200`:**

```json
{ "profile": { "age": 68, "biologicalSex": "female", "conditions": [], "medications": [], "lifestyle": [], "updatedAt": "2026-11-11T09:12:00.000000Z" } }
```

**Success — `200` (DELETE):**

```json
{ "message": "Health profile deleted." }
```

**Behavior:**

1. The row is matched by the authenticated user, never by an id in the body.
2. Omitted optional fields are stored as `null` / empty arrays, replacing any
   previously saved values.
3. `DELETE` is idempotent — it succeeds even when no profile exists, so the
   client can clear its local copy unconditionally.

**Errors:**
- `400` — validation error (`age` or `biologicalSex` missing or out of range, or an unknown option value)
- `401` — `{"message": "Unauthorized."}`

---

### 5.24 AI Health Risk

Estimates the authenticated user's heat-strain risk by combining their saved
health profile (§5.22) with the current weather, and returns the numbers the
client plots plus a written summary.

The profile is read **server-side** from the database rather than from the
request body, so the client cannot spoof or omit health details. The client
supplies the weather payloads it already fetched (via §5.1, §5.2, §5.3); the
server does **not** call Google again.

```
POST /api/ai/health-risk
```

**Auth:** required (Bearer token)

**Request body:**

```json
{
  "currentConditions": {
    "temperature": { "degrees": 36.0, "unit": "CELSIUS" },
    "relativeHumidity": 70
  },
  "hourlyForecast": {
    "forecastHours": [ /* ... */ ]
  },
  "dailyForecast": {
    "forecastDays": [ /* ... */ ]
  },
  "previousAssessment": {
    "riskScore": 40,
    "riskLevel": "high",
    "generatedAt": "2026-11-10T09:00:00Z"
  }
}
```

| Field | Type | Rules |
|---|---|---|
| `currentConditions` | object | required — the raw Google current-conditions payload |
| `hourlyForecast` | object | optional — the raw Google hourly forecast payload |
| `dailyForecast` | object | optional — the raw Google daily forecast payload |
| `previousAssessment` | object \| null | optional — the last assessment the user saw; sent when regenerating so the new answer stays consistent with it |

**Success — `200`:**

```json
{
  "riskScore": 62,
  "riskLevel": "very_high",
  "thresholdC": 38.0,
  "thresholdLabel": "Clinical fever threshold",
  "summary": "Heat strain is likely this afternoon; humidity keeps sweat evaporation low.",
  "uncertainty": "Humidity is forecast with moderate confidence, and no weight was provided.",
  "keyFindings": ["Peak risk is between 14:00 and 16:00."],
  "recommendations": ["Avoid strenuous outdoor work at midday."],
  "hourly": [
    {
      "hourIndex": 0,
      "hour": 12,
      "probability": 0.25,
      "coreTempMedianC": 37.4,
      "coreTempP10C": 37.1,
      "coreTempP90C": 37.8
    }
  ]
}
```

| Field | Type | Notes |
|---|---|---|
| `riskScore` | integer | 0 (none) – 100 (emergency) |
| `riskLevel` | string | one of `low`, `moderate`, `high`, `very_high`, `extreme` |
| `thresholdC` | number | the core-temperature threshold modelled against, in Celsius (35.0–42.0) |
| `thresholdLabel` | string | a short human-readable name for the threshold |
| `summary` | string | two to four plain-language sentences |
| `uncertainty` | string | the largest sources of uncertainty in the estimate |
| `keyFindings` | array of strings | 2–5 actionable findings |
| `recommendations` | array of strings | 2–5 concrete actions |
| `hourly` | array | up to 24 points, sorted by `hourIndex` |
| `hourly[].hourIndex` | integer | zero-based index of the hour in the supplied forecast — use it as the chart's x value so the axis stays correct across midnight |
| `hourly[].hour` | integer | hour of day, 0–23 |
| `hourly[].probability` | number | 0.0–1.0 chance of crossing `thresholdC` during that hour |
| `hourly[].coreTempMedianC` | number | median estimated core temperature |
| `hourly[].coreTempP10C` | number | 10th-percentile (optimistic) core temperature |
| `hourly[].coreTempP90C` | number | 90th-percentile (pessimistic) core temperature |

> The response describes statistical **estimates for awareness, not a diagnosis**.
> Out-of-range numbers are clamped (score to 0–100, probability to 0.0–1.0),
> a mis-ordered percentile triple is sorted, and hourly points with an invalid
> `hour` or `hourIndex` are dropped rather than failing the request.

**Errors:**
- `400` — validation error (`currentConditions` required), or the user has no saved profile (`{"message": "A health profile is required before generating an assessment."}`)
- `401` — `{"message": "Unauthorized."}`
- `502` — OpenRouter unreachable, errored, unconfigured API key, or returned a malformed/empty response

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
| `returnTo` | string \| optional | Where the callback should send the browser (and the issued token) afterwards. Carried through the OAuth `state` parameter. Only the native custom scheme (`GOOGLE_NATIVE_SCHEME`, default `nowcast`) is allowed; any other value falls back to the web origin (prevents open redirects). |

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

- **Android / iOS (native):** the `redirect_uri` is a **custom scheme / universal link** (e.g. `com.yourcompany.nowcast:/oauth2callback`). The native app intercepts the deep link, extracts the token from the fragment, and stores it securely.

The client should:
1. Store the token via the auth-store adapter (secure storage on native).
2. Attach it as `Authorization: Bearer <token>` on authenticated requests.
3. On `#error=1`, show a sign-in failure message.

---

## 7. Client Integration Checklist (Flutter)

- [ ] Central `ApiClient` with the platform base-URL adapter (absolute URL on native).
- [ ] `Content-Type: application/json` on all requests.
- [ ] Attach `Authorization: Bearer <token>` when authenticated.
- [ ] Handle `401` (clear token, redirect to Profile), `404`, and network errors with user-friendly messages.
- [ ] Typed models for `Weather`, `ForecastHour`, `WeatherLocation`, `Post`, `User`.
- [ ] Cancel stale in-flight requests when navigating away or pressing Reload.
- [ ] Read the heat index from `WeatherLocation.data.heatIndex.degrees` (falling back to `feelsLikeTemperature` / `temperature`); handle a missing heat index (data-unavailable alert).
- [ ] OAuth deep-link interception on native.

---

## 8. Quick Reference Table

| Method | URI | Auth | Request | Success |
|---|---|---|---|---|
| POST | `/api/weather` | No | `{latitude, longitude}` | `200` raw current conditions |
| POST | `/api/forecast` | No | `{latitude, longitude}` | `200` raw 6h forecast |
| POST | `/api/geocode` | No | `{latitude, longitude}` | `200` raw geocode |
| POST | `/api/analyze-heat-location` | No | `{latitude, longitude}` | `200` `{heatIndex, latitude, longitude, createdAt}` *(deprecated)* |
| POST | `/api/heat-locations` | No | `{}` | `200` array of heat locations *(deprecated)* |
| POST | `/api/analyze-weather-location` | No | `{latitude, longitude}` | `200` `{data, latitude, longitude, createdAt}` |
| POST | `/api/weather-locations` | No | `{}` | `200` array of weather locations |
| GET | `/api/posts` | No | — | `200` array of posts + user |
| GET | `/api/posts/{id}` | No | — | `200` post + user |
| GET | `/api/posts/{id}/comments` | No | — | `200` array of comments + user / `404` |
| GET | `/api/users/{id}/posts` | No | — | `200` array of a user's posts + user / `404` |
| POST | `/api/ai/summary` | No | `{currentConditions, hourlyForecast?, dailyForecast?}` | `200` `{summary, healthAdvice, articleUrl}` |
| POST | `/api/ai/activities` | No | `{currentConditions, hourlyForecast?, dailyForecast?, latitude, longitude, placeName?}` | `200` `{suggestions: [...]}` |
| GET | `/api/profile/health` | Yes | — | `200` `{profile: {...}\|null}` |
| PUT | `/api/profile/health` | Yes | `{age, biologicalSex, heightCm?, weightKg?, activityLevel?, conditions?, medications?, lifestyle?}` | `200` `{profile: {...}}` |
| DELETE | `/api/profile/health` | Yes | — | `200` `{message}` |
| POST | `/api/ai/health-risk` | Yes | `{currentConditions, hourlyForecast?, dailyForecast?, previousAssessment?}` | `200` `{riskScore, riskLevel, thresholdC, thresholdLabel, summary, uncertainty, keyFindings, recommendations, hourly}` |
| POST | `/api/posts` | Yes | `{content, address?, latitude?, longitude?}` | `201` post + user |
| DELETE | `/api/posts/{id}` | Yes | — | `200` / `401` / `404` |
| POST | `/api/posts/{id}/comments` | Yes | `{content}` | `201` comment + user / `401` / `404` |
| DELETE | `/api/comments/{id}` | Yes | — | `200` / `401` / `404` |
| GET | `/api/profile` | Yes | — | `200` user / `401` |
| POST | `/api/logout` | Yes | — | `200` |
| GET | `/api/auth/google/redirect` | No | `?returnTo=` | `302` to Google |
| GET | `/api/auth/google/callback` | No | `?code=&state=` | `302` with `#token=` or `#error=` |
