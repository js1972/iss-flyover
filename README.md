# ISS Flyover Explorer

A dark-themed static web app for tracking the International Space Station, previewing visible passes, and exploring the orbit on a globe.

## Features
- Real-time ISS position with smooth animation
- Globe view with draggable orbit track
- User view sky projection with preview mode for upcoming passes
- 7-day visibility forecast (night + high elevation)
- Location persistence between reloads
- Automatic forecast refresh on app resume and date rollover

## Run
This app is served as plain static files.

Option A (recommended):
- Run a local server from this folder:
  - `python3 -m http.server`
- Open the URL shown in your terminal.

Option B:
- Open `index.html` directly in your browser.
- Note: ES module loading requires `http://`; use a local server instead of `file://`.

## Notes
- Forecasts and orbit paths are computed from live TLE data in the browser.
- Cloudflare Pages can deploy this repo directly as static files; no build step is required.

## APIs & Libraries
- Where the ISS at? (ISS position + TLE): `https://api.wheretheiss.at`
- OpenStreetMap Nominatim (best-effort reverse geocoding): `https://nominatim.openstreetmap.org`
- Carto basemap tiles: `https://basemaps.cartocdn.com`
- Leaflet (map), SunCalc (sun position), satellite.js (orbit propagation), Three.js (globe rendering)

## Structure
- `index.html` — static HTML shell and third-party script includes
- `assets/css/app.css` — app styles
- `assets/js/main.js` — app bootstrap, rendering, actions, and orchestration
- `assets/js/config.js` — visual settings, API URLs, and forecast constants
- `assets/js/state.js` — shared runtime state
- `assets/js/dom.js` — DOM element references used by the app
- `assets/js/utils.js` — formatting and layout helpers
- `assets/icons/` — PWA and favicon assets
- `manifest.webmanifest` — PWA metadata

## Data Model
- Local/static data is the preferred pattern for stable astronomy catalogs.
- Live remote data is used where freshness matters, such as ISS telemetry, map tiles, and fallback geolocation providers.
