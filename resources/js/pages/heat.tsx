import { Activity } from 'lucide-react';

import AppShell from '@/components/app-shell';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';

export default function HeatDataPage() {
    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <Activity className="h-5 w-5 text-theme" />
                    Hourly Temperature Forecast
                </CardTitle>
                <CardDescription>
                    A 6-series heat-index chart will appear here.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <p className="text-muted">
                    Chart data is not wired up yet.
                </p>
            </CardContent>
        </Card>
    );
}

HeatDataPage.layout = (page: React.ReactNode) => <AppShell>{page}</AppShell>;
