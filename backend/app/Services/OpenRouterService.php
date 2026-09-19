<?php

namespace App\Services;

use App\Exceptions\OpenRouterApiException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;

/**
 * Generates AI weather summaries via OpenRouter.
 *
 * The client already holds the current-conditions and forecast payloads from
 * the weather endpoints, so this service accepts them as inputs and delegates
 * the "summarize + health advice + recommended article" analysis to an LLM
 * hosted on OpenRouter. Error handling and credential resolution stay uniform
 * with the Google services.
 */
class OpenRouterService
{
    /**
     * The OpenRouter chat completions endpoint.
     */
    protected const COMPLETIONS_URL = 'https://openrouter.ai/api/v1/chat/completions';

    /**
     * The keys the completion must return.
     */
    protected const REQUIRED_FIELDS = ['summary', 'healthAdvice', 'articleUrl'];

    /**
     * Ask the model to summarize the weather payloads and return structured advice.
     *
     * @param  array<string, mixed>  $currentConditions  The raw Google current-conditions payload.
     * @param  array<string, mixed>  $hourlyForecast  The raw Google hourly forecast payload.
     * @param  array<string, mixed>  $dailyForecast  The raw Google daily forecast payload.
     * @return array{summary: string, healthAdvice: string, articleUrl: string}
     *
     * @throws OpenRouterApiException When OpenRouter is unreachable, returns an
     *                                error, or the model output is malformed.
     */
    public function summarize(
        array $currentConditions,
        array $hourlyForecast,
        array $dailyForecast,
    ): array {
        $payload = $this->completionsRequestBody($currentConditions, $hourlyForecast, $dailyForecast);

        try {
            $response = Http::timeout(30)
                ->retry(2, 100)
                ->withToken($this->apiKey())
                ->withHeaders(['Accept' => 'application/json'])
                ->post(self::COMPLETIONS_URL, $payload);
        } catch (ConnectionException|RequestException) {
            throw new OpenRouterApiException('AI service is currently unreachable. Please try again later.');
        }

        if (! $response->successful()) {
            throw new OpenRouterApiException(
                'AI service returned an error. Please try again later.',
                $response->status(),
            );
        }

        $content = data_get($response->json(), 'choices.0.message.content');

        if (! is_string($content) || $content === '') {
            throw new OpenRouterApiException('AI service returned an empty response.');
        }

        $decoded = json_decode($content, true);

        if (! is_array($decoded)) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        return $this->normalize($decoded);
    }

    /**
     * Build the chat-completions request body with the weather context and a
     * strict JSON output contract.
     *
     * @param  array<string, mixed>  $currentConditions
     * @param  array<string, mixed>  $hourlyForecast
     * @param  array<string, mixed>  $dailyForecast
     * @return array<string, mixed>
     */
    protected function completionsRequestBody(
        array $currentConditions,
        array $hourlyForecast,
        array $dailyForecast,
    ): array {
        $system = [
            'role' => 'system',
            'content' => <<<'PROMPT'
You are an expert meteorologist and public-health advisor. You analyze live weather
current-conditions and forecast payloads and produce:
- "summary": a short, plain-language paragraph describing the current conditions
  and what to expect over the next few hours/days.
- "healthAdvice": a short paragraph of actionable health and safety advice based
  on the conditions (heat, cold, humidity, wind, precipitation, UV, air quality, etc.).
- "articleUrl": a single real, working URL to a relevant, reputable article (e.g.
  CDC, WHO, NOAA, a national weather service) that the user can read to learn more
  about the dominant weather risk.

Return strictly valid JSON with exactly these three keys: summary, healthAdvice,
articleUrl. Do not wrap the JSON in markdown or add commentary outside the JSON.
PROMPT,
        ];

        $userActual = array_filter([
            'currentConditions' => $currentConditions,
            'hourlyForecast' => $hourlyForecast,
            'dailyForecast' => $dailyForecast,
        ], fn ($value) => $value !== []);

        $user = [
            'role' => 'user',
            'content' => 'Here is the weather data to analyze: '.json_encode($userActual),
        ];

        return [
            'model' => $this->model(),
            'messages' => [$system, $user],
            'temperature' => 0.3,
            'response_format' => ['type' => 'json_object'],
        ];
    }

    /**
     * Extract the three summary fields, enforcing that the article is a usable URL.
     *
     * @param  array<string, mixed>  $decoded  The model-decoded response.
     * @return array{summary: string, healthAdvice: string, articleUrl: string}
     *
     * @throws OpenRouterApiException When any required field is missing or invalid.
     */
    protected function normalize(array $decoded): array
    {
        foreach (self::REQUIRED_FIELDS as $field) {
            if (! isset($decoded[$field])) {
                throw new OpenRouterApiException('AI service returned an invalid response.');
            }
        }

        $summary = (string) $decoded['summary'];
        $healthAdvice = (string) $decoded['healthAdvice'];
        $articleUrl = (string) $decoded['articleUrl'];

        if ($summary === '' || $healthAdvice === '' || filter_var($articleUrl, FILTER_VALIDATE_URL) === false) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        return [
            'summary' => $summary,
            'healthAdvice' => $healthAdvice,
            'articleUrl' => $articleUrl,
        ];
    }

    /**
     * Resolve the OpenRouter API key from configuration.
     *
     * @throws OpenRouterApiException When no key is configured.
     */
    protected function apiKey(): string
    {
        $key = config('services.openrouter.api_key');

        if (is_string($key) && $key !== '') {
            return $key;
        }

        throw new OpenRouterApiException('AI API key is not configured.');
    }

    /**
     * Resolve the OpenRouter model from configuration.
     */
    protected function model(): string
    {
        return (string) config('services.openrouter.model', 'deepseek/deepseek-v4-flash-0731:online');
    }
}