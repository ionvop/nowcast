# Commands

## Environment values

### API_BASE_URL

**Local**

```
http://localhost:8000/api
```

**Staging**

```
https://stage.ionvop.com/nowcast/public/api
```

**Production**

```
https://nowcast.ionvop.com/api
```

### GOOGLE_MAPS_CLIENT_KEY

```
Paste your Google Maps API key here
```

## Command templates

### Test on browser with backend running locally

```bash
flutter run -d web-server --web-port 8080 --web-define=GOOGLE_MAPS_CLIENT_KEY=___ --dart-define=GOOGLE_MAPS_CLIENT_KEY=___ --dart-define=API_BASE_URL=___
```

### Run on device

```bash
flutter run --dart-define=GOOGLE_MAPS_CLIENT_KEY=___ --dart-define=API_BASE_URL=___
```

### Build

```bash
flutter build apk --release --target-platform android-arm64 --dart-define=GOOGLE_MAPS_CLIENT_KEY=___ --dart-define=API_BASE_URL=___
```