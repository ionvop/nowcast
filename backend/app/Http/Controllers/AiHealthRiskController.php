<?php

namespace App\Http\Controllers;

use App\Exceptions\OpenRouterApiException;
use App\Http\Requests\AiHealthRiskRequest;
use App\Services\OpenRouterService;
use Illuminate\Http\JsonResponse;

/**
 * Generates a personalized heat-risk assessment from the authenticated user's
 * health profile and the weather payloads the client already fetched.
 *
 * The profile is read from the database rather than the request body, so the
 * assessment always reflects the details the user actually saved.
 */
class AiHealthRiskController extends Controller
{
    public function __construct(private readonly OpenRouterService $ai)
    {
    }

    /**
     * Assess the user's heat-strain risk and return the numbers the client
     * plots plus a written summary.
     */
    public function assess(AiHealthRiskRequest $request): JsonResponse
    {
        $profile = $request->user()->healthProfile;

        if ($profile === null) {
            return response()->json(
                ['message' => 'A health profile is required before generating an assessment.'],
                400,
            );
        }

        try {
            $assessment = $this->ai->assessHealthRisk(
                $this->profilePayload($profile),
                $request->currentConditions,
                $request->hourlyForecast ?? [],
                $request->dailyForecast ?? [],
                (float) $request->latitude,
                (float) $request->longitude,
                $request->placeName ?? null,
                $request->previousAssessment,
            );
        } catch (OpenRouterApiException $e) {
            return response()->json(
                ['message' => $e->getMessage()],
                $e->statusCode,
            );
        }

        return response()->json($assessment);
    }

    /**
     * Shape the stored profile into the camelCase payload the model expects.
     *
     * @return array<string, mixed>
     */
    protected function profilePayload(\App\Models\HealthProfile $profile): array
    {
        return [
            'age' => $profile->age,
            'biologicalSex' => $profile->biological_sex,
            'heightCm' => $profile->height_cm,
            'weightKg' => $profile->weight_kg,
            'activityLevel' => $profile->activity_level,
            'conditions' => $profile->conditions ?? [],
            'medications' => $profile->medications ?? [],
            'lifestyle' => $profile->lifestyle ?? [],
        ];
    }
}
