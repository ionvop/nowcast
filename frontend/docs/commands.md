# Commands

## Build

```bash
flutter build web --release --base-href "/app/" --dart-define-from-file=dart_defines.json
```

## Run

1. Copy files from `build/web/` to Laravel's `public/app/` directory.
2. Run `php artisan serve`