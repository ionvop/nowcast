<?php

use App\Services\OpenRouterService;
use Illuminate\Support\Facades\Http;

beforeEach(function (): void {
    config()->set('services.openrouter.api_key', 'test-openrouter-key');
    config()->set('services.openrouter.model', 'openrouter/free');
});

/**
 * Invoke the service's protected timeout resolver.
 */
function openRouterTimeout(): int
{
    $method = new ReflectionMethod(OpenRouterService::class, 'timeout');

    return $method->invoke(new OpenRouterService);
}

test('the openrouter timeout defaults to 30 seconds', function (): void {
    expect((int) config('services.openrouter.timeout'))->toBe(30)
        ->and(openRouterTimeout())->toBe(30);
});

test('the openrouter timeout follows configuration', function (): void {
    config()->set('services.openrouter.timeout', 12);

    expect(openRouterTimeout())->toBe(12);
});

test('an invalid openrouter timeout falls back to 30 seconds', function (int|string $value): void {
    config()->set('services.openrouter.timeout', $value);

    expect(openRouterTimeout())->toBe(30);
})->with([0, -1, 'fast']);

test('ai calls are attempted only once so they finish inside the client budget', function (): void {
    // A 502 from OpenRouter. With retries enabled this would produce two
    // upstream requests; the client's 60s AI deadline has room for one 30s
    // attempt only.
    Http::fake([
        'openrouter.ai/*' => Http::response(['error' => 'boom'], 502),
    ]);

    $this->postJson('/api/ai/summary', [
        'currentConditions' => ['temperature' => ['degrees' => 33.0, 'unit' => 'CELSIUS']],
        'latitude' => 7.4478,
        'longitude' => 125.8078,
    ])->assertStatus(502);

    Http::assertSentCount(1);
});
