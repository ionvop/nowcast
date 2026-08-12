# Commands

## Instructions

1. Copy this file and rename to `commands.md`.
2. Replace `YOUR_API_KEY` with your Google Maps API key.
3. Use the commands below to build and run the app.

## Build

```bash
flutter build web --release --base-href "/app/" --dart-define=GOOGLE_MAPS_CLIENT_KEY=YOUR_API_KEY --web-define=GOOGLE_MAPS_CLIENT_KEY=YOUR_API_KEY
```

## Run

1. Copy files from `build/web/` to Laravel's `public/app/` directory.
2. Run `php artisan serve`