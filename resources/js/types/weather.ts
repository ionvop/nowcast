/**
 * Types describing the Google Weather API responses as proxied by the backend.
 * These are intentionally loose to accommodate the upstream response shape.
 */

export type WeatherCondition = {
    code?: string;
    description?: string;
    iconBaseUri?: string;
    iconUri?: string;
    temperature?: {
        value?: number;
        unit?: string;
    };
    feelsLikeTemperature?: {
        value?: number;
        unit?: string;
    };
    dewPoint?: {
        value?: number;
        unit?: string;
    };
    heatIndex?: {
        value?: number;
        unit?: string;
    };
    windChill?: {
        value?: number;
        unit?: string;
    };
    wetBulbTemperature?: {
        value?: number;
        unit?: string;
    };
    [key: string]: unknown;
};

export type Weather = {
    weatherCondition?: {
        iconBaseUri?: string;
        description?: {
            text?: string;
            languageCode?: string;
        };
        type?: string;
    };
    temperature?: {
        unit?: string;
        degrees?: number;
    };
    [key: string]: unknown;
};

export type ForecastHour = {
    interval?: {
        startTime?: string;
        endTime?: string;
    };
    weatherCondition?: {
        iconBaseUri?: string;
        description?: {
            text?: string;
            languageCode?: string;
        };
        type?: string;
    };
    temperature?: {
        unit?: string;
        degrees?: number;
    };
    [key: string]: unknown;
};

export type Forecast = {
    forecastHours?: ForecastHour[];
    [key: string]: unknown;
};

export type GeocodeResult = {
    formattedAddress?: string;
    [key: string]: unknown;
};

export type Geocode = {
    results?: GeocodeResult[];
    [key: string]: unknown;
};
