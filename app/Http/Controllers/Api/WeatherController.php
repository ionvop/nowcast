<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;

class WeatherController extends Controller
{
    /**
     * Proxy the Google Weather API current conditions lookup.
     */
    public function weather(Request $request): JsonResponse
    {
        $data = $this->validateCoordinates($request);

        $response = Http::get('https://weather.googleapis.com/v1/currentConditions:lookup', [
            'key' => config('services.google.api_key'),
            'location.latitude' => $data['latitude'],
            'location.longitude' => $data['longitude'],
        ]);

        return $this->proxyResponse($response);
    }

    /**
     * Proxy the Google Geocoding API reverse geocode lookup.
     */
    public function geocode(Request $request): JsonResponse
    {
        $data = $this->validateCoordinates($request);

        $response = Http::get('https://geocode.googleapis.com/v4/geocode/location', [
            'key' => config('services.google.api_key'),
            'location.latitude' => $data['latitude'],
            'location.longitude' => $data['longitude'],
        ]);

        return $this->proxyResponse($response);
    }

    /**
     * Proxy the Google Weather API hourly forecast lookup (fixed 6 hours).
     */
    public function forecast(Request $request): JsonResponse
    {
        $data = $this->validateCoordinates($request);

        $response = Http::get('https://weather.googleapis.com/v1/forecast/hours:lookup', [
            'key' => config('services.google.api_key'),
            'hours' => 6,
            'location.latitude' => $data['latitude'],
            'location.longitude' => $data['longitude'],
        ]);

        return $this->proxyResponse($response);
    }

    /**
     * Validate and return the latitude/longitude from the request.
     *
     * @return array{latitude: float, longitude: float}
     */
    private function validateCoordinates(Request $request): array
    {
        $data = $request->validate([
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
        ]);

        return [
            'latitude' => (float) $data['latitude'],
            'longitude' => (float) $data['longitude'],
        ];
    }

    /**
     * Return the upstream response as JSON, preserving its status code.
     */
    private function proxyResponse(\Illuminate\Http\Client\Response $response): JsonResponse
    {
        return response()->json(
            $response->json(),
            $response->status(),
        );
    }
}
