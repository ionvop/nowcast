/**
 * Shared formatting utilities for the Nowcast app.
 */

/**
 * Convert a 24-hour hour (0-23) to a 12-hour AM/PM string, e.g. 15 -> "3PM".
 */
export function convertHour(hour24: number): string {
    const period = hour24 >= 12 ? 'PM' : 'AM';

    const hour12 = hour24 % 12 === 0 ? 12 : hour24 % 12;

    return `${hour12}${period}`;
}
