<?php

namespace Database\Factories;

use App\Models\WeatherLocation;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<WeatherLocation>
 */
class WeatherLocationFactory extends Factory
{
    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'data' => [
                'currentTime' => fake()->iso8601(),
                'isDaytime' => fake()->boolean(),
                'weatherCondition' => [
                    'iconBaseUri' => 'https://maps.gstatic.com/weather/v1/sunny',
                    'description' => ['text' => 'Sunny', 'languageCode' => 'en'],
                    'type' => 'CLEAR',
                ],
                'temperature' => ['degrees' => fake()->randomFloat(2, -10, 45), 'unit' => 'CELSIUS'],
                'feelsLikeTemperature' => ['degrees' => fake()->randomFloat(2, -10, 45), 'unit' => 'CELSIUS'],
                'heatIndex' => fake()->optional()->randomFloat(2, 10, 55),
                'relativeHumidity' => fake()->numberBetween(0, 100),
            ],
            'latitude' => fake()->latitude(),
            'longitude' => fake()->longitude(),
        ];
    }
}