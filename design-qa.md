# watchOS visual verification — build 13, 3 November 2026

final result: passed

This supersedes the build 12 visual sign-off. That earlier review accepted working
navigation and readable controls despite substantial drift from the approved image.
The user's physical-watch photo and the subsequent simulator comparison exposed it.

## Reference and comparison conditions

- Visual source: `ios/Artwork/Watch-release-reference.png` (1536 × 1024), the
  selected Tonight / Next ISS / Active pass concept.
- Final evidence: `ios/Artwork/Watch-build13/tonight-{40,46}mm.png`,
  `next-iss-{40,46}mm.png`, `active-pass-{40,46}mm.png` and
  `largest-text-{40,46}mm.png`.
- Native viewports: 40 mm, 162 × 197 points / 324 × 394 pixels; 46 mm,
  208 × 248 points / 416 × 496 pixels. Both are 2× captures on watchOS 27 simulators;
  CSS dimensions do not apply. The generated reference contains perspective watch
  cases, so comparison uses the proportions inside each black display, excluding
  bands, case and board labels. It is not a pixel-identical device-frame comparison.
- States match the reference: Saturn with NE / 42°, imminent ISS countdown, and a
  live pass. Countdown/elevation/time values advance during capture. The final source
  and native screenshots were inspected together in the same comparison input for
  each size. Full-resolution images also made the header, artwork, button clearance,
  endpoints and typography directly readable without separate focused crops.

## Findings, fixes and comparison history

1. **[P1, fixed] Small artwork and figures lost the intended hierarchy.** Build 12
   allocated 24–32-point artwork heights and 36–44-point main type. Build 13 uses
   prominent Saturn/ISS images and 58–72-point base figure sizes, scaled for 40 mm.
   Saturn's existing photograph is framed to emphasize the planet and rings.
2. **[P1, fixed] Generic header spacing and enlarged content pushed actions offscreen.**
   The first enlargement pass exposed this overflow. Compact title/back controls,
   explicit scroll-content insets, fitted figure line boxes and balanced action
   widths now keep both complete primary buttons above the page indicators.
3. **[P2, fixed] Time/location details collided with page dots.** Secondary details
   now start after a deliberate gap below the main face. They remain reachable by
   scrolling. The two horizontal pages and Crown scrolling remain intact.
4. **[P2, fixed] The pass screen lacked the reference's compact hierarchy.** A compact
   “ISS now” header replaces the oversized Back row and separate state row. The
   large altitude, path endpoints and remaining time fit together. The plot scales
   its vertical axis to the sampled pass (with zero at the horizon), preserving
   the actual altitude-over-time data rather than drawing a decorative semicircle.
5. **[P2, fixed] Larger text split Saturn mid-word beside its image.** `ViewThatFits`
   stacks artwork and title when the horizontal arrangement cannot fit. Labels and
   figures scale; extreme text sizes require scrolling. Tests reach and activate
   Find it, return, and continue to Moon and observing places at the largest request.
6. **[P2, fixed] Modern watchOS's soft top edge blurred the initial main figure.**
   The final pass disables that effect only while the scroll view is at the top;
   scrolling restores it to protect the header. This uses a watchOS 26 availability
   guard and preserves the existing fallback for earlier supported watchOS versions.

## Required fidelity surfaces

- **Typography:** large SF rounded bold figures, white SF labels, and monospaced
  countdowns now reproduce the intended emphasis. Long headings can stack; direction
  and countdown values fit a single line. Dynamic Type preserves scrolling access.
- **Spacing:** title and system clock share a compact header. The primary task fills
  the first face; charcoal actions have inset sides and clear space above page dots.
  The active pass has a prominent elevation and a clearly separated trajectory.
- **Colour:** black, bright mint, white and charcoal follow the reference. The current
  sample marker is white; endpoints and direction arrow are mint.
- **Images:** existing photographic Saturn and ISS assets remain sharp and retain
  their aspect ratios. Their lighting/viewpoint differs from the generated concept,
  but subject prominence is corrected. No rasterized UI or fake device chrome is used.
- **Copy:** Tonight, Find it, Next ISS, until visible, Northwest / direction arrow,
  View path, ISS now, above horizon and remaining time match the intended flow.
  Preview/ended states remain truthful; accessibility labels identify current versus
  preview elevation. Native Back and page indicators are intentional additions.

No actionable P0/P1/P2 visual findings remain in these reviewed states. This is a
simulator visual/interaction result, not a claim of complete accessibility compliance.

## Verification and limits

- Five UI tests pass on each of 40 mm and 46 mm after the final scroll-edge change.
  Coverage includes object guidance and Back, horizontal page switching, ISS preview,
  active pass, largest requested text, Moon/places, first launch, expired forecast,
  and distinct no-pass/no-orbit states.
- Primary-action assertions check horizontal bounds and full bottom clearance above
  page indicators. Controlled scrolling avoids flinging past the accessibility-size
  action; the action is actually tapped and its destination verified.
- Signed Release build 1.0 (13) succeeds for the iPhone, embedded watch and both
  widget extensions. Signatures, permanent team, separate App Groups and physical
  device eligibility are verified. Build 13 was subsequently installed and launched
  on both physical devices; the Watch's Tonight screen was visually confirmed.
- No website assets or astronomy/sync logic changed. Existing physical compass,
  haptics, notification routing, background sync, VoiceOver, battery and older-watchOS
  runtime checks remain in `ios/WATCH_RELEASE.md`; they are not reclassified as passed.
- P3 follow-up: judge outdoor readability and artwork prominence on the user's own
  watch after installation. The simulator is left open for preview first.
