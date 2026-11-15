# 雨量 page redesign — designer brief

Contract (frozen): `docs/logs/rainfall-page-contract.md`. Read it first.

## Cards (in this order, all shown directly, no tabs)
1. 最近測站 — the nearest rain gauge to the current place: name, distance, today mm, past 1h / 3h, warning level (thresholds 80/200/350/500 mm in `lib/features/hazard/rainfall/rainfall_logic.dart`).
2. 未來1hr預測 — map overlay of the 1-hour forecast grid (4 buckets) + the value at the current place + legend + issue time.
3. 小時累積雨量 — map overlay, past 1 hour accumulation, frames every 30 min with a time slider / playback (like the radar tab), legend, observation time.
4. 日累積雨量 — map overlay, today's accumulation since 00:00, frames every 30 min with playback, legend (17-colour CWA scale `AppPalette.rainfallMapScale`, `lib/core/theme/app_tokens.dart:151`), observation time.
5. 測站今日累積雨量 — list of stations with today's mm (currently `station_list.dart`), at the bottom.
States to show: loading, error, no API key (go to 設定), no place / location denied, no rain (all values 0).

## Current code to read
- Page: `lib/features/hazard/rainfall_screen.dart`, `lib/features/hazard/rainfall/*.dart`.
- Map widget shared with radar: `lib/features/radar/widgets/radar_map_view.dart`; playback UI `lib/features/radar/widgets/playback_card.dart`; radar page `lib/features/radar/radar_screen.dart`.
- Shared widgets: `lib/core/widgets/`. Tokens: `lib/core/theme/app_tokens.dart`. Adaptive layout rules: `docs/design/adaptive/hazard.md`, `docs/design/adaptive/system.md`.
- Format precedent: `docs/design/settings/designer-1/settings.html` and `settings.md`.

## Deliverable per designer
- `docs/design/rainfall/<your name>/rainfall.html`: links `../../tokens-fluent2-light.css` and `../../components.css`; page CSS in one `<style>` using only `var(--*)` tokens; light theme only; phone frame 375px plus a wide frame (≥1024px) showing the adaptive layout; extra frames for the states above; inline SVG only; Traditional Chinese, realistic Taiwan data. Map areas can be a static placeholder (grey box with a drawn Taiwan outline and coloured blobs) — no external tiles.
- `docs/design/rainfall/<your name>/rainfall.md`: card-by-card spec mapped to real widgets in `lib/core/widgets` and existing feature widgets (RadarMapView, playback card). Justify any new component. State how three map cards avoid being heavy (e.g. shared playback, lazy map, one map per card vs. others) and how the page scrolls with maps inside (gesture conflict).

## Directions (one per designer, so the proposals differ)
- designer-1: stacked full-width cards, each map card with its own compact map and its own inline playback.
- designer-2: map cards share a single time cursor (one playback control drives 小時累積 and 日累積 together); compact maps.
- designer-3: wide-first adaptive grid — 2–3 columns on wide screens, maps in a row; phone stacks.
- designer-4: glanceable — summary numbers first, maps collapsed to tappable thumbnails that open a full map view with playback.
