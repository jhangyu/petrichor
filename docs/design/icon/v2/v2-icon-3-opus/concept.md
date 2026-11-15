# Overlap Mixing — v2-icon-3-opus

**Concept.** One cloud built from three translucent lobes: a brand-blue lobe (left), a cyan lobe (right) and a
periwinkle base lobe with a flat bottom and a domed top. Where lobes overlap, the colour "accumulates" like
radar reflectivity: two-lobe overlaps turn cyan-teal and green (20–30 dBZ), the three-lobe core turns amber
(30–50 dBZ). The base lobe sheds two drops (brand blue, teal). Cloud = silhouette, radar echo = overlap colours,
rain = drops: one form, not three icons.
**Fluent 2 traits applied.** 3 major forms + 2 drops; generous radii (circles, 11.5-unit stadium ends);
overlap-driven depth and colour mixing; radial multi-stop gradients per lobe with a top-left key light;
soft white inner highlight on the upper lobes; soft drop shadow under the cloud and a blurred contact shadow;
light brand-tint background (`#f6fbff → #c3dcf8` + top-left glow); no strokes, no text.
**Palette.** Lobe A `#7cc0fb → #1f78d1 → #0f548c` (brand-100/80/60 family); lobe B `#c4f1ff → #4cc3ef → #1a8fd0`;
base `#e2edff → #9db8fb → #5b72e6` (violet accent); A∩B `#6fe3e0 → #16a9c4`; B∩base `#8ef0a8 → #22b14c` (`--dbz-20`);
A∩base `#7fe0b5 → #1ba67a`; core `#ffe066 → #ff8a00` (`--dbz-30`/`--dbz-40`); drops `#62abf5 → #0f6cbd`,
`#4fd6c8 → #1595b5`. Dark: same hues lifted, bg `#1b3554 → #081524`. Tinted: grey ramp on near-black.
**Construction grid (108).** Lobe A circle c(41,45.5) r14.5; lobe B c(60.5,41) r17.5; base stadium x23–85,
y47–70, end radius 11.5, top domed to y≈44; drops c(45,80) r3.9 and c(61.5,80.5) r3.2. Max distance of any
contour from centre = 32.0 < 33 (safe zone). iOS scales the 108 artwork ×11.2, macOS ×9.6 inside the 824 body.
**Why it survives masks.** All content inside the 66 dp circle; background is a full-bleed gradient with no
content at edges (parallax-safe). Organic round silhouette sits naturally in circle, squircle, cookie, flower.
Monochrome = union silhouette (cloud + 2 drops), one fill; reads as "rain cloud" at 16 px.
**Known weaknesses.**
- Radar meaning lives only in the overlap colours; monochrome and tinted variants lose it (plain rain cloud).
- At 16 px the three overlap colours merge into a multicolour blob; silhouette still reads, detail does not.
- Upper lobes are full circles, so at large sizes the cloud can read slightly "bubble / Venn"-like.
- Filters (drop shadow) do not convert to Android VectorDrawable; the Android foreground needs the shadow
  dropped or rasterised at export.
