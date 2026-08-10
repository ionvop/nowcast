<?php

namespace App\Http\Controllers;

use App\Exceptions\GoogleApiException;
use App\Http\Requests\CoordinateRequest;
use App\Services\GoogleWeatherService;
use Illuminate\Http\JsonResponse;

class WeatherController extends Controller
{
    public function __construct(private readonly GoogleWeatherService $weather)
    {
    }

    /**
     * Return the current weather conditions for a coordinate.
     */
    public function currentConditions(CoordinateRequest $request): JsonResponse
    {
        return $this->proxy(fn () => $this->weather->currentConditions(
            (float) $request->latitude,
            (float) $request->longitude,
        ));
    }

    /**
     * Return the 6-hour hourly forecast for a coordinate.
     */
    public function forecast(CoordinateRequest $request): JsonResponse
    {
        return $this->proxy(fn () => $this->weather->hourlyForecast(
            (float) $request->latitude,
            (float) $request->longitude,
        ));
    }

    /**
     * Reverse-geocode a coordinate into a human-readable address.
     */
    public function geocode(CoordinateRequest $request): JsonResponse
    {
        return $this->proxy(fn () => $this->weather->reverseGeocode(
            (float) $request->latitude,
            (float) $request->longitude,
        ));
    }

    /**
     * Execute an upstream call and translate failures into a uniform 502 JSON error.
     *
     * @param  callable(): array<string, mixed>  $call
     */
    protected function proxy(callable $call): JsonResponse
    {
        try {
            return response()->json($call());
        } catch (GoogleApiException $e) {
            return response()->json(
                ['message' => $e->getMessage()],
                $e->statusCode,
            );
        }
    }
}