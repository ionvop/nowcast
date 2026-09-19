<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * @property array<string, mixed> $currentConditions
 * @property array<string, mixed>|null $hourlyForecast
 * @property array<string, mixed>|null $dailyForecast
 */
class AiSummaryRequest extends FormRequest
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
        ];
    }
}