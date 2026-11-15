# 天氣 tab — 定稿候選 v1 / v2

Mockups: `home-v1.html`, `home-v2.html` (same folder). Contract: `docs/logs/home-page-contract.md`. Inputs: `designer-{1..4}/home.md`, `arch-solar.md`, `arch-forecast.md`, `arch-warnings.md`.
Each file has phone 375 px frames A 白天＋生效中警特報 · B 夜間＋無警特報 · C 載入中 · D 錯誤 · E 沒有 API 授權碼 · F 沒有地點／定位被拒, plus one wide 1280 px frame (白天＋警特報). The 7日, 72小時 and 警特報 blocks are the existing widgets, copied unchanged from designer-1's mockup.

## 1. Differences between v1 and v2

| Topic | v1 「太陽弧為主角」 | v2 「精簡」 |
|---|---|---|
| Sun arc | Large dome across the card top (view 320 × 200, max 360 wide). Temperature sits inside the dome. | Thin strip beside the temperature (view 184 × 92, max 240 wide). |
| Current weather on the arc | One pill = weather glyph + 仰角 (e.g. 「33°」), rides the sun position. | Glyph in a small disc at the sun position; 「仰角 33°」 label under it. |
| 過中天 mark | Label row above the apex: 「過中天 11:39 · 最高 47°」. | Label under the apex: 「過中天 11:39 · 47°」. |
| Tiles | Two labelled groups: 「體感與環境」 (體感 / 濕度 / 風向 / 降雨機率) and 「太陽」 (曙光 / 日出 / 日落 / 暮光) with meta 「今天 · 白晝 10 小時 54 分」. Next sun event = brand-subtle tile; passed events = muted value. | One dense 4 × 2 strip, no group labels, no next/past highlight. Row 1 comfort, row 2 sun. |
| Notes | 天氣建議 + 日照 in one bordered list (two rows, divider). | Two separate notes stacked with a gap. |
| Pull hint | Idle 「下拉即可重新整理」 kept. | Idle hint removed (app bar has 重新整理); loading pill kept. |
| Card height at 375 (estimate) | ≈ 560 px | ≈ 400 px |
| Wide (≥ 3 grid columns) | Now card full width (arc left, groups + notes right); row 2: 7日 (2 parts) \| 72小時 (3 parts); 警特報 full width at the bottom, summary and cards in 2 columns. | Designer-3 dashboard: left 2 columns = now \| 7日 on top, 72小時 spanning below; right column = 警特報 from the top. Jump badge hidden on wide (the section is on screen). |
| Phone warnings | Bottom of page. | Bottom of page. |

Same in both: page order now → 7日 → 72小時 → 警特報; all states; data; decisions in §3 and §4.

## 2. What came from which designer

| Element | v1 | v2 |
|---|---|---|
| Arc geometry, glyph+elevation pill, reserved 過中天 label row, night arc depth | designer-1 | — |
| Thin arc strip beside temperature, dense 4 × 2 tiles, removed idle pull hint | — | designer-2 |
| Tile groups 「體感與環境 / 太陽」, next-event highlight, 白晝 in the group meta, notes as one list | designer-4 | — |
| Wide dashboard (now \| 7日, 72小時 spanning, 警特報 side column on wide, bottom on phone; badge only below 3 columns) | — | designer-3 |
| Wide layout (now full, 7日 \| 72小時, warnings full) | designer-1 | — |
| Night glyph = moon (sun → moon, partly → moon-partly) | designer-1/2/3 | designer-1/2/3 |
| 「明天」 sun times after dusk | designer-4 (adapted, §4) | designer-4 (adapted, §4) |
| Sun error inline in the card, observation kept | designer-1/4, `arch-solar.md` §5 | same |
| Page-level single ApiKeyNotice | designer-1/2/3/4 (all proposed it) | same |
| Jump badge in the now-card eyebrow (marked 「可選」) | designer-1/2/3/4 | same |
| 7日 / 72小時 / WarningsSection markup | designer-1 copy of current widgets | same |

## 3. Widget mapping summary

| Block | Widget | Change |
|---|---|---|
| Now card shell | `AppCard(hero: true)` | new `NowCard` (`features/weather/widgets/now_card.dart`) replaces `HeroCard` + `SunCard`; both files deleted |
| Arc | `CustomPaint` painter in `now_card.dart` (reuses `dashedPath`, `paintLabel` from `chart_paint.dart`); labels painted unscaled | v1: dome + pill; v2: thin strip + disc |
| Weather glyph on the arc | `WeatherGlyphIcon` with new `night` flag | sun → moon, partly → moon-partly at night (now card only) |
| Tiles | `MetricGrid(columns: 4)` + `MetricTile(dense: true)` (optional params, default unchanged) | v1 adds a private `_TileGroup` (label row + grid) and optional `MetricTile.tone {normal, next, past}` |
| 天氣建議 note | the existing `HeroCard._summary` strip, promoted to one shared note widget (`AppNote`/`NoteCallout`, `core/widgets/status.dart`), tone rain | text = `slot.description` verbatim |
| Sun-status note | same note widget, tone neutral (bg-1 + stroke-3, brand icon; sun icon by day, moon at night) | text = `SunNow.note(now)` (`arch-solar.md` §3.3) |
| 仰角 | `solarElevationDegrees` computed on device (`arch-solar.md` §3.2/§4.1) | — |
| 過中天 time + noon elevation | CWA `A-B0062-001` `SunTransitTime` / `SunTransitAlt` | — |
| 7日預報 | `WeeklyCard` | unchanged; now before 72小時 |
| 未來72小時預報 | `Forecast72hCard` | unchanged; separate card (`arch-forecast.md` option A: 3-hour slots vs daily rows, different datasets and failures) |
| 警特報 | one shared `WarningsSection` (`arch-warnings.md` §3), at the page bottom (v2 wide: side column) | home top banner `_warningEntry` deleted |
| Jump badge (可選) | `AppBadge(alert tone)` in `InkWell` → `Scrollable.ensureVisible(warningsKey)` | only when the county has an active warning |
| No API key | one `ApiKeyNotice` + `EmptyState` from `WeatherScreen` when any dataset fails with `apiKeyIssue` | replaces per-card notices |
| No place / denied | `_NoPlaceGuide` | unchanged |
| Navigation | bottom nav / rail with 4 tabs 天氣 · 雷達 · 雨量 · 設定 | 警特報 tab removed (`arch-warnings.md` option B) — pending, §4 |
| Wide layout | v1: `_CardFlow` [now], [7日 \| 72小時], [警特報]; v2: `_HomeFlow` from designer-3 | `_EqualHeightPair` deleted in both |

Decisions settled in this merge:
- **Night arc direction**: the marker moves **right → left** (west → under the horizon → east) on a shallow arc below the horizon, from sunset to the next sunrise. Elapsed part is solid, the rest dashed; the day dome is dashed. Reason: it continues the day path (east → west) into one loop, so the marker never jumps; it is also the physical direction. Before sunrise the same arc uses yesterday's sunset (`arch-solar.md` §4.2).
- **Sun tiles after sunset**: between sunset and 暮光 the tiles keep today's times (暮光 is still ahead). After 暮光 ends, the whole sun row switches to **tomorrow's** four times, so the row always shows the next solar day and never mixes two dates. v1 shows 「明天 11/16」 in the 太陽 group meta and highlights 日出 as next; v2 prefixes each label with 「明天」 (4 characters fit a 54 px tile). Before sunrise the row shows today, which is the coming day. The sun note keeps the countdown 「距明天日出 8 小時 36 分」.
- **Removed vs today**: tomorrow's sunrise/sunset divider line and the 降雨機率 badge in the hero eyebrow (duplicates). v2 also drops 白晝長度; v1 keeps it in the 太陽 group meta.

## 4. Open decisions for the user

1. **Pick v1 or v2.** v1: the sun arc is the visual centre, tiles grouped and the next sun event highlighted; taller card. v2: smallest page height, dashboard layout on wide screens; less emphasis on the arc.
2. **Remove the 警特報 tab (bottom nav with 4 tabs)?** Both mockups show 4 tabs (`arch-warnings.md` option B: the home bottom section becomes the only warnings view). If you keep the tab (option A), the tab and the home page embed the same `WarningsSection`; nothing else on the home page changes.
3. **Keep the jump badge?** The small 「大雨特報 ⌄」 badge at the top of the now card (dashed box 「可選」 in the mockups) scrolls to the warnings section. It shows no warning content, only a pointer. Reason to keep: on a phone the warnings are about 3 screens down. Reason to drop: the contract says the warnings block moves to the bottom. Deleting it changes nothing else.
4. **Wind unit**: tiles show Beaufort 級 (「東北3級」, fits the tile); the 72小時 chart still shows m/s. Accept two units, or change the chart too.
5. Sample data is realistic but invented (Taipei / Taichung, 2026-11-15); elevations 33° and −61° were checked with the NOAA formula by hand (±1°).
