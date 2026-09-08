<?php

use App\Models\WeatherLocation;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.google.api_key', 'test-google-key');
});

test('analyze-weather-location stores the full payload and returns it', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentTime' => '2025-01-28T22:04:12.025273178Z',
            'isDaytime' => true,
            'weatherCondition' => [
                'iconBaseUri' => 'https://maps.gstatic.com/weather/v1/sunny',
                'description' => ['text' => 'Sunny', 'languageCode' => 'en'],
                'type' => 'CLEAR',
            ],
            'temperature' => ['degrees' => 28.5, 'unit' => 'CELSIUS'],
            'feelsLikeTemperature' => ['degrees' => 31.2, 'unit' => 'CELSIUS'],
            'heatIndex' => ['degrees' => 33.0, 'unit' => 'CELSIUS'],
            'relativeHumidity' => 65,
        ], 200),
    ]);

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'latitude' => 37.7749,
        'longitude' => -122.4194,
        'data' => [
            'temperature' => ['degrees' => 28.5, 'unit' => 'CELSIUS'],
            'heatIndex' => ['degrees' => 33.0, 'unit' => 'CELSIUS'],
        ],
    ]);

    $this->assertDatabaseHas('weather_locations', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);
});

test('analyze-weather-location persists the entire payload to the data column', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentTime' => '2025-01-28T22:04:12.025273178Z',
            'weatherCondition' => [
                'iconBaseUri' => 'https://maps.gstatic.com/weather/v1/partly_cloudy',
                'description' => ['text' => 'Partly cloudy', 'languageCode' => 'en'],
                'type' => 'PARTLY_CLOUDY',
            ],
            'temperature' => ['degrees' => 28.5, 'unit' => 'CELSIUS'],
            'feelsLikeTemperature' => ['degrees' => 31.2, 'unit' => 'CELSIUS'],
            'dewPoint' => ['degrees' => 22.1, 'unit' => 'CELSIUS'],
            'relativeHumidity' => 65,
            'heatIndex' => ['degrees' => 33.0, 'unit' => 'CELSIUS'],
            'wind' => [
                'direction' => ['degrees' => 180, 'cardinal' => 'SOUTH'],
                'speed' => ['value' => 12.3, 'unit' => 'KILOMETERS_PER_HOUR'],
            ],
            'visibility' => ['distance' => 16, 'unit' => 'KILOMETERS'],
            'cloudCover' => 10,
        ], 200),
    ]);

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk();

    $location = WeatherLocation::query()->first();

    expect($location)->not->toBeNull();
    expect($location->data['temperature']['degrees'])->toBe(28.5);
    expect($location->data['heatIndex']['degrees'])->toBe(33);
    expect($location->data['weatherCondition']['type'])->toBe('PARTLY_CLOUDY');
    expect($location->data['relativeHumidity'])->toBe(65);
});

test('analyze-weather-location stores an empty payload when unavailable', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([], 200),
    ]);

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'data' => [],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $this->assertDatabaseHas('weather_locations', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);
});

test('analyze-weather-location deduplicates readings within ~100 m', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'temperature' => ['degrees' => 40.0, 'unit' => 'CELSIUS'],
        ], 200),
    ]);

    WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 39.5, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk();

    $this->assertDatabaseCount('weather_locations', 1);
    $this->assertDatabaseHas('weather_locations', ['latitude' => 37.7749]);
});

test('analyze-weather-location keeps readings farther than ~100 m', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'temperature' => ['degrees' => 40.0, 'unit' => 'CELSIUS'],
        ], 200),
    ]);

    WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 39.5, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7849,
        'longitude' => -122.4194,
    ])->assertOk();

    $this->assertDatabaseCount('weather_locations', 2);
});

test('analyze-weather-location purges stale readings before inserting', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'temperature' => ['degrees' => 40.0, 'unit' => 'CELSIUS'],
        ], 200),
    ]);

    $stale = WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 30.0, 'unit' => 'CELSIUS']],
        'latitude' => 10.0,
        'longitude' => 10.0,
    ]);
    $stale->forceFill(['created_at' => now()->subHours(2)])->save();

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk();

    $this->assertDatabaseCount('weather_locations', 1);
    $this->assertDatabaseHas('weather_locations', ['latitude' => 37.7749]);
});

test('weather-locations returns all current readings', function (): void {
    WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 41.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 38.5, 'unit' => 'CELSIUS']],
        'latitude' => 40.7128,
        'longitude' => -74.0060,
    ]);

    $this->postJson('/api/weather-locations')
        ->assertOk()
        ->assertJsonCount(2);
});

test('weather-locations purges stale readings', function (): void {
    WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 41.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $stale = WeatherLocation::create([
        'data' => ['temperature' => ['degrees' => 30.0, 'unit' => 'CELSIUS']],
        'latitude' => 10.0,
        'longitude' => 10.0,
    ]);
    $stale->forceFill(['created_at' => now()->subHours(2)])->save();

    $this->postJson('/api/weather-locations')
        ->assertOk()
        ->assertJsonCount(1)
        ->assertJsonFragment(['latitude' => 37.7749]);
});

test('analyze-weather-location returns 502 when Google is unreachable', function (): void {
    Http::fake(function () {
        throw new Illuminate\Http\Client\ConnectionException('Connection refused');
    });

    $this->postJson('/api/analyze-weather-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'Google service is currently unreachable. Please try again later.',
    ]);
});

test('analyze-weather-location validation failures return 400', function (): void {
    $this->postJson('/api/analyze-weather-location', ['latitude' => 'nope'])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});