<?php

namespace App\Http\Controllers;

use App\Exceptions\GoogleApiException;
use App\Http\Requests\CoordinateRequest;
use App\Services\GoogleWeatherService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

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
     * Return the hourly forecast for a coordinate.
     *
     * An optional `hours` request field (1-360) controls the number of hours
     * to forecast. When omitted, the Google API default of 6 hours is used.
     */
    public function forecast(CoordinateRequest $request): JsonResponse
    {
        return $this->proxy(fn () => $this->weather->hourlyForecast(
            (float) $request->latitude,
            (float) $request->longitude,
            (int) $request->hours,
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
     * Proxy a weather icon image from the Google static CDN.
     *
     * The client passes the absolute icon URL (e.g. the `iconBaseUri` from the
     * weather payload) as the `iconBaseUri` query parameter. The image body is
     * returned with its original Content-Type so the client can render it
     * directly.
     */
    public function icon(Request $request): Response
    {
        $iconBaseUri = $request->query('iconBaseUri');

        if (! is_string($iconBaseUri) || $iconBaseUri === '') {
            return response()->json(['message' => 'The iconBaseUri query parameter is required.'], 400);
        }

        try {
            $icon = $this->weather->icon($iconBaseUri);
        } catch (GoogleApiException $e) {
            return response()->json(
                ['message' => $e->getMessage()],
                $e->statusCode,
            );
        }

        return response($icon['body'], 200, [
            'Content-Type' => $icon['contentType'],
        ]);
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