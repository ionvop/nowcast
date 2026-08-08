import { User } from 'lucide-react';

import AppShell from '@/components/app-shell';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';

export default function ProfilePage() {
    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <User className="h-5 w-5 text-theme" />
                    Profile
                </CardTitle>
                <CardDescription>
                    Google sign-in and account details will appear here.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <p className="text-muted">
                    Authentication is not wired up yet.
                </p>
            </CardContent>
        </Card>
    );
}

ProfilePage.layout = (page: React.ReactNode) => <AppShell>{page}</AppShell>;
