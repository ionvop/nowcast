<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * A crowd-sourced weather reading for a coordinate.
 *
 * Unlike {@link HeatLocation}, which stores only the heat index, this model
 * persists the entire Google current-conditions payload in the `data` JSON
 * column so the client can read any weather field it needs.
 */
#[Fillable(['data', 'latitude', 'longitude'])]
class WeatherLocation extends Model
{
    /** @use HasFactory<\Database\Factories\WeatherLocationFactory> */
    use HasFactory;

    protected function casts(): array
    {
        return [
            'data' => 'array',
            'latitude' => 'float',
            'longitude' => 'float',
        ];
    }
}