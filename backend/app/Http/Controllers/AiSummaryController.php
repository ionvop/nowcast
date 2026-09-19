<?php

namespace App\Http\Controllers;

use App\Exceptions\OpenRouterApiException;
use App\Http\Requests\AiSummaryRequest;
use App\Services\OpenRouterService;
use Illuminate\Http\JsonResponse;

class AiSummaryController extends Controller
{
    public function __construct(private readonly OpenRouterService $ai)
    {
    }

    /**
     * Generate a short AI summary, health advice, and a recommended article
     * from the current-conditions and forecast payloads supplied by the client.
     */
    public function summary(AiSummaryRequest $request): JsonResponse
    {
        try {
            $analysis = $this->ai->summarize(
                $request->currentConditions,
                $request->hourlyForecast ?? [],
                $request->dailyForecast ?? [],
            );
        } catch (OpenRouterApiException $e) {
            return response()->json(
                ['message' => $e->getMessage()],
                $e->statusCode,
            );
        }

        return response()->json([
            'summary' => $analysis['summary'],
            'healthAdvice' => $analysis['healthAdvice'],
            'articleUrl' => $analysis['articleUrl'],
        ]);
    }
}