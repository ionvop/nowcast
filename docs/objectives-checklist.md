# Objectives & Scope — Implementation Checklist

This document audits the project against the objectives and scope described in
[`objectives-and-scopes.md`](./objectives-and-scopes.md). Each item is marked
as **Implemented**, **Partially implemented**, or **Missing**, with evidence
drawn from the actual codebase (Flutter client in `frontend/`, Laravel API in
`backend/`).

Legend:
- ✅ **Implemented** — the feature exists and works end-to-end.
- 🟡 **Partially implemented** — some aspect exists, but the full objective is not met.
- ❌ **Missing** — no implementation was found.

---

## General Objective

> To create a Smart Weather App, a user-friendly, data-driven and respond to
> climate-related risks such as urban heat islands.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Smart Weather App exists | A Flutter client (`frontend/`) with a five-tab UI (Home, Heat Data, Map, Community, Profile) backed by a Laravel JSON API (`backend/`). See `frontend/lib/src/shell/app_shell.dart` and `backend/routes/api.php`. |
| ✅ | Data-driven | Weather, forecast, heat index, and geocoding data are fetched live from the Google Weather/Geocoding APIs via `backend/app/Services/GoogleWeatherService.php`. |
| ✅ | Responds to climate risks (heat islands) | Heat-index analysis, heat-danger detection, and heat alerts are implemented (see below). |

---

## Specific Objectives

### 1. Data Integration

> To collect and integrate publicly available GIS data, including satellite
> maps imagery, digital heat stress zones, and land-use data. To visualize
> this data through an interactive map that can pinpoint where heat is.

| Status | Item | Notes |
|--------|------|-------|
| 🟡 | Interactive map that pinpoints heat | Implemented via `frontend/lib/src/screens/map_screen.dart` using `google_maps_flutter`. Colored circular markers show crowd-sourced heat-index readings, and tapping a spot analyzes its heat index. |
| ❌ | Satellite map imagery | The map uses standard Google Maps tiles; no satellite imagery layer or toggle was found. |
| ❌ | Digital heat stress zones (GIS layer) | No GIS heat-stress zone layer is loaded. Heat is shown only as point markers derived from live API readings, not as pre-computed GIS zones. |
| ❌ | Land-use data | No land-use data integration was found. |
| ❌ | Open-source GIS layers | No open-source GIS layer ingestion (e.g. GeoJSON, WMS, raster) was found. Data comes from the Google Weather API rather than open GIS sources. |

### 2. Participatory GIS & Citizen Reporting

> To develop features that allow citizens to mark overheated areas and other
> climate risks in real-time.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Citizens can mark overheated areas | Tapping the map analyzes a spot and stores a crowd-sourced heat-index reading (`backend/app/Http/Controllers/HeatLocationController.php`, `WeatherLocationController.php`). Readings are deduplicated within ~100 m and expire after 1 hour. |
| ✅ | Real-time reporting | Readings are stored and re-fetched live; the map renders them as markers. |
| 🟡 | Community reporting of climate risks | A community feed (`frontend/lib/src/screens/community_screen.dart`) lets signed-in users post text updates, optionally tagged with a location (`Post` model). This is general text posting rather than a structured "mark a risk type" flow. |
| ❌ | Structured risk-type reporting | No structured categories (e.g. "overheated area", "flood", "other risk") for citizen reports were found. |

### 3. Security and Privacy

> To ensure secure and anonymized data collection, protecting user privacy
> while enabling detailed spatial analysis.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Secure authentication | Google OAuth via `backend/app/Http/Controllers/GoogleOAuthController.php` + `GoogleOAuthService.php`; protected routes use Laravel Sanctum (`auth:sanctum`). |
| ✅ | Anonymized weather data | Weather/heat readings are stored without a user link (`HeatLocation`, `WeatherLocation` models) and expire after 1 hour. |
| ✅ | Privacy policy | In-app privacy policy (`frontend/lib/src/screens/privacy_policy_screen.dart`) documents data collection, storage, and retention. |
| 🟡 | Detailed spatial analysis | Spatial analysis is limited to deduplication and proximity checks (haversine distance). No advanced spatial analytics or risk simulation exists. |

---

## Scope

### Scope (first paragraph)

> The project centers on developing and piloting an app-based geospatial
> framework with no additional hardware requirements.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | App-based geospatial framework | Flutter app + map + location services; no hardware requirements. |
| ✅ | No additional hardware | Uses device GPS and Google APIs only. |

> It covers data integration using open-source GIS layers, real-time citizen
> reporting, and cloud-based analytics for risk simulation.

| Status | Item | Notes |
|--------|------|-------|
| ❌ | Open-source GIS layers | Not found (see Data Integration). |
| ✅ | Real-time citizen reporting | Implemented (see Participatory GIS). |
| ❌ | Cloud-based analytics for risk simulation | No analytics or risk-simulation module was found. |

> The pilot deployment is focused on Tagum City, which will serve as a testbed
> for evaluating the app's technical performance and community impact.

| Status | Item | Notes |
|--------|------|-------|
| ❌ | Tagum City pilot configuration | No Tagum-specific configuration, geofencing, or pilot scoping was found in the code. |

> The framework will feature a digital twin viewer, participatory mapping
> tools, flood and heat island modeling, and an emergency alert system.

| Status | Item | Notes |
|--------|------|-------|
| ❌ | Digital twin viewer | No digital twin implementation was found. |
| ✅ | Participatory mapping tools | Map tap-to-analyze and crowd-sourced markers are implemented. |
| 🟡 | Flood and heat island modeling | Heat-island modeling is approximated by live heat-index readings and heat-danger detection (`frontend/lib/src/utils/heat_danger.dart`). Flood risk is approximated by a precipitation-based heuristic (`frontend/lib/src/utils/flood_danger.dart`). Neither is a true GIS model. |
| 🟡 | Emergency alert system | Heat alerts exist as a background notification service (`frontend/lib/src/services/heat_alert_service.dart`) and a startup heat/flood danger dialog with vibration. There is no general-purpose emergency alert system (e.g. government alerts, broadcast). |

> The security aspect includes implementing data privacy measures and
> compliance checks to ensure user trust.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Data privacy measures | Anonymized readings, OAuth, privacy policy. |
| ❌ | Compliance checks | No explicit compliance-checking module or audit tooling was found. |

### Scope (second paragraph — feature suite)

> The project centers on developing and piloting an app-based geospatial
> framework with no additional hardware requirements. It integrates a suite of
> features including a decision-making module, real-time temperature checks,
> interactive data graphs, and a vibration alert system that activates when a
> user enters a mapped red zone or heat hazard area.

| Status | Item | Notes |
|--------|------|-------|
| ❌ | Decision-making module | No dedicated decision-support module was found. |
| ✅ | Real-time temperature checks | Current conditions and heat-index analysis are fetched live. |
| ✅ | Interactive data graphs | `frontend/lib/src/screens/heat_screen.dart` renders hourly/daily multi-series line charts (temperature, feels-like, dew point, heat index, wind chill, wet bulb, UV) using `fl_chart`. |
| ✅ | Vibration alert on entering a red zone / heat hazard | `frontend/lib/src/screens/map_screen.dart` starts a vibration loop when a heat-danger dialog is shown (`_startDangerVibration`), gated by the vibration setting. |

> The app also includes health monitoring tools, air quality and UV index
> mapping, and a location bookmarking function that allows users to save
> cooler zones as favorites.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Health monitoring tools | Health reminders derived from weather (`frontend/lib/src/widgets/health_reminder_section.dart`): flood, rain, UV/SPF, heat, humidity. |
| 🟡 | Air quality mapping | No air-quality data or mapping was found. (Only UV index is surfaced; see below.) |
| 🟡 | UV index mapping | UV index is displayed in the heat charts and drives the SPF health reminder, but there is no dedicated UV-index map layer. |
| ❌ | Location bookmarking / save cooler zones as favorites | No bookmark/favorite feature was found anywhere in the codebase. |

> Additional functionalities include smart reminders for heat safety
> practices, predictive weather updates, and data analytics to visualize
> trends, assess risks, and support evidence-based planning.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Smart reminders for heat safety | Background heat-alert notifications (`heat_alert_service.dart`) and in-app health reminders. |
| ✅ | Predictive weather updates | Hourly and daily forecasts are fetched and displayed. |
| 🟡 | Data analytics to visualize trends | Charts visualize temperature/heat trends, but there is no risk assessment or evidence-based planning analytics. |

> The framework covers data integration using open-source GIS layers,
> participatory citizen reporting, and cloud-based analytics for real-time
> risk simulation.

| Status | Item | Notes |
|--------|------|-------|
| ❌ | Open-source GIS layers | Not found. |
| ✅ | Participatory citizen reporting | Implemented. |
| ❌ | Cloud-based analytics for real-time risk simulation | Not found. |

---

## Limitations

> The pilot will focus on Tagum.

| Status | Item | Notes |
|--------|------|-------|
| ❌ | Tagum-focused pilot | No Tagum-specific scoping/config was found in the code. |

> The project timeframe covers health and weather application.

| Status | Item | Notes |
|--------|------|-------|
| ✅ | Health and weather application | The app combines weather data with health-oriented features (heat alerts, health reminders). |

---

## Summary

| Category | Implemented | Partial | Missing |
|----------|-------------|---------|---------|
| General objective | 3 | 0 | 0 |
| Data integration | 0 | 1 | 4 |
| Participatory GIS & reporting | 2 | 1 | 1 |
| Security & privacy | 3 | 1 | 1 |
| Scope (framework) | 4 | 2 | 4 |
| Feature suite | 6 | 3 | 2 |
| Limitations | 1 | 0 | 1 |

### Key gaps to address

1. **Open-source GIS layers** — no satellite imagery, heat-stress zones, or
   land-use data are integrated; the map relies on live Google API point data.
2. **Digital twin viewer** — not implemented.
3. **Cloud-based analytics / risk simulation** — not implemented.
4. **Emergency alert system** — only heat/flood notifications exist; no
   general emergency alerting.
5. **Location bookmarking (save cooler zones as favorites)** — not implemented.
6. **Air quality mapping** — not implemented.
7. **Tagum City pilot scoping** — no Tagum-specific configuration found.
8. **Decision-making module** — not implemented.
