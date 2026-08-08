import { Link, router, usePage } from '@inertiajs/react';
import {
    Activity,
    Home,
    Map as MapIcon,
    MessageSquare,
    RefreshCw,
    User,
} from 'lucide-react';

import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

const NAV_ITEMS = [
    { key: 'home', label: 'Home', href: '/', icon: Home },
    { key: 'heat', label: 'Heat Data', href: '/heat', icon: Activity },
    { key: 'map', label: 'Map', href: '/map', icon: MapIcon },
    { key: 'community', label: 'Community', href: '/community', icon: MessageSquare },
    { key: 'profile', label: 'Profile', href: '/profile', icon: User },
] as const;

const TITLES: Record<string, string> = {
    home: 'Home',
    heat: 'Heat Data',
    map: 'Map',
    community: 'Community',
    profile: 'Profile',
};

export default function AppShell({
    children,
}: {
    children: React.ReactNode;
}) {
    const { component } = usePage();
    const activeKey = component.toLowerCase();
    const title = TITLES[activeKey] ?? 'Nowcast';

    const reload = () => {
        router.reload({ only: [] });
    };

    return (
        <div className="flex min-h-dvh flex-col bg-surface">
            {/* Header */}
            <header className="sticky top-0 z-20 flex h-14 items-center justify-between bg-theme px-3 text-white shadow">
                <Link href="/profile" aria-label="Profile">
                    <Button
                        variant="ghost"
                        size="icon"
                        className="text-white hover:bg-white/20 hover:text-white"
                    >
                        <User className="h-5 w-5" />
                    </Button>
                </Link>

                <h1 className="text-lg font-bold">{title}</h1>

                <Button
                    variant="ghost"
                    size="icon"
                    onClick={reload}
                    aria-label="Reload"
                    className="text-white hover:bg-white/20 hover:text-white"
                >
                    <RefreshCw className="h-5 w-5" />
                </Button>
            </header>

            {/* Content */}
            <main className="mx-auto w-full max-w-md flex-1 px-4 py-4 pb-24">
                {children}
            </main>

            {/* Bottom nav */}
            <nav className="fixed inset-x-0 bottom-0 z-20 border-t border-theme/20 bg-white">
                <div className="mx-auto grid max-w-md grid-cols-5">
                    {NAV_ITEMS.map((item) => {
                        const Icon = item.icon;
                        const active = activeKey === item.key;
                        return (
                            <Link
                                key={item.key}
                                href={item.href}
                                className={cn(
                                    'flex flex-col items-center gap-1 py-2 text-xs font-medium transition-colors',
                                    active
                                        ? 'text-theme'
                                        : 'text-muted hover:text-theme',
                                )}
                            >
                                <Icon
                                    className={cn(
                                        'h-5 w-5',
                                        active && 'fill-theme/20',
                                    )}
                                />
                                <span>{item.label}</span>
                            </Link>
                        );
                    })}
                </div>
            </nav>
        </div>
    );
}
