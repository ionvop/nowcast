<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A user's personal and health details, used to personalize heat-risk
 * modelling.
 *
 * Only `age` and `biological_sex` are required; the remaining columns are
 * nullable so the user can share as much or as little as they wish. The three
 * JSON columns hold arrays of short machine-readable keys (see
 * {@link \App\Http\Requests\HealthProfileRequest} for the allowed values).
 */
#[Fillable([
    'age',
    'biological_sex',
    'height_cm',
    'weight_kg',
    'activity_level',
    'conditions',
    'medications',
    'lifestyle',
])]
class HealthProfile extends Model
{
    /** @use HasFactory<\Database\Factories\HealthProfileFactory> */
    use HasFactory;

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'age' => 'integer',
            'height_cm' => 'float',
            'weight_kg' => 'float',
            'conditions' => 'array',
            'medications' => 'array',
            'lifestyle' => 'array',
        ];
    }

    /**
     * The user this profile belongs to.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
