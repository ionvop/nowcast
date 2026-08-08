import { CloudSun } from 'lucide-react';

import AppShell from '@/components/app-shell';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';

export default function HomePage() {
    return (
        <div className="space-y-4">
            <Card>
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <CloudSun className="h-5 w-5 text-theme" />
                        Current Weather
                    </CardTitle>
                    <CardDescription>
                        Live conditions for your location will appear here.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <p className="text-muted">
                        Weather data is not wired up yet.
                    </p>
                </CardContent>
            </Card>

            <Card>
                <CardHeader>
                    <CardTitle>Hourly Forecast</CardTitle>
                    <CardDescription>
                        A 6-hour forecast strip will appear here.
                    </CardDescription>
                </CardHeader>
                <CardContent>
                    <p className="text-muted">
                        Forecast data is not wired up yet.
                    </p>
                </CardContent>
            </Card>
        </div>
    );
}

HomePage.layout = (page: React.ReactNode) => <AppShell>{page}</AppShell>;
