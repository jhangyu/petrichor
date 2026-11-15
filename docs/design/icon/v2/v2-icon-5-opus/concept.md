# Echo Rain — v2-icon-5-opus

**Concept.** One frosted cloud and three rain streaks. The rain is the radar echo: each streak carries one
dBZ level (light blue → green → amber/orange), and the same colours glow up inside the cloud's belly, so the
cloud reads as "lit from within by its own reflectivity" and the echo drains out of it as rain.
**How the motifs merge.** Cloud and rain are one layered form (streaks tuck under the cloud base); the radar echo
is not a separate object but the colour of the rain plus its blurred reflection clipped inside the cloud. 4 shapes total (cloud + 3 streaks) → boldest silhouette, clean 16 px and monochrome.

**Fluent 2 traits applied.** Few bold rounded forms (circle-lobe cloud, capsule streaks, no strokes); layered
overlap with a soft contact shadow under the cloud; translucent colour bleed (echo glow seen through the
frosted cloud); multi-stop linear gradients in every shape; top-left radial key-light highlight on the cloud;
light, soft brand-blue background gradient; no text.

**Palette.** Background `#DCEBFB → #96C6FA → #479EF5` (brand-150/130/100). Cloud `#FFFFFF → #F2F8FE → #CFE4FA`.
Streaks: `#5FD2FF → #1F7FE0` (dbz-10 family), `#6FE08F → #22B14C` (dbz-20), `#FFD43B → #FF8A00` (dbz-30/40).
Shadow `#0C3B5E` @ 32 %. Dark: bg `#0F548C → #0A2E4A → #061724`, cloud `#EBF3FC → #77B7F7`. Tinted: neutral greys. macos-dark.svg = iOS dark palette.

**Construction (108 grid).** Cloud = three circles (37,46 r11), (53,37.6 r16), (71,44 r13) joined to a flat base
at y 57. Streaks: width 8.5, slant 16°, tops x 43 / 56.5 / 70, lengths 22 / 31 / 25. Farthest content point
30.5 dp from centre (safe 33). Art shifted (+0.4, +5) dp: mass centroid 1.8 dp above centre. iOS art × 13.2; macOS ×10.6.
Monochrome: cloud + streaks with a 4.5 dp gap below the cloud base, single fill.

**Why it survives each mask.** All content within the 66 dp circle; background is a content-free gradient,
so parallax and every M3 shape (cookie, clover, flower, sunny, gem, pentagon, pill, arch, slanted) only trim
background. Vertical stack (cloud above, rain below) is optically centred (mass slightly above centre).

**Known weaknesses.** Cloud-with-rain is a familiar weather glyph; the radar idea rests on colour (dBZ ramp +
belly glow) and disappears in monochrome/tinted, where it is "just" a rain cloud. White cloud on light-blue
background has modest contrast at 16 px. The belly glow uses a Gaussian blur filter: Android vector drawables
cannot express it, so the production foreground needs a gradient-mesh or raster fallback for the glow.
