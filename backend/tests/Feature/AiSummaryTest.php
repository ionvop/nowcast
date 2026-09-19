<?php

use App\Exceptions\OpenRouterApiException;
use App\Services\OpenRouterService;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.openrouter.api_key', 'test-openrouter-key');
    config()->set('services.openrouter.model', 'deepseek/deepseek-v4-flash-0731:online');
});

test('ai summary returns the model analysis', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [
                [
                    'message' => [
                        'content' => json_encode([
                            'summary' => 'Hot and humid with a heat index of 41°C.',
                            'healthAdvice' => 'Limit strenuous outdoor activity and stay hydrated.',
                            'articleUrl' => 'https://www.cdc.gov/heat-health/about/index.html',
                        ]),
                    ],
                ],
            ],
        ], 200),
    ]);

    $this->postJson('/api/ai/summary', [
        'currentConditions' => [
            'temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS'],
            'heatIndex' => ['degrees' => 41.0, 'unit' => 'CELSIUS'],
        ],
        'hourlyForecast' => ['forecastHours' => []],
        'dailyForecast' => ['forecastDays' => []],
    ])->assertOk()->assertJson([
        'summary' => 'Hot and humid with a heat index of 41°C.',
        'healthAdvice' => 'Limit strenuous outdoor activity and stay hydrated.',
        'articleUrl' => 'https://www.cdc.gov/heat-health/about/index.html',
    ]);

    Http::assertSent(function ($request) {
        $body = $request->data();

        return $request->url() === 'https://openrouter.ai/api/v1/chat/completions'
            && $request->hasHeader('Authorization', 'Bearer test-openrouter-key')
            && $body['model'] === 'deepseek/deepseek-v4-flash-0731:online'
            && $body['response_format'] === ['type' => 'json_object']
            && $body['messages'][0]['role'] === 'system'
            && $body['messages'][1]['role'] === 'user'
            && str_contains($body['messages'][1]['content'], 'currentConditions');
    });
});

test('ai summary requires currentConditions', function (): void {
    $this->postJson('/api/ai/summary', [])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});

test('ai summary returns 502 when OpenRouter is unreachable', function (): void {
    Http::fake(function () {
        throw new ConnectionException('Connection refused');
    });

    $this->postJson('/api/ai/summary', [
        'currentConditions' => ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service is currently unreachable. Please try again later.',
    ]);
});

test('ai summary returns 502 when the API key is missing', function (): void {
    config()->set('services.openrouter.api_key', '');

    $this->postJson('/api/ai/summary', [
        'currentConditions' => ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
    ])->assertStatus(502)->assertJson([
        'message' => 'AI API key is not configured.',
    ]);
});

test('ai summary returns 502 when the model output is not JSON', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => 'not json']]],
        ], 200),
    ]);

    $this->postJson('/api/ai/summary', [
        'currentConditions' => ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('ai summary returns 502 when a required field is missing', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode([
                'summary' => 'Hot.',
                'healthAdvice' => 'Stay hydrated.',
            ])]]],
        ], 200),
    ]);

    $this->postJson('/api/ai/summary', [
        'currentConditions' => ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('ai summary returns 502 when the article URL is invalid', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => json_encode([
                'summary' => 'Hot.',
                'healthAdvice' => 'Stay hydrated.',
                'articleUrl' => 'not-a-url',
            ])]]],
        ], 200),
    ]);

    $this->postJson('/api/ai/summary', [
        'currentConditions' => ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
    ])->assertStatus(502)->assertJson([
        'message' => 'AI service returned an invalid response.',
    ]);
});

test('service throws OpenRouterApiException on upstream error status', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response(['error' => 'boom'], 500),
    ]);

    expect(fn () => app(OpenRouterService::class)->summarize(
        ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
        [],
        [],
    ))->toThrow(OpenRouterApiException::class);
});