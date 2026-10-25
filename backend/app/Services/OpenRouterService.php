<?php

namespace App\Services;

use App\Exceptions\OpenRouterApiException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Arr;
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
     * The keys each activity suggestion must return.
     */
    protected const ACTIVITY_REQUIRED_FIELDS = ['name', 'category', 'description', 'reason', 'url'];

    /**
     * The allowed activity categories.
     */
    protected const ACTIVITY_CATEGORIES = ['outdoor', 'indoor', 'food', 'cultural', 'sports', 'family', 'other'];

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

        return $this->normalize($this->completions($payload));
    }

    /**
     * Ask the model to look up nearby places with web search and recommend
     * activities that fit the current weather.
     *
     * @param  array<string, mixed>  $currentConditions  The raw Google current-conditions payload.
     * @param  array<string, mixed>  $hourlyForecast  The raw Google hourly forecast payload.
     * @param  array<string, mixed>  $dailyForecast  The raw Google daily forecast payload.
     * @param  float  $latitude  The location latitude.
     * @param  float  $longitude  The location longitude.
     * @param  ?string  $placeName  An optional human-readable place name (e.g. from geocoding).
     * @return array{suggestions: array<array<string, mixed>>}
     *
     * @throws OpenRouterApiException When OpenRouter is unreachable, returns an
     *                                error, or the model output is malformed.
     */
    public function suggestActivities(
        array $currentConditions,
        array $hourlyForecast,
        array $dailyForecast,
        float $latitude,
        float $longitude,
        ?string $placeName,
    ): array {
        $payload = $this->activitiesRequestBody(
            $currentConditions,
            $hourlyForecast,
            $dailyForecast,
            $latitude,
            $longitude,
            $placeName,
        );

        return $this->normalizeActivities($this->completions($payload));
    }

    /**
     * Send a chat-completions request and return the decoded model output.
     *
     * @param  array<string, mixed>  $payload  The request body.
     * @return array<string, mixed>
     *
     * @throws OpenRouterApiException When OpenRouter is unreachable, returns an
     *                                error, or the model output is malformed.
     */
    protected function completions(array $payload): array
    {
        try {
            // Keep the total worst case (timeout x attempts) inside the
            // client's 30s deadline so the app receives a real error message
            // instead of timing out on its own.
            $response = Http::timeout(20)
                ->retry(1, 200)
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

        return $decoded;
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
            'reasoning_effort' => 'none',
            'response_format' => [
                'type' => 'json_schema',
                'json_schema' => [
                    'name' => 'weather_summary',
                    'strict' => true,
                    'schema' => [
                        'type' => 'object',
                        'additionalProperties' => false,
                        'required' => self::REQUIRED_FIELDS,
                        'properties' => [
                            'summary' => [
                                'type' => 'string',
                                'description' => 'A short, plain-language paragraph describing the current conditions and what to expect over the next few hours/days.',
                            ],
                            'healthAdvice' => [
                                'type' => 'string',
                                'description' => 'A short paragraph of actionable health and safety advice based on the conditions.',
                            ],
                            'articleUrl' => [
                                'type' => 'string',
                                'description' => 'A single real, working URL to a relevant, reputable article about the dominant weather risk.',
                            ],
                        ],
                    ],
                ],
            ],
            'tools' => [
                [
                    'type' => 'openrouter:web_search',
                    'parameters' => [
                        'engine' => 'parallel',
                        'mode' => 'turbo',
                        'max_results' => 10,
                    ]
                ]
            ]
        ];
    }

    /**
     * Build the chat-completions request body for weather-aware activity
     * recommendations, enabling the web-search server tool so the model can
     * look up real nearby places.
     *
     * @param  array<string, mixed>  $currentConditions
     * @param  array<string, mixed>  $hourlyForecast
     * @param  array<string, mixed>  $dailyForecast
     * @param  float  $latitude
     * @param  float  $longitude
     * @param  ?string  $placeName
     * @return array<string, mixed>
     */
    protected function activitiesRequestBody(
        array $currentConditions,
        array $hourlyForecast,
        array $dailyForecast,
        float $latitude,
        float $longitude,
        ?string $placeName,
    ): array {
        $system = [
            'role' => 'system',
            'content' => <<<'PROMPT'
You are a local guide and activity planner. You use web search to find real,
nearby places and activities, then recommend the ones that best fit the current
weather. Produce a "suggestions" array with 3 to 6 entries, each containing:
- "name": the name of the place or activity.
- "category": one of outdoor, indoor, food, cultural, sports, family, other.
- "description": one or two sentences describing the place or activity.
- "reason": one sentence explaining why it suits the current weather.
- "url": a real, working URL to the place or activity when you found one via
  web search; otherwise null. Never invent or guess a URL.

Return strictly valid JSON with exactly one key, suggestions. Do not wrap the
JSON in markdown or add commentary outside the JSON.
PROMPT,
        ];

        $userActual = array_filter([
            'currentConditions' => $currentConditions,
            'hourlyForecast' => $hourlyForecast,
            'dailyForecast' => $dailyForecast,
        ], fn ($value) => $value !== []);

        $location = [
            'latitude' => $latitude,
            'longitude' => $longitude,
        ];

        if (is_string($placeName) && $placeName !== '') {
            $location['placeName'] = $placeName;
        }

        $user = [
            'role' => 'user',
            'content' => 'Here is the weather data and location to analyze: '.json_encode([
                'location' => $location,
                'weather' => $userActual,
            ]),
        ];

        return [
            'model' => $this->model(),
            'messages' => [$system, $user],
            'temperature' => 0.3,
            'reasoning_effort' => 'none',
            'response_format' => [
                'type' => 'json_schema',
                'json_schema' => [
                    'name' => 'weather_activities',
                    'strict' => true,
                    'schema' => [
                        'type' => 'object',
                        'additionalProperties' => false,
                        'required' => ['suggestions'],
                        'properties' => [
                            'suggestions' => [
                                'type' => 'array',
                                'maxItems' => 8,
                                'items' => [
                                    'type' => 'object',
                                    'additionalProperties' => false,
                                    'required' => self::ACTIVITY_REQUIRED_FIELDS,
                                    'properties' => [
                                        'name' => [
                                            'type' => 'string',
                                            'description' => 'The name of the place or activity.',
                                        ],
                                        'category' => [
                                            'type' => 'string',
                                            'enum' => self::ACTIVITY_CATEGORIES,
                                            'description' => 'The activity category.',
                                        ],
                                        'description' => [
                                            'type' => 'string',
                                            'description' => 'One or two sentences describing the place or activity.',
                                        ],
                                        'reason' => [
                                            'type' => 'string',
                                            'description' => 'One sentence explaining why it suits the current weather.',
                                        ],
                                        'url' => [
                                            'type' => ['string', 'null'],
                                            'description' => 'A real, working URL found via web search, or null when none was found.',
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
            'tools' => [
                [
                    'type' => 'openrouter:web_search',
                    'parameters' => [
                        'engine' => 'parallel',
                        'mode' => 'turbo',
                        'max_results' => 10,
                    ]
                ]
            ]
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
     * Extract and validate the activity suggestions, dropping any URL that is
     * missing or not a usable URL so the client never receives a fabricated link.
     *
     * @param  array<string, mixed>  $decoded  The model-decoded response.
     * @return array{suggestions: array<array<string, mixed>>}
     *
     * @throws OpenRouterApiException When the suggestions are missing or malformed.
     */
    protected function normalizeActivities(array $decoded): array
    {
        $suggestions = $decoded['suggestions'] ?? null;

        if (! is_array($suggestions) || $suggestions === []) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        $normalized = [];

        foreach ($suggestions as $suggestion) {
            if (! is_array($suggestion)) {
                throw new OpenRouterApiException('AI service returned an invalid response.');
            }

            foreach (self::ACTIVITY_REQUIRED_FIELDS as $field) {
                if (! Arr::exists($suggestion, $field)) {
                    throw new OpenRouterApiException('AI service returned an invalid response.');
                }
            }

            $name = (string) $suggestion['name'];
            $category = (string) $suggestion['category'];
            $description = (string) $suggestion['description'];
            $reason = (string) $suggestion['reason'];

            if ($name === '' || $description === '' || $reason === ''
                || ! in_array($category, self::ACTIVITY_CATEGORIES)) {
                throw new OpenRouterApiException('AI service returned an invalid response.');
            }

            $item = [
                'name' => $name,
                'category' => $category,
                'description' => $description,
                'reason' => $reason,
            ];

            $url = $suggestion['url'] ?? null;

            if (is_string($url) && $url !== '' && filter_var($url, FILTER_VALIDATE_URL) !== false) {
                $item['url'] = $url;
            }

            $normalized[] = $item;
        }

        return ['suggestions' => $normalized];
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
        return (string) config('services.openrouter.model', 'deepseek/deepseek-v4.1-flash');
    }
}