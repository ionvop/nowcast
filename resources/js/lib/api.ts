/**
 * Thin typed wrapper around fetch for the Nowcast JSON API.
 */

import type { Forecast, Geocode, Weather } from '@/types/weather';

export class ApiError extends Error {
    status: number;

    constructor(message: string, status: number) {
        super(message);
        this.name = 'ApiError';
        this.status = status;
    }
}

type ApiOptions = {
    signal?: AbortSignal;
};

async function postJson<T>(
    url: string,
    body: Record<string, unknown>,
    options: ApiOptions = {},
): Promise<T> {
    const response = await fetch(url, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            Accept: 'application/json',
        },
        body: JSON.stringify(body),
        signal: options.signal,
    });

    if (!response.ok) {
        throw new ApiError(`Request to ${url} failed (${response.status})`, response.status);
    }

    return (await response.json()) as T;
}

export const api = {
    weather: (latitude: number, longitude: number, signal?: AbortSignal) =>
        postJson<Weather>('/api/weather', { latitude, longitude }, { signal }),

    geocode: (latitude: number, longitude: number, signal?: AbortSignal) =>
        postJson<Geocode>('/api/geocode', { latitude, longitude }, { signal }),

    forecast: (latitude: number, longitude: number, signal?: AbortSignal) =>
        postJson<Forecast>('/api/forecast', { latitude, longitude }, { signal }),
};
