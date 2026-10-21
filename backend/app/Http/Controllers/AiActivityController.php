<?php

namespace App\Http\Controllers;

use App\Exceptions\OpenRouterApiException;
use App\Http\Requests\AiActivityRequest;
use App\Services\OpenRouterService;
use Illuminate\Http\JsonResponse;

class AiActivityController extends Controller
{
    public function __construct(private readonly OpenRouterService $ai)
    {
    }

    /**
     * Recommend nearby activities that fit the current weather, using the
     * current-conditions and forecast payloads plus the location supplied by
     * the client. The model uses web search to find real nearby places.
     */
    public function activities(AiActivityRequest $request): JsonResponse
    {
        try {
            $result = $this->ai->suggestActivities(
                $request->currentConditions,
                $request->hourlyForecast ?? [],
                $request->dailyForecast ?? [],
                (float) $request->latitude,
                (float) $request->longitude,
                $request->placeName ?? null,
            );
        } catch (OpenRouterApiException $e) {
            return response()->json(
                ['message' => $e->getMessage()],
                $e->statusCode,
            );
        }

        return response()->json([
            'suggestions' => $result['suggestions'],
        ]);
    }
}