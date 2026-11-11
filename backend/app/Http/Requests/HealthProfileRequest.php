<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Validates the personal and health details used for heat-risk modelling.
 *
 * Only `age` and `biologicalSex` are required. Everything else is optional so
 * the user can share as much or as little as they are comfortable with; the
 * model treats missing values as "unknown" rather than as "no risk".
 *
 * @property int $age
 * @property string $biologicalSex
 * @property float|null $heightCm
 * @property float|null $weightKg
 * @property string|null $activityLevel
 * @property array<int, string>|null $conditions
 * @property array<int, string>|null $medications
 * @property array<int, string>|null $lifestyle
 */
class HealthProfileRequest extends FormRequest
{
    /**
     * The accepted biological-sex values.
     *
     * @var array<int, string>
     */
    public const SEXES = ['male', 'female', 'other'];

    /**
     * The accepted activity levels, from least to most active.
     *
     * @var array<int, string>
     */
    public const ACTIVITY_LEVELS = ['sedentary', 'light', 'moderate', 'active', 'very_active'];

    /**
     * The chronic conditions that materially raise heat-strain risk.
     *
     * @var array<int, string>
     */
    public const CONDITIONS = [
        'cardiovascular',
        'diabetes',
        'respiratory',
        'kidney',
        'pregnancy',
        'neurological',
        'obesity',
    ];

    /**
     * The medication classes that impair thermoregulation.
     *
     * @var array<int, string>
     */
    public const MEDICATIONS = [
        'diuretics',
        'beta_blockers',
        'anticholinergics',
        'antipsychotics',
        'stimulants',
        'antihistamines',
    ];

    /**
     * The behavioural and environmental modifiers the model can reason about.
     *
     * @var array<int, string>
     */
    public const LIFESTYLE = [
        'acclimatized',
        'alcohol',
        'dehydrated',
        'outdoor_worker',
        'high_fitness',
        'limited_mobility',
    ];

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
            'age' => ['required', 'integer', 'between:1,120'],
            'biologicalSex' => ['required', 'string', Rule::in(self::SEXES)],
            'heightCm' => ['nullable', 'numeric', 'between:50,250'],
            'weightKg' => ['nullable', 'numeric', 'between:20,300'],
            'activityLevel' => ['nullable', 'string', Rule::in(self::ACTIVITY_LEVELS)],
            'conditions' => ['nullable', 'array', 'max:10'],
            'conditions.*' => ['string', Rule::in(self::CONDITIONS)],
            'medications' => ['nullable', 'array', 'max:10'],
            'medications.*' => ['string', Rule::in(self::MEDICATIONS)],
            'lifestyle' => ['nullable', 'array', 'max:10'],
            'lifestyle.*' => ['string', Rule::in(self::LIFESTYLE)],
        ];
    }
}
