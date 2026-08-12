<?php

use App\Models\HeatLocation;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.google.api_key', 'test-google-key');
});

test('analyze-heat-location stores a reading and returns the heat index', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => ['feelsLikeTemperature' => ['degrees' => 41.2, 'unit' => 'CELSIUS']],
        ], 200),
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'heatIndex' => 41.2,
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $this->assertDatabaseHas('heat_locations', [
        'heat_index' => 41.2,
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);
});

test('extracts heat index from the real Google nested payload shape', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => [
                'feelsLikeTemperature' => ['degrees' => 31.1, 'unit' => 'CELSIUS'],
                'temperature' => ['degrees' => 28.5, 'unit' => 'CELSIUS'],
            ],
        ], 200),
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'heatIndex' => 31.1,
    ]);
});

test('analyze-heat-location falls back to temperature when feels-like is missing', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => ['temperature' => ['degrees' => 38.0, 'unit' => 'CELSIUS']],
        ], 200),
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'heatIndex' => 38.0,
    ]);
});

test('analyze-heat-location stores a null heat index when unavailable', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => [],
        ], 200),
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'heatIndex' => null,
    ]);

    $this->assertDatabaseHas('heat_locations', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
        'heat_index' => null,
    ]);
});

test('analyze-heat-location deduplicates readings within ~100 m', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => ['feelsLikeTemperature' => ['degrees' => 40.0, 'unit' => 'CELSIUS']],
        ], 200),
    ]);

    HeatLocation::create([
        'heat_index' => 39.5,
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk();

    $this->assertDatabaseCount('heat_locations', 1);
    $this->assertDatabaseHas('heat_locations', ['heat_index' => 40.0]);
});

test('analyze-heat-location keeps readings farther than ~100 m', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => ['feelsLikeTemperature' => ['degrees' => 40.0, 'unit' => 'CELSIUS']],
        ], 200),
    ]);

    HeatLocation::create([
        'heat_index' => 39.5,
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7849,
        'longitude' => -122.4194,
    ])->assertOk();

    $this->assertDatabaseCount('heat_locations', 2);
});

test('analyze-heat-location purges stale and null readings before inserting', function (): void {
    Http::fake([
        'weather.googleapis.com/*' => Http::response([
            'currentConditions' => ['feelsLikeTemperature' => ['degrees' => 40.0, 'unit' => 'CELSIUS']],
        ], 200),
    ]);

    $stale = HeatLocation::create([
        'heat_index' => 30.0,
        'latitude' => 10.0,
        'longitude' => 10.0,
    ]);
    $stale->forceFill(['created_at' => now()->subHours(2)])->save();

    HeatLocation::create([
        'heat_index' => null,
        'latitude' => 20.0,
        'longitude' => 20.0,
    ]);

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk();

    $this->assertDatabaseCount('heat_locations', 1);
    $this->assertDatabaseHas('heat_locations', ['latitude' => 37.7749]);
});

test('heat-locations returns all current readings', function (): void {
    HeatLocation::create([
        'heat_index' => 41.0,
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    HeatLocation::create([
        'heat_index' => 38.5,
        'latitude' => 40.7128,
        'longitude' => -74.0060,
    ]);

    $this->postJson('/api/heat-locations')
        ->assertOk()
        ->assertJsonCount(2);
});

test('heat-locations purges stale and null readings', function (): void {
    HeatLocation::create([
        'heat_index' => 41.0,
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ]);

    $stale = HeatLocation::create([
        'heat_index' => 30.0,
        'latitude' => 10.0,
        'longitude' => 10.0,
    ]);
    $stale->forceFill(['created_at' => now()->subHours(2)])->save();

    HeatLocation::create([
        'heat_index' => null,
        'latitude' => 20.0,
        'longitude' => 20.0,
    ]);

    $this->postJson('/api/heat-locations')
        ->assertOk()
        ->assertJsonCount(1)
        ->assertJsonFragment(['latitude' => 37.7749]);
});

test('analyze-heat-location returns 502 when Google is unreachable', function (): void {
    Http::fake(function () {
        throw new Illuminate\Http\Client\ConnectionException('Connection refused');
    });

    $this->postJson('/api/analyze-heat-location', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'Google service is currently unreachable. Please try again later.',
    ]);
});

test('analyze-heat-location validation failures return 400', function (): void {
    $this->postJson('/api/analyze-heat-location', ['latitude' => 'nope'])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});
