# 首頁 (天氣 tab) redesign — brief

Contract (frozen): `docs/logs/home-page-contract.md`. Read it first.

## Target page order
1. Merged now card: current weather on the sun arc (elevation mark + 過中天 time), temperature, stat tiles row(s): 體感 / 濕度 / 風向 / 降雨機率 / 日出 / 日落 / 曙光 / 暮光, notes: 天氣建議 + sun-status note ("現在 21:40，已日落，距明天日出 8 小時 12 分").
2. 7日預報.
3. 未來72小時預報 (or one merged forecast card, only if justified — see contract item 4).
4. 特警報 — at the bottom; the same component as the top-level 特警報 page.
States to show: loading, error, no API key (go to 設定), no place / location denied, night (sun below horizon), daytime, an active warning, no warnings.

## Current code to read
- Page: `lib/features/weather/weather_screen.dart`; cards in `lib/features/weather/widgets/` (hero_card, sun_card, weekly_card, forecast_72h_card, home_logic, chart_paint, weather_glyph_icon).
- Data: `lib/features/weather/weather_provider.dart`, `lib/data/repositories/weather_repository.dart`, `lib/data/models/weather_models.dart`.
- Warnings: `lib/features/hazard/warnings_screen.dart`, `lib/features/hazard/warnings/`, `lib/features/hazard/hazard_provider.dart`; tabs in `lib/app_shell.dart`.
- Shared widgets: `lib/core/widgets/`. Tokens: `lib/core/theme/app_tokens.dart`. Adaptive rules: `docs/design/adaptive/`.
- Code maps from the readers (appear during the round): `docs/design/home/code-*.md`.
- Format precedent: `docs/design/settings/designer-1/settings.html` and `settings.md`.

## Deliverable per designer
- `docs/design/home/<your name>/home.html`: links `../../tokens-fluent2-light.css` and `../../components.css`; page CSS in one `<style>` using only `var(--*)` tokens; light theme only; phone frame 375px plus a wide frame (≥1024px); extra frames for the states above; inline SVG only; Traditional Chinese; realistic Taiwan data.
- `docs/design/home/<your name>/home.md`: card-by-card spec mapped to real widgets in `lib/core/widgets` and the existing feature widgets; justify any new component; state the 7日/72小時 merge decision with reasons; how the sun arc stays readable at 375px.

## Directions (one per designer)
- designer-1: arc-as-hero — a large sun arc spans the card top, weather glyph rides the sun position; tiles in a 4-column grid below.
- designer-2: compact — a thin arc strip beside the temperature, tiles as a dense 2-row chip strip; minimum page height.
- designer-3: wide-first adaptive — on wide screens now card + forecasts side by side, warnings in a side column that drops to the bottom on phone.
- designer-4: information hierarchy — tiles grouped by meaning (comfort vs sun times), notes styled as one callout list; explore merging 7日 and 72小時 into one card with a day selector that expands into hourly detail.
