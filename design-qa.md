# Saturn ring visibility and preview cleanup — build 22

Review date: 6 November 2026.

final result: passed for the revised simulator artwork, affected interactions and user-confirmed on-watch appearance.

The user's physical build-21 feedback supersedes the earlier background crop:
Saturn's rings must be recognizable. The circular source-photo scale is now 1.45
and its vertical center is 0.65; the label remains 12-point semibold without time.
`ios/Artwork/Watch-complications/rings-build22-comparison.png` compares the physical
build-21 circle (422 × 514 source, crop 58,388–150,480) with the native build-22
simulator circle (324 × 394 source, crop 112,84–212,184). Both crops are normalized
to 240 × 240. The physical face is desaturated; the simulator is full color, so this
comparison judges silhouette/crop/spacing, not color fidelity. The raw new capture
is `portrait-fill-build22-simulator.png` in the same folder.

Resolved P2: the previous crop hid the outer ring turns. The revised capture shows
both ring ends and a clear dark gap between the globe and rings. Typography and
name-only copy are unchanged and legible; spacing now leaves the ring outline
inside the boundary above the name. Existing photography, contrast fade and native
text remain. Smart Stack retains its previous scale and layout. No new visual
P0/P1/P2 findings remain in this comparison.

At the user's request, the event preview's Continue on iPhone button, message and
Handoff activity were removed. The existing scrolling/sync UI test passes all
eight cycles in 117.7 seconds, including foreground resume and continued forecast
processing. `preview-footer-build22-simulator.png` confirms the footer retains
Remind me without Continue on iPhone. Signed Release build 22 verifies, and both
paired device inventories confirm it is installed. The user confirmed the result
on the Watch and approved the completed work. They subsequently requested one
combined commit and push of all changes.

---

# Circular complication refinement — build 21

Review date: 6 November 2026.

final result: passed for the revised simulator layout and physical circular complication.

The user refined the original Portrait Fill direction after seeing it on the Watch:
slightly smaller Saturn artwork, a larger readable name, and no time in the tiny
circular slot. The exact original reference remains below; these later instructions
supersede its circular text/scale. Smart Stack retains the selected layout.

`ios/Artwork/Watch-complications/watch-face-device-build20.png` confirms actual
system-host rendering and shows the tight crop that prompted this change.
`portrait-fill-build21-comparison.png` in the same folder places the original design
and revised native capture together, using the same crops/density normalization
recorded in the build-20 review. `portrait-fill-build21-simulator.png` is the raw
324 × 394 capture. The circular subject is still prominent but 11.7% smaller; the
native semibold name is 12 points instead of 9. Its single row fits without the
previous time row. The existing event URL still opens details.

Fidelity review: native SF typography is larger and legible; bottom label spacing
fits within the circular clip; black/white contrast and bundled photographic assets
are retained; the new name-only copy follows the user's explicit instruction.
The smaller ring crop remains intentional background art rather than an entire
uncropped photo. The card's layout, colors, scale and copy are unchanged. No new
P0/P1/P2 findings remain in the simulator comparison. No frame or text is baked
into the artwork. The dedicated Moon phase percentage remains useful and unchanged.

Signed Release build 21 and all four nested identities/profiles pass verification.
Both devices independently report build 21 after successful installation. The
physical `ios/Artwork/Watch-complications/watch-face-device-build21.png` confirms
the smaller artwork, larger name and absent time in the actual widget host. The
Smart Stack layout was not changed in this refinement; its hardware appearance
remains an explicitly unverified item from build 20.

---

# Watch complication and Moon review — build 20

Review date: 6 November 2026.

final result: passed for the compared simulator design and affected interactions.
Build 20 is installed on both devices. The later physical circular capture confirms
rendering; the user requested the build-21 refinement above. Smart Stack hardware
confirmation remains pending.

## Target and evidence

The user selected the **first** generated design, Portrait Fill. Its exact source
is `ios/Artwork/Watch-complications/selected-portrait-fill.png` (1487 × 1058).
The existing bundled photographic assets are retained, including their different
Saturn ring angle; the mock establishes scale, crop and information hierarchy.

Evidence lives in `ios/Artwork/Watch-complications/`:

- `portrait-fill-comparison.png`: selected target and final SwiftUI render together.
- `portrait-fill-simulator.png`: 324 × 394 capture of the 162 × 197-point simulator.
- `all-subjects-simulator.png`: Saturn, Jupiter, Mars, ISS, full Moon and Venus.
- `moon-phases-simulator.png`: eight southern-hemisphere phase symbols.
- `moon-page-40mm.png`: actual app Moon page, correct first-quarter illuminated side.
- `tonight-spacing-40mm.png`: compact home hero, time, place and two page dots.

The comparison excludes design-board headings and the simulator clock. Reference
circle (54,335)–(435,720) and card (450,337)–(1440,740) are normalized to 200 × 200
and 640 × 280. Implementation crops (112,84)–(212,184) and (2,212)–(322,352)
use the same comparison sizes. Actual native components are 50 × 50 and 160 × 70
points at 2× density. The illustrative card has a slightly wider aspect ratio;
normalization compares hierarchy rather than asserting exact pixel equivalence.
The enlarged evidence naturally magnifies the real device's lower pixel density.

## Findings and revisions

- **Resolved P2: artwork too small.** First implementation still left Saturn's globe
  small. Increased its crop to fill the upper circular region and right card region;
  moved the card subject inward and circular artwork upward. Final comparison shows
  the planet as background imagery, not a thumbnail beside the title.
- **Resolved P2: time hierarchy compressed.** The initial 70-point card compressed
  its time to nearly title size. Reduced vertical padding and title size, separated
  the direction overlay and removed excess spacing. The final time is distinctly
  larger than the subject, matching the selected hierarchy.
- **Resolved P1: Moon illumination inverted.** Default palette darkened the lit
  portion. Explicit opaque shadow/white illumination now renders new, crescent,
  quarter, gibbous and full phases correctly. A translucent-shadow intermediate
  failed the eight-phase gallery and was corrected before acceptance.
- **Resolved P2: home footer below first screen.** Compact hero/footer spacing places
  viewing time and observing place above the native page dots; the hero remains a
  tappable navigation link. Existing large-text scrolling remains available.

## Required fidelity surfaces

- **Typography:** native SF, semibold subject, bold primary time, quieter place and
  direction. Name/time remain readable at actual size. Text remains native and live;
  no text is embedded in the artwork. The 50-point circle uses small fonts appropriate
  to its limited space rather than scaling the design-board typography literally.
- **Spacing/layout:** art fills the upper circle/right card, labels align to the
  lower circle/left card and direction sits upper right. System widget chrome owns
  the physical outer treatment; no decorative mock frame is introduced.
- **Colors:** white text, gray place, black contrast fades; original planet colors
  remain in full color. Accented display requests desaturation. Actual face tinting
  and Always On remain physical checks, not claims from this gallery.
- **Images:** correct bundled subject photography, bounded bitmap size, no invented
  replacement icons. Different ring angle/lighting from the generated concept is
  intentional reuse of the app's actual asset. Small circular imagery is necessarily
  less detailed than the enlarged reference; the final native-size gallery remains
  recognizable. No actionable P0/P1/P2 design mismatch remains in these captures.
- **Copy:** Saturn, 21:46, Stirling and N · 57° match the selected sample. Production
  values stay tied to the selected place/event. Live ISS and stale/empty fallbacks
  retain their existing semantics.

## Verification and limits

Signed Release build 20 and all nested signatures/provisioning verify. Relevant
Tonight navigation/paging and Moon/places/largest-text tests pass on 40 mm, including
an additional final Moon-page test. The visual gallery uses actual production view
code in an isolated temporary app; it is not proof of system complication rendering.
Build 18's prior bounded-image path was physically confirmed. Both build-20 installs and launches succeeded. The physical home capture
`tonight-device-build20.png` confirms time and place are visible with the hero.
Final watch-face/Smart Stack checks remain pending.

No commits or pushes were made. No static-site files changed.

---

# watchOS design and interaction review — build 14

Review date: 3 November 2026.

Final result: passed for the reviewed simulator design and interaction scenarios.
Physical-device confirmation remains open.

## Correct reference

The canonical reference is `ios/Artwork/Watch-approved-reference.png`, the exact
948 × 626 image supplied with the user's build-13 rejection. The previous
`Watch-release-reference.png` and build-13 sign-off used the wrong visual target.
Those screenshots are historical evidence, not acceptance criteria.

Compare the display interiors, excluding the illustrative cases and bands:

- Tonight: mint heading, left-aligned white Saturn title, compact gray NE · 42°,
  large cropped photographic Saturn, midnight background, navy Find it capsule.
- Next ISS: small mint ISS silhouette, large white countdown, gray until-visible
  caption, Look northwest, thin mint progress track, navy View path capsule.
- Active pass: mint heading, mint sampled trajectory and white marker above a blue
  horizon, white altitude below the plot, gray remaining time beneath it.

All text, controls, progress, trajectory and marker are native SwiftUI. The two
new raster assets are decorative backgrounds only. Existing NASA planet imagery
is retained; its lighting and rings differ slightly from the illustrative mock.
The ISS silhouette derives from the existing ISS asset. The system clock is real.
A small Back chevron is retained on details. The trajectory uses actual sampled
altitudes, so live passes will not all have the concept's illustrative arc shape.

## Iteration and fixes

- Replaced build 13's giant mint cardinal direction, small Saturn/title row,
  photographic ISS hero and giant mint elevation with the correct hierarchy.
- Compared successive simulator captures against the supplied reference. Early
  passes exposed an extra native title row, overflowing system progress bar,
  excessive plot height, countdown compression and compact-screen action clipping.
  Reworked those rather than accepting an existence-only test.
- Added separate compact spacing and artwork placement for 40 mm. The default
  primary actions must fit above the rounded bottom edge. Accessibility text may
  scroll, and tests actually reach and activate the actions at the largest size.
- Removed the one-second TimelineView surrounding the entire pager and the one
  surrounding the details ScrollView. The pager, scroll containers and navigation
  stack remain stable; only live content owns a one-second clock. Clocks stop when
  inactive/dimmed or on an unselected page. Rankings refresh at minute intervals.
- Removed scroll-geometry state feedback and dynamic scroll-edge-effect toggling.
  The remaining small, constant native-header/content insets do not change during
  gestures. Native horizontal paging and Crown/touch scrolling are retained.
- Moved forecast cache loading, JSON decoding and atomic forecast persistence to a
  dedicated actor. Incoming updates are serialized after startup loading; schema
  and revision checks remain intact. Connectivity background tasks are not completed
  until queued updates finish. Small reminder-action persistence is unchanged.
- Compute the trajectory's altitude ceiling once per plot render, removing repeated
  full-path scans for every sampled point.

## Verification evidence

Final images live in `ios/Artwork/Watch-build14`:
`tonight-{40,46}mm.png`, `next-iss-{40,46}mm.png`,
`active-pass-{40,46}mm.png`, and `largest-text-{40,46}mm.png`.
Native viewports are 162 × 197 and 208 × 248 points, captured at 2×. Each final
screen pair was inspected in the same comparison input as the canonical reference.
The sample values are frozen only for these design captures; the system time remains
real. Large-text captures show the screen after scrolling the entire action into view.

- Six UI tests passed on each size: active pass, missing/expired forecast,
  large text/Moon/places, no-pass versus no-orbit, repeated interaction under sync,
  and Tonight → guidance → Back → Next ISS → pass preview.
- The dense-update stress runs completed eight cycles on each size, taking
  113 seconds (40 mm) and 115 seconds (46 mm), without a failed gesture, stalled
  revision or forced relaunch. After the final face-height adjustment, both affected
  layout/navigation tests were rerun on each size and passed.
- Strengthened large-text assertions require the entire action to fit, rather than
  merely a tappable sliver. The stricter check passes on both sizes.
- Final post-spacing 46 mm stress rerun passed all eight cycles in 116 seconds.
  No actionable P0/P1/P2 findings remain in the compared default-size screens.
  Native clock/back affordance and photographic viewpoint differences are documented
  above; this is not a pixel-identical recreation of the illustrative watch hardware.
- Development-signed Release 1.0 (14) builds successfully for iPhone with the
  embedded Watch app and widget extensions. Deep, strict signature verification
  passes. Permanent team and bundle identities are preserved. The subsequent
  authorized device installation is recorded below.
- No website assets or astronomy engine changes. Static-site verification and cache
  version bumps do not apply to this native-only change.

The interaction stress scenario injects increasing revisions containing about
24,000 additional trajectory samples every two seconds. It exercises the real
receive/decode/validation/publication pipeline and atomic writes to a temporary
forecast file, without overwriting the normal cache or refreshing real widgets.
Eight cycles swipe both directions, open ISS details, scroll to Handoff, return,
scroll Tonight, open object guidance and return. It also backgrounds/reactivates
the app and asserts that received revisions keep increasing. Normal clocks keep
running; this test does not use frozen design-capture time.

Simulator checks cannot establish that every physical-device freeze is eliminated.
Physical Crown feel, WatchConnectivity transport, compass, haptics, VoiceOver,
Always On power use and prolonged on-wrist operation still need device testing.
Build 14 was subsequently installed and launched on both physical devices at the
user’s request. Both device inventories confirm build 14. See the installation
record in `ios/WATCH_RELEASE.md`; prolonged on-wrist interaction testing remains open.

## Build 15 follow-up: secondary event cards

The user's on-wrist photo exposed the default capsule button styling on multiline
secondary events. Those rows are now navy rounded rectangles with 12-point content
padding and a 16-point corner radius. White leading-aligned titles wrap freely;
time/direction uses smaller gray type, and the chevron yields its space when needed.
The background follows the content height; no fixed-height pill clips the label.
The existing main-face design is unchanged.

The fixture reproduces the three names in the photo. Tests verify full labels,
10-point minimum text-to-card-edge clearance, separation of title and metadata,
whole-card visibility, opening each event and returning, and paging after scrolling.
The first large-text iteration exposed an unwanted wrap in the SSE metadata row
on 40 mm. The final adaptive detail row resolves it without reducing title size.

Final result: passed for the reviewed card states. Two targeted UI tests pass on
both sizes (four runs), each opening all three events and checking Back and paging.
The final normal/large-text screenshots were visually inspected for both sizes:
`ios/Artwork/Watch-build15/cards-{40,46}mm.png` and
`cards-large-text-{40,46}mm.png`. Titles and metadata remain inside the card's
padding; the 40 mm largest-text SSE row correctly uses the full width.
Release build 15 and deep, strict verification of the app's nested signatures pass.
No website files changed; static cache-version bumps do not apply.
