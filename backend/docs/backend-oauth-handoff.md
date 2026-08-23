# Backend Handoff: Google OAuth returns to `localhost:8000` on Android

**Date:** 2026-08-24
**Reporter:** Frontend (Flutter) team
**Severity:** Bug — native Google sign-in is broken on Android

## Summary

When signing in on Android, the user is redirected to Google's consent screen and
then bounced to `localhost:8000/...` instead of back into the app. This breaks
the native OAuth flow.

The frontend is behaving correctly. The defect is **not** the backend's use of a
single `redirect_uri` — the backend already routes native `returnTo` correctly.
The real cause is that `GOOGLE_REDIRECT_URI` points to `localhost:8000`, a
dev-machine URL that a phone cannot reach, so the callback never completes.

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

The backend's `redirect_uri` (env `GOOGLE_REDIRECT_URI`) is currently set to
`http://localhost:8000/api/auth/google/callback` in `.env`. That URL is sent to
Google regardless of whether the requesting client is web or native, which is
correct — the backend must receive the authorization code to exchange it for a
Sanctum token. The breakage is that `localhost:8000` is only reachable on the
developer's machine, not from a phone.

- Web client → `returnTo` is the web origin, `redirect_uri` is the web URL →
  works when the callback URL is reachable.
- Android client → `returnTo` is `nowcast://auth`. The backend already handles
  this: `sanitizeReturnTo()` allows the native scheme, and the callback
  redirects to `nowcast://auth#token=...`. The only requirement is that the
  `redirect_uri` sent to Google is a URL the phone's browser can reach (a
  deployed backend or a tunnel). With `localhost:8000`, the phone lands on a
  dead address and the deep link is never triggered.

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
  `nowcast` scheme, so the return-target routing is in place. The callback already
  redirects to `$returnTo#token=...`, which works for `nowcast://auth`. The
  consent-screen `redirect_uri` is **not** wrong; it must stay the backend callback
  so the server can exchange the code and issue a Sanctum token.

## Desired behavior

- **Web / PWA:** `redirect_uri` = the backend callback URL (current behavior).
- **Android / iOS (native):** `redirect_uri` = the backend callback URL, reachable
  from the device. The native custom scheme (`nowcast://auth`) is used only as the
  return target after the code has been exchanged, not as the Google `redirect_uri`.

### Why the native scheme cannot be the Google `redirect_uri`

If `redirect_uri` were `nowcast://auth`, Google would redirect the browser straight
back to the app with `?code=...`. The backend would never receive the code, so it
could not exchange it for a Sanctum token — breaking the server-side flow the
acceptance criteria require. The backend callback must remain the `redirect_uri`
for both clients.

### Config added

A `GOOGLE_NATIVE_REDIRECT_URI` env key (config `services.google.native_redirect`)
was added for documentation and future use. It is **not** sent to Google today.

## Required on the Google side (outside this repo)

- Register the **backend callback URL** (the value of `GOOGLE_REDIRECT_URI`) as an
  **Authorized redirect URI** in the Google Cloud Console OAuth client. It must be
  a URL reachable from the device (deployed backend or tunnel), not `localhost:8000`.
- Note: Google treats redirect URIs literally (exact match, no wildcards). The
  registered URI must match the backend's `GOOGLE_REDIRECT_URI` exactly.

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
   callback? **Answer:** Pure server-side. The backend exchanges the code and issues
   the Sanctum token before redirecting the browser to the return target.
2. How does the backend want to detect "native client vs web client"? **Answer:** It
   does not need to. The backend callback is the `redirect_uri` for both clients, and
   the return target is inferred from the already-sanitized `returnTo` scheme.