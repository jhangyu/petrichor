# First Drop — Petrichor icon concept

**Concept.** The word made literal: one cool raindrop lands on warm, dry clay. Two ripple rings mark
the impact. Two soft wisps rise beside it, the scent the app is named after. One subject, calm.

**Palette.**
- Clay background: vertical gradient `#C9774C` to `#8E4527`
- Rain drop: `#9AD6FF` to `#1E78DC` (close to the app brand blue `#0F6CBD` in `lib/core/theme/app_tokens.dart`)
- Ripples and scent: dry-sand `#F4D9B8`; drop rim `#A9582F`; highlight `#FFFFFF` at 70%
- Dark: bg `#2A1D16` to `#140D0A`, ripples `#D9A47A`. Tinted: bg black, drop white to `#A6A6A6`, ripples `#8C8C8C`

**Construction (108 dp grid, centre 54,54, safe circle r 33).**
- Drop: tip at y 25, round base r 13 centred at (54, 55.5), base at y 68.5. Optical centre sits slightly high on purpose; the rings below balance it.
- Inner ring: ellipse 17 x 4.2 at y 70, stroke 2.4. Outer ring: 27 x 6.6 at y 70.5, stroke 1.8, 55% opacity.
- Wisps: two S-curves at x 35.5 and 72.5, y 44 to 64, stroke 2.
- Every point stays inside r 33 (outer ring tip is about 32 from centre).
- iOS: the 80 dp window (14 to 94) maps to 1024 (scale 12.8). macOS: the same window maps to the 824 body (scale 10.3), radius 185, shadow dy 12 blur 14 at 32%.

**Why it survives each mask.**
- The background is a plain gradient with no edge content, so 18 dp parallax and every shape crop are safe.
- All artwork sits in the 66 dp circle, so circle, cookie, clover, flower, gem and pentagon never cut it.
- The composition is vertical and centred, so pill and slanted masks lose only empty clay.
- Monochrome keeps drop and rings only, one colour `#000000`, with the outer ring at 60% alpha.
- At 16 px the wisps and rings fade out and a blue drop on orange clay remains. That is still a readable "rain" mark.

**Known weaknesses.**
- The drop is the most common weather glyph. The clay colour and the ripple carry the distinction. At 16 px it is only "blue drop on orange".
- The wisps can read as "steam" or "hot", a weak signal for a rain app. If the user does not like this, remove the wisps.
- In monochrome the drop base touches the inner ring. The shapes merge slightly at the contact points.
- Orange-brown is warm and unusual for a weather app. Some users may not link it to weather at first glance.
- The drop rim (`#A9582F`) is darker than the bg near the top of the drop. It reads as a thin outline, not as a cut-out gap.
