# Radar Echo — icon concept (icon-2-opus)

**Concept.** A weather-radar scope (the kind of display meteorologists read, with range rings, a north/east crosshair and 30° bearing ticks) shown just after the sweep has passed over a rain cell. The echo is shaped like a single raindrop and filled with three nested contour bands, the same way the app's radar screen colours reflectivity. Petrichor is the smell of the first rain, and the icon shows that rain the moment the radar first picks it up: calm, exact, and about rain. It is drawn from the app itself, not from generic weather clip-art.

**Palette** (all colours come from `lib/core/theme/app_tokens.dart`)
- Scope ground: radial gradient `#0E4775` → `#0A2E4A` → `#061724` (the app's brand blues, steps 50/30/10)
- Rings `#479EF5` at 55% opacity, outer bezel and ticks `#77B7F7`, sweep wedge `#62ABF5` fading 0 → 42%, sweep line and hub `#EBF3FC`
- Echo bands, taken verbatim from the radar colour scale (`AppPalette.dbzScale`): `#00C8FF` (3 dBZ, outer), `#00C800` (20 dBZ, middle), `#FFD300` (34 dBZ, core). Only three of the 66 colours are used. Red and magenta are left out on purpose, because they made the drop read as a flame.
- Stray echoes `#00C8FF` at 70% opacity

**Construction (108 dp grid, centre 54,54).** Scope radius 32 (inside the 33 safe radius). Inner rings sit at 1/3 and 2/3 of that radius. The drop is a sharp tip at (43.5,24) joined by straight tangents to a body circle (centre (43.5,46), r 13.2). The inner bands are the same drop scaled ×0.64 and ×0.30 toward (43.5,48.5). The sweep's leading edge points to −72° (about 1 o'clock) and its wedge trails 95° behind. iOS scales the scope to radius 384 on the 1024 canvas (75%). macOS uses an 824 body with radius 185 and a 12 px y-offset blur shadow, with the scope at radius 339.

**Why it survives each mask.** Every essential element sits inside a circle of radius 32.5, so circle, squircle, rounded square, square, pill, arch, slanted, cookie, clover, flower, sunny, gem and pentagon masks can only cut the plain navy background or, on the tightest masks, the faint outer bezel. The background layer is a pure gradient, so the 18 dp parallax shift shows nothing new at the edges. The monochrome layer uses one fill colour, with alpha steps for the bands. The tinted variant is a grayscale version of the same drawing on black, so the system tint keeps the hierarchy: core brightest, then bands, then rings.

**Small sizes.** At 16–32 px the rings and ticks disappear and what remains is a dark disc, a bright drop in the upper left and a light diagonal sweep line. That outline is still recognisable.

**Known weaknesses.**
- The drop sits off-centre toward the upper left (so the scope still reads as a scope), which leaves the lower right visually light. The stray echoes only partly balance it.
- Cyan, green and yellow on navy is saturated next to Fluent-calm UIs. A dimmer variant could swap green for `#00A000`.
- The iOS dark variant is close to the light one. Radar scopes are dark by nature, so this design has no true "light" look.
- Nested coloured drops can still faintly suggest a flame at a glance. Removing the red core reduced this but did not remove it.
- The preview's Material 3 shapes are hand-built approximations, not the AOSP shape paths.
