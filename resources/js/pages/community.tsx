import { MessageSquare } from 'lucide-react';

import AppShell from '@/components/app-shell';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';

export default function CommunityPage() {
    return (
        <Card>
            <CardHeader>
                <CardTitle className="flex items-center gap-2">
                    <MessageSquare className="h-5 w-5 text-theme" />
                    Community
                </CardTitle>
                <CardDescription>
                    The public feed of posts will appear here.
                </CardDescription>
            </CardHeader>
            <CardContent>
                <p className="text-muted">
                    Community posts are not wired up yet.
                </p>
            </CardContent>
        </Card>
    );
}

CommunityPage.layout = (page: React.ReactNode) => <AppShell>{page}</AppShell>;
