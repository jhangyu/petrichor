# The Sweep — icon concept (v2-icon-2-opus)

**Concept.** A radar sweep is drawn as one thick, rounded gradient band that arcs clockwise over the sky. It starts as a faint violet tail at the lower left and ends in a bright, glowing cyan head at the lower right. The band wraps the top of a soft rain cloud. Its head sinks behind the cloud's right lobe and shows through the translucent cloud, so the sweep and the cloud read as one form. Rain falls in the open bottom of the sweep, where the beam has just passed. The three drops use the app's radar dBZ colours (light blue, blue/teal, green).

**How the motifs merge.** Sweep = the cloud's top edge and halo, plus a soft translucent swept sector behind the cloud. Cloud = the body the sweep wraps around. Rain = what the sweep found, falling out of the swept area. There is one silhouette, not three icons in a row.

**Fluent 2 traits applied.** Only 3 major forms (sweep band, cloud, drops). Generous rounding (round caps, round cloud lobes, teardrops). The layers overlap: the cloud is 90 % opaque over the sweep head, so the colours mix. Multi-stop linear and radial gradients are used in every shape. A key light at the top left (background radial highlight, cloud inner highlight). Soft contact shadows under each layer. A light, clean tile. No strokes and no text.

**Palette.** Background `#FFFFFF → #EAF3FD → #C7DEF8` (brand-160/150 family). Sweep `#8C7BF5` (violet tail, fades to 18 %) → `#2886DE` (brand-90) → `#22D3EE` (cyan head), with a `#5BE3F5` glow. Swept sector `#479EF5` (brand-100) at 0 → 42 %. Cloud `#FFFFFF → #E3EFFC → #B4D6FA` (brand-140). Drops `#A6E3FF→#2F8FE6` (dbz-0→dbz-10), `#5FD0E8→#0F6CBD` (brand-80), `#7FE0A6→#22B14C` (dbz-20). Contact shadow `#0F548C` (brand-60) at 28 %. Dark variant: navy ground `#173A63 → #061724` (brand-10), brighter sweep. Tinted variant: grayscale on black.

**Construction (108 dp grid).** The sweep pivot is at (54, 51). Outer radius 28. The band runs from 150° to 394° (screen degrees, clockwise). The band thickness grows from 4.4 to 11.6 dp along an ease-in curve (t^1.4). Both ends have round caps. Cloud: lobes r 12.6 at (56, 44), r 8.8 at (40.8, 51.8), r 7.4 at (69.6, 53.4), and a rounded base from x 32 to 77, y 49 to 62.6. The cloud is built as one unioned path. Drops are at y 74–78, rotated 14°. Every element sits inside r ≈ 31 of the canvas centre (safe zone r 33). iOS scales the 108 grid by 1024/86. macOS uses an 824 body with radius 185, a 12 px y-offset shadow, and a scale of 824/90. The generator lives at `.claude/tmp/v2-icon-2/gen.py` (scratch, gitignored).

**Monochrome.** One fill colour. The sweep is cut 2 dp away from the cloud (geometric difference, no mask), so the silhouette stays as three separate readable parts: arc, cloud and drops.

**Why it survives each mask.** All content is inside the 66 dp circle. The background is a pure gradient that extends past every edge, so the 18 dp parallax shift shows nothing new. Circle, squircle, rounded square, square, arch, slanted, cookie, clover, flower, sunny, gem and pentagon masks only cut the background. The narrow pill mask clips the lower-left drop slightly.

**Small sizes.** At 16–32 px the thick band and the white cloud still read as "cloud under a radar arc". The drops become blue-green dots.

**Known weaknesses.**
- A ring around a cloud can read as a gauge or speedometer before it reads as radar. The fading tail and glowing head help, but some viewers may still see a gauge.
- On the light tile, the white cloud has low contrast with the background. It is separated mainly by the shadow and the sweep.
- The swept-sector glow behind the cloud is subtle and mostly hidden. The radar idea rests on the band's gradient.
- The Material 3 mask shapes in the preview are hand-built approximations, not the AOSP paths.
