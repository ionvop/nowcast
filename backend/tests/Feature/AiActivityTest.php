<?php

use App\Exceptions\OpenRouterApiException;
use App\Services\OpenRouterService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.openrouter.api_key', 'test-openrouter-key');
    config()->set('services.openrouter.model', 'deepseek/deepseek-v4-flash-0731:online');
});

test('ai activities returns weather-aware suggestions', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [
                [
                    'message' => [
                        'content' => json_encode([
                            'suggestions' => [
                                [
                                    'name' => 'Golden Gate Park',
                                    'category' => 'outdoor',
                                    'description' => 'A large urban park with gardens and trails.',
                                    'reason' => 'Mild temperatures make a stroll comfortable.',
                                    'url' => 'https://www.goldengatepark.org/',
                                ],
                                [
                                    'name' => 'SFMOMA',
                                    'category' => 'cultural',
                                    'description' => 'A modern art museum in downtown San Francisco.',
                                    'reason' => 'Rain is expected, so an indoor activity fits.',
                                    'url' => null,
                                ],
                            ],
                        ]),
                    ],
                ],
            ],
        ], 200),
    ]);

    $this->postJson('/api/ai/activities', [
        'currentConditions' => [
            'temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS'],
            'weatherCondition' => ['description' => 'Partly cloudy'],
        ],
        'hourlyForecast' => ['forecastHours' => []],
        'dailyForecast' => ['forecastDays' => []],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
        'placeName' => 'San Francisco',
    ])->assertOk()->assertJson([
        'suggestions' => [
            [
                'name' => 'Golden Gate Park',
                'category' => 'outdoor',
                'description' => 'A large urban park with gardens and trails.',
                'reason' => 'Mild temperatures make a stroll comfortable.',
                'url' => 'https://www.goldengatepark.org/',
            ],
            [
                'name' => 'SFMOMA',
                'category' => 'cultural',
                'description' => 'A modern art museum in downtown San Francisco.',
                'reason' => 'Rain is expected, so an indoor activity fits.',
            ],
        ],
    ]);

    Http::assertSent(function ($request) {
        $body = $request->data();

        return $request->url() === 'https://openrouter.ai/api/v1/chat/completions'
            && $request->hasHeader('Authorization', 'Bearer test-openrouter-key')
            && $body['model'] === 'deepseek/deepseek-v4-flash-0731:online'
            && $body['response_format']['type'] === 'json_schema'
            && $body['response_format']['json_schema']['strict'] === true
            && $body['response_format']['json_schema']['schema']['required'] === ['suggestions']
            && $body['response_format']['json_schema']['schema']['properties']['suggestions']['items']['required']
                === ['name', 'category', 'description', 'reason', 'url']
            && $body['tools'][0]['type'] === 'openrouter:web_search'
            && $body['messages'][0]['role'] === 'system'
            && $body['messages'][1]['role'] === 'user'
            && str_contains($body['messages'][1]['content'], 'currentConditions')
            && str_contains($body['messages'][1]['content'], 'San Francisco');
    });
});

test('ai activities requires currentConditions', function (): void {
    $this->postJson('/api/ai/activities', [
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(400)->assertJsonStructure(['message']);
});

test('ai activities requires latitude', function (): void {
    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'longitude' => -122.4194,
    ])->assertStatus(400)->assertJsonStructure(['message']);
});

test('ai activities rejects an invalid latitude', function (): void {
    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 'nope',
        'longitude' => -122.4194,
    ])->assertStatus(400)->assertJsonStructure(['message']);
});

test('ai activities returns 502 when OpenRouter is unreachable', function (): void {
    Http::fake(function () {
        throw new ConnectionException('Connection refused');
    });

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service is currently unreachable. Please try again later.',
    ]);
});

test('ai activities returns 502 when the API key is missing', function (): void {
    config()->set('services.openrouter.api_key', '');

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'AI API key is not configured.',
    ]);
});

test('ai activities returns 502 when the model output is not JSON', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => 'not json']]],
        ], 200),
    ]);

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('ai activities returns 502 when suggestions are missing', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode([])]]],
        ], 200),
    ]);

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('ai activities returns 502 when suggestions are empty', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode([
                'suggestions' => [],
            ])]]],
        ], 200),
    ]);

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('ai activities returns 502 when a suggestion is missing a required field', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode([
                'suggestions' => [
                    [
                        'name' => 'Golden Gate Park',
                        'category' => 'outdoor',
                        'description' => 'A large urban park.',
                        'url' => null,
                    ],
                ],
            ])]]],
        ], 200),
    ]);

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('ai activities drops an invalid suggestion URL', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode([
                'suggestions' => [
                    [
                        'name' => 'Golden Gate Park',
                        'category' => 'outdoor',
                        'description' => 'A large urban park.',
                        'reason' => 'Mild temperatures make a stroll comfortable.',
                        'url' => 'not-a-url',
                    ],
                ],
            ])]]],
        ], 200),
    ]);

    $this->postJson('/api/ai/activities', [
        'currentConditions' => ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        'latitude' => 37.7749,
        'longitude' => -122.4194,
    ])->assertOk()->assertJson([
        'suggestions' => [
            [
                'name' => 'Golden Gate Park',
                'category' => 'outdoor',
                'description' => 'A large urban park.',
                'reason' => 'Mild temperatures make a stroll comfortable.',
            ],
        ],
    ]);
});

test('service throws OpenRouterApiException on upstream error status', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response(['error' => 'boom'], 500),
    ]);

    expect(fn () => app(OpenRouterService::class)->suggestActivities(
        ['temperature' => ['degrees' => 18.0, 'unit' => 'CELSIUS']],
        [],
        [],
        37.7749,
        -122.4194,
        'San Francisco',
    ))->toThrow(OpenRouterApiException::class);
});