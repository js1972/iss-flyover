# watchOS visual verification — 3 November 2026

final result: passed

This result covers native simulator layout and interaction QA. Physical sensors,
system notification delivery, complication scheduling, Handoff UI and battery use
remain release gates in `ios/WATCH_RELEASE.md`.

## Visual source and capture conditions

- Source: `ios/Artwork/Watch-release-reference.png`, 1536 × 1024, the user's selected
  third concept. App content only is the target; the rendered cases/bands are not UI.
- Implementation: `ios/Artwork/Watch-validation/tonight-40mm.png`, `next-iss-40mm.png`,
  `active-pass-40mm.png`, and corresponding `*-46mm.png` files.
- Native viewports: 40 mm, 162 × 197 points at 2× (324 × 394 pixels); 46 mm,
  208 × 248 points at 2× (416 × 496 pixels). No CSS/browser viewport applies.
- The concept's approximately 198 × 242-point content is rendered inside a larger
  board. Comparison excludes case/board padding and uses logical point proportions,
  rather than treating board pixels as native screen pixels. No claim of pixel-identical
  device chrome or chart shape is made.
- States: illustrative Saturn Tonight, future ISS countdown, active ISS pass;
  separate captures cover object guidance, Moon, larger text and failure states.
  Capture times differ: counts advance while the active app runs. The plotted path
  uses sample elevations rather than a decorative semicircle.

## Findings and comparison history

1. [P2, fixed] The initial native navigation title consumed a second row. The main
   button and active-pass remaining time were below the first viewport. Replaced
   the root title with a compact leading toolbar label, applied an explicit 44-point
   primary-button style and adjusted density for the 40 mm display. The default-size
   controls are now visible in the committed screenshots.
2. [P2, fixed] The first small-screen adjustment flattened the chart by leaving too
   little plotting height after direction labels. Increased its allocation, reduced
   empty internal margins and balanced the elevation type size. The final 40 mm and
   46 mm active-pass images show the measured curve, marker, directions and remaining
   time together.
3. One automated 46 mm Tonight screenshot caught a transition with missing static
   labels. A settled simulator capture confirmed the complete title/object/artwork
   and replaced that capture (`tonight-46mm.png`).

## Required fidelity review

- **Typography:** native SF rounded bold numeric values, SF labels and monospaced
  countdowns retain the selected hierarchy. Scaled metrics support larger text;
  scrolling exposes content that cannot fit simultaneously at accessibility sizes.
- **Spacing:** compact primary task, one action, no nested cards or tab bar. Native
  horizontal page dots and Back button provide navigation. Extra events, location,
  reminders and weather are below the primary task. Larger text intentionally needs
  more scrolling; the navigation tests reach and activate controls.
- **Colours:** black background, existing mint RGB 0.43/0.90/0.78 and white text.
  Charcoal buttons replace the initially green system tint to match the chosen concept.
- **Images:** existing NASA planet/ISS assets are reused without distortion. Saturn
  remains a compact thumbnail; the ISS illustration supports the countdown. Standard
  SF Symbols provide actions. The pass plot is factual native drawing, not artwork.
- **Copy:** previews and current positions are distinguished; no-visible-pass and
  unavailable/expired data have separate explanations. A minute countdown omits the
  extra “until visible” line on the 40 mm layout to keep the main action in view.
  Native Back/state labels differ intentionally from the concept's presentation.

Full-view comparison checked hierarchy, density, imagery and action placement for
all three screens against the selected board. Focused review of the native toolbar,
primary button and pass plot used the full-resolution 324/416-pixel captures; these
regions are readable without a separate crop. Larger text/Moon captures were reviewed
separately because the concept does not specify those states.

## Interaction evidence

- Watch UI suite: five passing tests on each of 40 mm and 46 mm, including horizontal
  navigation, separate object/ISS details, Back, Moon, places and data failures.
- Compact foreground phone/watch transport verified with real Perth forecasts.
- Native release build succeeds. No actionable visual P0/P1/P2 findings remain in
  the reviewed states. Hardware behaviour is explicitly not established by this report.
- Website browser smoke test separately covered the updated static support/privacy
  pages and preserved event preview. It is not a substitute for native watch testing.

## Follow-up polish and release gates

- Review default and accessibility typography on a physical watch outdoors.
- Measure active tracking battery consumption and dimmed-display update behaviour.
- Capture App Store screenshots after hardware acceptance and signing validation.
- See `ios/WATCH_RELEASE.md` for all remaining platform delivery checks.
