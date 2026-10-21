# Sky Tonight

A local sky guide for planning an evening around planets, ISS flyovers, weather, and moonlight. This repository contains a static website/PWA and an independent native iOS app with widgets.

## Native iOS app

The SwiftUI app supports iPhone and iPad running iOS/iPadOS 18 or later. It includes:

- **Tonight:** evening-first recommendations, Moon and weather conditions, and observing reminders.
- **Sky:** a native sky chart, compass alignment, time exploration, and previews of selected events.
- **Upcoming:** seven observing nights of planets, stars, deep-sky targets, meteor showers, and visible ISS passes.
- **Settings:** saved observing places, optional device location, city search, and manual coordinates with a time zone.
- **Widgets:** Sky Tonight and Next ISS Pass on the Home Screen and Lock Screen, with saved-place selection and links into the app.

Open [`ios/SkyTonight.xcodeproj`](ios/SkyTonight.xcodeproj), select the **SkyTonight** scheme and an iPhone simulator, then Run. A physical iPhone requires signing with the configured paid developer team.

See the [iOS guide](ios/README.md) for signing, device setup, adding widgets, architecture, and tests. Sky Tonight has its own bundle identifiers and storage. Its private App Group is used only by Sky Tonight and its own widgets; it does not share data with other apps.

The native app focuses on observing and widgets. The 3D globe/ground-track view and additional alignment/eclipse highlights remain website features. Apple Watch and Live Activities are not included.

## TestFlight and release management

### Account and useful links

Use Jason Scott's individual Apple Developer membership with **`js.dev.one@proton.me`**, team **`NF8828LV3U`**, in both Xcode and App Store Connect. The old Programic account is unrelated. Check the signed-in email before managing agreements or uploads; a generic Apple link can open a different account's browser session.

| Item | Value |
| --- | --- |
| App Store Connect app | Sky Tonight, Apple app ID `6825144581` |
| App bundle ID | `com.js1972.skytonight` |
| Widget bundle ID | `com.js1972.skytonight.widgets` |
| Exclusive App Group | `group.com.js1972.skytonight` |
| Record SKU / language | `skytonight-ios` / English (Australia) |

- [TestFlight builds and review status](https://appstoreconnect.apple.com/teams/4112ab50-c19d-44d5-afef-87f86c676f8e/apps/6825144581/testflight)
- [Early testers group and assigned builds](https://appstoreconnect.apple.com/teams/4112ab50-c19d-44d5-afef-87f86c676f8e/apps/6825144581/testflight/groups/f4ff7cd2-72c4-46ef-b516-d88bd960be86/builds)
- [Public App Store version](https://appstoreconnect.apple.com/apps/6825144581/distribution/ios/version/inflight)
- [Privacy policy](https://iss-flyover.pages.dev/privacy.html) and [support](https://iss-flyover.pages.dev/support.html), hosted on the existing Cloudflare Pages site.

### Setup completed on 21 October 2026

This records the state at the first beta submission; App Store Connect is the source for the current status.

1. Verified the Proton account and signing team, accepted the updated Developer Program agreement manually, and created the Sky Tonight App Store Connect record.
2. Prepared the Earth-horizon icon, optional native Apple WeatherKit, privacy/support pages, and iPad layouts. WeatherKit is enabled for both permanent app IDs. iPad verification used simulators only; build 10 was also installed directly on Jason's iPhone.
3. Saved support/privacy URLs and review details. TestFlight has its own beta description, feedback email and review contact, including a separately entered phone number. **Sign-in required is off** because the app has no accounts.
4. Archived and uploaded **version 1.0, build 10** with team `NF8828LV3U`, including symbols and allowing external testing. Apple processed the upload successfully.
5. Created the empty **Internal checks** group, then the external **Early testers** group with one external tester. Public links and automatic internal distribution are off. Tester addresses and private review phone numbers stay in App Store Connect, outside this repository.
6. Assigned build 10 to Early testers, saved **What to Test** notes, enabled **Automatically notify testers**, and submitted it to Beta App Review. The confirmed status at submission was **Waiting for Review**. Apple will email the tester after approval; this recorded state does not establish email delivery or installation.

Jason can continue receiving direct development installs on his phone; TestFlight is optional for him. External testers install the free TestFlight app, accept Apple's email invitation on their device, and install Sky Tonight from there. Testing notes and feedback are available in TestFlight. See Apple's [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview).

### Check progress and manage feedback

During active testing, check **App Store Connect → Sky Tonight → TestFlight** and the Proton inbox for Apple review messages. On a narrow browser panel, open the page-heading menu to reveal the sidebar.

| Build status | What to do |
| --- | --- |
| Ready to Submit | Assign the build to Early testers and submit it for beta review. Uploading alone does not start external testing. |
| Waiting for Review / In Beta Review | Wait for Apple and respond if it requests information. |
| Ready to Test | Check group assignment and tester notification; use Notify Testers if notification was left manual. |
| Testing | Check tester acceptance, installs, sessions and feedback. |
| Missing Compliance | Complete the build's export-compliance questions for the actual code and dependencies. |
| Rejected | Read Apple's explanation, address it, and upload a corrected build as required. |
| Expired | Supply a newer build; the old one is no longer testable. |

These are build statuses, separate from the public App Store version's status. Apple documents [build statuses](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses) and [metrics](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-build-status-and-metrics/).

Check **Early testers → Testers** for invitation/acceptance and installation information. **No Builds Available** means checking that the group has an approved, unexpired build. If an approved build's invitation has not arrived, verify the email address, ask the tester to check junk mail, and resend the invitation from the tester controls when available. An invitation count alone does not prove installation.

Read **Feedback → Screenshots** and **Feedback → Crashes**, filtering by build where useful. Record each issue with its build number, device/iOS version, reproduction steps and expected behaviour; avoid copying private location or contact details into public issues. Prioritise crashes, incorrect event times/places, unreadable layouts and broken weather or widget flows. See Apple's [feedback guide](https://developer.apple.com/help/app-store-connect/test-a-beta-version/view-tester-feedback/).

### Add or remove a tester

1. Open **TestFlight → Early testers → Testers → Add Testers**.
2. Choose **Email** for a new tester, or **Existing** for someone already registered. Enter the intended email address and add the tester.
3. Check **Early testers → Builds** contains the intended approved build. Pending review still prevents installation.
4. Keep public-link invitations off while testing with a small named group. Use an external tester invitation for friends and family; they do not need App Store Connect staff access.

To end someone's access, use the group's tester removal controls and check whether they also belong to another group or have an individual build assignment. Manage addresses in Apple's console. See Apple's [external tester instructions](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/).

### Send the next build

1. Fix and verify the change using the [native build/test guide](ios/README.md#build-and-test) and [release checklist](ios/APP_STORE_RELEASE.md). Continue simulator-only iPad checks. Use dedicated Sky Tonight simulators when another project is using the simulator; avoid global resets or shutting down its devices.
2. Choose a build number higher than previous uploads. Update `CURRENT_PROJECT_VERSION` in `ios/scripts/generate_project.py`, then run `python3 ios/scripts/generate_project.py` from the repository root so app and widget settings stay in sync. Keep `MARKETING_VERSION` at `1.0` for further 1.0 beta builds. Review the generated diff, verify, commit and push before phone testing or distribution. Record the source commit corresponding to each uploaded build in the release checklist.
3. In Xcode, select **SkyTonight** and a generic iOS device destination, then **Product → Archive**. In Organizer, validate and distribute to **App Store Connect** for upload. Use team `NF8828LV3U`, upload symbols, and allow external testing; do not choose an internal-only distribution. See Apple's [upload guide](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).
4. Wait for processing in TestFlight. Open the new build, update **What to Test**, and resolve any compliance or review-information requirements. Keep the beta review contact current and login requirement off while the app has no accounts. Save contact changes before assigning a build; refresh the TestFlight page if the assignment form still shows old details.
5. Open **Early testers → Builds → Add Build to Group**, select the new build, enable **Automatically notify testers**, and submit for beta review if prompted. Later builds may still require review; do not assume immediate availability.
6. Check the resulting status and group assignment. Existing testers receive the new build through TestFlight when available; they do not need a new staff account or a new group for every build.

TestFlight builds last **up to 90 days from upload**. Plan a replacement before expiry if testing continues. If a build has a serious problem, use **Expire Build** to stop TestFlight testing and supply a corrected build. Keep the archive and symbols for diagnosing reports. See the [TestFlight lifecycle](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview).

### Public App Store release

Beta approval does not publish the app. The public version was left in **Prepare for Submission**, with **manual release** selected. After testing, complete its listing, iPhone/iPad screenshots, age rating, privacy and export answers, pricing/availability and applicable regional details; select the tested build and submit it to public App Review. Release it manually after approval when ready. The [release checklist](ios/APP_STORE_RELEASE.md) holds the detailed verification and remaining publishing work.

## Website / PWA

The website remains independently deployable as static files, with no build step or package manager. Features include:

- Real-time ISS position with smooth animation, a 3D globe view, and orbit tracks.
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
- **Apple WeatherKit:** optional native app/widget weather. **Open-Meteo:** separate website weather forecasts.
- **OpenStreetMap Nominatim:** website reverse geocoding only. The flat Map View and CARTO basemaps have been removed.
- **Astronomy Engine, SunCalc, satellite.js:** pinned local calculation libraries, also bundled for native JavaScriptCore.
- **Three.js:** website globe rendering; **SwiftUI and WidgetKit:** native interface and widgets.

Stable astronomy catalogs are local. Orbital and weather data refresh remotely. The native app calculates astronomy offline and shares cached forecasts only with its own widgets; see the [freshness rules](ios/README.md#architecture-and-freshness).

The PWA displays Open-Meteo source and CC BY 4.0 links beside Weather Tonight, the evening timeline, nightly weather outlooks and detailed observing conditions. The credit notes that forecast summaries and ratings are adapted for stargazing. Shared markup is in `assets/js/weather-attribution.js`; preserve it when adding weather displays. Attribution is separate from the free API's non-commercial and usage restrictions; review the [licence](https://open-meteo.com/en/licence) and [service terms](https://open-meteo.com/en/terms) before commercial use. Native Apple Weather attribution is separate.

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
