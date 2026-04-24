# AGENTS.md

Keep changes minimal and aligned with the existing static-site setup.

## Workflow
- Work on the `main` branch by default.
- Do not create or switch to another branch unless the user explicitly asks.
- Do not add a build step, package manager, or framework unless requested.
- Preserve static-file deployability.

## Run Locally
- Run a local web server from the repo root with `python3 -m http.server`.
- Test through `http://`, not `file://`.

## Verification
- After relevant changes, do a browser smoke test locally.
- Verify the affected flows, especially location handling, live ISS refresh, forecast rendering, and failure states for remote data.
- Real-device testing requires committing and pushing changes first.

## Operational Notes
- This app is aggressively cached on phones. When shipping static asset changes, bump the asset/app version in `index.html`, `manifest.webmanifest`, `assets/js/version.js`, and `version.json`.
- Prefer CelesTrak TLE data for fast startup and refresh. Treat it as a valid live source, not a degraded forecast condition. Keep `wheretheiss.at` TLE as backup only.
- Keep the boot path fast: orbit/forecast data should unblock the initial render, while weather can refresh in the background after the UI becomes usable.

## Project Structure
- `index.html`: static app shell and CDN script includes.
- `assets/css/app.css`: styles.
- `assets/js/main.js`: main app orchestration.
- `assets/js/config.js`: API URLs and app constants.
- `assets/js/state.js`: shared runtime state.
- `assets/js/dom.js`: DOM references.
- `assets/js/data/catalogs.js`: static astronomy catalog data.

## Code Shape
- Prefer extending existing modules over introducing new tooling.
- Keep `assets/js/main.js` from growing further when a change can be cleanly factored into a small module.
