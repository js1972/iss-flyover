# Sky Tonight release checks

Version 1.0, build 10. Keep app ID `com.js1972.skytonight`, widget ID `com.js1972.skytonight.widgets`, App Group `group.com.js1972.skytonight` and team `NF8828LV3U` unchanged.

## Account and signing verification

Use only Jason Scott’s individual Apple Developer membership, Apple Account `js.dev.one@proton.me`, team `NF8828LV3U`. Jason’s legacy Programic account is unrelated and must never be used for this app. A generic Apple account link may open a different signed-in browser session; verify both the email and team ID in the actual session before any agreement or distribution action.

On 21 October 2026, the exact Release build 10 installed on the phone was inspected again: app and widget signatures and embedded provisioning profiles all identify team `NF8828LV3U`, with their existing bundle IDs, dedicated App Group and WeatherKit entitlement. The App Store Connect account menu for record `6825144581` showed `js.dev.one@proton.me`. The Developer portal in that same in-app browser showed the same email and individual team, with renewal on 12 October 2027. No signing or bundle identifiers were changed during this check.

## WeatherKit and costs

Both targets require `com.apple.developer.weatherkit = true`. Enable WeatherKit under both **Capabilities** and **App Services** for both existing App IDs in Apple's developer portal. Xcode automatic signing must refresh both profiles. No REST signing key, backend, Open-Meteo subscription or user weather account is required by the native app. Do not place private signing keys in the app.

Apple Developer Program membership includes 500,000 WeatherKit calls/month across the membership, not per app. The implementation requests hourly data only, reuses cached conditions for 30 minutes and refreshes widgets on the system's schedule. Monitor account usage; this is not a promise of unlimited free capacity.

Weather is off by default, including after upgrading from Open-Meteo. Settings opt-in covers app/widget background requests for saved coordinates. Old native weather caches lack Apple credit and are hidden. The official Apple Weather marks for light and dark backgrounds and legal link are stored alongside each forecast. No weather is displayed without its credit. Offline astronomy still works if WeatherKit, attribution or the network is unavailable.

## Privacy and support

- Developer: Jason Scott
- Support: js.dev.one@proton.me
- Privacy: https://iss-flyover.pages.dev/privacy.html
- Support URL: https://iss-flyover.pages.dev/support.html

The public pages are static files deployed by the existing Cloudflare Pages repository connection. Confirm both production URLs render after the push; having files locally does not establish deployment success. The same policy/support content is bundled for offline native viewing. Edit `Resources/AppInformation.json`, then run `python3 ios/scripts/generate_legal_pages.py`. Run `generate_project.py` if adding resources or Swift sources.

The privacy manifest declares UserDefaults reasons CA92.1 (own app preferences) and 1C8F.1 (own App Group sharing), no tracking, and no developer-collected data. The app contains no advertising, analytics, account or application backend. Apple framework/service processing, support emails, incidental network-provider logs and device backups are explained in the policy. Local saved data is not uploaded to the developer. Settings provides weather opt-out, saved-place removal, and confirmed local reset.

Before answering App Store Connect privacy questions, review the final app and all providers against Apple's current definitions. Apple's guidance distinguishes on-device processing and data collected independently by Apple frameworks from collection by the developer. Do not treat this manifest as an automatic App Store privacy questionnaire answer. Check any newly added SDKs or support workflows. No App Tracking Transparency prompt is needed for the current non-tracking design. There are no user accounts to delete; local reset is available.

The separate interactive website retains Open-Meteo and other web providers. Their terms and data handling are independent of the native WeatherKit migration; review the website's commercial use before promoting a paid product through it.

## Verification

Use Xcode's available simulator names/IDs. Test iPad in portrait, landscape and upside-down portrait; a smaller iPad exercises the single-column layout. Verify event-card navigation, Return to Live, Upcoming ISS empty states, offline policy/support, widgets in light/dark appearances and the largest accessibility text. All iPad checks for this release are simulator-only. iPhone installation is a separate, explicitly requested check.

```sh
xcodebuild -project ios/SkyTonight.xcodeproj -scheme SkyTonight \
  -destination 'platform=iOS Simulator,name=Sky Tonight iPhone' \
  CODE_SIGN_IDENTITY=- -parallel-testing-enabled NO test
```

`testLiveAppleWeatherOptIn` is deliberately skipped in ordinary runs. Set `SKY_WEATHER_LIVE_CHECK=YES` in the UI test runner environment for an explicit integration run using the simulator's default public Perth place. It launches the normal app, turns weather on and requires an attributed live forecast. This requires functioning WeatherKit provisioning/service activation. Do not count offline UI fixture tests as live-weather verification.

Verify the Release build, embedded widget, dedicated profiles and WeatherKit entitlements. Export the compiled asset catalog metadata to confirm the 1024px icon is opaque. Check that regeneration preserves the icon and committed project. Save simulator captures as release evidence. Simulator tests cannot establish physical heading accuracy, actual widget scheduling or real notification delivery.

### Verified on 21 October 2026

- Enabled the separate WeatherKit App Service for both existing identifiers in Apple Developer; the capability was already enabled. The live simulator request then succeeded.
- Live hourly conditions, official image attribution, the legal link, and turning weather off passed an explicit iPhone simulator integration run using the public default Perth place.
- iPad Pro 13-inch on iPadOS 26.5: 18 ordinary unit checks and four UI flows passed. The two opt-in live checks were skipped in this ordinary run and exercised separately above. Portrait, landscape and upside-down portrait, event previews, Upcoming, offline privacy, largest accessibility text and light/dark widget previews passed.
- iPad mini (A17 Pro) on iPadOS 27.0: the same four ordinary UI flows passed, including narrow portrait, wide landscape and largest text.
- Signed iOS Release build 1.0 (9) passed. Both embedded profiles contain WeatherKit and only the dedicated Sky Tonight App Group. The compiled 1024px App Store icon is opaque.
- Five website visibility checks passed. Local browser smoke checks covered the running website, event preview and static privacy/support pages. Project/page regeneration preserves the curated icon and has no output drift.

The initial verification above used simulators. Builds 9 and 10 were subsequently installed and launched on the paired iPhone 16 Pro Max at Jason’s explicit request; the phone reported the expected installed build numbers. iPad verification remains simulator-only. Build 10 was subsequently archived and uploaded to TestFlight on 21 October 2026. No public App Review submission has been made.

Build 10 moves the saved-place deletion control beside the Saved places list and labels it Edit places (Done while removing places). Other settings continue to apply immediately. The signed Release build and the existing standard/large-text preview-to-Settings simulator flows passed for build 10.

## App Store Connect record

Created on 21 October 2026 under Jason Scott:

- App: Sky Tonight (iOS, covering the app’s iPhone and iPad support)
- Apple app ID: `6825144581`
- Bundle ID: `com.js1972.skytonight` (existing app ID, not the widget ID)
- SKU: `skytonight-ios`
- Primary language: English (Australia)
- Privacy policy URL saved: https://iss-flyover.pages.dev/privacy.html
- Support URL saved: https://iss-flyover.pages.dev/support.html
- Version 1.0 is set to manual release; no public release is scheduled.
- [App Information](https://appstoreconnect.apple.com/apps/6825144581/distribution/info)
- [TestFlight](https://appstoreconnect.apple.com/teams/4112ab50-c19d-44d5-afef-87f86c676f8e/apps/6825144581/testflight)

The public version record is in Prepare for Submission. Jason manually accepted the updated Apple Developer Program License Agreement on 21 October 2026; acceptance was verified in the Proton/team NF8828LV3U session before the successful upload. Any future agreement must be reviewed in that verified session, never the legacy Programic account. Jason entered the private public-review contact phone number directly in App Store Connect and those details were saved successfully. Sign-in required is off because the app has no user accounts. Private phone numbers and tester email addresses are not stored in this repository.

## TestFlight setup on 21 October 2026

- Release 1.0 (10) was archived for generic iOS devices with automatic signing explicitly restricted to team `NF8828LV3U`. App and widget archive identifiers, App Group and WeatherKit entitlements were checked before export.
- App Store Connect export/upload completed successfully. The export used `method=app-store-connect`, `destination=upload`, `teamID=NF8828LV3U`, and `testFlightInternalTestingOnly=false`; version/build numbers were preserved.
- Apple finished processing the upload; build 10 was then submitted to Beta App Review and is **Waiting for Review**, expiring in 90 days. This is not approval for external testing.
- An empty **Internal checks** group was created as required before external testing. Automatic internal distribution is off; Jason has not been invited to TestFlight.
- The external **Early testers** group contains the one tester explicitly authorized by Jason and build **1.0 (10)**. Public-link invitations are off. The build is not yet available to install while beta review is pending.
- The beta description, feedback email and privacy URL were saved. Build-specific **What to Test** instructions cover choosing places, event previews/Return to Live, Apple Weather opt-in, saved-place editing, widgets, reminders and iPhone/iPad layout, with feedback through TestFlight.
- The separate beta-review contact and review notes are saved. Jason entered the private phone number directly in App Store Connect. **Sign-in required is off** because the app has no user accounts.
- **Automatically notify testers** was enabled when submitting build 10. Apple will notify the authorized external tester after approval; no invitation delivery or installation has been confirmed yet.
- Next: Apple reviews this first external build. After approval, the tester can follow Apple's invitation to install TestFlight and Sky Tonight, read the testing notes, and send feedback. Resolve any beta-review feedback in this same app record and Proton/team NF8828LV3U session.

The first external build requires Apple’s beta review. Adding a tester alone does not send an installable build. This setup does not submit or release the public App Store version.

## App Store Connect tasks

1. Confirm active membership and agreements. Complete applicable tax/banking information if charging.
2. Create/select the app record for the permanent app ID. Check name availability and branding before locking the listing; the current display name is Sky Tonight.
3. Provide required descriptions, category, age rating, content rights, support/privacy URLs, privacy responses, screenshots for iPhone and iPad, review contact and export-compliance answers. Answer regional distribution/trader questions for selected storefronts.
4. Archive the Release scheme, validate in Organizer and upload. A signed development build is not App Store validation or an uploaded distribution archive.
5. Test the distribution build through TestFlight. Explain optional location/weather, widgets, local reminders and offline calculations in review notes.
6. Select the tested build, add it for review and submit. Submission and public release are separate actions and have not been performed by this implementation task.

References: [WeatherKit](https://developer.apple.com/weatherkit/), [service activation](https://developer.apple.com/help/account/services/weatherkit/), [privacy answers](https://developer.apple.com/app-store/app-privacy-details/), [submission](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/).
