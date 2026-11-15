# Petrichor icon — Atmosphere (icon-5-opus)

**Concept.** Rain seen through glass: a frosted, layered cloud (a translucent second cloud behind it gives depth), one lit raindrop
falling in front of it, and a ripple where it lands. A warm earth glow rises from the bottom of a dusk-blue sky — the moment
rain meets dry ground. Calm, single-subject, rain-centric.

**Palette.**
Sky `#102C4A` → `#22547A` → `#3D7B92` · earth glow `#E9AE74` (50 % → 0) · cloud `#FFFFFF` → `#D3E3F2` ·
back cloud `#A9CBEA` @ 42 % · drop `#B4E2FF` → `#4A9BEA` → `#1C59B8` · ripple `#D7ECFA` · drop shadow `#0A2340` @ 28 %.
Dark: sky `#070F1A` → `#16324A`, cloud `#E4EDF6` → `#A9C1D8`. Tinted: black ground, cloud gray 60 %, drop white.

**Construction (108 grid, centre 54,54).** Cloud = circles (41,50 r11) (56,41 r15) (70.5,50.5 r10.5) + flat base y 61.
Drop: tip (54,47), bowl r 11.5 centred (54,69). A 2.9-unit gap (clip-path, not a stroke) separates drop from cloud so the two
silhouettes never merge at small size or in monochrome. Ripple: ellipses rx 12/5.5 at y 85.5. Farthest essential point sits at
r ≈ 32.4 from centre — everything inside the 66 dp circle (r 33). iOS art = 108 grid × 10.8; macOS = × 8.7 inside the
824 body (rx 185) with baked 14 px blur / 12 px offset shadow and a faint top rim light.

**Why it survives each mask.** Background is a pure full-bleed gradient (extends to −20…128, so 18 dp parallax shows no edge).
All content is inside r 33, so circle, squircle, cookie, clover (min r 36), flower, sunny, gem, pentagon, arch and slanted never
clip it. Monochrome is one fill colour; the gap is geometry, so the themed icon keeps cloud/drop separation; the back cloud uses
50 % alpha (Android monochrome honours alpha). Tinted variant keeps the drop as the brightest element so the system tint lands on it.
Foreground uses only gradients and opacity — no filters — so it converts to an Android VectorDrawable losslessly.

**Known weaknesses.**
- Cloud + raindrop is a common weather metaphor; distinctiveness comes from the material treatment, not the silhouette.
- At 16 px the ripple and back cloud disappear (acceptable: cloud + drop still read). A 16 px-specific simplified glyph would help.
- The warm glow is subtle; on some screens the bottom reads as muddy grey-teal rather than "earth".
- macOS body uses SVG `rx`, a circular corner, not Apple's continuous-curvature squircle.
- Translucent back cloud shows through the main cloud slightly (intended glass layering, but faintly visible seam at 32 px).
