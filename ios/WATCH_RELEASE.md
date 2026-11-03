# Apple Watch companion release

Native SwiftUI companion, watchOS 11 or later, bundled with the existing iOS 18+
app. Version 1.0 build 14. Design reference: `Artwork/Watch-approved-reference.png`
(the exact Tonight / Next ISS / Active pass mock supplied on 3 November). The watch UI has two horizontal pages; Crown
scrolling reveals secondary content. The full chart and place editing stay on iPhone.

## Included

- Tonight: one featured target, direction/elevation, more recommendations, saved-place
  selection, evening-first ranking, Moon phase/illumination, optional attributed weather.
- Find it: separate object guidance, explicitly labelled preview time or current
  sampled position. Compass is user-initiated, checks the user is within 20 km of
  the observing place, requires a usable true-north heading, and stops when inactive.
- Next ISS: countdown, visible-now state, pass list and altitude-over-time path.
  The marker interpolates cached SGP4 samples, never extrapolates outside the pass.
  A preview transitions into live tracking. A foreground haptic marks that transition;
  continuous background execution is not requested or promised.
- Tonight, Next ISS and Moon complications in circular/inline/rectangular/corner
  families; Next to Observe provides a dedicated Smart Stack rectangular widget.
- Durable reminder requests from watch, iPhone acknowledgements, set/cancel on phone,
  and OS notification mirroring. iPhone is the sole scheduling owner.
- Explicit Handoff to the iPhone event preview; URL links also open watch details.
- Cached forecasts, separate no-pass/missing-orbit/expired/setup states, accessibility
  labels, scalable text and reduced-motion support. Live clocks pause when dimmed or
  inactive and refresh immediately on return.

## Architecture and limits

`WatchShared/WatchTransfer.swift` is the versioned wire contract and portable
interpolation/expiry policy. `SkyTonight/WatchCompanion.swift` calculates sampled
paths on the iPhone using the existing pinned engine, sends compressed versioned snapshots using
WCSession, and reconciles queued reminder requests. No JavaScriptCore dependency
is compiled into watch targets. Compressed snapshots up to 48 KB use application context. Larger multi-place/weather
forecasts use file transfers plus a revision notice. Apple documents that Simulator
does not support file transfers; verify that fallback on paired physical devices.

Watch app and widgets share a cache **on the watch**. App Groups do not transfer
data between devices. Files are persisted atomically; older/duplicate revisions
are rejected. A changed or deleted observing place cannot reuse a different place's
forecast. Changing the phone's selected place updates watch selection on the next
sync; a watch-only place selection otherwise remains local.

First launch requires an iPhone sync. The watch has no independent orbit or weather
network client and no astronomy engine. Away from the phone, it uses the last synced
seven-night forecast; missing/expired data requires reconnecting. Optional weather
retains its shorter freshness limit and original Apple attribution. Disabling it
on phone takes effect on watch after delivery. Updates and widget refreshes are
opportunistic; Always On and background operation do not promise second-by-second
tracking or haptic timing. A stale orbital epoch invalidates ISS guidance independently
of the rest of the forecast. Forecasts remain specific to the named observing place.

`Continue on iPhone` publishes an NSUserActivity with event/location/time. Users
accept the system Handoff suggestion; it does not force an app to the foreground.
Reminders requested on watch remain pending until iPhone confirms. Notification
permission can be enabled in iPhone Settings → Apple Watch → Enable observing reminders. The app
does not schedule a second local notification on watch.

## Identity and build

Keep the existing iOS app, widget, team and App Group identities unchanged.

| Target | Bundle ID / group |
| --- | --- |
| SkyWatch | `com.js1972.skytonight.watchkitapp` |
| SkyWatchWidgets | `com.js1972.skytonight.watchkitapp.widgets` |
| Watch-only shared storage | `group.com.js1972.skytonight.watch` |
| Team | `NF8828LV3U` |

Register/provision the new watch IDs and watch App Group with the existing paid
team. The watch has no WeatherKit entitlement because it only displays synced
attributed data. Do not change the existing phone identifiers to fix provisioning.

```sh
python3 ios/scripts/bundle_engine.py
python3 ios/scripts/generate_project.py
xcodebuild -project ios/SkyTonight.xcodeproj -scheme SkyWatch \
  -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project ios/SkyTonight.xcodeproj -scheme SkyWatch \
  -destination 'platform=watchOS Simulator,name=Sky Tonight Watch 46mm' \
  CODE_SIGN_IDENTITY=- -parallel-testing-enabled NO test
```

Use the SkyTonight scheme for the phone and existing regression tests, including
`WatchTransferTests`. Dedicated simulators avoid disrupting another project's
devices. Debug-only `--watch-preview` provides clearly labelled sample data;
`--iss-page`, `--active-pass`, `--empty-watch`, `--expired-watch`, `--no-iss` and
`--no-orbit` exercise visual and failure states. These flags are excluded from Release.

## Physical-device and distribution gates

Commit and push simulator-verified source before installing on a real device.

- Verify initial and background transfer with the phone locked, asleep and disconnected;
  reconnect, change/delete places, disable weather and clear saved data.
- Verify watch reminder acknowledgement, cancellation, duplicate-transfer handling,
  phone/watch notification routing under Focus, and delivered-notification deep links.
- Check compass bearing outdoors against known directions, denied location permission,
  magnetic interference and a distant saved place.
- Add all complications, test their taps and natural refresh/expiry behaviour, and
  test Smart Stack at night transitions and while a pass begins/ends.
- Check 40 mm readability, largest text, VoiceOver, Reduce Motion and Always On.
- Measure sustained active-pass battery use and compare with a baseline; verify sensor
  activity stops after leaving guidance or lowering the wrist.
- Check Handoff from both preview and live event states on the paired iPhone.
- Validate signed Release archive and nested watch/widget provisioning, then prepare
  App Store watch screenshots, TestFlight notes and reviewer installation instructions.
  Upload/distribution and public release remain separate from simulator verification.

Record actual results below; do not count simulator checks as hardware validation.

## Verification record

Verified on 3 November 2026:

- Debug watch app and all four widget configurations compile; Release iPhone,
  embedded watch and watch widget build succeeds for physical architectures with
  signing disabled. This does not establish provisioning or distribution readiness.
- Five watch UI tests pass on both 40 mm and 46 mm simulators: Tonight → Find it →
  Back → Next ISS → View path; active pass; first launch/expired forecast; distinct
  no-pass/no-orbit states; Moon, saved places and largest requested text size.
- Eight watch-specific unit tests pass: wire compression/corruption, revision ordering,
  changed/deleted/expired places, sampled positions versus the astronomy engine,
  north-crossing interpolation/no extrapolation, exact timeline expiry, delayed/stale
  reminder validation and iPhone Handoff time/settings routing.
- Existing astronomy/lunar/unit tests and affected iPhone UI flows pass. The opt-in
  live WeatherKit test remains skipped in the ordinary suite; no live-weather claim.
- Paired simulators exchange real compact application-context forecasts: 113 events
  and 1,010 position samples received and displayed for default Perth. This is a
  foreground compact-transport check, not background file-transfer verification.
- Five website pass-visibility tests pass. Local HTTP browser smoke checks confirm
  forecast startup, event-card chart preview and the updated support/privacy pages.
- Source generators run successfully; whitespace/diff checks pass. Screenshots for
  both sizes and failure states are in `Artwork/Watch-validation/`.

Physical compass/haptics, actual notification routing, large-file transfers,
background sync, system complication/Smart Stack scheduling and taps, Handoff UI,
VoiceOver on hardware and battery measurements remain device gates. A direct
`simctl openurl` watch launch returned a simulator LaunchServices error; this does
not verify the system complication entry path. Signed archive validation and
App Store/TestFlight distribution have not been performed for build 12.

### Signed device installation — 3 November 2026

- Built version 1.0 (12), Debug configuration, from pushed source `4555baa`
  with automatic provisioning on the permanent paid team `NF8828LV3U`.
- Verified code signatures for the phone app, phone widget, embedded watch app
  and watch widget. All four profiles include the intended physical device and
  the correct platform-specific Sky Tonight App Group. The new watch profiles
  expire 3 November 2027; existing phone profiles expire 21 October 2027.
- Installed and launched on the iPhone 16 Pro Max (iOS 27.0.1) and paired Apple
  Watch (watchOS 27.2). Device inventories confirm version 1.0, build 12 on both.
- Captured the running screens and confirmed the first physical foreground sync:
  Tonight on watch displays the phone's Saturn recommendation at 22:03, north,
  57° elevation. Existing phone settings and forecast remained available.
- This is a development-signed device build. The remaining hardware behaviour
  checks above and signed distribution archive validation are still outstanding.


### Visual correction candidate — build 13, 3 November 2026

Build 13 corrects the mismatch between the approved third design and build 12:
larger artwork and main values, compact aligned headers, inset charcoal buttons,
clear page-indicator spacing, a prominent live-pass elevation/path, and full-word
ISS directions with an arrow. Large headings stack when needed. The initial face
stays crisp on modern watchOS; the system header fade returns while scrolling.

- Five watch UI tests pass on both 40 mm and 46 mm simulators after the final change.
  Tests also assert that both primary actions fit above the page indicators.
- Final visual evidence is in `Artwork/Watch-build13/`; the corrected comparison and
  explicit limitations are in `../design-qa.md`. This supersedes the previous visual
  acceptance, not the earlier functional test or physical installation records.
- Version 1.0 (13) builds successfully in Release configuration with development
  signing. All four code signatures, team `NF8828LV3U`, platform-specific App Groups
  and eligibility for the paired iPhone/Watch are verified.
- This candidate was initially prepared without device installation, as requested.
  The subsequent authorized installation is recorded below. App Store/TestFlight
  distribution remains a separate action.

### Build 13 device installation — 3 November 2026

- Installed development-signed Release version 1.0 (13) from pushed source
  `508800c` on the iPhone 16 Pro Max and paired Apple Watch, preserving their
  permanent bundle identifiers and existing data.
- Both apps launched successfully. Device inventories confirm build 13 on both.
  The Watch initially timed out connecting; installation succeeded after it was
  awakened and unlocked.
- A physical Watch screenshot confirms the revised Tonight layout with prominent
  Saturn artwork, large north direction, 57° elevation, and the complete Find it
  button clear of the page indicators. The existing forecast remains available.
- This installation check does not close the remaining compass, haptics, reminders,
  complication scheduling, background sync, VoiceOver or battery testing gates.

### Correct reference and interaction rebuild — build 14, 3 November 2026

Build 13 was rejected: its visual review used the wrong reference, and the user
reported difficult paging, glitchy scrolling and repeated freezes. The canonical
reference is now `Artwork/Watch-approved-reference.png`; see `../design-qa.md` for
comparison history, fresh screenshots and verification limits.

- Restored mint headers, large cropped Saturn, compact direction/elevation,
  midnight navy surfaces, white ISS countdown, small mint station silhouette,
  thin progress track and the arc-above-altitude active-pass composition.
- Removed whole-pager/ScrollView second-by-second updates and scroll-geometry
  feedback. Live timers are confined to leaf content; the native containers retain
  their state during interaction. Forecast decode/load/persistence runs on an actor,
  with serialized revisions and background-task completion after queued processing.
- Added a repeated paging/scrolling/details/resume test during dense forecast
  updates and atomic writes. Added full remaining-time visibility assertions.
- `--design-capture` freezes sample astronomy values for comparison only;
  `--stress-sync` drives the debug stress fixture. Neither exists in Release.
- Final simulator and signed-build results are recorded in `../design-qa.md`.
  Build 14 is prepared for a subsequent physical test; it is not installed here.
