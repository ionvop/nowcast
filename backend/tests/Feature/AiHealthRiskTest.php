<?php

use App\Models\HealthProfile;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.openrouter.api_key', 'test-openrouter-key');
    config()->set('services.openrouter.model', 'deepseek/deepseek-v4.1-flash');
});

/**
 * Build a valid model response for the health-risk endpoint.
 *
 * @param  array<string, mixed>  $overrides
 * @return array<string, mixed>
 */
function healthRiskContent(array $overrides = []): array
{
    return array_merge([
        'riskScore' => 62,
        'riskLevel' => 'very_high',
        'thresholdC' => 38.0,
        'thresholdLabel' => 'Clinical fever threshold',
        'summary' => 'Heat strain is likely this afternoon.',
        'uncertainty' => 'Humidity is forecast with moderate confidence.',
        'keyFindings' => ['Peak risk is between 14:00 and 16:00.'],
        'recommendations' => ['Avoid strenuous outdoor work at midday.'],
        'hourly' => [
            [
                'hourIndex' => 0,
                'hour' => 12,
                'probability' => 0.25,
                'coreTempMedianC' => 37.4,
                'coreTempP10C' => 37.1,
                'coreTempP90C' => 37.8,
            ],
            [
                'hourIndex' => 1,
                'hour' => 13,
                'probability' => 0.55,
                'coreTempMedianC' => 37.9,
                'coreTempP10C' => 37.5,
                'coreTempP90C' => 38.3,
            ],
        ],
    ], $overrides);
}

/**
 * Create a user with a saved health profile.
 */
function userWithProfile(): User
{
    $user = User::factory()->create();

    $user->healthProfile()->create([
        'age' => 68,
        'biological_sex' => 'female',
        'conditions' => ['cardiovascular'],
        'medications' => ['beta_blockers'],
        'lifestyle' => ['acclimatized'],
    ]);

    return $user;
}

/**
 * Fake a successful OpenRouter completion carrying [$content].
 *
 * @param  array<string, mixed>  $content
 */
function fakeHealthRiskResponse(array $content): void
{
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [
                ['message' => ['content' => json_encode($content)]],
            ],
        ], 200),
    ]);
}

test('ai health risk returns the assessment', function (): void {
    fakeHealthRiskResponse(healthRiskContent());

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => [
                'temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS'],
                'relativeHumidity' => 70,
            ],
            'hourlyForecast' => ['forecastHours' => []],
            'dailyForecast' => ['forecastDays' => []],
        ])
        ->assertOk()
        ->assertJson([
            'riskScore' => 62,
            'riskLevel' => 'very_high',
            'thresholdC' => 38.0,
            'thresholdLabel' => 'Clinical fever threshold',
            'summary' => 'Heat strain is likely this afternoon.',
            'uncertainty' => 'Humidity is forecast with moderate confidence.',
            'keyFindings' => ['Peak risk is between 14:00 and 16:00.'],
            'recommendations' => ['Avoid strenuous outdoor work at midday.'],
        ])
        ->assertJsonCount(2, 'hourly')
        ->assertJsonPath('hourly.0.hourIndex', 0)
        ->assertJsonPath('hourly.1.probability', 0.55);
});

test('ai health risk sends the stored profile and a strict schema', function (): void {
    fakeHealthRiskResponse(healthRiskContent());

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertOk();

    Http::assertSent(function ($request) {
        $body = $request->data();
        $schema = $body['response_format']['json_schema'];

        return $request->url() === 'https://openrouter.ai/api/v1/chat/completions'
            && $request->hasHeader('Authorization', 'Bearer test-openrouter-key')
            && $body['model'] === 'deepseek/deepseek-v4.1-flash'
            && $body['response_format']['type'] === 'json_schema'
            && $schema['strict'] === true
            && $schema['schema']['additionalProperties'] === false
            && $schema['schema']['required'] === [
                'riskScore',
                'riskLevel',
                'thresholdC',
                'thresholdLabel',
                'summary',
                'uncertainty',
                'keyFindings',
                'recommendations',
                'hourly',
            ]
            && $schema['schema']['properties']['riskLevel']['enum'] === [
                'low',
                'moderate',
                'high',
                'very_high',
                'extreme',
            ]
            && $body['messages'][0]['role'] === 'system'
            && $body['messages'][1]['role'] === 'user'
            // The profile is read server-side, not taken from the request.
            && str_contains($body['messages'][1]['content'], '"age":68')
            && str_contains($body['messages'][1]['content'], 'cardiovascular')
            && str_contains($body['messages'][1]['content'], 'currentConditions');
    });
});

test('ai health risk forwards the previous assessment as context', function (): void {
    fakeHealthRiskResponse(healthRiskContent());

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
            'previousAssessment' => [
                'riskScore' => 40,
                'riskLevel' => 'high',
                'generatedAt' => '2026-11-10T09:00:00Z',
            ],
        ])
        ->assertOk();

    Http::assertSent(function ($request) {
        $content = $request->data()['messages'][1]['content'];

        return str_contains($content, 'previousAssessment')
            && str_contains($content, '2026-11-10T09:00:00Z');
    });
});

test('ai health risk omits previousAssessment when none is supplied', function (): void {
    fakeHealthRiskResponse(healthRiskContent());

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertOk();

    Http::assertSent(function ($request) {
        return ! str_contains($request->data()['messages'][1]['content'], 'previousAssessment');
    });
});

test('ai health risk returns 401 when unauthenticated', function (): void {
    $this->postJson('/api/ai/health-risk', [
        'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
    ])->assertStatus(401);
});

test('ai health risk returns 400 when the user has no profile', function (): void {
    $user = User::factory()->create();

    $this->actingAs($user, 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(400)
        ->assertJson([
            'message' => 'A health profile is required before generating an assessment.',
        ]);
});

test('ai health risk returns 400 when currentConditions is missing', function (): void {
    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [])
        ->assertStatus(400)
        ->assertJsonStructure(['message']);
});

test('ai health risk returns 502 when OpenRouter is unreachable', function (): void {
    Http::fake(function () {
        throw new ConnectionException('Connection refused');
    });

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502)
        ->assertJson([
            'message' => 'AI service is currently unreachable. Please try again later.',
        ]);
});

test('ai health risk returns 502 when the API key is missing', function (): void {
    config()->set('services.openrouter.api_key', '');

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502)
        ->assertJson(['message' => 'AI API key is not configured.']);
});

test('ai health risk returns 502 when the model output is not JSON', function (): void {
    Http::fake([
        'openrouter.ai/*' => Http::response([
            'choices' => [['message' => ['content' => 'not json']]],
        ], 200),
    ]);

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502)
        ->assertJson(['message' => 'AI service returned an invalid response.']);
});

test('ai health risk returns 502 when a required field is missing', function (): void {
    $content = healthRiskContent();
    unset($content['uncertainty']);
    fakeHealthRiskResponse($content);

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502)
        ->assertJson(['message' => 'AI service returned an invalid response.']);
});

test('ai health risk returns 502 when the risk level is not allowed', function (): void {
    fakeHealthRiskResponse(healthRiskContent(['riskLevel' => 'catastrophic']));

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502);
});

test('ai health risk returns 502 when the threshold is implausible', function (): void {
    fakeHealthRiskResponse(healthRiskContent(['thresholdC' => 50.0]));

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502);
});

test('ai health risk returns 502 when the hourly list is empty', function (): void {
    fakeHealthRiskResponse(healthRiskContent(['hourly' => []]));

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502);
});

test('ai health risk returns 502 when an hourly point is missing a field', function (): void {
    fakeHealthRiskResponse(healthRiskContent([
        'hourly' => [
            ['hourIndex' => 0, 'hour' => 12, 'probability' => 0.2],
        ],
    ]));

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertStatus(502);
});

test('ai health risk clamps out-of-range numbers and repairs the percentile order', function (): void {
    fakeHealthRiskResponse(healthRiskContent([
        'riskScore' => 140,
        'hourly' => [
            [
                'hourIndex' => 1,
                'hour' => 13,
                'probability' => 1.8,
                // Deliberately inverted: p10 above p90.
                'coreTempMedianC' => 37.9,
                'coreTempP10C' => 38.6,
                'coreTempP90C' => 37.2,
            ],
            [
                'hourIndex' => 0,
                'hour' => 12,
                'probability' => -0.4,
                'coreTempMedianC' => 37.4,
                'coreTempP10C' => 37.1,
                'coreTempP90C' => 37.8,
            ],
        ],
    ]));

    $response = $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertOk();

    // riskScore is clamped to the 0-100 range.
    expect($response->json('riskScore'))->toBe(100);

    // Points are sorted by hourIndex regardless of the order the model used.
    expect($response->json('hourly.0.hourIndex'))->toBe(0);
    expect($response->json('hourly.1.hourIndex'))->toBe(1);

    // Probabilities are clamped to 0.0-1.0. (JSON drops the zero fraction, so
    // compare as floats rather than relying on the encoded representation.)
    expect((float) $response->json('hourly.0.probability'))->toBe(0.0);
    expect((float) $response->json('hourly.1.probability'))->toBe(1.0);

    // The inverted triple is sorted so p10 <= median <= p90.
    expect($response->json('hourly.1.coreTempP10C'))->toBe(37.2);
    expect($response->json('hourly.1.coreTempMedianC'))->toBe(37.9);
    expect($response->json('hourly.1.coreTempP90C'))->toBe(38.6);
});

test('ai health risk drops hourly points that cannot be plotted', function (): void {
    fakeHealthRiskResponse(healthRiskContent([
        'hourly' => [
            [
                'hourIndex' => 0,
                'hour' => 12,
                'probability' => 0.2,
                'coreTempMedianC' => 37.4,
                'coreTempP10C' => 37.1,
                'coreTempP90C' => 37.8,
            ],
            [
                'hourIndex' => 1,
                'hour' => 99,
                'probability' => 0.3,
                'coreTempMedianC' => 37.5,
                'coreTempP10C' => 37.2,
                'coreTempP90C' => 37.9,
            ],
        ],
    ]));

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertOk()
        ->assertJsonCount(1, 'hourly')
        ->assertJsonPath('hourly.0.hour', 12);
});

test('ai health risk drops empty strings from the findings and recommendations', function (): void {
    fakeHealthRiskResponse(healthRiskContent([
        'keyFindings' => ['Peak risk at 15:00.', '', '   '],
        'recommendations' => ['Drink water.', ''],
    ]));

    $this->actingAs(userWithProfile(), 'sanctum')
        ->postJson('/api/ai/health-risk', [
            'currentConditions' => ['temperature' => ['degrees' => 36.0, 'unit' => 'CELSIUS']],
        ])
        ->assertOk()
        ->assertJsonPath('keyFindings', ['Peak risk at 15:00.'])
        ->assertJsonPath('recommendations', ['Drink water.']);
});
