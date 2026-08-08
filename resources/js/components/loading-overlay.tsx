import { Loader2 } from 'lucide-react';

/**
 * Full-page loading overlay with a spinner and a progress label,
 * e.g. "Loading geolocation... (1/4)".
 */
export default function LoadingOverlay({
    label,
    step,
    total,
}: {
    label: string;
    step?: number;
    total?: number;
}) {
    const progress = step != null && total != null ? ` (${step}/${total})` : '';

    return (
        <div className="fixed inset-0 z-50 flex flex-col items-center justify-center gap-4 bg-surface/90 backdrop-blur-sm">
            <Loader2 className="h-10 w-10 animate-spin text-theme" />
            <p className="text-sm font-medium text-muted">
                {label}
                {progress}
            </p>
        </div>
    );
}
