<?php

use App\Models\User;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.google.client_id', 'test-client-id');
    config()->set('services.google.client_secret', 'test-client-secret');
    config()->set('services.google.redirect', 'http://localhost/api/auth/google/callback');
    config()->set('app.url', 'http://localhost');
});

test('profile returns 401 with a fixed message when unauthenticated', function (): void {
    $this->getJson('/api/profile')
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);
});

test('profile returns the authenticated user', function (): void {
    $user = User::factory()->create([
        'name' => 'Ada Lovelace',
        'email' => 'ada@example.com',
    ]);

    $this->actingAs($user, 'sanctum')
        ->getJson('/api/profile')
        ->assertOk()
        ->assertJson([
            'id' => $user->id,
            'name' => 'Ada Lovelace',
            'email' => 'ada@example.com',
        ]);
});

test('logout returns 401 when unauthenticated', function (): void {
    $this->postJson('/api/logout')
        ->assertStatus(401)
        ->assertJson(['message' => 'Unauthorized.']);
});

test('logout revokes the current token', function (): void {
    $user = User::factory()->create();
    $token = $user->createToken('nowcast')->plainTextToken;

    $this->withToken($token)
        ->postJson('/api/logout')
        ->assertOk()
        ->assertJson(['message' => 'Logged out.']);

    // The token row is removed from the database.
    $this->assertDatabaseCount('personal_access_tokens', 0);
});

test('oauth redirect sends the browser to the Google consent screen', function (): void {
    $response = $this->get('/api/auth/google/redirect?returnTo=http://localhost');
    $response->assertRedirect();

    $location = $response->headers->get('Location');
    expect($location)->toContain('https://accounts.google.com/o/oauth2/v2/auth');
    expect($location)->toContain('client_id=test-client-id');
    expect($location)->toContain('redirect_uri='.urlencode('http://localhost/api/auth/google/callback'));
    expect($location)->toContain('state='.urlencode('http://localhost'));
});

test('oauth callback exchanges the code, upserts the user, and issues a token', function (): void {
    Http::fake([
        'oauth2.googleapis.com/*' => Http::response([
            'access_token' => 'google-access-token',
        ], 200),
        'www.googleapis.com/*' => Http::response([
            'email' => 'ada@example.com',
            'name' => 'Ada Lovelace',
            'picture' => 'https://example.com/avatar.png',
        ], 200),
        'example.com/*' => Http::response('avatar-bytes', 200, ['Content-Type' => 'image/png']),
    ]);

    $response = $this->get('/api/auth/google/callback?code=test-code&state='.urlencode('http://localhost'));
    $response->assertRedirect();

    $location = $response->headers->get('Location');
    expect($location)->toStartWith('http://localhost#token=');

    $token = substr($location, strlen('http://localhost#token='));
    expect($token)->not->toBeEmpty();

    $this->assertDatabaseHas('users', [
        'email' => 'ada@example.com',
        'name' => 'Ada Lovelace',
    ]);

    // The issued token works against a protected endpoint.
    $this->withToken($token)
        ->getJson('/api/profile')
        ->assertOk()
        ->assertJson(['email' => 'ada@example.com']);
});

test('oauth callback inlines the avatar as a base64 data URI', function (): void {
    Http::fake([
        'oauth2.googleapis.com/*' => Http::response(['access_token' => 'google-access-token'], 200),
        'www.googleapis.com/*' => Http::response([
            'email' => 'ada@example.com',
            'name' => 'Ada Lovelace',
            'picture' => 'https://example.com/avatar.png',
        ], 200),
        'example.com/*' => Http::response('avatar-bytes', 200, ['Content-Type' => 'image/png']),
    ]);

    $this->get('/api/auth/google/callback?code=test-code&state='.urlencode('http://localhost'))
        ->assertRedirect();

    $this->assertDatabaseHas('users', [
        'email' => 'ada@example.com',
        'avatar' => 'data:image/png;base64,'.base64_encode('avatar-bytes'),
    ]);
});

test('oauth callback redirects with an error fragment on upstream failure', function (): void {
    Http::fake([
        'oauth2.googleapis.com/*' => Http::response(['error' => 'invalid_grant'], 400),
    ]);

    $this->get('/api/auth/google/callback?code=bad-code&state='.urlencode('http://localhost'))
        ->assertRedirect('http://localhost#error=1');
});

test('oauth callback falls back to the web origin for an unknown return target', function (): void {
    Http::fake([
        'oauth2.googleapis.com/*' => Http::response(['access_token' => 'google-access-token'], 200),
        'www.googleapis.com/*' => Http::response([
            'email' => 'ada@example.com',
            'name' => 'Ada Lovelace',
        ], 200),
    ]);

    $response = $this->get('/api/auth/google/callback?code=test-code&state='.urlencode('https://evil.example.com'));
    $response->assertRedirect();

    expect($response->headers->get('Location'))->toStartWith('http://localhost#token=');
});

test('oauth redirect carries the native return target in state while keeping the backend callback as redirect_uri', function (): void {
    $response = $this->get('/api/auth/google/redirect?returnTo=nowcast://auth');
    $response->assertRedirect();

    $location = $response->headers->get('Location');
    expect($location)->toContain('https://accounts.google.com/o/oauth2/v2/auth');
    expect($location)->toContain('client_id=test-client-id');
    // The redirect_uri sent to Google is still the backend callback, so the
    // server can exchange the code and issue a Sanctum token.
    expect($location)->toContain('redirect_uri='.urlencode('http://localhost/api/auth/google/callback'));
    expect($location)->toContain('state='.urlencode('nowcast://auth'));
});

test('oauth callback returns the token to the native scheme after consent', function (): void {
    Http::fake([
        'oauth2.googleapis.com/*' => Http::response(['access_token' => 'google-access-token'], 200),
        'www.googleapis.com/*' => Http::response([
            'email' => 'ada@example.com',
            'name' => 'Ada Lovelace',
        ], 200),
    ]);

    $response = $this->get('/api/auth/google/callback?code=test-code&state='.urlencode('nowcast://auth'));
    $response->assertRedirect();

    $location = $response->headers->get('Location');
    expect($location)->toStartWith('nowcast://auth#token=');

    $token = substr($location, strlen('nowcast://auth#token='));
    expect($token)->not->toBeEmpty();

    // The issued token works against a protected endpoint.
    $this->withToken($token)
        ->getJson('/api/profile')
        ->assertOk()
        ->assertJson(['email' => 'ada@example.com']);
});

test('oauth callback redirects to the native scheme with an error fragment on upstream failure', function (): void {
    Http::fake([
        'oauth2.googleapis.com/*' => Http::response(['error' => 'invalid_grant'], 400),
    ]);

    $this->get('/api/auth/google/callback?code=bad-code&state='.urlencode('nowcast://auth'))
        ->assertRedirect('nowcast://auth#error=1');
});
