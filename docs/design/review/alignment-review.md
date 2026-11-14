# Alignment / centering / spacing review — Fluent 2 light mockups

Scope: 10 files (`team-a/*.html`, `team-b/*.html`), contract conditions 1, 2, 4, 5, 6.
Reviewer did not design these files. All numbers below are measured, not estimated.

## Method

- Headless Chrome (`--headless=new`) driven by raw CDP from Node 25 (`.claude/tmp/rv-align/measure.mjs`, `probe.mjs` + `p1..p4.js`).
- Viewport set with `Emulation.setDeviceMetricsOverride` (not the window size). Measured `innerWidth` = 375 and 1280 for every file — the "will not go below ~485px window" limit does not apply to this method.
- Per phone frame (`.app-shell`), via `getBoundingClientRect` + `getComputedStyle`: frame-row centering, vertical-centre spread of every no-wrap row flex/grid, icon-in-button centring, every padding/margin/gap value mod 4, left edges of card children vs card content box vs app-bar title, numeric column right/left-edge spread, text `scrollWidth > clientWidth`, elements leaving the frame or the page, and a style signature (app bar, title, tabs, section heading, card, bottom nav) for team comparison.
- Instrument check: a canary page with one injected violation per detector (5px padding, flex-start row, clipped text, 500px child, off-centre column child, misaligned number column). All 6 detectors fired (`canary.json`). So the zero counts below are real zeros, not blind spots.
- Raw output: `.claude/tmp/rv-align/raw.json` (20 file×viewport runs, `run.log` ends `RC=0`), `p1_375.json`, `p2_375.json`, `p3_375.json`, `p3_1280.json`, `p4.json`, `grep.log`, screenshots in `shots/`.

## Global results (all 10 files)

| Check | 375 | 1280 |
|---|---|---|
| Horizontal scroll (`scrollWidth` vs `clientWidth`) | 375 = 375 everywhere | 1280 = 1280 everywhere |
| Elements outside page / outside frame (excl. intentional scrollers) | 0 | 0 |
| Clipped text | 0 | 0 |
| Frame rows centred (left gap − right gap) | 0 px diff, every row | 0 px diff, every row (e.g. A 45.5/45.5, B 53.5/53.5) |
| Off-centre children in centred columns (hero / empty / error) | 0 | 0 |
| Numeric columns with inconsistent edges | 0 | 0 |
| Bottom nav: 5 items, equal width, icon centred (dx = 0), active = current page | pass, all 10 | pass, all 10 |
| Non-4px spacing authored in page CSS | 0 (only UA defaults, see nits) | same |

Greps:
- Dark theme (the exact contract §2 pattern and the broader task pattern) over `docs/design`: one hit only, `contract.md:19`, which is the contract quoting its own grep command. No hit in any HTML/CSS. This review file deliberately does not spell the pattern, so it adds no hit.
- Hex / `rgb()` / `hsl()` literals in the 10 pages, `components.css`, `components.html`: 0 lines. No named colours in fill/stroke/color/background.

## Shared foundation findings (not attributable to one page; `components.css` is read-only for teams)

| # | Selector | Viewport | Measured | Severity | Suggested fix |
|---|---|---|---|---|---|
| S1 | `.status-banner .status-banner__icon` vs `.status-banner__title` first line | both | icon centre is 2px below title first-line centre in every banner of every page (e.g. A home ④ 4183 vs 4181; B rainfall ② 1970 vs 1968) | should-fix | `.status-banner__icon { height: var(--type-body1-lh); align-items: center; }` so the 20px icon is centred on the 20px title line |
| S2 | `.fab` | both | `padding: 1px 6px` (browser default, not reset) | nit (no visible effect: fixed 44×44 box, icon measured centred dx=dy=0) | add `padding: var(--space-0);` to `.fab` |

---

## Team A — Glanceable dashboard

Team signature (default frame, measured): app bar 56px, padding 16/4, title 20/28/600; bottom nav 73px (4/8 padding + 1px stroke), 5 items × 73.4px; page padding-top 8, gap 16; card `radius 12px`, `padding 16 16 20`; hero `padding 24 20`; card title 20/28/600 (home reference).

### team-a/home.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| A-H1 | `.hero` content vs `.card--a` content | both | hero content left = 36px, following cards' content left = 32px (hero padding 20 vs card 16) | should-fix | `.hero { padding-inline: var(--space-16); }` (or move cards to 20) so all card contents share x=32 |
| A-H2 | `.warn-entry` (status banner, `align-items:center`) | both | icon centred on the 90px banner (cy 45) while title first line is at cy 23 — icon sits 22px below its title | nit | acceptable for a single-block entry; if wanted, `align-items: flex-start` + S1 |
All other checks: 0 findings (rows centred, 7-day grid columns aligned, scroller items centred).

### team-a/radar.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| A-R1 | `.hero` vs `.card--a` content left | both | 36 vs 32 | should-fix | same as A-H1 |
| A-R2 | `.map-fabs > button.fab` | both | padding 1px 6px (UA default) | nit | S2 |
| A-R3 | `.playback__time` (`align-items: baseline`) | both | timestamp vs frame counter centre spread 2px | nit (baseline alignment of different font sizes is correct) | none |

### team-a/rainfall.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| A-F1 | `.hero` vs `.card--a` content left | both | 36 vs 32; flush list rows text at 32 | should-fix | same as A-H1 |
| A-F2 | `.card__header--top` | both | title block and badge top-aligned (spread 56px) | nit (intended top alignment of a tall title block) | none |

### team-a/warnings.html — verdict: **fix blockers** (1)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| A-W1 | `.section__title` ("生效中", "臺北市") | both | 16px / 22px line height, placed outside a card at x=16. Home (team reference) section headings are `.card--a .card__title` 20px / 28px inside cards at x=32 | **blocker** (team inconsistency of section heading style) | use the home pattern: wrap the list in `.card.card--a` with `.card__header > .card__title`, or give `.section__title` the subtitle1 tokens (`--type-subtitle1-size/-lh/-weight`) |
| A-W2 | frame wrapper: border on outer `.frame`, not on `.app-shell` | 1280 | inner content width 373 vs 375 on home/radar/rainfall; page top 56 vs 57; bottom-nav items shifted 1px (x 4 vs 5) | should-fix | copy home's frame CSS (`.frame .app-shell { border…; border-radius…; box-shadow… }`) |
| A-W3 | `.hero` | both | 1px severity-tinted border; home hero has none; hero content left 37 vs 36 on home | should-fix | drop the border (tint via background) or apply the same stroke on all team heroes |
| A-W4 | `.warn` | both | 3px left accent stroke pushes summary content to x=19 while section header is at x=16 | nit | none needed if accent stripe is intended |

### team-a/location.html — verdict: **fix blockers** (2)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| A-L1 | `.section__title` ("我的地點", "縣市", "臺北市 · 鄉鎮市區") | both | 16/22 at x=16, outside cards; home reference 20/28 inside cards at x=32 | **blocker** (team inconsistency) | same as A-W1 |
| A-L2 | `.card__title` ("開啟步驟", line ~381) | both | 16/22 because the card lacks `card--a`; other Team A card titles 20/28 | **blocker** (team inconsistency of card style) | add `card--a` to that card (or the same override) |
| A-L3 | frame border on outer `.frame` | 1280 | content 373 vs 375, page top 56 vs 57, nav 1px shift | should-fix | same as A-W2 |
| A-L4 | `.loc-hero`, `.intro` heroes | both | 1px brand/warning border; `.intro` shadow is shadow-4 vs shadow-8 on other heroes | should-fix | one hero recipe across the team (home: no border, shadow-8) |
| A-L5 | `div.field > input` | both | padding 1px 2px (UA default) | nit | `.field input { padding: var(--space-0); }` |

---

## Team B — Dense information list

Team signature (default frame, measured): app bar 56px, padding 16/4, title 20/28/600; header block (app bar + tabs + 1px divider) ends at y=102 on home, radar, rainfall, warnings; tabs 44px, first tab at x=5; section heading 14/20/600 in a 32px head with 16px inset (`.tb-section__title` and `.group__label` compute identically); card radius 0, no shadow; list rows padding 16 horizontal; bottom nav 73px.

### team-b/home.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| B-H1 | `.tb-frame` | 375 | phone frame rendered 343px wide (16px side margins) instead of 375; Team A goes full-bleed at ≤420px | should-fix | in the narrow media query: `.board{padding-inline:0}` + `.tb-frame .app-shell{border-inline:none;border-radius:var(--radius-none)}` so the 375 frame is really 375 |
| B-H2 | `.list-row.tb-alert` leading slot | both | text starts at x=53 (24px leading) vs warnings/location rows at x=61 (32px leading) | should-fix | use the same leading size (32px slot) for all team list rows |

### team-b/radar.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| B-R1 | header + sections implemented with a second class family (`.app-bar--pivot`/`.pivot`/`.page--dense`/`.group`) instead of home's `.tb-header`/`.tb-page`/`.tb-section` | both | visually identical (divider at y=102, tabs at x=5 × 44px, heading 14/20/600, page gap 16) — divergence is in code only | should-fix (maintenance: two implementations of one team pattern) | rename to the home classes |
| B-R2 | `.map-fab` | both | padding 1px 6px (UA default) | nit | S2 |
| B-R3 | B-H1 applies (frame 343 at 375) | 375 | — | should-fix | as B-H1 |

### team-b/rainfall.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| B-F1 | same second class family as B-R1 | both | visually identical | should-fix | as B-R1 |
| B-F2 | `a.status-banner--alert-3` trailing chevron | both | chevron on the title line (cy 23) of a 90px banner; home's warning entry is a list row | nit | `align-self: center` on the chevron, or reuse the home `.tb-alert` row |
| B-F3 | B-H1 applies | 375 | — | should-fix | as B-H1 |

### team-b/warnings.html — verdict: **fix blockers** (1)
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| B-W1 | `.wrow__head` → `.wicon`, `.wrow__chev` vs `.wrow__title` | both | `align-items: flex-start`; icon and chevron centre at y=28, title first-line centre at y=22 (6px off), row centre at y=54/44. Neither centred on the row nor on the first line. All 6 rows in frames ①②③⑥ | **blocker** (visibly misaligned primary list element) | either `.wrow__head { align-items: center; }`, or keep top alignment and set `.wicon, .wrow__chev { margin-top: calc((var(--type-body1-lh) - 32px) / 2); }` so their centre is on the title line |
| B-W2 | B-H1 applies | 375 | — | should-fix | as B-H1 |

### team-b/location.html — verdict: **pass**
| # | Selector | Viewport | Measured | Severity | Fix |
|---|---|---|---|---|---|
| B-L1 | `label.field > input` | both | padding 1px 2px (UA default) | nit | `.field input { padding: var(--space-0); }` |
| B-L2 | B-H1 applies | 375 | — | should-fix | as B-H1 |

---

## Summary

| File | Blockers | Verdict |
|---|---|---|
| team-a/home.html | 0 | pass |
| team-a/radar.html | 0 | pass |
| team-a/rainfall.html | 0 | pass |
| team-a/warnings.html | 1 | fix blockers |
| team-a/location.html | 2 | fix blockers |
| team-b/home.html | 0 | pass |
| team-b/radar.html | 0 | pass |
| team-b/rainfall.html | 0 | pass |
| team-b/warnings.html | 1 | fix blockers |
| team-b/location.html | 0 | pass |

Contract condition 5 (blocker = 0) is **not met**: 4 blockers in 3 files. Conditions 2 and 6 pass. Condition 1 passes for colour literals; spacing and radius are all tokens (non-token px values found are only layout widths such as 375/812/1280 and grid column widths). Condition 4: Team A fails on section heading style (A-W1, A-L1, A-L2); Team B passes visually, with a code-level split (B-R1/B-F1).

## Parking-lot (out of contract, not severity-rated)

- Board wrappers differ inside each team (Team A: `.board/.frame` on home/radar/rainfall vs `.doc/.frame-col/.frame-cap` on warnings/location; Team B: `.tb-frame` vs `.frame`). Outside the phone frames, so not an app-UI issue.
- Team B home app bar uses a custom `.tb-loc` location title instead of `.app-bar__subtitle`; type matches, structure differs.
- Measurement covers geometry only; data realism and feature coverage (contract condition 3) were not reviewed here.
