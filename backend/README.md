# Nowcast Backend

The backend for **Nowcast** — a headless JSON API built with **Laravel 13** and **Laravel Sanctum**. It proxies Google Weather, Geocoding, and OAuth APIs, and persists users, posts, and crowd-sourced heat-index readings.

This API is the contract for the Flutter client (Android, iOS, and web/PWA). The authoritative API reference lives in [`docs/api-docs.md`](docs/api-docs.md).

---

## Features

- **Weather** — current conditions, hourly forecast, and reverse geocoding proxied from Google.
- **Weather icon proxy** — serves weather icons from the Google static CDN (host allow-listed).
- **Heat locations** — analyze a coordinate (fetch + store the heat index) and list current crowd-sourced readings.
- **Posts** — list, show, create, and delete time-limited posts (24h expiry) with embedded authors.
- **Authentication** — server-side Google OAuth flow issuing Sanctum Bearer tokens; profile and logout endpoints.
- **Rate limiting** — all routes wrapped in the `throttle:api` middleware.

---

## Requirements

- PHP **^8.3**
- [Composer](https://getcomposer.org/)
- Node.js + npm (for the Vite build)

---

## Setup

```bash
# 1. Install PHP dependencies
composer install

# 2. Configure the environment
cp .env.example .env
php artisan key:generate

# 3. Run the database migrations
php artisan migrate

# 4. Install and build frontend assets (Vite)
npm install
npm run build
```

> A convenience `composer run setup` script performs steps 1–4 automatically.

### Local development

```bash
composer run dev
```

This starts the dev server, the queue worker, and Vite concurrently.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in the Google credentials:

| Variable | Description |
|---|---|
| `GOOGLE_API_KEY` | Google Weather API key |
| `GOOGLE_MAPS_KEY` | Google Maps / Geocoding API key |
| `GOOGLE_CLIENT_ID` | Google OAuth client ID |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret |
| `GOOGLE_REDIRECT_URI` | OAuth redirect URI (web page URL or native custom scheme / universal link) |
| `GOOGLE_NATIVE_SCHEME` | Native custom scheme for OAuth deep links (default: `nowcast`) |

---

## API Overview

- **Base path:** all endpoints are prefixed with `/api`.
- **Format:** JSON request/response bodies (`Content-Type: application/json`).
- **Authentication:** optional for most endpoints; required for creating/deleting posts, viewing the profile, and logging out. Uses **Laravel Sanctum** Bearer tokens.
- **Rate limiting:** all routes are wrapped in the `throttle:api` middleware.
- **CORS:** `allowed_origins => ['*']`.

### Base URL per platform

| Platform | Base URL |
|---|---|
| Web / PWA | `/api` (reverse proxy serves the Flutter build and the API under `/api`) |
| Android emulator | `http://10.0.2.2:8000/api` |
| iOS simulator / real device / production | `https://yourdomain.com/api` |

---

## Endpoints

| Method | URI | Auth | Purpose |
|---|---|---|---|
| POST | `/api/weather` | No | Current conditions for a coordinate |
| POST | `/api/forecast` | No | Hourly forecast for a coordinate |
| POST | `/api/geocode` | No | Reverse geocode a coordinate |
| GET | `/api/weather/icon` | No | Proxy a weather icon image |
| POST | `/api/analyze-heat-location` | No | Fetch + store the heat index for a coordinate |
| POST | `/api/heat-locations` | No | List current heat-location readings |
| GET | `/api/posts` | No | List posts (newest first) |
| GET | `/api/posts/{id}` | No | Show a single post |
| POST | `/api/posts` | Yes | Create a post |
| DELETE | `/api/posts/{id}` | Yes | Delete a post (owner only) |
| GET | `/api/profile` | Yes | Current user's profile |
| POST | `/api/logout` | Yes | Revoke the current token |
| GET | `/api/auth/google/redirect` | No | Redirect to the Google consent screen |
| GET | `/api/auth/google/callback` | No | OAuth callback (issues a Sanctum token) |

See [`docs/api-docs.md`](docs/api-docs.md) for full request/response shapes, validation rules, error codes, and the data models.

---

## Authentication

Authentication is handled **server-side** via Google OAuth. The client never holds the Google credentials; it redirects the browser to the consent screen and later receives a Sanctum token.

1. Redirect the browser to `GET /api/auth/google/redirect?returnTo=<target>`.
2. Google redirects back to `GET /api/auth/google/callback?code=<code>&state=<returnTo>`.
3. The server exchanges the code, fetches userinfo, upserts the user, and issues a Sanctum token.
4. The browser is redirected to `<returnTo>#token=<sanctum-token>` (or `<returnTo>#error=1` on failure).

Send the token on every authenticated request:

```
Authorization: Bearer <sanctum-token>
```

On a `401`, the client should clear the stored token and redirect the user to the Profile screen.

---

## Testing

```bash
composer run test
# or
php artisan test
```

The suite uses [Pest](https://pestphp.com/) and covers authentication, posts, heat locations, and the Google weather proxy.

---

## Documentation

- [`docs/api-docs.md`](docs/api-docs.md) — authoritative API reference (endpoints, models, OAuth flow, client checklist).
- [`docs/endpoint-responses.md`](docs/endpoint-responses.md) — real Google payload examples.

---

## License

This project is open-sourced software licensed under the [MIT license](https://opensource.org/licenses/MIT).
