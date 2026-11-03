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
  passes. Permanent team and bundle identities are preserved; no device installation.
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
No build-14 physical installation is performed as part of this review.
