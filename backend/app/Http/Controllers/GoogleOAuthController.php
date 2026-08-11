<?php

namespace App\Http\Controllers;

use App\Exceptions\GoogleApiException;
use App\Models\User;
use App\Services\GoogleOAuthService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

class GoogleOAuthController extends Controller
{
    /**
     * The query parameter used to carry the client's return target.
     */
    protected const RETURN_TO_PARAM = 'returnTo';

    /**
     * The fragment key used to deliver the issued Sanctum token.
     */
    protected const TOKEN_FRAGMENT = 'token';

    /**
     * The fragment key used to signal an OAuth failure.
     */
    protected const ERROR_FRAGMENT = 'error';

    public function __construct(private readonly GoogleOAuthService $oauth)
    {
    }

    /**
     * Redirect the browser to the Google consent screen.
     *
     * The optional "returnTo" query parameter names where the callback should
     * send the browser (and the issued token) afterwards. It is carried
     * through the OAuth "state" parameter so it survives the round-trip.
     */
    public function redirect(Request $request): RedirectResponse
    {
        $returnTo = $this->sanitizeReturnTo($request->query(self::RETURN_TO_PARAM));

        return redirect()->away($this->oauth->buildAuthUrl($returnTo));
    }

    /**
     * Handle the Google OAuth callback.
     *
     * Exchanges the authorization code, upserts the user, issues a Sanctum
     * token, and redirects the browser back to the client with the token in
     * the URL fragment (e.g. "#token=..."). On failure it redirects with an
     * "#error=..." fragment instead.
     */
    public function callback(Request $request): RedirectResponse
    {
        $returnTo = $this->sanitizeReturnTo($request->query('state'));

        try {
            $token = $this->issueToken($request->query('code'));
        } catch (GoogleApiException) {
            return $this->redirectWithError($returnTo);
        }

        return redirect()->away($returnTo.'#'.self::TOKEN_FRAGMENT.'='.$token);
    }

    /**
     * Exchange the code, upsert the user, and return a fresh Sanctum token.
     *
     * @throws GoogleApiException When any upstream Google call fails.
     */
    protected function issueToken(?string $code): string
    {
        if ($code === null || $code === '') {
            throw new GoogleApiException('Missing authorization code.');
        }

        $tokens = $this->oauth->exchangeCode($code);
        $accessToken = $tokens['access_token'] ?? null;

        if (! is_string($accessToken) || $accessToken === '') {
            throw new GoogleApiException('Google did not return an access token.');
        }

        $info = $this->oauth->fetchUserInfo($accessToken);
        $email = $info['email'] ?? null;

        if (! is_string($email) || $email === '') {
            throw new GoogleApiException('Google did not return a user email.');
        }

        $user = User::updateOrCreate(
            ['email' => $email],
            [
                'name' => $info['name'] ?? $email,
                'avatar' => $this->oauth->inlineAvatar($info['picture'] ?? null),
            ],
        );

        return $user->createToken('nowcast')->plainTextToken;
    }

    /**
     * Redirect the browser back to the client signalling an OAuth failure.
     */
    protected function redirectWithError(string $returnTo): RedirectResponse
    {
        return redirect()->away($returnTo.'#'.self::ERROR_FRAGMENT.'=1');
    }

    /**
     * Validate and normalize the client's return target.
     *
     * Only the configured web origin and the native custom scheme are
     * allowed, preventing open-redirect abuse. Anything else falls back to
     * the configured web origin.
     */
    protected function sanitizeReturnTo(mixed $value): string
    {
        $fallback = $this->webOrigin();

        if (! is_string($value) || $value === '') {
            return $fallback;
        }

        $url = parse_url($value);

        if ($url === false || ! isset($url['scheme'], $url['host'])) {
            return $fallback;
        }

        $scheme = strtolower($url['scheme']);
        $host = strtolower($url['host']);

        if ($scheme === 'http' || $scheme === 'https') {
            if ($host === strtolower(parse_url($fallback, PHP_URL_HOST) ?: '')) {
                return $value;
            }

            return $fallback;
        }

        if ($scheme === $this->nativeScheme()) {
            return $value;
        }

        return $fallback;
    }

    /**
     * The default web origin used as the OAuth return target.
     */
    protected function webOrigin(): string
    {
        return config('app.url', 'http://localhost');
    }

    /**
     * The native custom scheme used to return the token to mobile clients.
     */
    protected function nativeScheme(): string
    {
        return config('services.google.native_scheme', 'nowcast');
    }
}
