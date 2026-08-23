# Backend Handoff: Google OAuth returns to `localhost:8000` on Android

**Date:** 2026-08-24
**Reporter:** Frontend (Flutter) team
**Severity:** Bug — native Google sign-in is broken on Android

## Summary

When signing in on Android, the user is redirected to Google's consent screen and
then bounced to `localhost:8000/...` instead of back into the app. This breaks
the native OAuth flow.

The frontend is behaving correctly. The defect is in the backend's use of a
**single, web-origin `redirect_uri`** for both web and native clients.

## How the flow works today

1. The Flutter client calls `GET /api/auth/google/redirect?returnTo=nowcast://auth`.
2. The backend builds the Google consent URL via `GoogleOAuthService::buildAuthUrl()`
   and `302`s the browser to `accounts.google.com`.
3. After the user approves, Google redirects the browser to the backend's configured
   `redirect_uri`.
4. The backend's `/auth/google/callback` handler issues a Sanctum token and sends the
   browser to `<returnTo>#token=...`. On native this should be `nowcast://auth#token=...`,
   which the app intercepts via its `nowcast://auth` deep link.

## The problem

The backend's `redirect_uri` (env `GOOGLE_REDIRECT_URI`) is a **single web URL**. That
URL is sent to Google regardless of whether the requesting client is web or native.

- Web client → `returnTo` is the web origin, `redirect_uri` is the web URL → works.
- Android client → `returnTo` is `nowcast://auth`, **but** the `redirect_uri` sent to
  Google is still the web URL. Google redirects the browser to the web URL, and the
  `nowcast://auth` deep link is never triggered. The browser lands on `localhost:8000`
  (or the configured web origin) with no app to receive the callback.

### Exact code locations (in `../backend/`)

`app/Services/GoogleOAuthService.php`

```php
public function buildAuthUrl(string $state): string
{
    $query = http_build_query([
        'client_id'     => $this->clientId(),
        'redirect_uri'  => $this->redirectUri(),   // <-- single value, used for everything
        'response_type' => 'code',
        'scope'         => 'email profile',
        'state'         => $state,
    ]);
    // ...
}

protected function redirectUri(): string
{
    return $this->required('redirect', 'Google OAuth redirect URI is not configured.');
}
```

- `config/services.php` defines a single `redirect` + `native_scheme`:

```php
'google' => [
    'api_key'       => env('GOOGLE_API_KEY'),
    'client_id'     => env('GOOGLE_CLIENT_ID'),
    'client_secret' => env('GOOGLE_CLIENT_SECRET'),
    'redirect'      => env('GOOGLE_REDIRECT_URI'),              // web/web-pwa callback
    'native_scheme' => env('GOOGLE_NATIVE_SCHEME', 'nowcast'),  // not usable as a redirect_uri today
],
```

- `app/Http/Controllers/GoogleOAuthController.php` already sanitizes the client's
  `returnTo` (`sanitizeReturnTo()`) and allows both the web origin and the native
  `nowcast` scheme, so the return-target routing is in place. Only the
  consent-screen `redirect_uri` is wrong.

## Desired behavior

- **Web / PWA:** `redirect_uri` = the backend callback URL (current behavior).
- **Android / iOS (native):** `redirect_uri` = the native custom scheme, e.g.
  `nowcast://auth` (or `nowcast://oauth2callback`).

### Suggested endpoint/parameter contract (to confirm)

Keep the client contract unchanged. The client already passes `returnTo` on
`/auth/google/redirect?returnTo=...`. Server-side, the backend should select the
`redirect_uri` based on the incoming `returnTo` scheme (or an inferred client type):

```
returnTo scheme == native_scheme  -> use native redirect_uri
returnTo scheme == http(s) web/   -> use web redirect_uri
```

This requires a **second** Google OAuth redirect URI configured in the backend env,
e.g.:

- `GOOGLE_REDIRECT_URI` (`web`) = `https://<host>/<path>/api/auth/google/callback`
- `GOOGLE_NATIVE_REDIRECT_URI` (`native`) = `nowcast://auth`

## Required on the Google side (outside this repo)

- Register `nowcast://auth` as an **Authorized redirect URI** in the Google Cloud
  Console OAuth client (alongside the existing web redirect URI), so Google does not
  reject the native redirect.
- Note: Google treats redirect URIs literally (exact match, no wildcards). A native
  custom-scheme URI must be listed exactly as the backend sends it.

## Acceptance criteria

- [ ] Web / PWA sign-in still works and returns the token via the web callback.
- [ ] Android sign-in returns to `nowcast://auth#token=...` after consent.
- [ ] The app intercepts the deep link and persists the Sanctum token.
- [ ] Rejected consent returns `nowcast://auth#error=1`.

## Out of scope

- Changing the Flutter client contract (the client is already correct).
- Everything not related to the OAuth `redirect_uri` selection (e.g. weather,
  geocoding, posts).

## Questions for the backend agent

1. Is the backend currently serving web OAuth with a JS-launches or a pure server-side
   callback? (Affects whether the web `redirect_uri` must stay as-is.)
2. How does the backend want to detect "native client vs web client"? Expected:
   infer from the `returnTo` scheme (safe, already sanitized) rather than user-agent
   sniffing, which is unreliable in an external browser context.