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

On 14 October 2026, after signing in through Xcode Settings → Apple Accounts, automatic provisioning created dedicated profiles for both targets. Version 1.0 was first installed as build 1 (`58a65b4`); build 2 (`51be65a`) was subsequently installed and launched successfully on the paired iPhone 16 Pro Max, with its installed version verified. Both signatures and profiles were verified against the permanent identifiers, the exclusive Sky Tonight App Group, and device eligibility; profiles expire 14 October 2027. No App Store upload was performed. Physical compass accuracy and Home/Lock Screen widget behaviour remain for hands-on testing.

## Run on an iPhone and add widgets

1. Open `ios/SkyTonight.xcodeproj` from the repository root and select the **SkyTonight** scheme.
2. Sign in to the paid account in **Xcode Settings → Apple Accounts** if new profiles are needed. Existing valid profiles can support later builds without a new sign-in.
3. Select the permanent team above for both app and widget targets, with automatic signing. Let Xcode create profiles that include Sky Tonight’s own App Group.
4. Connect or select the paired iPhone, enable Developer Mode if required, and unlock it. Commit and push verified changes before choosing **Run** for physical-device testing. Update the existing installation; do not uninstall it or change identifiers to resolve signing problems.
5. Open Sky Tonight and check the observing place in **Settings**. The initial place is Perth until changed; device location is optional. Let a forecast load before adding widgets.
6. To add a Home Screen widget, long-press the Home Screen, choose **Edit → Add Widget**, and search for **Sky Tonight**. Choose **Sky Tonight** or **Next ISS Pass** and a size. Edit the widget to select a saved observing place.
7. For the Lock Screen, open its customization screen, select the widget area, and choose a Sky Tonight widget. Tap an event widget to open its event-time sky preview in the app.

Widgets refresh on iOS’s schedule rather than every few seconds. A successful app installation includes the widget extension, but widgets must be added to the Home/Lock Screen separately. Check compass alignment, reminders, widget refresh, and widget links on the actual phone; simulator tests do not establish those hardware behaviours.

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

When editing `SkyCore/engine.js` or updating its pinned libraries, regenerate `Resources/SkyEngine.js`. Regenerate the Xcode project when adding/removing Swift files or changing settings in the project generator. These commands run from the repository root:

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

Verification for build 2: 12 native unit tests, 2 native UI tests, and 5 JavaScript
visibility regression tests passed. Local browser checks covered Perth’s empty
ISS forecast, sunlit passes at a second location, live refresh, and ISS/sky-card
previews. The signed iPhone build was installed as an update with the permanent
app and widget identities unchanged.

## Widget appearance (build 3, 15 October 2026)

Home Screen widgets retain their navy background in light and dark appearance.
Their full-colour content uses a dark colour scheme on that background so primary
and secondary text stay light and readable during the day. Lock Screen, tinted,
and background-free presentations continue to use the system’s colour scheme.

The debug widget preview now starts in light appearance and includes a Light/Dark
selector. A rendering regression compares small and medium cards in both
appearances for populated forecasts, no-visible-ISS, and unavailable-data states;
UI tests capture both appearances. The app and widget identifiers remain unchanged.


## Planet widget artwork (build 4, 15 October 2026)

Small and medium full-colour Sky Tonight widgets show bundled NASA imagery when
the leading forecast event is Mercury, Venus, Mars, Jupiter, or Saturn. The planet
name, time and direction remain readable on navy in both phone appearances.
Medium cards retain links to the next two events beneath the featured planet.
ISS, other event types, expired forecasts, Lock Screen widgets, tinted widgets,
and background-free presentations retain their text-based layouts.

`Resources/PlanetAssets.xcassets` is compiled into this app and its widget extension
only. The five images total about 100 KB on disk, with no runtime image requests.
Source URLs, credits, and the Jupiter CC BY attribution are in
`Resources/Acknowledgements.txt`, also available in the app's acknowledgements.
The images are illustrative spacecraft views, not current phase/orientation or
naked-eye appearance. No identifiers, entitlements, or shared containers changed.

The debug `--widget-preview` screen has an artwork sample picker and a Light/Dark
selector. Sample selection substitutes the picture/name while retaining forecast
times, and does not alter saved forecasts. Rendering tests check all five planets
in both sizes and appearances, verify assets in both bundles, and cover unsupported
subjects. Build 4 was reviewed in the simulator before the build 5 refinement below.


## Larger widget artwork (build 5, 15 October 2026)

Planet images now extend behind the main labels and towards the card edge rather
than occupying a small slot beside the title. Horizontal and vertical fading keeps
the text and footer readable. Next ISS cards have a bundled transparent NASA ISS
illustration, including unavailable/expired/no-visible-pass states; artwork never
changes the data status or implies there is a visible pass. Lock Screen and tinted
layouts continue to follow the system presentation.

The simulator preview launched with `--uitesting --widget-preview` uses an offline
forecast and intentionally skips live orbit/weather downloads. Its ISS data
unavailable state is expected. Remove `--uitesting` to exercise live data. The
preview and screenshots do not establish real-device refresh cadence. After simulator review, version 1.0 build 5 was installed and launched successfully
on the paired iPhone 16 Pro Max on 15 October 2026. The installed version was
verified. App and widget signatures, device profiles, and the exclusive Sky Tonight
App Group were checked before installation. The installed app code is `203ccb5`.


## Location label consistency (build 6, 15 October 2026)

Home Screen empty-state location labels now use the same 10-point secondary text
as populated small cards. This keeps the ISS location consistent with the planet
widget when no pass or no orbit data is available.
