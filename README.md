# Sky Tonight

A local sky guide for planning an evening around planets, ISS flyovers, weather, and moonlight. This repository contains a static website/PWA and an independent native iOS app with widgets.

## Native iOS app

The SwiftUI app requires iOS 18 or later. It includes:

- **Tonight:** evening-first recommendations, Moon and weather conditions, and observing reminders.
- **Sky:** a native sky chart, compass alignment, time exploration, and previews of selected events.
- **Upcoming:** seven observing nights of planets, stars, deep-sky targets, meteor showers, and visible ISS passes.
- **Settings:** saved observing places, optional device location, city search, and manual coordinates with a time zone.
- **Widgets:** Sky Tonight and Next ISS Pass on the Home Screen and Lock Screen, with saved-place selection and links into the app.

Open [`ios/SkyTonight.xcodeproj`](ios/SkyTonight.xcodeproj), select the **SkyTonight** scheme and an iPhone simulator, then Run. A physical iPhone requires signing with the configured paid developer team.

See the [iOS guide](ios/README.md) for signing, device setup, adding widgets, architecture, and tests. Sky Tonight has its own bundle identifiers and storage. Its private App Group is used only by Sky Tonight and its own widgets; it does not share data with other apps.

The native app focuses on observing and widgets. Globe/ground-track views and additional alignment/eclipse highlights remain website features. Apple Watch and Live Activities are not included.

## Website / PWA

The website remains independently deployable as static files, with no build step or package manager. Features include:

- Real-time ISS position with smooth animation, globe and map views, and orbit tracks.
- Local sky projection with event-time previews from ISS and night-sky cards.
- Seven-day visible ISS forecast and ranked sky highlights.
- A tonight timeline with sky events, darkness, weather, Moon, and ISS moments.
- Persisted location and viewing preference, plus forecast refresh on app resume and date rollover.

### Run locally

From the repository root:

```sh
python3 -m http.server 8000 --bind 127.0.0.1
```

Open <http://127.0.0.1:8000/>. Use HTTP; opening `index.html` through `file://` does not support the app's ES modules correctly.

Cloudflare Pages can deploy the repository directly as static files. Changes under `ios/` do not add a website build step. When changing web assets, bump the app/asset version in `index.html`, `manifest.webmanifest`, `assets/js/version.js`, and `version.json`, including affected module import URLs, because phones cache the app aggressively.

## How visible ISS passes are selected

Passing above the horizon does not mean the ISS can be seen. Both apps require:

- Sunlight reaching the ISS, rather than the station being in Earth's shadow.
- A dark observer sky: the Sun below −6°.
- An illuminated visible window lasting at least 60 seconds and reaching at least 20° elevation.

Predictions describe the visible portion of a pass, ending when the station enters shadow or viewing conditions no longer qualify. Clouds and local obstructions can still prevent viewing.

Before the 14 October 2026 correction, the PWA checked darkness and elevation but omitted Earth shadow, so it could recommend invisible nighttime flyovers. The native app already checked illumination. See the [comparison and regression test](ios/README.md#iss-visibility-comparison-14-october-2026).

## Data and libraries

- **CelesTrak:** preferred ISS orbital elements for local SGP4 predictions.
- **Where the ISS at?:** live website ISS telemetry and backup orbital elements.
- **Open-Meteo:** weather forecasts.
- **OpenStreetMap Nominatim:** website reverse geocoding; **CARTO/OpenStreetMap:** website basemaps.
- **Astronomy Engine, SunCalc, satellite.js:** pinned local calculation libraries, also bundled for native JavaScriptCore.
- **Leaflet and Three.js:** website map/globe rendering; **SwiftUI and WidgetKit:** native interface and widgets.

Stable astronomy catalogs are local. Orbital and weather data refresh remotely. The native app calculates astronomy offline and shares cached forecasts only with its own widgets; see the [freshness rules](ios/README.md#architecture-and-freshness).

## Structure

| Path | Purpose |
| --- | --- |
| `index.html`, `manifest.webmanifest` | Website shell and PWA metadata |
| `assets/css/app.css` | Website styles |
| `assets/js/main.js` | Website orchestration and rendering |
| `assets/js/pass-visibility.js` | Sunlit ISS window filtering |
| `assets/js/config.js`, `state.js`, `dom.js`, `utils.js` | Website configuration, state, DOM references, and helpers |
| `assets/js/data/`, `assets/vendor/` | Astronomy catalogs and pinned libraries |
| `ios/SkyTonight/` | SwiftUI app |
| `ios/SkyWidgets/` | WidgetKit extension |
| `ios/SkyCore/` | Native shared models, calculations, cache, and data services |
| `ios/SkyTonightTests/`, `ios/SkyTonightUITests/` | Native unit and UI tests |
| `tests/` | Website ISS visibility regression tests and public orbital fixture |

## Verification

Run the focused ISS visibility tests from the repository root (Node.js is only needed to run these tests, not to serve or deploy the website):

```sh
node --experimental-default-type=module --test tests/pass-visibility.test.mjs
```

Follow the [native build/test instructions](ios/README.md#build-and-test) for iOS. After website changes, smoke-test location handling, live refresh, forecasts, data failure states, and card-to-sky previews over HTTP. Commit and push before physical-device testing.
