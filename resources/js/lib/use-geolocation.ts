import { useCallback, useEffect, useState } from 'react';

export type Coordinates = {
    latitude: number;
    longitude: number;
};

type GeolocationState = {
    coords: Coordinates | null;
    error: string | null;
    loading: boolean;
};

const OPTIONS: PositionOptions = {
    enableHighAccuracy: true,
    timeout: 15000,
    maximumAge: 60000,
};

function getPosition(): Promise<Coordinates> {
    return new Promise((resolve, reject) => {
        if (!('geolocation' in navigator)) {
            reject(new Error('Geolocation is not supported.'));

            return;
        }

        navigator.geolocation.getCurrentPosition(
            (position) =>
                resolve({
                    latitude: position.coords.latitude,
                    longitude: position.coords.longitude,
                }),
            (err) => reject(new Error(err.message || 'Unable to retrieve your location.')),
            OPTIONS,
        );
    });
}

/**
 * Request the browser's geolocation once on mount. Returns the coordinates,
 * an error message, and a loading flag. Call `request` to re-trigger.
 */
export function useGeolocation() {
    const [state, setState] = useState<GeolocationState>({
        coords: null,
        error: null,
        loading: true,
    });

    const request = useCallback(() => {
        setState({ coords: null, error: null, loading: true });
        getPosition()
            .then((coords) => setState({ coords, error: null, loading: false }))
            .catch((err: Error) =>
                setState({ coords: null, error: err.message, loading: false }),
            );
    }, []);

    useEffect(() => {
        let active = true;

        getPosition()
            .then((coords) => {
                if (active) {
                    setState({ coords, error: null, loading: false });
                }
            })
            .catch((err: Error) => {
                if (active) {
                    setState({ coords: null, error: err.message, loading: false });
                }
            });

        return () => {
            active = false;
        };
    }, []);

    return { ...state, request };
}
