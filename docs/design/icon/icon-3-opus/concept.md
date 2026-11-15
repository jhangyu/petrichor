# Island Rain — icon-3-opus
**Concept.** A plum-rain (梅雨) cloud stands over Taiwan's central mountain ridge. Three slanted streaks fall toward the peak, and the sea lies at the island's foot.
**Metaphor.** Petrichor is rain meeting dry ground, so the rain is shown arriving on the land. The icon suggests a place (mountain island, monsoon sky, sea), not a map outline.
## Palette
| Role | Light | Dark | Tinted |
|---|---|---|---|
| Sky gradient (bg) | #0F3346 → #2C6F7A | #06141C → #0F2C35 | #0A0A0A → #1C1C1C |
| Cloud | #EEF5F3 | #DCE9E7 | #FFFFFF |
| Rain | #8ED3D6 | #6FBFC4 | #D0D0D0 |
| Back ridge (jade) | #5FA58F | #3E8371 | #9A9A9A |
| Front ridge (forest) | #1E4C42 | #163830 | #555555 |
| Sea / wave | #133D52 / #8ED3D6 55% | #0B2533 / #6FBFC4 | #2E2E2E / #BBBBBB |
## Construction grid (108 dp)
- Safe zone: circle at (54,54), r 33. Cloud spans y 24–47 and x 30–78. Rain spans y 50–56. Peak is at (54,59). Ridges sit on a sea line at y 85.
- Cloud = one rounded bar plus three circles (r 8 / 11 / 7) with a flat base. Rain = three capsules, 3.2 dp wide, slanted 3:6.
- Background layer = vertical sky gradient only. It is full-bleed and has nothing at the edges, so parallax up to 18 dp shows no seams.
- Foreground: the ridges and sea extend to the canvas edges as bleed. The essential marks (cloud, rain, peak) stay inside the safe zone.
- iOS shows the 84 dp window (12–96) at 1024. macOS uses the same window inside an 824 body with rx 185, a baked shadow (blur 14, dy 12, 35%) and a transparent surround.
- Monochrome uses the same cloud and rain, a trimmed ridge, and a wave bar, all inside r 33. It uses one fill color.
## Why it survives each mask
- The cloud, rain and peak sit in a vertical stack on the center axis. Every mask trims only the sky corners and the bleed of the ridge and sea.
- The ground bleeds to all bottom edges, so circle, squircle, arch, gem and pentagon each show a horizon instead of a cut-off shape.
- At 16–32 px the image reduces to a white cloud over a jade triangle on dark teal. That pair still reads as "rain weather".
## Known weaknesses
- Cloud with rain is a generic weather glyph. The place identity comes from the ridge and sea, and these lose detail below 32 px.
- In the Android masks, the sea strip shows only 85–90 dp. The wave line is mostly hidden, and the island-in-sea reading is clearest on iOS and macOS.
- The deep masks (clover, diagonal pill) clip the outer cloud lobes.
- The rain streaks are thinner than 1 px at 16 px.
- The monochrome ridge has a small notch on its left foot that reads as noise at small sizes.
