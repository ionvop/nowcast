<?php

namespace App\Http\Controllers;

use App\Exceptions\GoogleApiException;
use App\Http\Requests\CoordinateRequest;
use App\Models\WeatherLocation;
use App\Services\GoogleWeatherService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

/**
 * Crowd-sourced weather readings for a coordinate.
 *
 * This is the replacement for {@link HeatLocationController}: instead of
 * persisting only the heat index, each reading stores the entire Google
 * current-conditions payload in the `data` JSON column.
 */
class WeatherLocationController extends Controller
{
    /**
     * The approximate distance (in degrees) used to deduplicate readings.
     *
     * ~0.001° of latitude/longitude is roughly 100 m at the equator, which is
     * the tolerance used for collapsing nearby crowd-sourced readings into a
     * single point.
     */
    protected const DEDUP_DEGREES = 0.01;

    public function __construct(private readonly GoogleWeatherService $weather)
    {
    }

    /**
     * Analyze a coordinate: fetch its full current weather payload, replace
     * any nearby reading, and return the stored reading.
     *
     * Existing rows within ~0.001° (~100 m) of the point and rows older than
     * 1 hour are deleted before the new reading is inserted.
     */
    public function analyze(CoordinateRequest $request): JsonResponse
    {
        try {
            $payload = $this->weather->currentConditions(
                (float) $request->latitude,
                (float) $request->longitude,
            );
        } catch (GoogleApiException $e) {
            return response()->json(
                ['message' => $e->getMessage()],
                $e->statusCode,
            );
        }

        $latitude = (float) $request->latitude;
        $longitude = (float) $request->longitude;

        $this->purgeStale();
        $this->deleteNearby($latitude, $longitude);

        $location = WeatherLocation::create([
            'data' => $payload,
            'latitude' => $latitude,
            'longitude' => $longitude,
        ]);

        return response()->json([
            'data' => $location->data,
            'latitude' => $location->latitude,
            'longitude' => $location->longitude,
            'createdAt' => $location->created_at,
        ]);
    }

    /**
     * Return all current weather-location readings.
     *
     * Rows older than 1 hour are purged first.
     */
    public function index(): JsonResponse
    {
        $this->purgeStale();

        return response()->json(WeatherLocation::all());
    }

    /**
     * Delete weather-location rows older than 1 hour.
     */
    protected function purgeStale(): void
    {
        WeatherLocation::query()
            ->where('created_at', '<', Carbon::now()->subHour())
            ->delete();
    }

    /**
     * Delete weather-location rows within ~0.001° (~100 m) of a coordinate.
     */
    protected function deleteNearby(float $latitude, float $longitude): void
    {
        WeatherLocation::query()
            ->whereBetween('latitude', [
                $latitude - self::DEDUP_DEGREES,
                $latitude + self::DEDUP_DEGREES,
            ])
            ->whereBetween('longitude', [
                $longitude - self::DEDUP_DEGREES,
                $longitude + self::DEDUP_DEGREES,
            ])
            ->delete();
    }
}