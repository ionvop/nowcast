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
     * The keys the health-risk assessment must return.
     */
    protected const HEALTH_RISK_REQUIRED_FIELDS = [
        'riskScore',
        'riskLevel',
        'thresholdC',
        'thresholdLabel',
        'summary',
        'uncertainty',
        'keyFindings',
        'recommendations',
        'hourly',
    ];

    /**
     * The keys each hourly health-risk point must return.
     */
    protected const HEALTH_RISK_HOUR_FIELDS = [
        'hourIndex',
        'hour',
        'probability',
        'coreTempMedianC',
        'coreTempP10C',
        'coreTempP90C',
    ];

    /**
     * The allowed risk levels, from least to most severe.
     */
    protected const HEALTH_RISK_LEVELS = ['low', 'moderate', 'high', 'very_high', 'extreme'];

    /**
     * The plausible range for a human core-temperature threshold, in Celsius.
     *
     * Anything outside this range is a model error rather than a clinical
     * judgement, so it is rejected instead of being clamped.
     */
    protected const HEALTH_RISK_THRESHOLD_MIN = 35.0;

    /**
     * The upper bound of the plausible core-temperature threshold range.
     */
    protected const HEALTH_RISK_THRESHOLD_MAX = 42.0;

    /**
     * The maximum number of hourly points accepted from the model.
     */
    protected const HEALTH_RISK_MAX_HOURS = 24;

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
     * Estimate the user's heat-strain risk from their health profile and the
     * current weather, returning the numbers the client plots plus a written
     * summary.
     *
     * The profile is read server-side from the authenticated user, so the
     * client cannot inflate or omit details. When a previous assessment is
     * supplied it is included in the prompt as a reference point so a
     * regeneration stays consistent with what the user already saw.
     *
     * @param  array<string, mixed>  $profile  The user's health profile.
     * @param  array<string, mixed>  $currentConditions  The raw Google current-conditions payload.
     * @param  array<string, mixed>  $hourlyForecast  The raw Google hourly forecast payload.
     * @param  array<string, mixed>  $dailyForecast  The raw Google daily forecast payload.
     * @param  array<string, mixed>|null  $previousAssessment  The last assessment shown to the user, if any.
     * @return array<string, mixed>
     *
     * @throws OpenRouterApiException When OpenRouter is unreachable, returns an
     *                                error, or the model output is malformed.
     */
    public function assessHealthRisk(
        array $profile,
        array $currentConditions,
        array $hourlyForecast,
        array $dailyForecast,
        ?array $previousAssessment = null,
    ): array {
        $payload = $this->healthRiskRequestBody(
            $profile,
            $currentConditions,
            $hourlyForecast,
            $dailyForecast,
            $previousAssessment,
        );

        // This prompt is heavier than the summary/activities ones, so trade the
        // retry for a longer single attempt: 25s still lands inside the
        // Flutter client's 30s deadline, whereas 20s x 2 attempts would not.
        return $this->normalizeHealthRisk($this->completions($payload, timeout: 25, retries: 0));
    }

    /**
     * Send a chat-completions request and return the decoded model output.
     *
     * @param  array<string, mixed>  $payload  The request body.
     * @param  int  $timeout  Per-attempt timeout in seconds.
     * @param  int  $retries  How many times to retry a failed attempt.
     * @return array<string, mixed>
     *
     * @throws OpenRouterApiException When OpenRouter is unreachable, returns an
     *                                error, or the model output is malformed.
     */
    protected function completions(array $payload, int $timeout = 20, int $retries = 1): array
    {
        try {
            // Keep the total worst case (timeout x attempts) inside the
            // client's 30s deadline so the app receives a real error message
            // instead of timing out on its own.
            $response = Http::timeout($timeout)
                ->retry($retries, 200)
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
            'provider' => [
                'require_parameters' => true
            ],
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
            'provider' => [
                'require_parameters' => true
            ],
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
     * Build the chat-completions request body for the health-risk assessment.
     *
     * @param  array<string, mixed>  $profile
     * @param  array<string, mixed>  $currentConditions
     * @param  array<string, mixed>  $hourlyForecast
     * @param  array<string, mixed>  $dailyForecast
     * @param  array<string, mixed>|null  $previousAssessment
     * @return array<string, mixed>
     */
    protected function healthRiskRequestBody(
        array $profile,
        array $currentConditions,
        array $hourlyForecast,
        array $dailyForecast,
        ?array $previousAssessment,
    ): array {
        $system = [
            'role' => 'system',
            'content' => <<<'PROMPT'
You are a physiologist and biometeorologist who models heat strain for public-health
decision support. You combine a person's health profile with live weather to estimate
how likely their core body temperature is to cross a clinical threshold.

Produce:
- "riskScore": an integer from 0 to 100, where 0 is no measurable heat strain and 100
  is an immediate life-threatening emergency.
- "riskLevel": one of low, moderate, high, very_high, extreme. Keep it consistent with
  riskScore: low < 20, moderate 20-39, high 40-59, very_high 60-79, extreme >= 80.
- "thresholdC": the core-body-temperature threshold in degrees Celsius that is clinically
  meaningful for THIS person, given their age, conditions, and medications. A healthy
  young adult is typically around 38.0; a frail, elderly, or chronically ill person is
  lower. It must be between 35.0 and 42.0.
- "thresholdLabel": a short human-readable name for that threshold, e.g.
  "Clinical fever threshold" or "Heat-strain threshold for cardiovascular risk".
- "summary": two to four plain-language sentences explaining the overall risk and the
  main driver. Write for a non-clinician.
- "uncertainty": one or two sentences naming the largest sources of uncertainty in this
  estimate (for example missing profile details, forecast spread, or humidity assumptions).
- "keyFindings": 2 to 5 short bullet-style sentences a decision-maker can act on.
- "recommendations": 2 to 5 short, concrete, actionable steps for this person today.
- "hourly": one entry per hour of the supplied hourly forecast, in the same order, with:
  - "hourIndex": the zero-based index of the hour in the supplied forecast.
  - "hour": the hour of day in 24-hour time (0-23).
  - "probability": the probability, from 0.0 to 1.0, that core temperature crosses
    thresholdC during that hour.
  - "coreTempMedianC": the median estimated core temperature in degrees Celsius.
  - "coreTempP10C": the 10th-percentile (optimistic) core temperature.
  - "coreTempP90C": the 90th-percentile (pessimistic) core temperature.

Rules:
- coreTempP10C must be less than or equal to coreTempMedianC, which must be less than or
  equal to coreTempP90C, for every hour.
- Base the estimate on the supplied weather and profile only. Do not invent measurements.
- Treat missing profile details as unknown, not as absent risk, and say so in "uncertainty".
- These are statistical estimates for awareness, not a diagnosis or medical advice.
- If a "previousAssessment" is supplied, treat it as the last estimate the user saw. Stay
  consistent with it unless the weather or the profile has changed materially, and say
  what changed when your numbers move.

Return strictly valid JSON with exactly these keys: riskScore, riskLevel, thresholdC,
thresholdLabel, summary, uncertainty, keyFindings, recommendations, hourly. Do not wrap
the JSON in markdown or add commentary outside the JSON.
PROMPT,
        ];

        $weather = array_filter([
            'currentConditions' => $currentConditions,
            'hourlyForecast' => $hourlyForecast,
            'dailyForecast' => $dailyForecast,
        ], fn ($value) => $value !== []);

        $context = [
            'profile' => $profile,
            'weather' => $weather,
        ];

        if ($previousAssessment !== null && $previousAssessment !== []) {
            $context['previousAssessment'] = $previousAssessment;
        }

        $user = [
            'role' => 'user',
            'content' => 'Here is the health profile and weather data to assess: '.json_encode($context),
        ];

        return [
            'model' => $this->model(),
            'messages' => [$system, $user],
            'temperature' => 0.2,
            'reasoning_effort' => 'none',
            'provider' => [
                'require_parameters' => true
            ],
            'response_format' => [
                'type' => 'json_schema',
                'json_schema' => [
                    'name' => 'health_risk_assessment',
                    'strict' => true,
                    'schema' => [
                        'type' => 'object',
                        'additionalProperties' => false,
                        'required' => self::HEALTH_RISK_REQUIRED_FIELDS,
                        'properties' => [
                            'riskScore' => [
                                'type' => 'integer',
                                'description' => 'Overall heat-strain risk from 0 (none) to 100 (emergency).',
                            ],
                            'riskLevel' => [
                                'type' => 'string',
                                'enum' => self::HEALTH_RISK_LEVELS,
                                'description' => 'The risk band matching riskScore.',
                            ],
                            'thresholdC' => [
                                'type' => 'number',
                                'description' => 'The clinically meaningful core-temperature threshold in degrees Celsius for this person.',
                            ],
                            'thresholdLabel' => [
                                'type' => 'string',
                                'description' => 'A short human-readable name for the threshold.',
                            ],
                            'summary' => [
                                'type' => 'string',
                                'description' => 'Two to four plain-language sentences explaining the overall risk and its main driver.',
                            ],
                            'uncertainty' => [
                                'type' => 'string',
                                'description' => 'One or two sentences naming the largest sources of uncertainty.',
                            ],
                            'keyFindings' => [
                                'type' => 'array',
                                'maxItems' => 5,
                                'items' => [
                                    'type' => 'string',
                                    'description' => 'A short, actionable finding.',
                                ],
                            ],
                            'recommendations' => [
                                'type' => 'array',
                                'maxItems' => 5,
                                'items' => [
                                    'type' => 'string',
                                    'description' => 'A short, concrete action for this person today.',
                                ],
                            ],
                            'hourly' => [
                                'type' => 'array',
                                'maxItems' => self::HEALTH_RISK_MAX_HOURS,
                                'items' => [
                                    'type' => 'object',
                                    'additionalProperties' => false,
                                    'required' => self::HEALTH_RISK_HOUR_FIELDS,
                                    'properties' => [
                                        'hourIndex' => [
                                            'type' => 'integer',
                                            'description' => 'Zero-based index of the hour in the supplied forecast.',
                                        ],
                                        'hour' => [
                                            'type' => 'integer',
                                            'description' => 'Hour of day in 24-hour time (0-23).',
                                        ],
                                        'probability' => [
                                            'type' => 'number',
                                            'description' => 'Probability from 0.0 to 1.0 that core temperature crosses the threshold during this hour.',
                                        ],
                                        'coreTempMedianC' => [
                                            'type' => 'number',
                                            'description' => 'Median estimated core temperature in degrees Celsius.',
                                        ],
                                        'coreTempP10C' => [
                                            'type' => 'number',
                                            'description' => '10th-percentile (optimistic) core temperature in degrees Celsius.',
                                        ],
                                        'coreTempP90C' => [
                                            'type' => 'number',
                                            'description' => '90th-percentile (pessimistic) core temperature in degrees Celsius.',
                                        ],
                                    ],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * Validate and repair the health-risk assessment returned by the model.
     *
     * The JSON schema is advisory: the model can still return out-of-range
     * numbers or a mis-ordered percentile triple. Structural problems are
     * rejected, while recoverable numeric problems are clamped or sorted so a
     * single bad hour does not discard an otherwise usable assessment.
     *
     * @param  array<string, mixed>  $decoded  The model-decoded response.
     * @return array<string, mixed>
     *
     * @throws OpenRouterApiException When the response is structurally invalid.
     */
    protected function normalizeHealthRisk(array $decoded): array
    {
        foreach (self::HEALTH_RISK_REQUIRED_FIELDS as $field) {
            if (! Arr::exists($decoded, $field)) {
                throw new OpenRouterApiException('AI service returned an invalid response.');
            }
        }

        $summary = (string) $decoded['summary'];
        $uncertainty = (string) $decoded['uncertainty'];
        $thresholdLabel = (string) $decoded['thresholdLabel'];
        $riskLevel = (string) $decoded['riskLevel'];

        if ($summary === '' || $uncertainty === '' || $thresholdLabel === ''
            || ! in_array($riskLevel, self::HEALTH_RISK_LEVELS, true)) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        $threshold = $this->number($decoded['thresholdC']);

        if ($threshold === null
            || $threshold < self::HEALTH_RISK_THRESHOLD_MIN
            || $threshold > self::HEALTH_RISK_THRESHOLD_MAX) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        $hourly = $this->normalizeHealthRiskHours($decoded['hourly']);

        if ($hourly === []) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        return [
            'riskScore' => $this->clampInt($decoded['riskScore'], 0, 100),
            'riskLevel' => $riskLevel,
            'thresholdC' => round($threshold, 1),
            'thresholdLabel' => $thresholdLabel,
            'summary' => $summary,
            'uncertainty' => $uncertainty,
            'keyFindings' => $this->stringList($decoded['keyFindings']),
            'recommendations' => $this->stringList($decoded['recommendations']),
            'hourly' => $hourly,
        ];
    }

    /**
     * Validate, clamp, and order the hourly points of a health-risk assessment.
     *
     * @param  mixed  $hours  The raw `hourly` value from the model.
     * @return array<int, array<string, mixed>>
     *
     * @throws OpenRouterApiException When an entry is not an object or is missing a field.
     */
    protected function normalizeHealthRiskHours(mixed $hours): array
    {
        if (! is_array($hours)) {
            throw new OpenRouterApiException('AI service returned an invalid response.');
        }

        $normalized = [];

        foreach ($hours as $hour) {
            if (! is_array($hour)) {
                throw new OpenRouterApiException('AI service returned an invalid response.');
            }

            foreach (self::HEALTH_RISK_HOUR_FIELDS as $field) {
                if (! Arr::exists($hour, $field)) {
                    throw new OpenRouterApiException('AI service returned an invalid response.');
                }
            }

            $hourIndex = $this->number($hour['hourIndex']);
            $hourOfDay = $this->number($hour['hour']);
            $probability = $this->number($hour['probability']);
            $median = $this->number($hour['coreTempMedianC']);
            $p10 = $this->number($hour['coreTempP10C']);
            $p90 = $this->number($hour['coreTempP90C']);

            if ($hourIndex === null || $hourOfDay === null || $probability === null
                || $median === null || $p10 === null || $p90 === null) {
                throw new OpenRouterApiException('AI service returned an invalid response.');
            }

            $hourIndex = (int) $hourIndex;
            $hourOfDay = (int) $hourOfDay;

            // Drop points that cannot be placed on the chart rather than
            // failing the whole assessment.
            if ($hourIndex < 0 || $hourOfDay < 0 || $hourOfDay > 23) {
                continue;
            }

            // Repair a mis-ordered percentile triple by sorting it, so the
            // band always renders the right way up.
            $triple = [$p10, $median, $p90];
            sort($triple);

            $normalized[] = [
                'hourIndex' => $hourIndex,
                'hour' => $hourOfDay,
                'probability' => round(min(1.0, max(0.0, $probability)), 3),
                'coreTempP10C' => round($triple[0], 2),
                'coreTempMedianC' => round($triple[1], 2),
                'coreTempP90C' => round($triple[2], 2),
            ];
        }

        usort($normalized, fn (array $a, array $b) => $a['hourIndex'] <=> $b['hourIndex']);

        return array_slice($normalized, 0, self::HEALTH_RISK_MAX_HOURS);
    }

    /**
     * Read a numeric value, accepting numeric strings from the model.
     */
    protected function number(mixed $value): ?float
    {
        return is_numeric($value) ? (float) $value : null;
    }

    /**
     * Clamp a numeric value to an integer range.
     */
    protected function clampInt(mixed $value, int $min, int $max): int
    {
        $number = $this->number($value);

        if ($number === null) {
            return $min;
        }

        return (int) max($min, min($max, (int) round($number)));
    }

    /**
     * Keep only the non-empty strings from a list, preserving order.
     *
     * @return array<int, string>
     */
    protected function stringList(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $strings = [];

        foreach ($value as $item) {
            if (is_string($item) && trim($item) !== '') {
                $strings[] = $item;
            }
        }

        return $strings;
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
        return (string) config('services.openrouter.model', 'openrouter/free');
    }
}