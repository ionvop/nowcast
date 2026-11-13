<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * Validates the weather payloads sent to the health-risk endpoint.
 *
 * The health profile is deliberately **not** part of this request: the
 * controller reads it from the authenticated user so the client cannot spoof
 * or omit health details.
 *
 * @property array<string, mixed> $currentConditions
 * @property array<string, mixed>|null $hourlyForecast
 * @property array<string, mixed>|null $dailyForecast
 * @property array<string, mixed>|null $previousAssessment
 * @property float $latitude
 * @property float $longitude
 * @property ?string $placeName
 */
class AiHealthRiskRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'currentConditions' => ['required', 'array'],
            'hourlyForecast' => ['sometimes', 'array'],
            'dailyForecast' => ['sometimes', 'array'],
            'previousAssessment' => ['sometimes', 'nullable', 'array'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'placeName' => ['sometimes', 'string'],
        ];
    }
}
