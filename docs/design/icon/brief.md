# App icon brief — Petrichor

## App
Petrichor is a Flutter weather app for Taiwan built on Central Weather Administration (CWA) open data.
Features: current conditions and forecasts for the user's location, 24h / weekly forecast, weather radar
(animated radar images), rainfall observation map, weather warnings, location management, settings (API key).
Name meaning: "petrichor" = the earthy smell of rain falling on dry ground. Mood: calm, precise, rain-centric.
Context files (read-only): `docs/design/brief.md`, `docs/design/preflight/page-inventory.md`, `docs/design/adaptive/system.md`.

## Goal
Five designers each produce one independent icon concept. The user picks one later.
Do NOT read other designers' folders; independence is the point.

## Platform compatibility (hard requirements)
One master artwork must survive every platform mask:
- **Android adaptive icon (Material 3)**: 108×108 dp canvas, separate `background` and `foreground` layers.
  All essential content inside the 66 dp diameter safe-zone circle (centered). Launchers mask with
  circle, squircle, rounded square, and Material 3 shapes (e.g. circle, square, rounded square, pill,
  arch, slanted, cookie/scalloped, clover, flower, sunny, gem, pentagon). Launchers may also parallax
  the layers by up to 18 dp, so the background must be full-bleed and content-free at edges.
- **Android 13+ themed icon**: single-color `monochrome` layer (alpha only), same safe zone.
- **iOS / iPadOS**: 1024×1024 full-bleed square, no transparency, no pre-applied corner radius
  (the system applies the continuous-corner squircle). Also provide dark and tinted variants
  (iOS 18+: dark = transparent-friendly foreground on dark bg; tinted = grayscale foreground).
- **macOS**: 1024×1024 canvas with the Big Sur+ icon grid: rounded-rect (continuous corner) body
  824×824 centered, corner radius ≈ 185, with a subtle drop shadow baked in, transparent outside.
- **Small size**: must read at 16, 29, 32, 48 px (favicon, Windows taskbar, settings rows).

## Deliverables (per designer, in `docs/design/icon/<your-name>/`)
1. `foreground.svg`, `background.svg`, `monochrome.svg` — 108×108 viewBox (Android layers).
2. `ios-light.svg`, `ios-dark.svg`, `ios-tinted.svg` — 1024×1024 full-bleed.
3. `macos.svg` — 1024×1024 with the 824 body, radius, and shadow.
4. `preview.html` — self-contained (inline SVG only, no external resources except Google Fonts),
   showing the master icon under ALL of: circle, squircle, rounded square, square, and at least
   6 Material 3 shapes; the 66 dp safe-zone overlay toggle; themed monochrome on light and dark
   wallpaper; iOS light / dark / tinted; macOS on light and dark desktop; and a small-size strip
   at 16 / 29 / 32 / 48 / 64 px.
5. `concept.md` — ≤ 30 lines: concept and metaphor, palette (hex), construction grid, why it
   survives each mask, known weaknesses.

All artwork pure SVG (paths, shapes, gradients, filters). No raster, no text glyphs that depend on fonts
(convert letterforms to paths). No external image generation required; you may use the design skills
`frontend-design:frontend-design`, `ui-ux-pro-max:design`, `ui-ux-pro-max:design-system`,
`logo-design`, `svg-logo-craft` for guidance only.

## Acceptance (mechanical)
- All 9 files above exist in your folder; every `.svg` parses as XML (`xmllint --noout`).
- Android layer SVGs have `viewBox="0 0 108 108"`; iOS/macOS SVGs have `viewBox="0 0 1024 1024"`.
- `monochrome.svg` uses a single fill color.
- `preview.html` contains no `http` URL except `fonts.googleapis.com` / `fonts.gstatic.com`.

## Red lines
Write only inside your own folder. Do not touch `lib/`, `android/`, `ios/`, `macos/`, or any other file.
No git commands except read-only (`git status`, `git log`). Do not commit.
