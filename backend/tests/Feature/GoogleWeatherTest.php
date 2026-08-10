<?php

use App\Exceptions\GoogleApiException;
use App\Services\GoogleWeatherService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.google.api_key', 'test-google-key');
});

test('current conditions proxied from the Google Weather API', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => ['temperature' => 32.5],
        ], 200),
    ]);

    $this->postJson('/api/weather', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'currentConditions' => ['temperature' => 32.5],
    ]);

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/v1/currentConditions:lookup')
            && $request['location']['latitude'] == 37.7749
            && $request['key'] === 'test-google-key';
    });
});

test('6-hour forecast proxied from the Google Weather API', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'hours' => ['forecast' => ['sunny']],
        ], 200),
    ]);

    $this->postJson('/api/forecast', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'hours' => ['forecast' => ['sunny']],
    ]);

    Http::assertSent(function ($request) {
        return str_contains($request->url(), '/v1/forecast/hours:lookup')
            && $request['hours'] == 6;
    });
});

test('reverse geocoding proxied from the Google Geocode API', function (): void {
    Http::fake([
        'geocode.googleapis.com/*' => Http::response([
            'formattedAddress' => '1 Market St, San Francisco, CA',
        ], 200),
    ]);

    $this->postJson('/api/geocode', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'formattedAddress' => '1 Market St, San Francisco, CA',
    ]);
});

test('validation failures return 400 with a message', function (): void {
    $this->postJson('/api/weather', ['latitude' => 'nope'])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});

test('upstream connection failures return 502 with a message', function (): void {
    Http::fake(function () {
        throw new ConnectionException('Connection refused');
    });

    $this->postJson('/api/weather', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'Google service is currently unreachable. Please try again later.',
    ]);
});

test('missing API key returns 502 instead of leaking config', function (): void {
    config()->set('services.google.api_key', '');

    $this->postJson('/api/weather', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'Google API key is not configured.',
    ]);
});

test('service throws GoogleApiException on upstream error status', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response(['error' => 'boom'], 500),
    ]);

    expect(fn () => app(GoogleWeatherService::class)->currentConditions(37.7749, -122.4194))
        ->toThrow(GoogleApiException::class);
});