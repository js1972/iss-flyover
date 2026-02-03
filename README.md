# ISS Flyover Explorer

A single-file, dark-themed web app for tracking the International Space Station, previewing visible passes, and exploring the orbit on a globe.

## Features
- Real-time ISS position with smooth animation
- Globe view with draggable orbit track
- User view sky projection with preview mode for upcoming passes
- 7-day visibility forecast (night + high elevation)
- Browser notifications for the next visible pass
- Location persistence between reloads

## Run
This is a single HTML file.

Option A (quick):
- Open `index.html` directly in your browser.

Option B (recommended for best compatibility):
- Run a local server from this folder:
  - `python3 -m http.server`
- Open the URL shown in your terminal.

## Notes
- Forecasts and orbit paths are computed from live TLE data in the browser.
- Notifications require permission and the tab to stay open.

## APIs & Libraries
- Where the ISS at? (ISS position + TLE): `https://api.wheretheiss.at`
- Carto basemap tiles: `https://basemaps.cartocdn.com`
- Leaflet (map), SunCalc (sun position), satellite.js (orbit propagation), Three.js (globe rendering)

## Files
- `index.html` — the entire app
