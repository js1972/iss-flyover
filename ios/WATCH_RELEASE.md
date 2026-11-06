# Apple Watch companion release

Native SwiftUI companion, watchOS 11 or later, bundled with the existing iOS 18+
app. Version 1.0 build 22. Design reference: `Artwork/Watch-approved-reference.png`
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
- Complication URL links open watch details. Event previews stay on the Watch;
  the redundant Continue on iPhone control was removed in build 22.
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

Reminder setup can publish a settings Handoff suggestion for the paired iPhone;
event previews no longer publish a Handoff activity or offer a Continue button.
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

Install verified working changes when requested. Commit and push only when the
user explicitly asks; installation does not imply permission to commit.

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
- Check reminder-setup Handoff on the paired iPhone.
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
  Build 14 was initially prepared for a subsequent physical test; the later
  authorized installation is recorded below.

### Build 14 device installation — 3 November 2026

- Installed development-signed Release 1.0 (14) from pushed source `6401c19`
  on the iPhone 16 Pro Max and paired Apple Watch, preserving bundle identities
  and existing app data.
- Both apps launched successfully. Device inventories independently confirm
  version 1.0, build 14 on both devices.
- The manual simulator follow-up also checked paging in both directions, opening
  the ISS path, scrolling through reminder/Handoff controls, and returning to the
  first page. No interaction failure was observed.
- A post-install Watch screenshot attempt timed out establishing its network
  tunnel; no physical-screen visual confirmation is claimed for this install.
- Physical-device installation and launch are verified. The user's prolonged
  on-wrist paging/scrolling test remains the check for the reported intermittent
  lockups; installation alone does not establish that those are eliminated.

### Secondary event cards — build 15, 3 November 2026

- Replaced the default watchOS capsule style on secondary Tonight events with
  content-sized navy rounded rectangles, white leading-aligned titles, generous
  internal padding, a quieter time/direction row and a subtle border.
- Titles wrap without a fixed row height or truncation. The metadata row omits its
  decorative chevron when larger text needs the width. The entire card opens the
  existing event detail route; the same component styles subsequent ISS passes.
- Added a More tonight section label. The approved main faces, paging, timers and
  forecast processing remain unchanged.
- Added debug fixtures for Small Magellanic Cloud, Large Magellanic Cloud and
  Orion Nebula. UI checks measure text bounds inside each card, verify the full
  title, open all three details, return and swipe between pages at standard and
  largest text sizes on 40 mm and 46 mm simulators.

- Both targeted UI tests pass at both simulator sizes. Final visual evidence is
  in `Artwork/Watch-build15`; signed Release build 15 and nested signatures verify.

### Build 15 device installation — 3 November 2026

Installed the signed Release from pushed source `59fef3c` on the iPhone 16 Pro Max
and paired Apple Watch. Both apps launched successfully and both device inventories
confirm version 1.0, build 15. Existing bundle identities and app data were preserved.

### Complication artwork update — build 16, 6 November 2026

Tonight and event complications reuse the bundled planet, ISS and full-Moon
artwork. Circular slots include the target name and local viewing time (or “Now”
for an active ISS pass); rectangular slots retain a compact numeric ISS countdown.
Corner slots use the artwork with their existing curved title/time label. Inline
slots retain text and a system symbol. The dedicated Moon complication keeps its
phase symbol and illumination rather than showing a full Moon at every phase.
Accented rendering requests luminance-based artwork so surface detail survives
tinting; expired circular forecasts explicitly say “Refresh”.

The watch app and extension build for watchOS Simulator. Temporary 40 mm simulator
galleries exercise the actual view layout with all five planet assets, ISS, full
Moon, Moon phase, missing data, no highlights and expired data. These are app-hosted
layout previews, not installed watch-face complications; system tinting, corner
labels, VoiceOver and real refresh/tap behaviour still require watch-face checks.
Installed and launched development-signed Release version 1.0 (16) on the iPhone
16 Pro Max and paired Apple Watch on 6 November 2026. Both device inventories
independently confirm build 16. All four bundle signatures, permanent identifiers,
team, App Groups and device provisioning eligibility were verified. The update
preserves existing installations and data. Source is uncommitted working changes,
as explicitly requested; no commit, push or distribution release was performed.
The on-watch appearance of the complications remains for the user's review.


### Artwork, home spacing and Moon lighting — build 20, 6 November 2026

- Physical feedback after build 16 revealed stale star layouts and then blank
  artwork. Downsampling into small CGImages and using a simpler image rendering
  path restored actual watch-face images in build 18; a physical screenshot and
  the user's confirmation establish that result. App-hosted previews alone had
  not exposed the failure. App launch/manual refresh now requests fresh timelines.
- The selected first mock, `Artwork/Watch-complications/selected-portrait-fill.png`,
  is the visual target for circular and Smart Stack complications. Real bundled
  artwork fills the background, with native subject/time/place labels over a baked
  contrast fade. Circular bitmaps are 100 × 100 and rectangular bitmaps 336 × 144;
  full source photos are not serialized into the complication's view archive.
- The home hero opens guidance when tapped. The redundant Find it button is gone,
  native page dots remain visible, and compact hero/footer spacing brings time and
  place above the dots on 40 mm. Build 19's spacing reached the phone but its Watch
  installation disconnected; build 20 includes the same spacing correction.
- Watch weather attribution is a small noninteractive mark; the unsupported Watch
  link is removed. The iPhone retains its existing attribution link.
- Moon symbols explicitly use opaque dark gray for the shadow layer and white for
  the illuminated layer. A translucent shadow exposed the white layer underneath
  during visual QA and was replaced with opaque gray. Southern observing places
  rotate the schematic by 180 degrees. All eight phases were inspected, including
  dark new Moon, bright full Moon and opposite quarter phases.
- The affected Tonight/guidance/paging and Moon/places/largest-text UI tests pass
  on the dedicated 40 mm simulator. The final Moon component was additionally
  tested on the real Moon page after the palette correction. Current screenshots
  and the normalized selected-design comparison are in `Artwork/Watch-complications`.
  These galleries validate layout, not the watchOS widget host or system tinting.
- Release build 20 succeeds. Phone, phone widget, Watch and Watch widget signatures,
  unchanged team/IDs/App Groups and paired-device provisioning are verified.
  Both installations and launches succeeded; independent phone and Watch
  inventories confirm build 20. The physical Watch home screenshot confirms
  the corrected spacing. A later physical watch-face screenshot confirms the
  enlarged, desaturated Saturn artwork renders in the system circular complication;
  the user requested the smaller crop and larger label recorded below. The Smart
  Stack appearance still awaits physical confirmation.
- No website changes, commits, pushes or distribution uploads.


### Circular label and crop refinement — build 21, 6 November 2026

Following the physical build-20 screenshot, reduced Saturn's circular image scale
from 3.0 to 2.65 (about 12%) and increased event labels from 9 to 12 points. Circular
event complications show only their subject name; tapping retains the existing
event-details URL. The dedicated Moon phase complication keeps its illumination
percentage. Smart Stack, corner and inline layouts retain their prior content.

The isolated native simulator gallery confirms the revised circle and retained
Smart Stack layout. Release build 21 passes, with all four signatures, permanent
identities, App Groups and paired-device provisioning verified. No additional
navigation tests were needed for the image scale/label-only change; the existing
link is unchanged. Installed on both paired devices; independent phone and Watch
inventories confirm version 1.0, build 21. Launching the Watch app refreshed its
timelines. `Artwork/Watch-complications/watch-face-device-build21.png` confirms
the smaller Saturn image, larger label and removed time in the physical circular
complication. Smart Stack hardware appearance remains unverified; its layout was
unchanged by this refinement. No commits or pushes were made.


### Ring visibility and preview simplification — build 22, 6 November 2026

The physical build-21 crop still hid most of Saturn's rings. Its circular image now
fits the ring outline across the slot (source-photo scale 1.45) and sits slightly
lower within the circular boundary. The larger name-only label remains. Other
subjects and Smart Stack layout are unchanged. The simulator render in
`Artwork/Watch-complications/portrait-fill-build22-simulator.png` shows the rings.

Removed Continue on iPhone, its explanatory message and event Handoff state/activity
from WatchEventView. Reminder setup's separate phone settings flow remains. The
existing navigation/scrolling stress test uses the reminder control as its footer
anchor instead of the removed button. Signed Release build 22 and all four bundles'
identities, signatures, App Groups and paired-device eligibility are verified.
The affected UI test passes all eight cycles of paging, preview scrolling, return
navigation and foreground resume while forecast updates arrive (117.7 seconds).
The footer capture confirms Remind me remains without Continue on iPhone. Both
paired devices now independently report build 22. The Watch installation succeeded
after reconnecting, and the app launched to refresh its complications. The user
confirmed the on-watch appearance looks great and approved the completed work,
then explicitly requested one combined commit and push of all changes.
