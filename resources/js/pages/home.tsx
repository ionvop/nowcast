import { useQuery } from '@tanstack/react-query';
import { CloudSun, MapPin, Thermometer } from 'lucide-react';

import AppShell from '@/components/app-shell';
import LoadingOverlay from '@/components/loading-overlay';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { api } from '@/lib/api';
import { convertHour } from '@/lib/format';
import { useGeolocation } from '@/lib/use-geolocation';
import type { ForecastHour } from '@/types/weather';

const TOTAL_STEPS = 4;

export default function HomePage() {
    const { coords, error: geoError, loading: geoLoading } = useGeolocation();

    const coordsReady = coords != null;

    // Current weather
    const weatherQuery = useQuery({
        queryKey: ['weather', coords?.latitude, coords?.longitude],
        queryFn: ({ signal }) =>
            api.weather(coords!.latitude, coords!.longitude, signal),
        enabled: coordsReady,
    });

    // Reverse geocode
    const geocodeQuery = useQuery({
        queryKey: ['geocode', coords?.latitude, coords?.longitude],
        queryFn: ({ signal }) =>
            api.geocode(coords!.latitude, coords!.longitude, signal),
        enabled: coordsReady,
    });

    // Hourly forecast
    const forecastQuery = useQuery({
        queryKey: ['forecast', coords?.latitude, coords?.longitude],
        queryFn: ({ signal }) =>
            api.forecast(coords!.latitude, coords!.longitude, signal),
        enabled: coordsReady,
    });

    const loading =
        geoLoading ||
        (coordsReady &&
            (weatherQuery.isPending || geocodeQuery.isPending || forecastQuery.isPending));

    // Derive the current progress step from the loading state.
    const step = geoLoading
        ? 1
        : weatherQuery.isPending
          ? 2
          : geocodeQuery.isPending
            ? 3
            : forecastQuery.isPending
              ? 4
              : 4;

    const loadingLabel =
        step === 1
            ? 'Loading geolocation...'
            : step === 2
              ? 'Loading current weather...'
              : step === 3
                ? 'Loading your location...'
                : 'Loading hourly forecast...';

    const current = weatherQuery.data;
    const address = geocodeQuery.data?.results?.[0]?.formattedAddress;
    const hours = forecastQuery.data?.forecastHours ?? [];

    return (
        <div className="space-y-4">
            {loading && <LoadingOverlay label={loadingLabel} step={step} total={TOTAL_STEPS} />}

            {geoError && !coords && (
                <Card>
                    <CardContent className="p-6 text-center">
                        <p className="font-medium text-muted">
                            We couldn't access your location.
                        </p>
                        <p className="mt-1 text-sm text-muted">
                            Please grant location permission and reload to see weather for your
                            area.
                        </p>
                    </CardContent>
                </Card>
            )}

            {coords && (
                <>
                    {/* Current Weather */}
                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <CloudSun className="h-5 w-5 text-theme" />
                                Current Weather
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            {weatherQuery.isError ? (
                                <p className="text-sm text-muted">
                                    Weather data is currently unavailable.
                                </p>
                            ) : (
                                <div className="flex items-center gap-4">
                                    {current?.weatherCondition?.iconBaseUri && (
                                        <img
                                            src={current.weatherCondition.iconBaseUri + '.svg'}
                                            alt={
                                                current.weatherCondition.description?.text ??
                                                'Weather icon'
                                            }
                                            className="h-16 w-16"
                                        />
                                    )}
                                    <div>
                                        <p className="text-4xl font-bold">
                                            {current?.temperature?.degrees != null
                                                ? `${Math.round(current.temperature.degrees)}°C`
                                                : '--'}
                                        </p>
                                        <p className="text-muted">
                                            {current?.weatherCondition?.description?.text ??
                                                'Loading...'}
                                        </p>
                                    </div>
                                </div>
                            )}
                        </CardContent>
                    </Card>

                    {/* City / Address */}
                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <MapPin className="h-5 w-5 text-theme" />
                                Location
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            {geocodeQuery.isError ? (
                                <p className="text-sm text-muted">
                                    Location name is currently unavailable.
                                </p>
                            ) : (
                                <p className="text-muted">{address ?? 'Loading...'}</p>
                            )}
                        </CardContent>
                    </Card>

                    {/* Hourly Forecast */}
                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <Thermometer className="h-5 w-5 text-theme" />
                                Hourly Forecast
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            {forecastQuery.isError ? (
                                <p className="text-sm text-muted">
                                    Forecast data is currently unavailable.
                                </p>
                            ) : (
                                <ForecastStrip hours={hours} />
                            )}
                        </CardContent>
                    </Card>
                </>
            )}
        </div>
    );
}

function ForecastStrip({ hours }: { hours: ForecastHour[] }) {
    if (hours.length === 0) {
        return <p className="text-sm text-muted">Loading forecast...</p>;
    }

    return (
        <div className="flex gap-3 overflow-x-auto pb-2">
            {hours.map((hour, index) => {
                const time = hour.interval?.startTime
                    ? new Date(hour.interval.startTime)
                    : null;
                const hourLabel = time ? convertHour(time.getHours()) : `+${index}h`;
                const iconUri = hour.weatherCondition?.iconBaseUri;
                const temp = hour.temperature?.degrees;

                return (
                    <div
                        key={hour.interval?.startTime ?? index}
                        className="flex min-w-[72px] flex-col items-center gap-1 rounded-xl border border-theme/20 bg-white p-3"
                    >
                        <span className="text-xs font-medium text-muted">{hourLabel}</span>
                        {iconUri && (
                            <img
                                src={iconUri + '.svg'}
                                alt=""
                                className="h-9 w-9"
                            />
                        )}
                        <span className="text-sm font-semibold">
                            {temp != null ? `${Math.round(temp)}°` : '--'}
                        </span>
                    </div>
                );
            })}
        </div>
    );
}

HomePage.layout = (page: React.ReactNode) => <AppShell>{page}</AppShell>;
