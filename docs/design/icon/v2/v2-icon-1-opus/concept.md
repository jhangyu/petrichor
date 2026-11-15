# Echo Cloud — v2-icon-1-opus

**Concept.** The cloud *is* the radar echo. One soft Fluent cloud is drawn four times, each copy smaller and
contracting toward an off-centre storm cell: sky-blue rim → blue → teal-green → amber-to-red core, the dBZ
ramp read as nested reflectivity contours. Three rounded, slanted rain pills fall from it. Cloud, radar and
rain are one form, not three icons side by side. Petrichor: the warm core is the heavy cell that wets dry ground.

**Fluent 2 traits.** Few bold, rounded forms (cloud + nested bands + pills); every shape is a multi-stop
linear/radial gradient; bands are slightly translucent (opacity .92–.96) with soft blurred contact shadows
between layers, which gives depth by overlap; top-left key light (radial white highlight clipped to the
cloud); soft blurred ground shadow under cloud and drops; light, clean background; no strokes, no text.

**Palette.** Background `#F7FBFF → #E6F1FC → #D3E4FA` + violet glow `#C9C2FA`. Rim `#BFEBFF → #8CCFFB → #479EF5`
(brand-100). Blue band `#4FA8F7 → #1E6FD9`. Green band `#2FD1B4 → #16A35A` (dBZ-20 family). Core
`#FFE14A → #FF9A1F → #F5513A → #E5394F` (dBZ-30/40/50 family). Rain `#62ABF5 → #2163D8`.
Dark: background `#14304F → #070F1E` + violet `#4B2E8F`. Monochrome: single fill.

**Construction (108 grid).** Cloud = circles (57,43,r16) (40,49,r11.5) (72.5,50.5,r10.5) + base rect 27–84 × 46–64, rx 9.
Bands = same cloud scaled 0.76 / 0.54 / 0.33 about the cell anchor (58.5,52.5). Drops 5.6×11, rx 2.8,
rotated 20°, at (43,75) (55.5,79) (68,75). Whole art scaled 0.92 about centre (54,54) → all content inside r ≈ 30.
iOS uses the 84-unit window 12–96 → 1024; macOS maps the same window onto the 824 body, r 185, baked shadow.

**Masks.** All content sits inside the 66 dp circle with ~3 dp to spare, so circle, squircle, square, pill,
arch, slanted, cookie, clover, flower, sunny, gem and pentagon never touch the art. Background is a
content-free gradient, safe for 18 dp parallax. Monochrome = cloud + three pills silhouette (bands omitted on purpose).

**Weaknesses.** At 16 px the bands collapse into a warm dot inside a blue cloud — still a "storm cloud", but the
radar-contour idea needs ≥ 29 px. The orange core can briefly read as "sun behind cloud". iOS tinted is
a desaturated copy of the colour art; the bands become grey steps, readable but flatter. Rain pills are
small in the monochrome layer at 16 px.
