# 特警報 merge — architecture plan (home bottom section + 警特報 page)

Contract: `docs/logs/home-page-contract.md` item 5. Code map: `docs/design/home/code-warnings.md`.
All paths under `lib/` unless noted. Line numbers are at commit `96a3b78`.

## 1. Current duplication

Already one data path: both views watch the same `activeWarningsProvider`
(`features/hazard/hazard_provider.dart:11-13`, all of Taiwan, CWA W-C0033-001 + W-C0033-002 in one
repository call). Both use `groupWarnings` / `groupsForCounty` (`features/hazard/warnings/warning_groups.dart:45,71`).
No second fetch, no second model. The duplication is in the views:

| # | Duplicated item | Home (`features/weather/weather_screen.dart`) | 警特報 page (`features/hazard/warnings_screen.dart`) |
|---|---|---|---|
| 1 | Result switch (api key / failure / error / success) | :171-177 | :80-89 |
| 2 | Error banner 「無法取得警特報」 + retry | :181-186 | :227-233 (+ EmptyState :235-242) |
| 3 | `ApiKeyNotice` branch | :172 | :83-86 |
| 4 | 即將生效 / 生效中 strings | :200 | `warnings/warning_card.dart:10-11` |
| 5 | Time-range format | own `_range` :207-208 (`monthDay`+`clockText`) | `formatTaiwanMonthDayClock` (`warning_card.dart:121`, `warnings_hero.dart:28`) — output differs |
| 6 | Level → colour | alert1/alert3 only :199 (levels 2 and 4 collapse) | alert1-4 via `WarningLevelStyle` (`warnings/warning_style.dart:20-30`) |
| 7 | Clock | `weatherClockProvider` :115 | `warningsClockProvider` :24, :96 |
| 8 | County filter inline | :120-123 | :93-95 |
| 9 | Source credit assembled | :132 | :124 |

Home renders one `StatusBanner` for the top group (:188-205) that jumps to the tab (:196); the page renders
`WarningsHero` + scope chips + `WarningCard` grid. Same data, two renderings.

## 2. Options

### A. Keep the 警特報 tab; both views embed one shared `WarningsSection`
- Tabs stay 天氣｜雷達｜雨量｜警特報｜設定 (`app_shell.dart:13,39-45`).
- Home bottom = `WarningsSection(scope: mine)`; tab = `AppPageScaffold` wrapping `WarningsSection(scope: all)`.
- Pros: all-Taiwan view stays one tap away; the tab survives as a destination for a future notification deep link.
- Cons: the same section appears twice with only the default scope changed — two entry points to one view, which is what
  the contract asks to merge away. `WarningsScreen` keeps its own place gating (:48-76), duplicating home's
  place gating (`weather_screen.dart:66-87`). Two scope states (one per `IndexedStack` page, `app_shell.dart:58-63`)
  can disagree. Keeps `AppTab.warnings` nav plumbing and `warningsClockProvider`.

### B. Remove the 警特報 tab; the home bottom section is the only warnings view (recommended)
- Tabs become 天氣｜雷達｜雨量｜設定 (4). `AppTab.warnings`, its `_tabs` entry and `WarningsScreen` are deleted.
- The home bottom section carries everything the page had: hero summary, scope chips 「我的縣市 / 全部」, card grid,
  expandable bulletin detail, 「查看雨量」 → 雨量 tab.
- 雨量 tab: unchanged (`features/hazard/rainfall_screen.dart`, 觀測 / 未來 1 小時). It is the only remaining hazard tab;
  `WarningCard`'s 「查看雨量」 still targets `AppTab.rainfall`. 雷達 and 設定 unchanged. No other screen links to
  `AppTab.warnings` except the home banner being deleted (grep `AppTab.warnings`: `weather_screen.dart:196` only).
- Pros: one view, one place gate (home's), one scope state, one clock; deletes `warnings_screen.dart` (259 lines) and
  the home banner code. 4 tabs fit the compact `NavigationBar` and short landscape rail better
  (`app_shell.dart:78-79` already needs `scrollable` for 5).
- Cons: an active warning for the user's county sits below the forecasts; on a phone the user must scroll to see it.
  The all-Taiwan view is reachable only from home. No standalone destination for a future notification deep link
  (it would scroll home to the section instead).

### Recommendation: B
Contract item 5 asks to move warnings to the bottom of home **and** merge with the page into one component with no
duplicate implementation. B is the only option with one rendering and one navigation path; A keeps two entry points to
one view. The visibility cost of B comes from contract item 5 itself (bottom placement), not from the merge.
The wide layout (designer-3 direction) can put the section in a side column, which removes the cost on ≥1024px.

## 3. Data model and provider API

**Single provider: keep `activeWarningsProvider` as is (all of Taiwan).** Do not add a place-filtered provider:
- The 全部 scope and the hero foot 「影響 N 個縣市 · 你所在的X有 M 項」 need all counties.
- The CWA call returns all counties either way (one request, two datasets); a filtered provider would not save traffic.
- Filtering is the pure `groupsForCounty(groupWarnings(data), county)` already under test.

No new model. `WarningGroup` (`warning_groups.dart:8-41`) stays the view model.

**Clock:** delete `warningsClockProvider` (`warnings_screen.dart:24`; no test overrides it). The section takes
`now` as a parameter from `WeatherScreen`, which reads `weatherClockProvider` (`weather_screen.dart:115`). One clock.

**Shared widget** — new file `features/hazard/warnings/warnings_section.dart`:

```dart
/// 特警報 section at the bottom of 天氣: hero summary, 我的縣市 / 全部 chips, card grid.
class WarningsSection extends ConsumerStatefulWidget {
  const WarningsSection({super.key, required this.county, required this.now});
  final String county;   // place.county, CWA 「臺」 spelling; caller has already resolved a place
  final DateTime now;    // from weatherClockProvider
}
// State: bool _mineOnly = true;  watches activeWarningsProvider;
// retry = ref.invalidate(activeWarningsProvider);
// 查看雨量 = ref.read(appTabProvider.notifier).select(AppTab.rainfall).
```

Body moves from `WarningsScreen._data`/`_list` (`warnings_screen.dart:92-188`) into the section, minus
`AppPageScaffold` / `AppPageHeader` / `SourceLine` (home owns those). Reused unchanged:
`WarningsHero`, `WarningCard`, `WarningLevelStyle`, `warningIcon`, `groupWarnings`, `groupsForCounty`, `countyCount`.

Default scope on home = 我的縣市 (home is place-centred; current page default is 全部, `warnings_screen.dart:35`).
Designers may argue otherwise; the API does not change.

**Home integration** (`weather_screen.dart`):
- Delete `_warningEntry`, `_warningError`, `_activeEntry`, `_range` (:163-208) and the inline `groups` (:120-123).
- Append `AppGridItem.full(child: WarningsSection(county: place.county, now: now))` as the last child.
- Source credit: add both warning datasets when `warnings` is `AsyncData(value: Success())` — the 「目前無警特報」 hero is
  also data from those datasets. Keep `refresh()` invalidating `activeWarningsProvider` (:43).

## 4. Error states (all inside `WarningsSection`; the place states stay in `WeatherScreen`)

| Input | Rendering | Notes |
|---|---|---|
| place loading / NoPlace / place error | not built — `WeatherScreen` shows its own guide (`weather_screen.dart:66-87`) | removes the page's copy (`warnings_screen.dart:48-76`) |
| `AsyncLoading` | `AppCard.loading(hero: true)` skeleton | today home shows nothing while loading (:176) — a gap the user cannot tell from 「無特報」 |
| `Failure(apiKeyIssue)` | `ApiKeyNotice(issue)` | same per-card pattern as `hero_card.dart:30`, `sun_card.dart:35`, etc. |
| `Failure(message)` / `AsyncError` | `StatusBanner(error, '無法取得警特報', text: message, RetryButton)` + line 「這不代表目前沒有警特報。」 | never render the empty hero on failure (no silent fallback); drop the page's 「回天氣主頁」 button (already on home) |
| Success, scope empty, other counties have warnings | `WarningsHero` empty variant, foot 「其他縣市有 N 項，切換到「全部」查看」 | replaces the separate `EmptyState` (`warnings_screen.dart:190-206`) |
| Success, no warnings anywhere | `WarningsHero` empty variant, foot 「最近檢查 HH:mm」 (`fetchedAt`) | refresh = page pull-to-refresh / header button |
| Success with groups | hero + chips + `SectionHeader` + `WarningCard` grid (first card open) | `AppGrid.columnsFor` uses the section's own width, so a side column (wide) works unchanged |

## 5. Tests (core logic only)

- Keep `test/unit/warning_groups_test.dart` (grouping, sort, level, `groupsForCounty`, `countyCount`, `isUpcoming`) — unchanged.
- Keep `test/unit/hazard_repository_test.dart` warning cases — unchanged.
- Add none. The merge moves widgets and deletes code; it adds no new logic. Widget/render tests are out of policy.
- Verification (one-off, not committed): `flutter analyze` clean; full unit suite green; grep
  `WarningsScreen|warningsClockProvider|AppTab.warnings|_warningEntry` over `lib/ test/` returns zero lines;
  headless app start on a fixed place renders the home without exceptions (no GUI automation).

## 6. Work packages (disjoint file ownership)

| WP | Owner files | Content | Depends on |
|---|---|---|---|
| W1 shared section | create `features/hazard/warnings/warnings_section.dart`; edit `features/hazard/warnings/warnings_hero.dart` only if the empty foot needs a new field | move body from `warnings_screen.dart:92-188`, states per §4 | — |
| W2 home integration | `features/weather/weather_screen.dart` | §3 home integration | W1 API (frozen above). This file is also owned by the home-layout work package; assign W2 to that same member, do not split the file |
| W3 navigation removal | `app_shell.dart`; delete `features/hazard/warnings_screen.dart` | drop `AppTab.warnings` and its `_tabs` entry; update the shell doc comment (:26) to 4 tabs | W2 (removes the last `AppTab.warnings` reference) |

W1 can start now. W2 and W3 run in that order after W1; W3 is a few-line change and may go to the W2 member.

## 7. Uncertain / for the user

- B removes a top-level tab. This changes navigation the user sees; confirm B over A before implementation.
- Whether home needs any top-of-page cue when the user's county has an active warning. Contract item 5 says bottom, so
  this plan adds none; a cue would be a second rendering and conflicts with "no duplicate implementations".
- Parking lot (not this contract): `ActiveWarnings.forCounty` (`data/models/hazard_models.dart:152-157`) has no caller
  in `lib/` (tests only) — dead code by project rules.
- Parking lot: on a missing API key every home card shows its own `ApiKeyNotice`; the section adds one more.
