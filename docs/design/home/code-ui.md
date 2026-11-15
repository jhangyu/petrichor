# 首頁 (天氣 tab) UI code map

All paths under `lib/`. Every claim verified by reading the file; line numbers as of working tree on main (96a3b78 + untracked docs).

## 0. Key findings (read first)
- **No "天氣建議" widget or string exists in code.** `grep 天氣建議 lib` = 0 hits (only docs/design/home/brief.md:6). The closest existing element is HeroCard's `.hero__summary` strip (the forecast slot's 天氣預報綜合描述, verbatim) — `features/weather/widgets/hero_card.dart:114-129`. Treat it as the 天氣建議 note source unless the user says otherwise (see §6).
- **No shared "note / callout" widget exists in `core/widgets`.** The hero summary is an inline `Container` (hero_card.dart:117-128); the sun-status line is an inline `Row(Icon+Text)` (sun_card.dart:74-86). The only callout-like shared widget is `StatusBanner` (core/widgets/status.dart:11-74).
- **No shared "stat tile" other than `MetricTile`/`MetricGrid`** (core/widgets/data_display.dart:90-173). SunCard uses its own plain `Column(label,value)` cells (sun_card.dart:108-133), and Forecast72hCard has a private `_stat` tile (forecast_72h_card.dart:85-112).
- Home warning banner is built inline in `weather_screen.dart:163-209` from `StatusBanner`; WarningsScreen uses different widgets (`WarningsHero`, `WarningCard`) — no shared component today (see §8).

## 1. Page layout & card order
`WeatherScreen` (`features/weather/weather_screen.dart:33`), `ConsumerWidget`. Watches `currentPlaceProvider` (:38) and `weatherNotifierProvider` (:39).

State switch (:66-87): `NoPlace` → `_NoPlaceGuide` banner (:67-70, :370-416); place `AsyncError` → `EmptyState '無法讀取已選地點'` (:71-81); place loading → `_PullHint(loading:true)` (:82-85); else `_content` (:86).

Header `AppPageHeader` (:50-64): title = place name / `定位中…` / `尚未選擇地點` (:51); subtitle `目前位置|已選地點 · 更新於 HH:mm` / `更新中…` (:92-105); actions: refresh `AppIconButton` (:57-61) and `切換地點` (:62); title tap → settings tab (:55).

`_content` children order, inside `AppPageScaffold` (:134-160), top→bottom:
1. `_PullHint` — only when loading or width class compact (:139-140). Strings `載入天氣資料…` (:351), `下拉即可重新整理` (:360).
2. Warning entry (`_warningEntry`, :141, :165-179) — **above all cards, full row**.
3. `_CardFlow` (:142-158) with 4 cards: `hero`=HeroCard (:144-148), `sun`=SunCard (:149), `forecast`=Forecast72hCard (:150), `weekly`=WeeklyCard (:151-156). Current order: hero → sun → 72h → 7日 → (warnings are already above).
4. `SourceLine` footer, dataset ids only for data on screen (:125-137; widget core/widgets/page_scaffold.dart:208-221).

### Adaptive layout (`_CardFlow`, weather_screen.dart:214-255)
`columns = AppGrid.columnsFor(box.maxWidth, spanUnits: 4)` (:231) = `max(1, min(floor((w+16)/(340+16)), 6, 4))` (core/layout/adaptive.dart:99-107; gridMinColumn 340, gap 16 at core/theme/app_tokens.dart `AppLayout` ~:247-251). `box.maxWidth` = window width minus page margin both sides (margin 16 / 24 / 32 for compact <600 / medium <840 / expanded+; adaptive.dart:49-53, tokens `AppBreakpoint` medium 600, expanded 840, large 1200).
| columns (content width w) | layout | line |
|---|---|---|
| 1 (w < 712) | `[hero, sun, forecast, weekly]` stacked, gap 16 | :244 |
| 2 (712 ≤ w < 1068) | `_EqualHeightPair(hero, sun)` then forecast, then weekly stacked | :245 |
| ≥3 (w ≥ 1068) | `_EqualHeightPair(hero, sun)` then `Row(forecast flex 3, weekly flex 2)` | :246-249; flex consts :223-224 |
Thresholds derived arithmetically from the formula (not stated in code). `_EqualHeightPair` (:259-324) is a custom RenderBox: two equal-width cards, both as tall as the taller (comment :257-258: IntrinsicHeight can't measure SunCard's LayoutBuilder). Rail vs bottom nav: `WindowSizeClass.usesRail` = width ≠ compact (adaptive.dart:46; app_shell.dart:64).

In-card adaptivity: `MetricGrid` 2 columns, or all tiles in one row when grid width ≥ `AppLayout.cardWideWidth` 520 (data_display.dart:152; tokens :264). SunCard arc beside details when card content width ≥ 520 (sun_card.dart:94-103), else stacked.

`AppPageScaffold` (core/widgets/page_scaffold.dart:17-102): scrollable `AppGrid(children)` (:71) with page margin; `RefreshIndicator` when `onRefresh` set (:91-96); bg `AppPalette.bg3` (:84). Children here are wrapped `AppGridItem.full` so each spans the whole row (adaptive.dart:62).

## 2. HeroCard — 即時觀測 (`features/weather/widgets/hero_card.dart`)
Constructor (:19): `HeroCard({current: Result<CurrentWeather>?, slot: HourlyForecast?, onRetry})`. `slot` = `currentSlot(hourly.data, now)` (weather_screen.dart:146; home_logic.dart:164-169, 3 h slots :161).
States (:28-34): null → `AppCard.loading(hero:true, skeletonHeight:266)` (:14); `Failure(apiKeyIssue)` → `ApiKeyNotice`; `Failure` → `AppCard.error(title:'無法取得目前天氣')`; `Success` → `AppCard(hero:true, child:_content)`.
Content `Column`, gap s16 (:38-41), top→bottom:
1. Eyebrow row (:42-52): `即時觀測 · HH:mm` (observedAt, caption1 fg3, :46) + `AppBadge('降雨機率 N%', rain)` when `slot.pop != null` (:50).
2. Temp row (:53-82): left `tempText(c.temperature)` `AppType.display` (:60-63) and 高/低 pair `_hilo` (dailyHigh `tempHot`, dailyLow `tempCold`; :64-70, :131-143); right `WeatherGlyphIcon(size 64)` + `c.weather ?? '—'` (:74-80).
3. `MetricGrid` of 4 `MetricTile(onHero:true)` (:83-108): 體感 `tempText(slot?.apparentTemperature)` (:85-90, icon thermostat_outlined); 濕度 `N%` (:91-96, water_drop_outlined); 風 label = `風` or `風 · {東北|靜風|風向不定}` via `observedWindLabel` (:97-105, icon air; value `speedText` e.g. `3 m/s`); 降雨機率 `percentText(pop)` (:106, umbrella_outlined). Note 降雨機率 appears twice (badge :50 and tile :106).
4. Optional summary note `?_summary(slot?.description)` (:109, :114-129) — see §6.
Source of obs: dataset O-A0003-001 (:16 doc comment). Format helpers: home_logic.dart:61-72 (`tempText`, `percentText`, `speedText`), :23-26 `clockText`.

## 3. SunCard — 日出日落 (`features/weather/widgets/sun_card.dart`)
Constructor (:19): `SunCard({days: Result<List<SunDay>>?, now, onRetry})`; `days = [今天, 明天]` (:17-18, :37). Title const `日出日落` (:26). States (:33-38): loading `AppCard.loading(title, skeletonHeight 260)`; apiKey notice; `AppCard.error('無法取得日出日落資料')`; success `_card(today, tomorrow?)`.
`AppCard(title:'日出日落', meta:'{今天|明天|週X} M/D（X）')` (:90-92). Body is `LayoutBuilder` (:93-104): ≥520 → `Row[Expanded(arc), Expanded(details)]`, else `Column[arc, details]`.
- **Arc** (:43-59): `AspectRatio(288/112)` max width 360 (:29, :45-47) `CustomPaint(_SunArcPainter)` + Semantics label `太陽位置：曙光…、日出…、過中天…（仰角 N°）、日落…、暮光…` (:50-55).
  `_SunArcPainter` (:158-250), viewbox 288×112 (:164-165): horizon line (:207-211); dashed future arc stroke1 + solid elapsed arc `iconSun` (:213-216); twilight dashed alpha 0.4 outside sunrise/sunset (:218-222); rings at 曙光/暮光 (r3, fg4 :229-230), **過中天 point (r3, iconSun :231-232)**, sunrise/sunset endpoints (r4 :233-234); sun dot r8 only when `SunPhase.daytime` (:236-240) — at night **no marker is drawn**; labels above transit point: `clockText(transit)` and `仰角 N°` (:242-245, top y 24). Points placed by time fraction `_fraction` (:184), ellipse `_point` (:186-189). Helpers `dashedPath`, `paintLabel` in `chart_paint.dart:4-47`. **The arc does not currently draw the weather glyph.**
- **Details column** (:60-89), gap s12:
  - row 1 `_row` (:64-68, :108-133): 日出 (subtitle1) / 白晝長度 `durationText` e.g. `10 小時 57 分` (body1, fg2) / 日落.
  - row 2 (:69-73): 曙光 / 過中天 / 暮光 (body1 fg2). These are plain `Column(Text label caption1 fg3, Text value)` cells, `_ValueSize` enum :153. **Not** MetricTile.
  - sun-status line (:74-86) — §7.
  - `_tomorrow` (:87, :135-149): top border stroke3; text `{明天} M/D（X）　日出 HH:mm · 日落 HH:mm` (:145).
Data: A-B0062-001 (:16); `SunDay` fields used: sunrise, sunset, civilDawn, civilDusk, transit, transitAltitudeDegrees, date.

## 4. WeeklyCard — 7 日預報 (`widgets/weekly_card.dart`)
Constructor (:17-23): `WeeklyCard({weekly: Result<List<DailyForecast>>?, currentTemperature: double?, now, onRetry})`; currentTemperature = observed temp (weather_screen.dart:153). Title `7 日預報` (:31), meta `M/D – M/D` (:54). States :39-45 (loading skeleton 424 :12; error `無法取得 7 日預報`; empty `暫無 7 日預報`).
Body (:55-62): 7 `_row`s with top divider (stroke3) + 8px gap + `_legend`.
`_row` (:66-138), min height 56: name column 64px (`今天/明天` + `週X M/D` caption, else `週X` + `M/D`; :67-70, :86-98); `WeatherGlyphIcon(24)` (:99); pop `N%` 36px, muted fg3 when `pop < rainLowThresholdPercent=30` (home_logic.dart:7; :71, :100-111); low temp 28px (:112-119); `_TempRange` bar on shared axis (`weeklyScale`, home_logic.dart:210-220) with gradient `tempBarCold→Hot` and a now-dot only on today (:120-127, :169-229); high temp 28px bold (:128-134).
Legend (:140-165): umbrella icon + `降雨機率`; right `目前溫度　區間 a°–b°` with `_NowDot` (:156-158) or just range.

## 5. Forecast72hCard — 未來 72 小時預報 (`widgets/forecast_72h_card.dart`)
Constructor (:19-25): `Forecast72hCard({hourly: Result<List<HourlyForecast>>?, issuedAt: Result<DateTime>?, now, onRetry})`. Title `未來 72 小時預報` (:35); meta `發布 M/D HH:mm` / `發布時間無法取得` (:46-50, home_logic.dart:91). States :39-43 (skeleton 456 :13; error `無法取得 72 小時預報`; empty `暫無 72 小時預報`).
Body `Column` gap s16 (:54-62): `_summary` (:71-83) three private stat tiles (`_stat` :85-112: bg2, stroke3, radius small; label caption1, value subtitle1 colored, sub caption1): 最高溫 (`tempHot`), 最低溫 (`tempCold`), 降雨機率 (`rainFg`) each with `{今天|明天} HH:mm` (:69); `_chart` (:114-): horizontal-scroll `CustomPaint` chart (height 340 :107 relative; `_ChartGeometry` consts at ~:246-273 file) of day/slot labels, weather icons, temp line, 體感 dashed, 3 h pop bars, wind; row labels `時段/天氣/溫度/體感/降雨/風` (~:294-299); `現在` marker (~:379); `_legend` (:157-) `溫度 / 體感 / 3 小時降雨機率` and `左右滑動看 72 小時` when scrolling (~:207).
Chart is 16–32 px per hour and scrolls when narrower (`_minPxPerHour/_maxPxPerHour` ~:247-248). Semantics label includes extremes (~:150-155). Data F-D0047-061 (:15).
Info level vs 7日: 72h = per-3h series (temp, 體感, wx, pop, wind) + extremes; 7日 = per-day (wx, pop, min/max). Different granularity (matters for contract item 4).

## 6. 天氣建議 note implementation
No code named 天氣建議. Candidate = `HeroCard._summary(String? text)` (hero_card.dart:114-129): returns null when `slot?.description == null` (:115), else `Container(padding h12 v8, color AppPalette.rainBg, radius AppRadius.small)` with `Row[Icon(umbrella_outlined,20,rainFg), Expanded(Text(text, body1, rainFg))]` (:117-127). Text = forecast slot `description` ("天氣預報綜合描述") shown verbatim (:114 doc). Appended as the last child of the hero column (:109). Inline private method; **not reusable**; icon is always umbrella and tint always rain regardless of content. UNCERTAIN: whether the user's "天氣建議" = this strip (best match); confirm with leader.

## 7. Sun-status line ("現在…已日落，距明天日出…")
- Text built by `sunNowLine(today, tomorrow, now)` (home_logic.dart:145-155): head `現在 HH:mm` (:147) then `sunPosition(today, now).phase` (:148-154):
  - beforeSunrise: `{head} · 距日出 {durationText}` (:150)
  - daytime: `{head} · 距日落 {durationText}` (:151)
  - afterSunset with tomorrow: `{head} · 已日落，距明天日出 {durationText(tomorrow.sunrise − now)}` (:152)
  - afterSunset without tomorrow: `{head} · 已日落` (:153)
  Note: the brief's example uses `，` after clock (`現在 21:40，已日落…`) but code uses ` · ` (:152).
- `sunPosition` (:130-143) → `SunPosition{phase, dayFraction, untilEvent}` (:120-128); `durationText` (:54-59) = `H 小時 M 分` / `M 分`.
- Rendered in SunCard as `Row(center, spacing s4)[Icon(schedule,16,brandFg), Flexible(Text(body1 fg1 tabular))]` (sun_card.dart:74-86). Inline, not a shared widget. `now` comes from `weatherClockProvider` read once per build (weather_screen.dart:115), so the line is not live-ticking.

## 8. Home warnings banner (`weather_screen.dart:163-209`)
- Data: `activeWarningsProvider` (:118, defined in features/hazard/hazard_provider.dart); `groupsForCounty(groupWarnings(data), place.county)` (:120-123; features/hazard/warnings/warning_groups.dart). Only success data is grouped; loading/failure → empty list.
- `_warningEntry` (:165-179) returns, wrapped in `AppGridItem.full` (:178), by state (:171-177): apiKey failure → `ApiKeyNotice`; other `Failure`/`AsyncError` → `_warningError` = `StatusBanner(error, '無法取得警特報', message, [RetryButton → invalidate activeWarningsProvider])` (:181-186); `Success` → `_activeEntry`; loading → null. **Success with no groups → null (nothing shown at all)** (:189).
- `_activeEntry` (:188-205): `top = groups.first`; `more = ' · 另有 N 則'` if >1 (:191). `Semantics(button, label '{name}，查看詳情')` → `InkWell(onTap: select AppTab.warnings, radius medium)` → `StatusBanner(tone: top.level null|1 ? alert1 : alert3 (:199), title '{name} · 即將生效|生效中' (:200, `top.isUpcoming(now)`), text '{M/D HH:mm – M/D HH:mm}{more}' (:201, :207-208))`. Only two tones used (alert1 yellow, alert3); levels 2/4 map to alert3 (:199; `StatusTone` enum status.dart:7 has only alert1, alert3). No county badges, no expand, no per-warning list.
- Top-level page for comparison (`features/hazard/warnings_screen.dart`): `WarningsScreen` (:27) → `WarningsHero` (:101-120), filter chips `AppChip` 全部/我的縣市 (:127-139), `SectionHeader` + column-distributed `WarningCard`s (:145-188, `initiallyOpen: i == 0` :172), `EmptyState` for none (:190-). Sources: `warnings/warnings_hero.dart` (110 lines), `warnings/warning_card.dart` (191 lines; `AppBadge` per county :179), `warnings/warning_style.dart:8-45` (`WarningLevelStyle.of(level)` bg/fg/stroke/solid/BadgeTone; `warningIcon`). The two implementations share only `groupWarnings`/`groupsForCounty` and `activeWarningsProvider`; they differ in widgets and level styling.

## 9. Shared widgets in `lib/core/widgets` (constructor API → where used)
| Widget (file:line) | Constructor | Used on home | Used elsewhere |
|---|---|---|---|
| `AppCard` (app_card.dart:15) | `AppCard({title?, meta?, trailing?, required child, hero=false, heroColor?, flush=false})` (:16-28); `.loading({title?, required skeletonHeight, hero})` (:30); `.error({required title, required message, required onRetry})` (:45); `.empty({required title, message?})` (:59). Padding 16/16/16/20, gap 16, radius 12, shadow s4 (hero s8, gradient brand160→bg1) (:101-150). error/empty render a `StatusBanner` (:107-113) | Hero (hero_card.dart:29-32), Sun, Weekly, 72h | rainfall, radar, warnings_hero, settings |
| `SectionHeader` (:176) | `({required title, trailing?})` | — | warnings_screen.dart:148, settings, place_picker |
| `StatusBanner` (status.dart:11) | `({required tone: StatusTone{loading,error,empty,permission,alert1,alert3}, required title, text?, icon?, actions=const[]})` (:7, :12-19); bg/stroke by tone (:31-39) | weather_screen.dart:181,198,406; via AppCard.error/empty; ApiKeyNotice | warnings, radar, rainfall, settings |
| `EmptyState` (status.dart:78) | `({required title, text?, icon=cloud_off_outlined, error=false, actions=[]})` | weather_screen.dart:74 | warnings_screen.dart:193,200,236 |
| `AppSpinner` (:116), `Skeleton` (:134, `({width?, required height, circle=false})`), `RetryButton` (:155, `({required onPressed, primary=false})`) | | `_PullHint` spinner (:350); skeleton via AppCard.loading; RetryButton :185 | many |
| `ApiKeyNotice` (api_key_notice.dart:11) | `({required ApiKeyIssue issue})`; StatusBanner error `需要 CWA token` + primary small button `前往設定` → settings tab (:18-33) | every home card's apiKey failure + warning entry | warnings, rainfall |
| `AppBadge` (data_display.dart:9) | `({required label, tone=BadgeTone.neutral, icon?})`; tones `neutral, rain, brand, success, danger, warning, alert1-4` (:6); min height 24 (AppSize.icon24), pill, caption1 w600 (:31-53) | hero_card.dart:50 (`降雨機率 N%`, rain) | warning_card, rainfall level_style, settings |
| `LevelDot` (:60) | `({level? 1-4})` 8px dot | — | warnings |
| `MetricTile` (:90) | `({required label, required value, icon?, onHero=false})`; padding h12 v8, radius small; bg1+stroke3 when onHero else bg2; icon 20 fg2; label caption1 fg3, value body1Strong ellipsis (:107-134) | hero_card.dart:85-106 (×4, onHero) | rainfall observation_view.dart:68-78 |
| `MetricGrid` (:141) | `({required List<MetricTile> children})`; 2 columns, or one row when width ≥ 520; gap 8; IntrinsicHeight rows (:150-170) | hero_card.dart:83 | observation_view.dart:68 |
| `AppList` (:177) / `AppListRow` (:206) | `AppList({children})`; `AppListRow({required primary, secondary?, leading?, trailing?, selected, enabled, flushTrailing, onTap})` | — | settings, place_picker |
| `AppPageScaffold` / `AppPageHeader` / `SourceLine` (page_scaffold.dart:17, 107, 208) | scaffold `({required header, required children, source?, onRefresh?})` + `.fill`; header `({required title, subtitle?, subtitleIcon?, subtitleIconColor, actions, onTitleTap?, onBack?})`; `SourceLine({required datasetIds})` | weather_screen.dart:50,134,137 | all tabs |
| `AppButton` (buttons.dart:10) / `AppIconButton` (:113) | `AppButton({required label, required onPressed, variant=secondary{primary,secondary,subtle}, icon?, small=false, block=false})` | header/_NoPlaceGuide | all |
| `AppChip` (choices.dart:9) / `AppSegmented<T>` (:68) / `AppSwitch` (:142) | `AppChip({required label, required selected, required onTap, icon?})`; `AppSegmented({required segments: List<(T,String)>, required selected, required onChanged})` | — | warnings filter chips, rainfall switcher, radar |
| `AppTextField` (inputs.dart:9) | variants filled/search | — | settings |
Layout helpers in `core/layout/adaptive.dart`: `WindowSizeClass` (:18), `AppGridItem(.full)` (:59), `AppGrid` (:81, `columnsFor` :99), `AppTwoPane` (:151; `fits(width)` :161; side share 0.4 clamped 320–480, tokens AppLayout :~255-262).
Feature-local (not core): `WeatherGlyphIcon({required text, required size})` (widgets/weather_glyph_icon.dart:19; `weatherGlyph` bucketing home_logic.dart:100-111, icon/tint map :7-16), `chart_paint.dart` (`dashedPath` :4, `paintLabel` :19), `_PullHint` (weather_screen.dart:327), `_NowDot` (weekly_card.dart:232).

## 10. Tokens used by these cards (`core/theme/app_tokens.dart`)
Spacing `AppSpace` s4–s64 (:177-); radius `AppRadius` small 8 / medium 12 (:195-); size `AppSize` icon16/20/24/32/48/64, dot 8, controlSm 32 (:213-); `AppLayout` gridMinColumn 340, gridGap 16, cardWideWidth 520 (:247-264); `AppBreakpoint` 600/840/1200 (~:235-245). Type/palette used: `AppType.display/subtitle1/subtitle2/body1/body1Strong/caption1` + `AppType.tabular`; `AppPalette.rainBg/rainFg/iconSun/tempHot/tempCold/brandFg/fg1–fg4/bg1–bg6/stroke1–3/alert1/alert3*`.

## Uncertain / not verified
- 天氣建議 mapping (§6): unconfirmed which element the user means; no such string exists.
- Exact token line numbers in §10 are approximate (`~`); not individually re-read for every constant.
- Chart-internal line numbers in §5 marked `~` were taken from a filtered grep offset (+139), not a full read of forecast_72h_card.dart:140-530; the card's public API and strings above are exact.
- Column thresholds (712/1068) are computed from the formula, not asserted in code.
