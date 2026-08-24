<?php

namespace App\Services;

use App\Exceptions\GoogleApiException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;

/**
 * Performs the server-side Google OAuth flow on behalf of the Flutter client.
 *
 * The client never holds the Google OAuth credentials; it only redirects the
 * browser to the consent screen and later receives a Sanctum token. All
 * upstream Google calls go through this single service so that error
 * handling and credential resolution stay uniform across endpoints.
 */
class GoogleOAuthService
{
    /**
     * The Google OAuth 2.0 authorization (consent) endpoint.
     */
    protected const AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';

    /**
     * The Google OAuth 2.0 token endpoint.
     */
    protected const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    /**
     * The Google userinfo endpoint.
     */
    protected const USERINFO_URL = 'https://www.googleapis.com/oauth2/v1/userinfo';

    /**
     * Build the Google consent-screen URL for the given OAuth state.
     *
     * The state carries the client's return target so the callback knows
     * where to redirect the browser (and the issued token) afterwards.
     */
    public function buildAuthUrl(string $state): string
    {
        $query = http_build_query([
            'client_id' => $this->clientId(),
            'redirect_uri' => $this->redirectUri(),
            'response_type' => 'code',
            'scope' => 'email profile',
            'state' => $state,
        ]);

        return self::AUTH_URL.'?'.$query;
    }

    /**
     * Exchange an authorization code for an access token.
     *
     * @return array<string, mixed> The decoded token response.
     *
     * @throws GoogleApiException When Google is unreachable or returns an error.
     */
    public function exchangeCode(string $code): array
    {
        try {
            $response = Http::timeout(10)
                ->asForm()
                ->post(self::TOKEN_URL, [
                    'code' => $code,
                    'client_id' => $this->clientId(),
                    'client_secret' => $this->clientSecret(),
                    'redirect_uri' => $this->redirectUri(),
                    'grant_type' => 'authorization_code',
                ]);
        } catch (ConnectionException|RequestException) {
            throw new GoogleApiException('Google service is currently unreachable. Please try again later.');
        }

        if (! $response->successful()) {
            throw new GoogleApiException(
                'Google returned an error. Please try again later.',
                $response->status(),
            );
        }

        return $response->json();
    }

    /**
     * Fetch the authenticated user's profile from Google.
     *
     * @return array<string, mixed> The decoded userinfo payload.
     *
     * @throws GoogleApiException When Google is unreachable or returns an error.
     */
    public function fetchUserInfo(string $accessToken): array
    {
        try {
            $response = Http::timeout(10)
                ->get(self::USERINFO_URL, ['access_token' => $accessToken]);
        } catch (ConnectionException|RequestException) {
            throw new GoogleApiException('Google service is currently unreachable. Please try again later.');
        }

        if (! $response->successful()) {
            throw new GoogleApiException(
                'Google returned an error. Please try again later.',
                $response->status(),
            );
        }

        return $response->json();
    }

    /**
     * Download a Google profile picture and inline it as a base64 data URI.
     *
     * Returns null when no picture is provided or it cannot be fetched, so a
     * missing avatar never breaks the sign-in flow.
     */
    public function inlineAvatar(?string $pictureUrl): ?string
    {
        if ($pictureUrl === null || $pictureUrl === '') {
            return null;
        }

        try {
            $response = Http::timeout(10)->get($pictureUrl);
        } catch (ConnectionException|RequestException) {
            return null;
        }

        if (! $response->successful()) {
            return null;
        }

        $mime = $response->header('Content-Type') ?: 'image/jpeg';
        $base64 = base64_encode($response->body());

        return 'data:'.$mime.';base64,'.$base64;
    }

    /**
     * Resolve the Google OAuth client ID from configuration.
     *
     * @throws GoogleApiException When no client ID is configured.
     */
    protected function clientId(): string
    {
        return $this->required('client_id', 'Google OAuth client ID is not configured.');
    }

    /**
     * Resolve the Google OAuth client secret from configuration.
     *
     * @throws GoogleApiException When no client secret is configured.
     */
    protected function clientSecret(): string
    {
        return $this->required('client_secret', 'Google OAuth client secret is not configured.');
    }

    /**
     * Resolve the Google OAuth redirect URI from configuration.
     *
     * @throws GoogleApiException When no redirect URI is configured.
     */
    protected function redirectUri(): string
    {
        return $this->required('redirect', 'Google OAuth redirect URI is not configured.');
    }

    /**
     * Read a required Google OAuth configuration value.
     *
     * @throws GoogleApiException When the value is missing or empty.
     */
    protected function required(string $key, string $message): string
    {
        $value = config('services.google.'.$key);

        if (is_string($value) && $value !== '') {
            return $value;
        }

        throw new GoogleApiException($message);
    }
}
