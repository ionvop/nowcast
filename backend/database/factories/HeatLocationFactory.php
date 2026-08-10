<?php

namespace Database\Factories;

use App\Models\HeatLocation;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<HeatLocation>
 */
class HeatLocationFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'heat_index' => fake()->optional()->randomFloat(2, 10, 55),
            'latitude' => fake()->latitude(),
            'longitude' => fake()->longitude(),
        ];
    }
}