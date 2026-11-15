# App icon brief v2 — Petrichor (Fluent 2 redesign)

All platform requirements, deliverables, acceptance checks and red lines of `docs/design/icon/brief.md` still apply.
Only the creative direction changes. Output folder: `docs/design/icon/v2/<your-name>/`.

## User feedback on round 1
All five round-1 concepts (`docs/design/icon/icon-*-opus/`) look **dated / old-fashioned**.
Do not reuse their style: no flat clip-art drop, no skeuomorphic landscape, no thin-line radar scope, no plain letter mark.

## Required motif
Combine all three: **cloud + rain + radar echo** (radar reflectivity blob / sweep / colour bands)
into ONE unified form, not three icons placed side by side.

## Required style: Microsoft Fluent 2 app-icon language
Reference: the 2023+ Fluent-style Microsoft 365 / Windows 11 app icons. Traits to apply:
- Soft, rounded, friendly geometry; generous corner radii; few bold shapes (2–4 major forms).
- Layered, overlapping, slightly translucent shapes that create depth by overlap and colour mixing.
- Smooth multi-stop gradients (linear and radial) inside each shape; vibrant but not neon.
- Subtle soft lighting: a top-left key light, gentle inner highlights, soft contact shadow under layers.
- Modern palette anchored on the app's Fluent brand blue ramp (`docs/design/tokens-fluent2-light.css`,
  `--color-brand-*`) and the app's radar dBZ colours (`--dbz-*` in the same file, `lib/core/theme/app_tokens.dart`),
  extended with fresh cyan / teal / violet accents as needed.
- Light, clean background (white/very light tint or a soft brand gradient); not dark and murky.
- No outlines/strokes as the primary drawing technique; no text.

## Still required
Monochrome layer must remain a clean single-colour silhouette; legible at 16 px.
`concept.md` must state how the three motifs merge and which Fluent 2 traits were applied.
