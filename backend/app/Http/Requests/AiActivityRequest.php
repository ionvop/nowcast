<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * @property array<string, mixed> $currentConditions
 * @property array<string, mixed>|null $hourlyForecast
 * @property array<string, mixed>|null $dailyForecast
 * @property float $latitude
 * @property float $longitude
 * @property ?string $placeName
 */
class AiActivityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'currentConditions' => ['required', 'array'],
            'hourlyForecast' => ['sometimes', 'array'],
            'dailyForecast' => ['sometimes', 'array'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'placeName' => ['sometimes', 'string'],
        ];
    }
}