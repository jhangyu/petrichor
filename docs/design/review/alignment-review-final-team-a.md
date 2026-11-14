# Alignment review — final, Team A (5 pages)

Scope: `team-a/{home,radar,rainfall,warnings,location}.html`, including the latest changes: home 「日出日落」 card and reworked 「未來 72 小時預報」 card, bottom nav order, radar 「播放設定」, and the single 「資料來源」 line per page.
The reviewer did not design these pages and did not review rounds 1–4. Every number below was measured.

## Method

- Instrument: `measure.mjs`, `probe.mjs` and `sum.mjs` copied from `.claude/tmp/rv-align4/`; `ps.js` copied from `.claude/tmp/rv-align3/`. The only change is in `measure.mjs`: it takes its widths from an environment variable (default 320, 375, 1280). Headless Chrome over raw CDP with `Emulation.setDeviceMetricsOverride`. Measured `innerWidth` was 320, 375 and 1280 for every file.
- Scratch folder: `.claude/tmp/rv-final-a/`. Every `*.log` and digest ends with a self-captured `RC=0`.
  - `run.log`, `raw.json`, `sum.txt`: full scan of all 5 files × 3 widths.
  - `pa.js` → `pa_*.json`, `pasum.txt`, `chrome.txt`: app bar, page, bottom nav, source-credit lines for every frame.
  - `phome.js` → `ph_*.json`: sunrise/sunset card and 72-hour card.
  - `ps.js` → `ps_*.json`, `ps_sum.txt`: radar playback settings.
  - `p320.js`: playback-settings header line boxes.
  - `pwrap.js` → `pw_*.json`, `pw_diff.txt`: text that wraps onto more lines at 320 or 1280 than at 375.
  - `pm.js` → `pm_*.json`: metric tiles and headers.
  - `grep.log`: greps plus a canary that proves both patterns can fire.
- Snapshot: the files changed during the review (home.html saved at 21:35:37). The final run was bracketed by `hash_before.txt` (21:38:16) and `hash_after.txt`. The sha1 hashes of the 5 pages, `components.css` and the tokens file are identical (`diff` RC=0). All numbers below come from that snapshot. After the lead declared home.html SETTLED (sha ab7cdd12…, the same as above), the home probes were run again (`psun.js` → `psun_*.json`; `phome.js`; full scan `raw_home.json`, `run_home_sum.txt`). They were bracketed by `hash_home_before.txt` (21:41:00) and `hash_home_after.txt`: hashes identical, `diff` RC=0.
- x values are measured from the left edge of the phone frame (`.app-shell`). At 1280 the frame has a 1px border, so content values there are +1.

## Global results

| Check | 320 | 375 | 1280 |
|---|---|---|---|
| Horizontal scroll (document `scrollWidth`) | 320 = 320, all files | 375 = 375 | 1280 = 1280 |
| Elements outside the page or the frame | 0 | 0 | 0 |
| Clipped text (`scrollWidth > clientWidth`) | 0 | 0 | 0 |
| Frame rows centred (left gap − right gap) | 0 | 0 | 0 |
| Off-grid spacing | only `margin-*: auto` results (`.fc72__hint`, `.page-source`) and the old `.fab` UA padding 1px 6px | same | same |
| Bottom nav order home, radar, rainfall, warnings, location; exactly 1 current item = this page | 30/30 frames | 30/30 | 30/30 |
| Dark-theme grep over `docs/design`, excluding `contract.md` | **0 hits** (RC=1; canary RC=0) | | |
| Hex / `rgb()` / `hsl()` literals in the 5 pages | **0 hits** (RC=1; canary RC=0) | | |

Team chrome is identical in all 30 frames at each width (one distinct signature per width, `chrome.txt`):
- App bar: 56 high, top 1, title x = 16 (17 at 1280).
- Page: top 57, padding 8 / 16 / 24, gap 16.
- Bottom nav: 73 high. Item x/width: 4 / 62.4 (320), 4 / 73.4 (375), 5 / 73 (1280). Icon centre offset ≤ 0.01.
- Exception: the location 「選擇地點」 subpage has a back button and its title at x = 52. This is intended.

## Source credit (「資料來源」)

Every credit line is a direct child of `.page` and is the last block before the bottom nav. No credit line is inside a card or a map. No frame has more than one credit line.
Credit lines per frame:

| Page | Frames with a credit | Frames without a credit |
|---|---|---|
| home | ① loaded, ⑤ permission denied (shows the default location's data) | ② loading, ③ error, ④ no data |
| radar | all 7, including ③ loading, ④ timeout, ⑤ no API key | — |
| rainfall | all 6, including ③ loading, ④ timeout, ⑤ empty, ⑥ no permission | — |
| warnings | default, my county, empty (「目前無警特報」) | loading, error |
| location | authorised + saved places, permission denied + default place | intro, manual selection, permanently denied, locating, location failed |

Every credit line is centred (text centre offset ≤ 0.01), 12/16 type, fg-3 colour, 16 in from both edges, and 1–3 lines long.

## Per-file findings

### team-a/home.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| H-1 | `.sun__arc .sun__end` vs `.sun__time` columns | all 3 | Arc end dots sit on the 日出 / 日落 column centres: dx 0.01 / 0.01 (320), 0.01 / 0.02 (375), 0.01 / 0.01 (1280). The arc centre sits on the middle column: dx 0.01. The second row (民用曙光 / 過中天 / 民用暮光) uses the same 3 column centres (dx ≤ 0.01). All labels and values are on 1 line. | pass | none |
| H-2 | `.sun__now` (現在 marker) | all | (204.1, 33.6) is on the ellipse (normalised 1.00). Its angle fraction is 0.72, which equals the daylight fraction for 14:00 between 06:10 and 17:07 (0.72). The done / remaining paths meet at the marker. | pass | none |
| H-2a | `.sun__twi` (曙光 / 暮光 points), `.sun__transit` (過中天 point) vs the second text row | all | All 7 arc points (2 twilight, 2 rise/set ends, transit, now) are on the same ellipse (normalised 1.00). The twilight dots sit 8–10px below the horizon, on the continuation of the arc. Their x is 0.54 / −0.53 px (320) and 0.65 / −0.64 px (375, 1280) from the 曙光 / 暮光 column centres, because the arc continues below the horizon. The transit dot is 0.16–0.21 px from the 過中天 column centre (11:38 is 0.2 viewBox units before the apex). | pass (sub-pixel) | none |
| H-2b | `.sun__arc-label` 「11:38 · 仰角 47°」 | all | Centred under the transit dot (dx 0) with a 3.2–4.1 gap. 12.5 (320) / 15.2 (375) clear of the 現在 marker, no overlap, fully inside the SVG. The SVG scales with the card, so this 10px caption renders at about 8.9px at 320 (scale 0.89). | nit | Optional: keep the label outside the scaled SVG, or accept it. |
| H-2c | `.sun` clipping | all | 0 clipped nodes in the card (`scrollWidth` check); SVG bottom → first label 8; lowest twilight dot → label 11.4–12.1. Labels read 曙光 / 暮光 (rename present in the snapshot). | pass | none |
| H-3 | `.sun` stack | all | Gaps 16 / 8 / 8 / 16 / 16 (the 8 comes from `margin-top: -8px` after the 16 gap). Title x = 32, the same as every other card. 「現在 14:00 …」 is centred (offset 0, icon centre 0). | pass | none |
| H-4 | `.sun__tomorrow` | all | The line is left-aligned at x = 32 (`text-align: start`). Everything above it in the card is centred. It sits below a divider, so it reads as a footer. | nit | Centre it, or leave it as a footer. |
| H-5 | `.sun__value--sub` 「10 小時 57 分」 | 320 | Text 84.0 in an 85.3 column (1.3 slack). `white-space: nowrap`, so a narrower screen would overflow, not wrap. | nit | none at ≥ 320 |
| H-6 | `.fc72` columns: `.fc-t--slot` / `.fc-icon` / `.fc-track` / `.fc-t--pop` / `.fc-t--wind` ×2 | all | One x per column: max spread 0.02 over 24 columns, pitch 48. The round-4 blocker R4-1 is resolved. The neighbour gaps between labels are ≥ 14.9 (slot), 26.9 (%) and 22.3 (wind). No text overlaps. | pass | none |
| H-7 | `.fc72__stat` tiles | all | All 3 tiles are 78 high with every line single (1/1/1). Widths: 80 (320), 98.33 (375), 97.66 (1280). The label is now 「降雨機率」. The round-4 blocker R4-2 is resolved. | pass | none |
| H-8 | `.fc72__axis` row labels (label centre − row centre) | all | 時段 0; 天氣 −0.67; 體感 +0.5 (vs the 體感 numbers); 風 +0.5 (vs the wind pair); 降雨 0 vs the bar track (−15.75 if the % text under the bar is counted too). 溫度 −9 vs the band from the top dot to the bottom label (the label sits near the middle of the temperature curve, which has no fixed row). The time-tick row (「15時」, y = 193.5) has no row label. | nit | Optional: set 溫度 y to 141. Treat the tick row as the axis of the temperature chart. |
| H-9 | `.fc-t--temp`, `.fc-t--at`, `.fc-t--tick` vs points | all | 25 points: temperature, apparent temperature, tick label and tick line all have dx 0. The day dividers (x = 192 / 576 / 960) cross 「0時」 and the two temperature labels, but a 4px `bg-1` halo (`paint-order: stroke`) masks the line behind the text. The round-4 should-fix R4-3 is resolved. | pass | none |
| H-10 | `.fc-now` | all | 現在 line at x = 34.7 = 14:10 (16 px per hour from the 14:00 point at x = 32). The sun card and the 72h header say 14:00. The line is 21.3 left of the first bar, so it does not cut a bar or text. | nit | Use x = 32 for 14:00, or make the stated times agree. |
| H-11 | `.metric-grid > .metric` 「風速 · 東北風」 | 320 | The label wraps to 2 lines, and the grid row becomes 70 high (the other row is 54). Both tiles in the row stay equal. Fits at 375 and 1280. | should-fix (320 only) | Shorten to 「風速」 and move the direction into the value, or use `white-space: nowrap` with an ellipsis. |
| H-12 | `.card--hero.hero` | all | Content x = 36 vs 32 in `.card--a` (round 2 A2-R3, carried, team-wide). | should-fix (carried) | as A2-R3 |

### team-a/radar.html — verdict: **pass** (0 blockers; see R-1)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| R-1 | `.pb-settings__summary` → `.pb-settings__title`, `.pb-settings__state` | **320** | The title 「播放設定」 breaks into 3 line boxes, 40 high (「播放」/「設定」 beside the icon). The state 「4 小時 · 4 fps · 重複」 breaks into 2 lines, 32 high. The 44px row does not grow and nothing is clipped, but both texts in this one-line header are broken. Both fit at 375 (20 / 16 high, 0px slack on the state) and at 1280. | should-fix (320 is outside contract condition 6; raise to blocker if 320 support is required) | `.pb-settings__title { white-space: nowrap; flex: none; }` and `.pb-settings__state { min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }`, or show only 「4 小時 · 4 fps」 in the state. |
| R-2 | `.chip` ×6, `.segmented__item` ×3 | all | Text centre dx 0 / dy 0. Height 32. No clipping. Gaps 8 (chips) and 4 (segments). The segments are equal: 71.3 (320), 89.7 (375), 89 (1280). | pass | none |
| R-3 | `.pb-field__label`, `.map-hint`, chips, segmented track, switch row | all | Shared left edge 45 (46 at 1280). Right edges: switch = segmented = 275 (320), 330 (375), 329 (1280). Switch 40×24 with centre offset 0. Thumb centred, inset 4. | pass | none |
| R-4 | `.chip-group` wrapping | all | 3 + 3 (320, 1280), 4 + 2 (375). Content-sized chips (64.9 / 65.3 / 72.7), so the two rows do not form columns (round 3 A3-3, carried). | nit | 3-column grid |
| R-5 | `.page-foot` on ③ loading, ④ timeout, ⑤ no API key | all | A credit line with the dataset list appears even though no radar image is shown. Frame ⑤ has never loaded any data. home, warnings and location show no credit on loading or error frames. | should-fix | One team rule: credit only on frames that show data. Remove it from ③④⑤, or add it to the loading/error frames of the other pages. |
| R-6 | `.map-fabs > button.fab` | all | UA padding 1px 6px (round 2 A2-R4, carried) | nit | `.fab { padding: var(--space-0); }` |
| R-7 | `.card--outline` | all | Content x = 33 (1px border) vs 32 | nit | none |

### team-a/rainfall.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| F-1 | `.page-foot` on ③ loading, ④ timeout, ⑤ empty, ⑥ no permission | all | Same rule difference as R-5. | should-fix | as R-5 |
| F-2 | `.page-foot` vs `.page-source` (placement) | all | rainfall, radar and home use `.page-foot`, which follows the content, so the gap to the nav varies: rainfall ④ 315, ⑥ 243, ③ 147 (375). warnings and location use `.page-source` with `margin-top: auto`, which pins the line 24 above the nav in every frame. On short frames the same line sits in a different place depending on the page. There are two class names for one element. | should-fix (team consistency) | One class in one place, e.g. `.page-foot { margin-top: auto; }` on all 5 pages, or drop the `auto` on warnings and location. |
| F-3 | `.metric__value` 「113.5 mm」 | 320 | The value breaks between 「113.5」 and 「mm」, and the tile row becomes 74 high. | should-fix (320 only) | `white-space: nowrap` on `.metric__value` |
| F-4 | `.card__header` 「未來 1 小時雨量」 + meta 「14:00 – 15:00 · 網格」 | 320 | Title 2 lines (56 high), meta 2 lines. One line each at 375 and 1280. | should-fix (320 only) | Let the meta wrap under the title (`flex-wrap: wrap`), or shorten the meta. |
| F-5 | `.hero` | all | Content x = 36 vs 32 (round 2 A2-F3, carried) | should-fix (carried) | as A2-R3 |

### team-a/warnings.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| W-1 | `.page-source` | all | One credit line on the 3 data frames (including the empty result). None on loading or error. Centred, pinned 24 above the nav. | pass for this page; see F-2 for the cross-page difference | as F-2 |
| W-2 | `section.card--hero.hero` | all | 1px border, so content x = 37 vs 36 on the home hero (round 2 A2-W1, carried) | should-fix (carried) | as A2-W1 |
| W-3 | gallery scaffold `.frame-col` / `.frame-cap` | 1280 | Frame pitch 399 (24 gap) vs 407 (32 gap) on home, radar and rainfall, which use `figure.frame` / `figcaption`. This is outside the phone frame. | nit | Use the home gallery markup. |

### team-a/location.html — verdict: **pass** (0 blockers)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| L-1 | `.page-source` | all | One credit line on the 2 frames that show observation data. None on the 5 frames without data. | pass; see F-2 | as F-2 |
| L-2 | `.loc-hero__name` 「臺北市 信義區」 | 320 | Wraps to 2 lines (box 116 wide, 64 high); the hero grows from 134 to 166. | should-fix (320 only) | `white-space: nowrap` with an ellipsis, or put the temperature block below the name at narrow widths. |
| L-3 | `.card--hero.intro`, `.loc-hero` | all | 1px border, content x = 37 (round 2 A2-L1, carried) | should-fix (carried) | as A2-L1 |
| L-4 | gallery scaffold | 1280 | Same as W-3 | nit | as W-3 |

## Summary

| File | Blockers | Verdict |
|---|---|---|
| team-a/home.html | 0 | pass |
| team-a/radar.html | 0 | pass |
| team-a/rainfall.html | 0 | pass |
| team-a/warnings.html | 0 | pass |
| team-a/location.html | 0 | pass |

**Verdict: pass.** Contract conditions 2 (dark grep 0), 5 (blocker 0) and 6 (no horizontal scroll at 375 / 1280; also none at 320) hold. Condition 1 also holds: no colour literals.
Both round-4 blockers on home (R4-1 columns, R4-2 tile wrap) and the should-fix R4-3 (divider strike-through) are resolved.

Should-fix items, in order of visibility:
1. Radar 播放設定 header breaks into multiple lines at 320 (R-1). This is the only broken text inside a control. If the team must support 320px phones, raise it to a blocker.
2. Credit-line placement differs by page: it follows the content on home, radar and rainfall, and is pinned above the nav on warnings and location. There are two class names (F-2).
3. Credit lines on loading/error frames appear only on radar and rainfall (R-5, F-1).
4. 320-only wraps: home wind label (H-11), rainfall 「113.5 mm」 (F-3), rainfall forecast card header (F-4), location place name (L-2).
5. Carried from earlier rounds: hero 1px border on warnings and location; hero inset 36 vs card 32.

## Limits

- 320 is not in contract condition 6. Items found only at 320 are rated should-fix. R-1 is flagged for a decision.
- Wrap detection (`pw_diff.txt`) compares line counts with 375. Text that already wraps at 375 is not flagged; at 375 all such text is body copy.
- Data realism and feature coverage (contract condition 3) were not reviewed.
