<?php

namespace App\Services;

use App\Exceptions\GoogleApiException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;

/**
 * Proxies the Google Weather and Geocoding APIs to the Flutter client.
 *
 * All upstream Google calls go through this single service so that error
 * handling, key resolution, and base URLs stay uniform across endpoints.
 */
class GoogleWeatherService
{
    /**
     * The base URL for the Google Weather API.
     */
    protected const WEATHER_BASE = 'https://weather.googleapis.com/v1';

    /**
     * The base URL for the Google Geocoding API.
     */
    protected const GEOCODE_BASE = 'https://geocode.googleapis.com/v4/geocode';

    /**
     * Fetch the current weather conditions for a coordinate.
     *
     * @return array<string, mixed> The raw Google current-conditions payload.
     */
    public function currentConditions(float $latitude, float $longitude): array
    {
        return $this->get(
            self::WEATHER_BASE.'/currentConditions:lookup',
            ['location' => ['latitude' => $latitude, 'longitude' => $longitude]],
        );
    }

    /**
     * Fetch the hourly forecast for a coordinate.
     *
     * @param  int  $hours  Number of hours to forecast (default 6).
     * @return array<string, mixed> The raw Google forecast payload.
     */
    public function hourlyForecast(float $latitude, float $longitude, int $hours = 6): array
    {
        return $this->get(
            self::WEATHER_BASE.'/forecast/hours:lookup',
            [
                'location' => ['latitude' => $latitude, 'longitude' => $longitude],
                'hours' => $hours,
            ],
        );
    }

    /**
     * Reverse-geocode a coordinate into a human-readable address.
     *
     * @return array<string, mixed> The raw Google geocode payload.
     */
    public function reverseGeocode(float $latitude, float $longitude): array
    {
        return $this->get(
            self::GEOCODE_BASE.'/location',
            ['location' => ['latitude' => $latitude, 'longitude' => $longitude]],
        );
    }

    /**
     * Perform a GET against the given Google endpoint and decode its payload.
     *
     * @param  string  $url  The full (key-less) endpoint URL.
     * @param  array<string, mixed>  $query  Query parameters (without the key).
     * @return array<string, mixed> The decoded JSON response.
     *
     * @throws GoogleApiException When Google is unreachable or returns an error.
     */
    protected function get(string $url, array $query): array
    {
        try {
            $response = Http::timeout(10)
                ->retry(2, 100)
                ->get($url, $this->toQuery($query, $this->apiKey()));
        } catch (ConnectionException|RequestException) {
            throw new GoogleApiException('Google service is currently unreachable. Please try again later.');
        }

        if (! $response->successful()) {
            throw new GoogleApiException(
                'Google returned an error. Please try again later.',
                $response->status(),
            );
        }

        return $response->json();
    }

    /**
     * Flatten the payload and append the API key into a query-string array.
     *
     * Google's gRPC-transcoded APIs expect nested fields to be encoded with
     * dot notation (e.g. "location.latitude") rather than PHP's bracket
     * notation ("location[latitude]"). This converts the nested payload
     * produced by the callers into the flat, dotted form the API requires.
     *
     * @param  array<string, mixed>  $params
     * @return array<string, mixed>
     */
    protected function toQuery(array $params, string $key): array
    {
        $query = $this->flatten($params);
        $query['key'] = $key;

        return $query;
    }

    /**
     * Recursively flatten nested arrays into dot-notation keys.
     *
     * @param  array<string, mixed>  $params
     * @return array<string, mixed>
     */
    protected function flatten(array $params, string $prefix = ''): array
    {
        $flat = [];

        foreach ($params as $name => $value) {
            $key = $prefix === '' ? (string) $name : $prefix.'.'.$name;

            if (is_array($value)) {
                $flat = array_merge($flat, $this->flatten($value, $key));
            } else {
                $flat[$key] = $value;
            }
        }

        return $flat;
    }

    /**
     * Resolve the Google API key from configuration.
     *
     * @throws GoogleApiException When no key is configured.
     */
    protected function apiKey(): string
    {
        $key = config('services.google.api_key');

        if (is_string($key) && $key !== '') {
            return $key;
        }

        throw new GoogleApiException('Google API key is not configured.');
    }
}