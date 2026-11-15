# 特警報 code map (home vs 警特報 tab)

All paths under `lib/` unless noted. Verified by reading code.

## 1. Data source & providers — SAME
- One provider for both: `activeWarningsProvider` = `FutureProvider<Result<ActiveWarnings>>` → `hazardRepositoryProvider.getActiveWarnings()` (features/hazard/hazard_provider.dart:11-13).
- Home consumer: features/weather/weather_screen.dart:118 (`ref.watch`); refresh invalidates it at :43; retry at :185.
- Tab consumer: features/hazard/warnings_screen.dart:80 (`ref.watch`); retry/refresh invalidate at :39, :42.
- Repository fetches two CWA datasets in parallel: `W-C0033-001` (per-county warnings) + `W-C0033-002` (bulletins) (data/repositories/hazard_repository.dart:12,15,46-61).
- Failure rules: 001 has warnings but 002 empty → Failure (hazard_repository.dart:56-60); no warnings = Success with empty `counties` (hazard_repository.dart:36-40 doc, hazard_provider.dart:10).
- Model join: `ActiveWarnings.fromJson` joins bulletin to county warning by county-in-affectedAreas + identical start/end (data/models/hazard_models.dart:162-189, `_matchBulletin` :194-199). `updatedAt` = newest bulletin update (hazard_models.dart:146-149). `fetchedAt` = app fetch time (:139-141). `ActiveWarnings.forCounty` (hazard_models.dart:152-157) has no caller in lib/, only in test/unit/hazard_repository_test.dart:72,84,85,137 (grep `.forCounty(`); UI uses groupsForCounty instead.
- No auto-refresh/polling; only invalidate (weather_screen.dart:43; warnings_screen.dart:39).

## 2. Filtering by place/area
- Place source: `currentPlaceProvider` (features/location/place_provider.dart:169); `place.county` is the filter key (CWA "臺" spelling, hazard_provider.dart:7).
- Shared logic: `groupWarnings` then `groupsForCounty(groups, county)` (features/hazard/warnings/warning_groups.dart:45, :71-72).
- Home: always filters to current place's county (weather_screen.dart:120-123); non-Success → empty list (:122).
- Tab: shows all groups by default; `_mineOnly` chip toggles to county-only (warnings_screen.dart:35, :93-95, :131-137). Default `false` (all of Taiwan).
- Tab depends on place being resolved first: loading/error/NoPlace states block warnings entirely (warnings_screen.dart:48-76). Home likewise requires a selected place (weather_screen.dart:66-87).
- Separate, unrelated: notification area selection `warningAreasProvider` (features/settings/notification_settings.dart:60-64; used only by features/settings/widgets/notification_card.dart:158-198). Does not feed the warnings UI.

## 3. UI
### Home — `WeatherScreen._warningEntry` (weather_screen.dart:163-205)
- Rendered at top of page body, after pull-hint, before card flow (weather_screen.dart:141, children list :138-159).
- Single banner only (`StatusBanner`) for highest group `groups.first` (:189). Content: `${top.name} · 即將生效|生效中` + time range + `· 另有 N 則` (:190-202). Tone: alert1 if level null/1 else alert3 (:199) — levels 2 and 4 collapse into alert3.
- Tap → `appTabProvider.select(AppTab.warnings)` (:196). No grouping, no list, no detail on home.
- States: ApiKeyNotice on key issue (:172), error banner with retry (:173-174, :181-186), empty/loading → nothing (:176, :189).
- Source credit adds 001/002 only when groups non-empty (:132).
### 警特報 tab — features/hazard/warnings_screen.dart
- Page = header + `WarningsHero` + filter chips (全部 N / 我的縣市) + list (warnings_screen.dart:122-141).
- Hero summary: count, per-name badge chips, foot line (warnings/warnings_hero.dart:11-109; chips :99-109). Empty variant uses `WarningLevelStyle.ok` (:34).
- List: `SectionHeader` (生效中 / county, "依等級排序") then multi-column masonry via `AppGrid.columnsFor`, item i → column i%columns (warnings_screen.dart:145-188). First card `initiallyOpen` (:177).
- Item = `WarningCard`, expandable (warnings/warning_card.dart:15-191): header icon/name/status badge/counties/period (:84-137); body = bulletin description, 影響縣市 badges, 發布時間 (:63-64, :151-190); "查看雨量" button on rain warnings (level != null) → `AppTab.rainfall` (:65-74; wired at warnings_screen.dart:176).
- Detail view = the expanded card body (no separate route/page).
- Upcoming vs active: `WarningGroup.isUpcoming(now)` = `now.isBefore(start)` (warning_groups.dart:39-40). Card shows badge 即將生效/生效中 (warning_card.dart:10-11,116). Not separated into sections; same list. `now` from `warningsClockProvider` (warnings_screen.dart:24, :96); home uses `weatherClockProvider` (weather_screen.dart:115) — two different clocks.
- Grouping: `groupWarnings` merges per-county warnings by (phenomena, significance, start, end); sort by rain level desc then start (warning_groups.dart:43-68). Level 1-4 by name contains 大雨/豪雨/大豪雨/超大豪雨; non-rain = null (:5, :32-37). Name = bulletin title else phenomena+significance (:29).
- Style: `WarningLevelStyle.of(level)`, `warningIcon` (warnings/warning_style.dart:20-45).
- States: loading skeleton (warnings_screen.dart:208-221), error + 回天氣主頁 (:223-245), api-key notice (:83-86), empty (:190-206).
- Page scaffold: `AppPageScaffold` with refresh icon + pull-to-refresh + `SourceLine` (warnings_screen.dart:247-257, :124).

## 4. Home → page navigation
- Only path: tap on home banner → `ref.read(appTabProvider.notifier).select(AppTab.warnings)` (weather_screen.dart:196). No deep link/arguments; target tab opens in its own state (default 全部 chip, first card open).
- Reverse: tab error page → `AppTab.weather` (warnings_screen.dart:240); tab → rainfall (:176) / settings (:70).

## 5. Duplication (home vs tab)
Already shared (good): provider (hazard_provider.dart:11), `groupWarnings`/`groupsForCounty`/`WarningGroup` (warning_groups.dart), source dataset ids (warningsByCountyDataset, warningBulletinsDataset).
Duplicated / divergent:
1. **Error + retry banner**: both build `StatusBanner(tone:error, title:'無法取得警特報', RetryButton → invalidate)` — weather_screen.dart:181-186 vs warnings_screen.dart:227-233 (tab adds an EmptyState below, :235-242).
2. **ApiKeyNotice branch**: weather_screen.dart:172 vs warnings_screen.dart:83-86.
3. **Result switch** (`Failure(apiKeyIssue)` / `Failure` / `AsyncError` / `Success`): weather_screen.dart:171-177 vs warnings_screen.dart:80-89.
4. **Upcoming/active label strings** '即將生效'/'生效中': weather_screen.dart:200 vs private consts warning_card.dart:10-11; both call `isUpcoming`.
5. **Time-range formatting**: home uses own `_range` with `monthDay(taiwanWall)`+`clockText` (weather_screen.dart:207-208, helpers features/weather/widgets/home_logic.dart:12,23,32); tab uses `formatTaiwanMonthDayClock` (features/radar/radar_playback.dart:156-158; warning_card.dart:121, warnings_hero.dart:28). Output formats differ (`11/14` unpadded vs `11/14` zero-padded via `_two`).
6. **Level→tone mapping**: home maps level to `StatusTone` alert1/alert3 only (weather_screen.dart:199); tab maps to alert1-4 via `WarningLevelStyle` (warning_style.dart:20-30).
7. **Clock providers**: `warningsClockProvider` (warnings_screen.dart:24) vs `weatherClockProvider` (weather_screen.dart:115).
8. **Source credit line** assembled separately: weather_screen.dart:132 vs warnings_screen.dart:124.
9. **County filter** applied inline in each screen (weather_screen.dart:121 / warnings_screen.dart:94).
10. Invalidate-on-refresh in two places (weather_screen.dart:43, warnings_screen.dart:39,42).
Home shows 1 summary banner; tab shows hero+chips+cards: presentation is genuinely different, not copy-paste, but both render the same `WarningGroup` list.

## 6. Position in tab/navigation structure
- `enum AppTab { weather, radar, rainfall, warnings, settings }` — 警特報 is 4th of 5 (app_shell.dart:13). Label/icon/screen at :43 (`'警特報', Icons.warning_amber_outlined, WarningsScreen()`).
- Home (`天氣`) is index 0, default tab (app_shell.dart:21).
- Bottom `NavigationBar` on compact, `NavigationRail` otherwise (app_shell.dart:64-113); tabs built lazily on first visit, kept alive in `IndexedStack` (:50-63) → warnings tab state (`_mineOnly`, open cards) persists across switches.
- Home placement: banner is above the card flow, top of page (weather_screen.dart:141-142).
- Doc comments still say "警特報 tab (team-a/warnings.html)" (warnings_screen.dart:26).

## 7. Tests
- test/unit/warning_groups_test.dart: grouping/sort/level/filter/isUpcoming (:27-55).
- test/unit/hazard_repository_test.dart: getActiveWarnings join, empty, missing bulletin, failures (:61-146).
- Fixtures: test/fixtures/cwa/W-C0033-001.json, W-C0033-002.json.
- No widget tests for WarningsScreen, WarningCard, WarningsHero, or the home banner (grep of test/ for `WarningsScreen|WarningCard|warningsClockProvider` → none).

## Uncertain
- None material.
