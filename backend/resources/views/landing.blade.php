<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}" class="scroll-smooth">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="Nowcast — a weather and heat-health monitoring app. Live weather, heat-index charts, an interactive heat map, community updates, and heat alerts.">

        <title>{{ config('app.name', 'Nowcast') }} — Weather & Heat-Health Monitoring</title>

        @fonts

        <!-- Styles / Scripts -->
        @if (file_exists(public_path('build/manifest.json')) || file_exists(public_path('hot')))
            @vite(['resources/css/app.css', 'resources/js/app.js'])
        @else
            <style>
                body { font-family: 'Instrument Sans', ui-sans-serif, system-ui, sans-serif; }
            </style>
        @endif
    </head>
    <body class="bg-[#EEEEFF] dark:bg-[#121212] text-[#1b1b18] dark:text-[#EDEDEC] font-sans antialiased min-h-screen flex flex-col">
        <!-- Header -->
        <header class="w-full">
            <nav class="max-w-6xl mx-auto px-6 py-5 flex items-center justify-between">
                <a href="/" class="flex items-center gap-2.5">
                    <span class="w-9 h-9 rounded-xl bg-[#00AAFF] flex items-center justify-center shadow-sm">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z" />
                        </svg>
                    </span>
                    <span class="text-lg font-semibold tracking-tight">Nowcast</span>
                </a>
                <a
                    href="https://github.com/ionvop/nowcast/releases"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium bg-[#00AAFF] text-white hover:bg-[#0095e0] transition-colors shadow-sm"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    Get the app
                </a>
            </nav>
        </header>

        <!-- Hero -->
        <main class="flex-1">
            <section class="max-w-6xl mx-auto px-6 pt-16 pb-20 text-center">
                <span class="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium bg-white dark:bg-[#1E1E1E] text-[#00AAFF] border border-[#00AAFF]/20 mb-6">
                    <span class="w-1.5 h-1.5 rounded-full bg-[#00AAFF]"></span>
                    Weather &amp; heat-health monitoring
                </span>

                <h1 class="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight leading-tight">
                    Know the heat<br class="hidden sm:block" />
                    <span class="text-[#00AAFF]">before it hits.</span>
                </h1>

                <p class="mt-6 max-w-2xl mx-auto text-lg text-[#4b4b4a] dark:text-[#A1A09A]">
                    Nowcast monitors current weather conditions and extreme-heat risk in your area — with live forecasts,
                    heat-index charts, an interactive heat map, and community updates.
                </p>

                <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
                    <a
                        href="https://github.com/ionvop/nowcast/releases"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="inline-flex items-center gap-2 px-8 py-4 rounded-2xl text-base font-semibold bg-[#00AAFF] text-white hover:bg-[#0095e0] transition-colors shadow-lg shadow-[#00AAFF]/25"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download Nowcast
                    </a>
                    <a
                        href="https://github.com/ionvop/nowcast"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="inline-flex items-center gap-2 px-8 py-4 rounded-2xl text-base font-semibold bg-white dark:bg-[#1E1E1E] text-[#1b1b18] dark:text-[#EDEDEC] border border-[#1b1b18]/10 dark:border-[#EDEDEC]/10 hover:border-[#00AAFF]/50 transition-colors"
                    >
                        View on GitHub
                    </a>
                </div>
            </section>

            <!-- Features -->
            <section class="max-w-6xl mx-auto px-6 pb-20">
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
                    <div class="bg-white dark:bg-[#1E1E1E] rounded-2xl p-6 shadow-sm border border-[#1b1b18]/5 dark:border-[#EDEDEC]/5">
                        <div class="w-11 h-11 rounded-xl bg-[#00AAFF]/10 flex items-center justify-center mb-4">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-[#00AAFF]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
                            </svg>
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Live weather &amp; forecast</h3>
                        <p class="text-sm text-[#4b4b4a] dark:text-[#A1A09A]">Current conditions, temperature, your city, and an hourly forecast strip for the next few hours.</p>
                    </div>

                    <div class="bg-white dark:bg-[#1E1E1E] rounded-2xl p-6 shadow-sm border border-[#1b1b18]/5 dark:border-[#EDEDEC]/5">
                        <div class="w-11 h-11 rounded-xl bg-[#00AAFF]/10 flex items-center justify-center mb-4">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-[#00AAFF]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                            </svg>
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Heat-index chart</h3>
                        <p class="text-sm text-[#4b4b4a] dark:text-[#A1A09A]">See how temperature, humidity, dew point, and heat index evolve over the next hours — and how dangerous it may feel.</p>
                    </div>

                    <div class="bg-white dark:bg-[#1E1E1E] rounded-2xl p-6 shadow-sm border border-[#1b1b18]/5 dark:border-[#EDEDEC]/5">
                        <div class="w-11 h-11 rounded-xl bg-[#00AAFF]/10 flex items-center justify-center mb-4">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-[#00AAFF]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7" />
                            </svg>
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Interactive heat map</h3>
                        <p class="text-sm text-[#4b4b4a] dark:text-[#A1A09A]">Crowd-sourced heat-index readings near you, from mild green to extreme purple. Tap anywhere to request a reading.</p>
                    </div>

                    <div class="bg-white dark:bg-[#1E1E1E] rounded-2xl p-6 shadow-sm border border-[#1b1b18]/5 dark:border-[#EDEDEC]/5">
                        <div class="w-11 h-11 rounded-xl bg-[#00AAFF]/10 flex items-center justify-center mb-4">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-[#00AAFF]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M17 8h2a2 2 0 012 2v6a2 2 0 01-2 2h-2v4l-4-4H9a1.994 1.994 0 01-1.414-.586m0 0L11 14h4a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2v4l.586-.586z" />
                            </svg>
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Community feed</h3>
                        <p class="text-sm text-[#4b4b4a] dark:text-[#A1A09A]">Share short, location-tagged updates with other users and see what's happening nearby.</p>
                    </div>

                    <div class="bg-white dark:bg-[#1E1E1E] rounded-2xl p-6 shadow-sm border border-[#1b1b18]/5 dark:border-[#EDEDEC]/5">
                        <div class="w-11 h-11 rounded-xl bg-[#00AAFF]/10 flex items-center justify-center mb-4">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-[#00AAFF]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                            </svg>
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Heat alerts</h3>
                        <p class="text-sm text-[#4b4b4a] dark:text-[#A1A09A]">Set a danger threshold and get notified when the heat index crosses it — even in the background.</p>
                    </div>

                    <div class="bg-white dark:bg-[#1E1E1E] rounded-2xl p-6 shadow-sm border border-[#1b1b18]/5 dark:border-[#EDEDEC]/5">
                        <div class="w-11 h-11 rounded-xl bg-[#00AAFF]/10 flex items-center justify-center mb-4">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-6 h-6 text-[#00AAFF]" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                            </svg>
                        </div>
                        <h3 class="text-lg font-semibold mb-2">Google sign-in</h3>
                        <p class="text-sm text-[#4b4b4a] dark:text-[#A1A09A]">Sign in with your Google account to post updates and personalize your experience.</p>
                    </div>
                </div>
            </section>

            <!-- CTA -->
            <section class="max-w-6xl mx-auto px-6 pb-24">
                <div class="rounded-3xl bg-[#00AAFF] text-white p-10 sm:p-14 text-center shadow-xl shadow-[#00AAFF]/25">
                    <h2 class="text-3xl sm:text-4xl font-bold tracking-tight">Ready to stay ahead of the heat?</h2>
                    <p class="mt-4 max-w-xl mx-auto text-white/90">Download the latest release of Nowcast and start monitoring weather and heat-health in your area.</p>
                    <a
                        href="https://github.com/ionvop/nowcast/releases"
                        target="_blank"
                        rel="noopener noreferrer"
                        class="mt-8 inline-flex items-center gap-2 px-8 py-4 rounded-2xl text-base font-semibold bg-white text-[#00AAFF] hover:bg-[#f0f0f0] transition-colors shadow-lg"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Go to releases
                    </a>
                </div>
            </section>
        </main>

        <!-- Footer -->
        <footer class="w-full border-t border-[#1b1b18]/10 dark:border-[#EDEDEC]/10">
            <div class="max-w-6xl mx-auto px-6 py-8 flex flex-col sm:flex-row items-center justify-between gap-4 text-sm text-[#4b4b4a] dark:text-[#A1A09A]">
                <span>© {{ date('Y') }} Nowcast. A weather and heat-health monitoring app.</span>
                <a
                    href="https://github.com/ionvop/nowcast"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-1.5 hover:text-[#00AAFF] transition-colors"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
                    </svg>
                    github.com/ionvop/nowcast
                </a>
            </div>
        </footer>
    </body>
</html>
