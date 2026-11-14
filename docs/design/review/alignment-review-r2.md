# Alignment review — round 2 (7 revised mockups)

Scope: `team-a/{warnings,location,radar,rainfall}.html`, `team-b/{warnings,radar,rainfall}.html`. References (unchanged): `team-a/home.html`, `team-b/home.html`, `team-b/location.html`.
Reviewer did not design these files and did not do round 1. All numbers are measured.

## Method

- Same instrument as round 1: `.claude/tmp/rv-align2/measure.mjs` is a byte-identical copy (`cmp` RC=0) of the round-1 script that fired all 6 detectors on the round-1 canary page. Headless Chrome over raw CDP, viewport set with `Emulation.setDeviceMetricsOverride`; measured `innerWidth` = 375 and 1280 on every file.
- Full run over all 10 files (7 revised + 3 references) at both widths: `raw.json`, `run.log` ends `RC=0`; digest `sum.txt` (`RC=0`).
- Targeted probes (each log ends `RC=0`): `p3_*.json` (header divider, page top, tabs, bottom-nav item x/width/icon dx, active item), `p4_*.json` + `p6_*.json` (warning-row icon/chevron vs title first line, all rows; map overlay overlap; source credit position), `p5_*.json` + `p5_sum.txt` (frame width / content width / border, section heading and card title type and x, 「資料來源」 nodes, timestamps, text counts).
- Greps: `grep.log` (dark theme over `docs/design` excluding `contract.md`; colour literals in the 7 pages).
- All x values are relative to the phone frame (`.app-shell`) left edge.

## Global results (7 revised files)

| Check | 375 | 1280 |
|---|---|---|
| Horizontal scroll | 375 = 375 all | 1280 = 1280 all |
| Elements outside page / frame | 0 | 0 |
| Clipped text | 0 | 0 |
| Frame rows centred (left gap − right gap) | 0 px every row | 0 px every row |
| Off-centre children in centred columns | 0 | 0 |
| Numeric column edge mismatch | 0 | 0 |
| Bottom nav: 5 equal items, icon dx 0, active = current page | pass all | pass all |
| Dark-theme grep over `docs/design` excl. `contract.md` | **0 hits** (RC=1) | — |
| Hex / `rgb()` / `hsl()` literals in the 7 pages | 0 (RC=1) | — |

Team chrome vs the team's home (identical in every revised file, both widths):
- Team A: app bar 56px, padding 16/4, title 20/28/600, divider at y=57, page top 57, page padding-top 8 / gap 16, nav 73px, first nav item x=4 (375) / 5 (1280), item width 73.4 / 73.
- Team B: app bar 56px, title 20/28/600, header divider y=102, tabs 44px from x=5, page padding-top 8 / gap 16, nav 73px, item width 66.6 (375) / 73 (1280), first item x=5.

## Round-1 blocker status

| Round-1 id | File | Status | Evidence |
|---|---|---|---|
| B-W1 | team-b/warnings | **resolved** | All 8 `.wrow__head` rows, both widths: icon centre − title first-line centre = 0px, chevron − title = 0px (`p6_*.json`). Fix: `.wicon, .wrow__chev { margin-top: calc((body1-lh − control-sm)/2) }` = −6px. |
| A-W1 | team-a/warnings | **resolved (accepted, not a team inconsistency)** | see reasoning below |
| A-L1 | team-a/location | **resolved (accepted)** | see reasoning below |
| A-L2 | team-a/location | **resolved** | 「開啟步驟」 `.card.card--a > .card__title` 20px/28px, x=32 (375) / 33 (1280) — identical to home card titles (32 / 33). |
| A-W2 / A-L3 (frame width, should-fix in r1) | team-a/warnings, location | **resolved; designer's claim confirmed** | At 1280 every Team A file, home included: shell 375, border 1px each side, content (`clientWidth`) 373, app bar and nav 373 wide, page top 57, first nav item x=5. At 375: border-inline none, content 375 everywhere. home = warnings = location = radar = rainfall. The round-1 1px offset is gone; the 2px gap is the frame border and is the same on home. |

### Section headings (A-W1 / A-L1) — judgement

Measured: `.section__title` 「生效中」「臺北市」(warnings), 「我的地點」「縣市」「臺北市 · 鄉鎮市區」(location) = 20px / 28px / 600, header height 32, 8px to the content below, x=16 (375) / 17 (1280), outside any card. Home's only headings are `.card--a .card__title` = 20px / 28px / 600 at x=32 inside cards.

Verdict: acceptable, not a blocker.
- Type style is now identical to the home heading (size, line height, weight, colour). The round-1 mismatch was 16/22 vs 20/28; that is fixed.
- The x difference (16 vs 32) follows the content: the content under each heading is already a surface. `.warn` is a card (bg-1, radius-lg, shadow-4). `.list` in components.css is also a surface (bg-1, radius-md, shadow-2). Wrapping these in `.card.card--a` would put a surface inside a surface. The heading starts at the same x as the surfaces under it (`nextL` 16 = heading x 16), so the left edge is consistent.
- Home has no list-of-surfaces section, so there is no conflicting home pattern for this case. The team now has two clear rules: title inside a single card at x=32; heading above a stack of surfaces at x=16.
- Only exception: 「縣市」 sits above a chip scroller, which is not a surface. The heading still aligns with the chips (x=16), so this is fine.

## Per-file findings

### team-a/warnings.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| A2-W1 | `section.card--hero.hero` | both | 1px border still present (`borderTopWidth` 1px); content left 37 vs 36 on home / radar / rainfall hero (r1 A-W3, not fixed) | should-fix | remove the border, tint with background only, so hero content is at x=36 like home |
| A2-W2 | `.hero__count` (`align-items: baseline`) | both | number vs label centre spread 22px | nit (intended baseline of display number + label) | none |
| A2-W3 | `.warn` 3px left accent | both | unchanged from r1 A-W4 | nit | none |

### team-a/location.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| A2-L1 | `section.card--hero.intro` | both | 1px border; shadow is shadow-4 (`0 2px 4px`) vs shadow-8 (`0 4px 8px`) on home hero; content left 37 vs 36 (r1 A-L4, not fixed) | should-fix | one hero recipe: no border, `box-shadow: var(--shadow-8)` |
| A2-L2 | `div.field > input` | both | padding 1px 2px (UA default; r1 A-L5) | nit | `.field input { padding: var(--space-0); }` |

### team-a/radar.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| A2-R1 | `.map-credit` 「資料來源：中央氣象署」 | both | present on the 4 maps that show radar data (frames ①②⑥⑦); inside the map, right 8 / bottom 8, 10px caption2 token, no clipping, no overlap with `.map-chip`, `.map-fabs` or banners. Absent on the muted maps in ③ loading and ④ error (no radar image shown) | pass | none |
| A2-R2 | `.map-chip` frame timestamp | both | 11/14 14:00 (①⑥⑦), 11/14 13:10 (②); `.playback__timestamp` 14:00 / 13:10 | pass | none |
| A2-R3 | `.hero` vs `.card--a` content left | both | 36 vs 32 (r1 A-R1, not fixed; also on home) | should-fix (team-wide, home is the same) | `.hero { padding-inline: var(--space-16); }` on all Team A pages |
| A2-R4 | `.map-fabs > button.fab` | both | padding 1px 6px (UA default, r1 A-R2 / S2) | nit | `.fab { padding: var(--space-0); }` in components.css |
| A2-R5 | `.note` (`flex-start`), `.playback__time` (baseline) | both | spread 26 / 2px | nit (intended top / baseline alignment) | none |

### team-a/rainfall.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| A2-F1 | content | both | Tabs = 雨量觀測 / 降雨預測 only. 「24 小時」 appears once on screen, in the alert-threshold hint (24h accumulation), not as a forecast. Forecast card is 「未來 1 小時雨量」 with source F-B0046-001 | pass | none |
| A2-F2 | `.card__header--top` | both | title block vs badge / icon top-aligned, spread 56 / 34 | nit (intended, r1 A-F2) | none |
| A2-F3 | `.hero` content left 36 vs cards 32 | both | r1 A-F1, not fixed | should-fix (team-wide) | as A2-R3 |

### team-b/warnings.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| B2-W1 | `.wrow__head` icon / chevron | both | 0px offset from title first line in all 8 rows (blocker B-W1 resolved) | pass | none |
| B2-W2 | `.wicon`, `.wrow__chev` `margin-top: -6px` | both | not a 4px multiple; it is a centring offset computed from tokens (20 − 32)/2, not a spacing value | nit | none needed; or set `.wicon` height to body1-lh and drop the margin |
| B2-W3 | content | both | tabs = 生效中 / 我的縣市 (2 tabs, 164.5px each at 375); 「已解除」 0 occurrences in file | pass | none |
| B2-W4 | `.tb-frame` | 375 | frame 343 wide (16px side margin) instead of full-bleed 375; same on team-b home (r1 B-H1, not fixed, team-wide) | should-fix | as r1 B-H1 |

### team-b/radar.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| B2-R1 | `.map-foot` (timestamp left, 「資料來源：中央氣象署」 right) | both | present on all 5 maps incl. loading / error; left 8 / right 8 / bottom 8 from the map border box (+1px map border); no clipping; no overlap with other absolute overlays; `.map-foot ~ .map-banner` lifted to bottom 40 | pass | none |
| B2-R2 | frame timestamp | both | map-foot 11/14 14:00, 13:20, 13:30, 14:00, loading 「—」; `.playback__timestamp` 14:00 / 13:20 | pass | none |
| B2-R3 | second class family (`.app-bar--pivot` / `.page--dense` / `.group`) vs home `.tb-*` | both | visually identical (divider y=102, tabs x=5 × 44, nav identical); code-level split remains (r1 B-R1) | should-fix | rename to home classes |
| B2-R4 | `button.fab.map-fab` | both | padding 1px 6px (UA default) | nit | S2 |
| B2-R5 | `.tb-frame` 343 at 375 | 375 | r1 B-H1 | should-fix | as r1 B-H1 |

### team-b/rainfall.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| B2-F1 | content | both | tabs = 雨量觀測 / 降雨預測; 「24 小時」 only in the threshold note and legend label (24h accumulation); forecast = 1 h F-B0046-001 grid value + grid map | pass | none |
| B2-F2 | `.fc-value` (new 1-hour value row) | both | `align-items: center`; level dot centred (cy 16), `mm` unit `align-self: flex-end` + 4px padding (cy 22), spread 6px | nit (intended unit-at-baseline) | none |
| B2-F3 | second class family, frame 343 at 375 | — | r1 B-F1 / B-F3 | should-fix | as above |

## Summary

| File | Blockers | Verdict |
|---|---|---|
| team-a/warnings.html | 0 | pass |
| team-a/location.html | 0 | pass |
| team-a/radar.html | 0 | pass |
| team-a/rainfall.html | 0 | pass |
| team-b/warnings.html | 0 | pass |
| team-b/radar.html | 0 | pass |
| team-b/rainfall.html | 0 | pass |

All 4 round-1 blockers are resolved. Contract condition 5 (blocker = 0) is met for the 7 revised files; the 3 unchanged reference files had 0 blockers in round 1 and measure the same in this run. Conditions 2 and 6 pass. Remaining should-fix items are carried from round 1 (hero border / shadow, hero 20px inset, Team B 343px frame at 375, Team B duplicate class family).

## Parking-lot (out of contract, not severity-rated)

- Shared `components.css` defines `.card__title` and `.section__title` as subtitle2 (16/22); Team A overrides both to subtitle1 (20/28) page by page. One team-level override (or a `card--a` / section modifier in one place) would remove the copies.
- Team A radar shows no source credit on the loading and error maps; Team B shows it on every map. Both are within the user decision (credit shown where frames are shown); align if one rule is wanted.
- Feature coverage and data realism (contract condition 3) were not reviewed; only text presence/absence listed above.

## Round 3 (team-a/radar.html, team-b/radar.html — new 播放設定 section)

Method: same instrument (`measure.mjs`, `sum.mjs`, `probe.mjs` copied from `.claude/tmp/rv-align2/` to `.claude/tmp/rv-align3/`), CDP device emulation, `innerWidth` = 375 and 1280. Raw output with self-captured RC: `rv-align3/run.log` (RC=0), `sum.txt` (RC=0), `ps_375.json` / `ps_1280.json` + `ps_*.log` (RC=0), `grep.log`. New probe `ps.js` measures chips / segmented items / switch row / summary row. Section was expanded (`details[open]`) in the file as delivered.

Whole-page scan, both files, both widths: horizontal scroll none (375=375, 1280=1280), elements outside page 0, clipped text 0, frame rows centred (diff 0). Off-grid spacing: only the existing `.fab` UA padding (1px 6px, r2 nit). Dark-theme grep over `docs/design` excl. `contract.md`: 0 hits (RC=1).

Option parity (read from markup): both pages = look-back 1/2/4/6/12/24 (default 4 = 24 frames), speed 2/4/8 fps (default 4), repeat switch default on, helper 「播放結束後等待 3 秒再重播」. Same sets and defaults. Timeline: Team A 24 `.tl-frame` buttons; Team B slider `max=24`, value 24. Presentation differs by team (A: chips 「N 小時」 + 3-segment block; B: 6-segment numeric + kv header 「回看範圍（小時）」) — intended per-team design, not an inconsistency.

### team-a/radar.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| A3-1 | `.chip` ×6, `.segmented__item` ×3 | both | text centre offset dx 0 / dy 0 in all 9; no clipping, single-line; all heights 32 | pass | none |
| A3-2 | `.chip-group` gaps | both | column gap 8, row gap 8 (both 4-multiples); no off-grid spacing inside `.pb-settings` | pass | none |
| A3-3 | `.chip-group` wrap | 375 | wraps 4 + 2 (row 1 right edge 329 of 330); chip widths 64.9 / 65.3 / 72.7 (content-sized), so columns do not line up across the two rows | nit | `.chip-group` as 3-column grid, or accept ragged chips |
| A3-4 | `.chip-group` | 1280 | wraps 4 + 2 as well (container 283 wide) | nit | same |
| A3-5 | `.segmented--block` | both | 3 equal items (89.7 / 89), gap 4, track left 45 = right-aligned with chips (330) | pass | none |
| A3-6 | `.pb-field__label`, `.map-hint`, `.pb-toggle` content left | both | label / hint / chips / segmented track / switch row all left 45 (375) / 46 (1280); right edge 330 / 329 = switch right edge; box left 32 = card content left of other cards (32) | pass | none |
| A3-7 | `.pb-toggle` | both | row 44; switch 40×24 centre offset 0, text block centre offset 0; thumb 16 centred (offset 0), inset 4 / 4 | pass | none |
| A3-8 | `.pb-settings__summary` | both | 44 high, padding 0 12; icon 20 / title text centre offset 0, gap 8; state text vs chevron centre offsets 0 / −0.5 | pass | none |
| A3-9 | `.pb-settings` | 375 | box 32…343, no overflow | pass | none |

### team-b/radar.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| B3-1 | `.segmented--sm.seg-fill` ×2 | both | 6 items 46.8 (375) / 52.2 (1280) equal; 3 items 97.7 / 108.3 equal; gap 4; no clipping; no wrap (「12」「24」 fit) | pass | none |
| B3-2 | `.segmented__item.num` text | both | dx 0; dy −0.5 (sub-pixel CJK/number line box) | nit | none |
| B3-3 | `.kv` header / `.list-row` / segmented / switch | both | text left 17 for 「回看範圍（小時）」「播放速度」「重複播放」 and helper; value (`.kv__v`) right edge 326 = segmented right 326 = switch right 326 (375); 358 = 358 = 358 (1280) | pass | none |
| B3-4 | `label.list-row` (repeat) | both | padding 12 / 16, row 61; switch 40×20 centre offset +0.5 vs text block +0.5 (same offset, centred together); thumb 12 centred (translateY −50%), inset 5 / 5 incl. border | pass | none |
| B3-5 | spacing inside 播放設定 | both | off-grid values: none | pass | none |
| B3-6 | `.switch` size | — | Team B 40×20, Team A 40×24; each team defines its own and only this page has a switch, so no in-team inconsistency | nit (cross-team only) | none |
| B3-7 | overflow / frame | 375 | frame 343 at 375 (r1 B-H1, team-wide, unchanged); section box 1…342 inside it, no overflow | should-fix (carried) | as r1 B-H1 |

### Round 3 verdict

| File | Blockers | Verdict |
|---|---|---|
| team-a/radar.html | 0 | pass |
| team-b/radar.html | 0 | pass |

Contract condition 5 (blocker = 0) holds for both changed pages. Option sets and defaults identical in both. Dark-theme grep 0.

## Round 4 — team-a/home 72h

Scope: `team-a/home.html`, new 「未來 72 小時預報」 card (`section.card.card--a.fc72`). Reviewer did not design it and did not review it before. Instrument: same CDP probe as above (`probe.mjs`, `Emulation.setDeviceMetricsOverride`, `innerWidth` = 375 and 1280 confirmed). Scratch: `.claude/tmp/rv-align4/` — probes `p7.js` (columns, tiles, row labels, dividers), `p8.js` (temperature labels vs points, divider crossings), `p9.js` (tile text wrapping); outputs `p7_*.json`, `p8_*.json`, `p9_*.json`; every `*.log` ends `RC=0`; `grep.log` (dark-theme grep, zero hits). x values below are in chart (SVG) px, relative to the scrolling chart's left edge.

### team-a/home.html (72h card) — verdict: **fail** (2 blockers)
| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| R4-1 | `.fc-t--time` vs `.fc-icon` / `.fc-track` / `.fc-t--pop` / `.fc-t--wind` | both | Icon, PoP bar, % text and both wind lines share one x per column (max dx 0.02), but each time label sits **24px left** of its own column (15:00 label x=48, its icon/bar/text x=72; same for all 24 columns; max dx 24.02). Temperature points and labels sit on the time-label x (dx 0), so two axes coexist: instant (time, temperature) vs block centre (icon, PoP, wind). | **blocker** | Put one x per column. Move icons / bars / % / wind to x = 48 + 48k (the time-label and temperature-point x). Then shift the 現在 marker or the first column right so the line (x=34.7) does not cut the first bar (x 32–64). |
| R4-2 | `.fc72__stat-label` 「最大降雨機率」 | 1280 (phone frame has 1px borders, tile inner 71.7px) | Label needs 72px and wraps to 2 lines: tile height 94 vs 78 at 375; the third tile's value and sub-line are 16px lower than tiles 1 and 2. At 375 it fits with 0px slack (text 72, box 72). Tiles themselves are equal: widths 98.33 / 98.33 / 98.34 (375), 97.66 / 97.67 / 97.66 (1280); heights equal; gap 8; text left edge 13 in all three. Narrower than 375 will wrap as well (fails near 320). | **blocker** | Shorten to 「降雨機率」, or `.fc72__stat { padding-inline: var(--space-8) }` plus `white-space: nowrap` on the label. |
| R4-3 | `.fc-day` dividers (x=192, 576, 960) | both | Dashed 1px, colour rgb(209,209,209), drawn **behind** the text (z index 3, texts later). It passes through the centre of 「00:00」, and through the temperature label and apparent-temperature label at the same x (e.g. 23° / 24°). No text is hidden: glyph colour is rgb(97,97,97) or darker on top of a light dash. Reads as a strike-through. With R4-1 fixed, the time label leaves the line; the two temperature labels stay. | should-fix | Add `paint-order: stroke; stroke: var(--color-bg-1); stroke-width: 3` to `.fc-t--temp, .fc-t--at`, or break the line around them. |
| R4-4 | `.fc72__axis text` (row labels, label box centre vs row centre) | both | 時間 0; 風 0 (vs wind block centre); 體感 −1; 天氣 −1.5 (vs 24px icon tile centre y=56); 溫度 +2.5 (label 134.5 vs point band 108–156 centre 132); 降雨 +2.5 (label 238.5 vs bar 216–256 centre 236). | should-fix | y = 61.5 (天氣), 137.5 (溫度), 241.5 (降雨). The 4px grid for baselines is what causes the offset. |
| R4-5 | `.fc-t--temp`, `.fc-t--at` vs points | both | All 25 labels centred on their point: dx 0 (max). Label top is 1px below the dot box. Apparent-temperature labels at the same x: dx 0. No label sits on the apparent-temperature line (0 hits); all 34 dots on the polyline vertices (offset 0). | pass | none |
| R4-6 | `.fc72` card box | both | Left edge 16 (375) / 17 (1280), width 343 / 341: same as every other Team A card in the frame (hero, warning, 7 日). Card title left = source line left = summary tile left = 16. Header title/meta centre equal. Padding 16/16/20 (20 is a 4-multiple). Gaps: summary 8, summary→chart 16, chart→legend 16, legend 4/16. All multiples of 4. | pass | none |
| R4-7 | `.fc72__scroll`, page | both | Chart viewport 271 / 269 wide, content 1224: horizontal scroll inside the chart only. Document scrollWidth 375 / 1280 (no page overflow). No clipped text in the card; axis labels 24px in a 40px column. | pass | none |
| R4-8 | `.fc-t--wind` (東北 / 3 m/s) | both | The two line boxes overlap by 1px (280–295 vs 294–309). Glyphs do not touch. | nit | wind line 2 at y=308 or leave |
| R4-9 | `.fc72__legend` | both | Hint wraps to a second row (right edge 327 = content right edge). Key marks centred on text (0.5 px). Row gap 4. | pass | none |

Other checks: dark-theme grep over `docs/design` excluding `contract.md` — 0 hits (`grep.log`, RC=1). Colour literals in `home.html` — 0.

Round 4 verdict: **fail**, 2 blockers (R4-1, R4-2); contract condition 5 is not met for `team-a/home.html` until both are fixed. Should-fix: R4-3, R4-4.
