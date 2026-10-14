# Sky Tonight for iOS

A native SwiftUI sky guide with Home Screen and Lock Screen widgets, alongside the existing static website. Requires iOS 18 or later. Open `SkyTonight.xcodeproj` and select the **SkyTonight** scheme.

## Included

- Tonight recommendations with an evening-first preference, seven observing nights, planets, bright stars, deep-sky targets and active meteor showers.
- Native sky chart, compass alignment, time exploration, and event-time previews.
- Visible ISS segments calculated with SGP4, observer darkness and Earth-shadow filtering. Passes must peak at least 20° and remain illuminated/above the horizon for at least a minute.
- Saved observing places, optional device location, city lookup and manual coordinates with an explicit time zone.
- Local reminders ten minutes before selected events; refreshed forecasts reconcile pending reminders. Stale orbital data cancels ISS reminders rather than claiming confidence.
- Sky Tonight and Next ISS Pass widgets, configurable per saved place. Home Screen small/medium; Lock Screen inline/circular/rectangular for Tonight, rectangular for ISS.
- App Group forecast caching, independent widget refresh, expiry states and cold-launch event deep links.

The first native release focuses on observing and widgets. The website still has the globe/ground-track views and additional alignment/eclipse highlights. Live Activities and Apple Watch targets are not included in this release.

## Permanent signing identity

Keep these identifiers stable, including when troubleshooting signing. Changing them installs a different app and breaks shared data.

| Target | Identifier |
| --- | --- |
| App | `com.js1972.skytonight` |
| Widget extension | `com.js1972.skytonight.widgets` |
| Shared App Group | `group.com.js1972.skytonight` |
| Paid development team | `NF8828LV3U` |

The paid developer account is `js.dev.one@proton.me`. Sky Tonight is an independent app: never reuse another app’s bundle identifiers, App Groups, keychain groups, or data containers. Its App Group is exclusively for Sky Tonight and its own widget extension. Only the Apple developer signing team is common to other apps in the account. Select that paid team for **both** targets in Signing & Capabilities and enable automatic signing. The new App Group must be registered and included in both provisioning profiles. Do not switch to a Personal Team or remove App Groups to work around a signing failure.

On 14 October 2026, after signing in through Xcode Settings → Apple Accounts, automatic provisioning created dedicated profiles for both targets. Version 1.0 (build 1), from commit `58a65b4`, was installed and launched successfully on the paired iPhone 16 Pro Max. Both signatures and profiles were verified against the permanent identifiers, the exclusive Sky Tonight App Group, and device eligibility; profiles expire 14 October 2027. No App Store upload was performed. Physical compass accuracy and Home/Lock Screen widget behaviour remain for hands-on testing.

## Build and test

The Xcode project and bundled calculation engine are checked in; opening/building the project requires no generator or package manager.

```sh
xcodebuild -project ios/SkyTonight.xcodeproj -scheme SkyTonight \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

xcodebuild -project ios/SkyTonight.xcodeproj -scheme SkyTonight \
  -destination 'platform=iOS Simulator,name=Sky Tonight iPhone' \
  CODE_SIGN_IDENTITY=- -parallel-testing-enabled NO test
```

Choose an available simulator name if the dedicated simulator does not exist on your Mac. Commit and push before real-device testing, following the repository workflow.

Only when adding source files or updating the pinned calculation libraries:

```sh
python3 ios/scripts/bundle_engine.py
python3 ios/scripts/generate_project.py
```

These scripts use Python's standard library. They do not alter the website or introduce a web build step.

## Architecture and freshness

`SkyCore` is compiled into the app and extension. It contains typed Swift data models, the cache, network services, widget selection and timeline policy. `SkyCalculator` isolates a bundled JavaScriptCore context behind an actor. The interface and widgets are native SwiftUI; no web view or remote executable code is involved.

The engine reuses the repository's pinned Astronomy Engine, SunCalc and satellite.js libraries. `SkyCore/engine.js` is a pure calculation boundary with UTC timestamps and explicit observing-night boundaries supplied by Swift's location-specific calendar. This avoids a premature SGP4 rewrite and allows numerical comparison against established reference vectors. Upstream notices are included in Acknowledgements.

- Astronomy works offline. Forecast snapshots cover seven observing nights.
- CelesTrak is the preferred orbital source; Where the ISS at is backup. Cache refresh is attempted after six hours. Orbit epoch age is separate from download age. Elements beyond seven days are unusable, and predictions do not extend beyond that epoch horizon.
- Weather is loaded after the first usable app render. Open-Meteo uses Unix timestamps; no implicit device-time-zone parsing. Samples more than an hour from the requested time or forecasts more than six hours old display as unavailable.
- Widget timelines contain future entries and a forecast-expiry state. Refresh requests and background work are opportunistic, not precise timers.
- The initial default place is explicitly Perth, not an inferred user location. Manual locations remain fully usable if device location is denied.

Weather comes from Open-Meteo's non-commercial API. Choose an appropriate commercial plan or WeatherKit before a commercial release. Attribution remains in Settings. No account, analytics, application backend or paid service is required for this development build.

## Verification focus

Automated tests cover reference SGP4 positions and Earth shadow, offline chart/forecast agreement, DST and pre-dawn observing-night boundaries, polar daylight, expired orbital/weather data, timeline expiry and native event-preview navigation. A simulator cannot verify physical heading accuracy or the real device's widget refresh cadence; check those on an iPhone after signing.

## ISS visibility comparison (14 October 2026)

The PWA previously counted high nighttime geometric flyovers as visible without
checking whether sunlight reached the station. With the CelesTrak orbit dated
13 October 2026 19:43 UTC, Perth’s 15 October 01:13 AWST flyover peaks near 73°
but is eclipsed throughout; it must not be recommended for visual observing.
The native calculation already excluded it. The PWA now checks illumination at
each sample and clips visible windows at shadow/twilight boundaries, using the
same 20° peak / 60-second minimum as iOS. Build 2 explains these criteria in
Upcoming → ISS passes; native orbital calculations are unchanged.

Run `node --experimental-default-type=module --test tests/pass-visibility.test.mjs`
from the repository root for the fixed-orbit regression and visibility boundary
checks. The real orbit fixture is public CelesTrak data, not device location data.
