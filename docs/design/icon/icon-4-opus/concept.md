# MARK — P-drop monogram (icon-4-opus)

**Concept.** A heavy geometric "P". The counter (hole) in the bowl is a geometric raindrop: a circle with one square corner, pointing up-left like wind-driven rain. A second drop of the same shape has fallen to the ground beside the stem, in a warm clay colour. Rain meeting earth is what "petrichor" means.

**Palette.**
- Background gradient: `#2886DE` → `#0C3B5E` (brand90 → brand40 from `lib/core/theme/app_tokens.dart`)
- Glyph: `#FFFFFF` → `#EBF3FC` (brand160)
- Fallen drop ("earth"): `#F2B66D`
- iOS dark: bg `#14191F` → `#06090D`, glyph `#77B7F7` → `#2886DE` (brand120 → brand90)
- iOS tinted: black bg, glyph `#FFFFFF` → `#C8C8C8`, drop `#8C8C8C`

**Construction grid (108 dp canvas, 4 dp unit).**
- Stroke weight is 10 everywhere: stem x 38–48, bowl ring 10 on top, right and bottom.
- Bowl: an outer circle of R 16 centred at (54, 44), with its top-left quadrant squared off into the stem.
- Counter: a drop of r 6 with the same centre and its square corner at (48, 38).
- Fallen drop: r 5 (diameter 10 = stroke weight) centred at (63, 73), square corner at its top-left.
- The glyph is scaled ×0.9 about the canvas centre. Its farthest point is 27.5 dp from the centre; the safe zone is 33 dp.
- The glyph spans x 38–70 and y 28–80 before scaling, so its bounding-box centre is (54, 54).
- iOS maps the 84 dp centre region to 1024 px, so the glyph is about 62 % of the icon height.
- macOS maps the same 84 dp region onto the 824 px body (×9.81).

**Why it survives each mask.** All content lies within a 27.5 dp radius, which leaves 5.5 dp of margin inside the 66 dp safe zone. The background is a plain gradient with nothing at its edges, so it holds up when the layers move 18 dp in parallax. Circle, squircle, rounded square, square, pill, arch, slanted, cookie, clover, flower, sunny, gem and pentagon were all checked in `preview.html`. The shape is a single flat silhouette with no detail thinner than 10 dp, so the monochrome / themed version is the same artwork with one fill. The P stays legible at 16 px.

**Known weaknesses.**
- At 16 px the fallen drop is about 1.7 px wide. It reads as a dot or a full stop, not as a drop; the P alone carries the mark.
- The outer bowl is a plain P silhouette. The drop idea lives only in the counter and the fallen drop, so at a glance the mark reads "P." more than "rain".
- The P-plus-full-stop look is close to generic letter-mark icons, so it is less distinctive than a pictorial concept.
- The clay-coloured drop is the only warm hue. In the tinted and themed versions it becomes the same ink as the glyph, so the rain-meets-earth colour story is lost there.
