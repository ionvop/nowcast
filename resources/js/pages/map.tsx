import { Map as MapIcon } from 'lucide-react';

import AppShell from '@/components/app-shell';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';

export default function MapPage() {
    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <MapIcon className="h-5 w-5 text-theme" />
                    Heat Map
                </CardTitle>
                <CardDescription>
                    An interactive map of heat-index readings will appear here.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <p className="text-muted">
                    Map data is not wired up yet.
                </p>
            </CardContent>
        </Card>
    );
}

MapPage.layout = (page: React.ReactNode) => <AppShell>{page}</AppShell>;
