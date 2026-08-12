<?php

namespace App\Http\Controllers;

use App\Exceptions\GoogleApiException;
use App\Http\Requests\CoordinateRequest;
use App\Models\HeatLocation;
use App\Services\GoogleWeatherService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

class HeatLocationController extends Controller
{
    /**
     * The approximate distance (in degrees) used to deduplicate readings.
     *
     * ~0.001° of latitude/longitude is roughly 100 m at the equator, which is
     * the tolerance the spec requires for collapsing nearby crowd-sourced
     * heat-index readings into a single point.
     */
    protected const DEDUP_DEGREES = 0.001;

    public function __construct(private readonly GoogleWeatherService $weather)
    {
    }

    /**
     * Analyze a coordinate: fetch its current heat index, replace any nearby
     * reading, and return the stored reading.
     *
     * Existing rows within ~0.001° (~100 m) of the point, rows older than
     * 1 hour, and rows with a NULL heat index are deleted before the new
     * reading is inserted.
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
        $heatIndex = $this->extractHeatIndex($payload);

        $this->purgeStale();
        $this->deleteNearby($latitude, $longitude);

        $location = HeatLocation::create([
            'heat_index' => $heatIndex,
            'latitude' => $latitude,
            'longitude' => $longitude,
        ]);

        return response()->json([
            'heatIndex' => $location->heat_index,
            'latitude' => $location->latitude,
            'longitude' => $location->longitude,
            'createdAt' => $location->created_at,
        ]);
    }

    /**
     * Return all current heat-location readings.
     *
     * Rows older than 1 hour or with a NULL heat index are purged first.
     */
    public function index(): JsonResponse
    {
        $this->purgeStale();

        return response()->json(HeatLocation::all());
    }

    /**
     * Extract the heat index from a Google current-conditions payload.
     *
     * Google's real payload nests these values (see docs/endpoint-responses.md):
     * "feelsLikeTemperature" and "temperature" are objects with a "degrees"
     * field. The "feels like" temperature is used as the heat index, falling
     * back to the raw temperature when it is unavailable.
     *
     * @param  array<string, mixed>  $payload
     */
    protected function extractHeatIndex(array $payload): ?float
    {
        $conditions = $payload['currentConditions'] ?? [];

        if (! is_array($conditions)) {
            return null;
        }

        $value = $this->degrees($conditions['feelsLikeTemperature'] ?? null)
            ?? $this->degrees($conditions['temperature'] ?? null)
            ?? null;

        return is_numeric($value) ? (float) $value : null;
    }

    /**
     * Read the "degrees" value from a temperature object, or null.
     *
     * @param  mixed  $temperature  A temperature object like {"degrees": 13.7, "unit": "CELSIUS"}.
     */
    protected function degrees(mixed $temperature): ?float
    {
        if (! is_array($temperature)) {
            return null;
        }

        $degrees = $temperature['degrees'] ?? null;

        return is_numeric($degrees) ? (float) $degrees : null;
    }

    /**
     * Delete heat-location rows older than 1 hour or with a NULL heat index.
     */
    protected function purgeStale(): void
    {
        HeatLocation::query()
            ->where('created_at', '<', Carbon::now()->subHour())
            ->orWhereNull('heat_index')
            ->delete();
    }

    /**
     * Delete heat-location rows within ~0.001° (~100 m) of a coordinate.
     */
    protected function deleteNearby(float $latitude, float $longitude): void
    {
        HeatLocation::query()
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
