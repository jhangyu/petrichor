# 設定 tab — Designer 1：分組設定清單（修訂 3，使用者選定）

Mockup: `settings.html` (same folder). Spec: `docs/logs/settings-tab-contract.md`.
Tokens: `lib/core/theme/app_tokens.dart`. Layout: `docs/design/adaptive/system.md`.

Revision 2 changes: per-row weather in 儲存的地點 (§5), spacing and alignment fixes (§10), Material 3 shape scale (§11), and a fifth token state 無法驗證 (§8).
Revision 3 changes: token field is an M3 filled text field (§9, §11); vertical centering rule (§10b); looser vertical spacing (§10, fixes 20–27).

## 1. Design idea

- Each of the four cards is a **settings group**: a `SectionHeader` (title + short meta) above one white rounded `AppList`. Each row holds one setting: a leading tinted icon, title + one-line explanation, and a trailing control (switch, value + chevron, badge, weather + temperature, icon button).
- This reuses the existing 我的地點 pattern (`location_screen.dart:641`).
- Status sits in the row it belongs to. Only a token that is missing (未設定) or rejected (無效) adds a full-width banner at the top.
- A setting is kept apart from its result. The 自動定位 switch stays on when permission is denied. With the notification master off, the child values are kept but disabled.
- Every alignment line is shared. Left 16 line: section titles, leading icons, sub-labels, footnotes. Text column at 60. Right 16 line: every trailing glyph and the section meta.

## 2. Page and shell

| Element | Widget | Notes |
|---|---|---|
| Tab | `AppShell._tabs` (`lib/app_shell.dart:44`) | Label 「地點」→「設定」, icon `Icons.location_on_outlined` → `Icons.settings_outlined`. Rename `AppTab.location` → `AppTab.settings` (`app_shell.dart:13`) and update every `select(AppTab.location)` caller. |
| Page frame | `AppPageScaffold` (`page_scaffold.dart:17`) | `source: SourceLine(datasetIds: ['O-A0003-001'])` only when at least one saved-place row has a `Success` observation; otherwise no source. `onRefresh`: invalidate `placeObservationProvider` for every saved place (re-reads per-row weather). |
| App bar | `AppPageHeader` (`page_scaffold.dart:107`) | `title: '設定'`. `subtitle`, in priority order: 「尚未設定 API 授權碼」 / 「API 授權碼無效」 / 「目前地點 臺北市 中正區 · GPS 定位」 (or 「· 手動選擇」). No actions. |
| Token banner | `StatusBanner(tone: StatusTone.error, icon: Icons.key_outlined)` (`status.dart:11`) in `AppGridItem.full` (`adaptive.dart:59`) | Only for 未設定 and 無效 (not for 無法驗證 or 驗證中). Action `AppButton(small: true, variant: primary)` 「輸入授權碼」/「更新授權碼」: `Scrollable.ensureVisible` on the token group's `GlobalKey`, then focus the field. |

## 3. Layout per breakpoint

Grid cells passed to `AppPageScaffold.children`; no new layout API:

```
[ if (tokenBanner) AppGridItem.full(banner),
  Column(spacing: AppSpace.s16, [savedPlacesGroup, locationGroup]),     // cell 1
  Column(spacing: AppSpace.s16, [notificationsGroup, tokenGroup]) ]     // cell 2
```

`AppGrid.columnsFor` (`adaptive.dart:99`) caps the column count at the 2 span units.

| Window (logical) | Width class / nav | Content width | Columns |
|---|---|---|---|
| 360–599 | compact / bottom bar | ≤ 567 | 1: 儲存的地點 → 地點設定 → 通知設定 → Token |
| 600–775 | medium / rail | < 696 | 1 |
| 776+ (1280 → 1136) | medium, expanded, large / rail | ≥ 696 | 2: left 地點 groups, right 通知 + Token (560 each at 1280); never 3 |

Wide interior (`LayoutBuilder`, `maxWidth >= AppLayout.cardWideWidth` 520) applies to the token group only. The field and 「儲存並驗證」 sit in one row (bottom-aligned, both 44 high). 「重新驗證」 and 「清除」 sit on the next line. The full-row banner text is capped at `AppLayout.readingWidth`.

## 4. Group shell (all four cards)

| Part | Widget | Spacing (tokens) |
|---|---|---|
| Group | `Column(crossAxisAlignment: stretch, spacing: AppSpace.s12, [header, list, ?footnote])` | header→list s12, list→footnote s12; group→group s16 (= `AppLayout.gridGap`, same in 1 and 2 columns) |
| Title row | `Padding(EdgeInsets.symmetric(horizontal: AppSpace.s16), SectionHeader(title, trailing: Text(meta, caption1 fg3)))` (`app_card.dart:176`) | inset s16: title on the left 16 line, meta on the right 16 line |
| Group body | `AppList` (`data_display.dart:174`), **children widened to `List<Widget>`** (`data_display.dart:177`) | dividers stroke3 1 px, unchanged |
| Setting row | `AppListRow` (`data_display.dart:203`) | padding h s16 / v s12, leading→text s12 (existing); **trailing inner gap s8**; **`flushTrailing: true` → padding `fromLTRB(s16, s8, s4, s8)`** when the trailing ends with an `AppIconButton` (§10 fixes 3, 16) |
| Leading icon | `_Tint` (`location_screen.dart:869`), always 32 (`AppSize.controlSm`) | text column starts at 16 + 32 + 12 = 60 |
| Padded block | page-local `_Block`: `Padding(EdgeInsets.all(AppSpace.s16))` + `Column(crossAxisAlignment: stretch, spacing: AppSpace.s16)` | block padding s16 all sides; block items s16 apart |
| Field group | label + field + helper/error, inside `AppTextField`: `Column([label, SizedBox(height: AppSpace.s8), field, SizedBox(height: AppSpace.s4), message])` | label→field **s8**, field→message s4 (M3 supporting text) |
| Sub-label | page-local `_GroupLabel`: `ColoredBox(bg2)` + `Padding(EdgeInsets.symmetric(horizontal: s16, vertical: s8))` + caption1 semibold fg3, text centred in the 32 band (fix 18) | on the left 16 line |
| Footnote | `_Note` (`location_screen.dart:978`) wrapped in `Padding(horizontal: s16)` | icon 16 + s8 + caption1 fg3 |

Row heights are fixed minimums, not padding results: one-line row `AppSize.listRowOneLine` 56, two-line row `AppSize.listRowTwoLine` 64 (new tokens, §10b). Content is centred inside. Every row is ≥ `AppSize.touch`.

## 5. Card 1 — 儲存的地點 (with per-row weather)

Providers: `savedPlacesProvider` (`save`, `remove`), `currentPlaceProvider` (`select`), `placeObservationProvider(place)` (`place_provider.dart:274`). This last one is a `FutureProvider.family<Result<CurrentWeather>, Place>` that calls `weatherRepository.getCurrentWeather` (dataset O-A0003-001). The old location screen uses the same provider for the same rows (`location_screen.dart:677`). Reorder is not shown because `SavedPlacesNotifier` has no reorder method.

### Data and icon mapping (all existing code)

| Need | Source |
|---|---|
| Temperature | `CurrentWeather.temperature` (`weather_models.dart:21`, non-null `double`) → `tempText(t)` (`home_logic.dart:62`: `'${t.round()}°'`, 「—」 for null) — same as the home hero (`hero_card.dart:59`) |
| Weather text | `CurrentWeather.weather` (`weather_models.dart:33`, `String?`, 天氣現象 e.g. 「晴時多雲」) |
| Observation time | `CurrentWeather.observedAt` (`weather_models.dart:18`) → `clockText` (as used at `location_screen.dart:181`) |
| Icon | `WeatherGlyphIcon(text: weather, size: AppSize.icon20)` (`weather_glyph_icon.dart:19`) → `weatherGlyph(text)` buckets (`home_logic.dart:100`) → `weatherGlyphStyle` icon + tint (`weather_glyph_icon.dart:7`). The home hero uses the same widget at 64 (`hero_card.dart:75`). `null` or unmatched text gives `Icons.help_outline` in fg3, and the semantics label is the weather text |
| Error type | `Failure.message` and `Failure.apiKeyIssue` (`weather_repository.dart:65`, `:72`; `ApiKeyIssue { missing, rejected, unreadable }` at `:77`) |

### Row

`AppListRow(flushTrailing: true, leading: _Tint(Icons.bookmark_outline), primary: '臺北市 中正區', secondary: …, selected: isCurrent, onTap: select, trailing: Row(spacing: s8, [if (isCurrent) AppBadge('使用中', tone: BadgeTone.brand), _PlaceWeather(...), AppIconButton(Icons.delete_outline, tooltip: '移除臺北市 中正區')]))`

`_PlaceWeather` (page-local, ~25 lines): `Row(spacing: AppSpace.s4, [glyph 20, SizedBox(width: AppSize.icon32, child: Text(temp, textAlign: end, body1Strong fg1 tabular))])`. The fixed 32 column right-aligns the digits, so temperatures line up across rows.

| State (`ref.watch(placeObservationProvider(p))`) | Glyph (20) | Temperature | Secondary text |
|---|---|---|---|
| `AsyncData(Success(data))`, weather present | `WeatherGlyphIcon(text: data.weather)` | `tempText(data.temperature)` fg1 semibold | 「晴時多雲 · 觀測 14:10」 |
| `Success`, `weather == null` (no 天氣現象) | `WeatherGlyphIcon(text: null)` → help_outline fg3 | temperature as above | 「無天氣現象資料 · 觀測 14:10」 |
| `AsyncLoading` | `Skeleton(width: 20, height: 20, circle: true)` | `Skeleton(width: AppSize.icon32, height: AppSpace.s16)` | 「讀取天氣中…」; row `Semantics(label: '…，天氣載入中')` |
| `Failure` with `apiKeyIssue == missing / unreadable` | `Icon(Icons.key_outlined, fg3)` | 「—」 fg3 regular | 「需要 API 授權碼」 |
| `Failure` with `apiKeyIssue == rejected` | `Icon(Icons.key_outlined, fg3)` | 「—」 | 「API 授權碼無效」 |
| `Failure` (other) | `Icon(Icons.cloud_off_outlined, fg3)` | 「—」 | 「無法取得天氣：」 + `Failure.message` as-is |
| `AsyncError(error)` | `Icon(Icons.cloud_off_outlined, fg3)` | 「—」 | 「無法取得天氣：$error」 |

There is no per-row retry button. Pull to refresh re-reads every row (page `onRefresh`). An error never removes or disables the row: select and remove still work. The current row keeps 「使用中」 in every state. The row semantics label joins place, current marker, weather and temperature: 「臺北市 中正區，目前地點，晴時多雲 28 度」.

| Other element | Widget | Copy / behaviour |
|---|---|---|
| Header | `SectionHeader` | 「儲存的地點」 · meta 「N 個地點」 |
| Add | `AppListRow(leading: _Tint(Icons.add, brand: true), primary: '新增地點', trailing: Icon(Icons.chevron_right))` | opens `_PickerView` (`location_screen.dart:423`) |
| Footnote (GPS in use) | `_Note(Icons.info_outline)` | 「目前使用 GPS 定位（見「地點設定」）。點選儲存的地點會改用該地點並關閉自動定位。」 |
| Empty | `StatusBanner(tone: StatusTone.empty, icon: Icons.bookmark_outline)` in a block + the add row | 「尚未儲存地點」 / 「儲存地點後，可快速切換、查看各地現況，並分別設定警特報通知。」 |
| List loading / corrupt | `AppCard.loading(skeletonHeight: AppSize.touch * 3)` / `StatusBanner(tone: error)` 「無法讀取已儲存的地點」 + error text (as at `location_screen.dart:671`) | |

## 6. Card 2 — 地點設定 (manual search + auto-locate in one card)

| Element | Widget | Copy | Behaviour |
|---|---|---|---|
| Search field (block) | `AppTextField(readOnly: true, label: '手動搜尋地點', hint: '搜尋縣市或鄉鎮市區', prefixIcon: Icons.search)` | | Tap → `_PickerView(autofocus: true)` |
| Auto-locate | `AppListRow(leading: _Tint(Icons.my_location, brand: on), primary: '自動定位', trailing: AppSwitch, onTap: toggle)` | on: 「啟動時以 GPS 取得所在鄉鎮」; off: 「已關閉：使用儲存的地點「臺北市 中正區」」 / 「已關閉：尚未選擇地點」 | on → `useGps()`; off → persist the flag; no place left = no-place state (no silent default) |
| Located | `AppListRow(selected: true, flushTrailing: true, leading: _Tint(Icons.check_circle_outline), primary: '已定位：臺北市 中正區', secondary: '定位於 14:10', trailing: [AppBadge('使用中', brand), AppIconButton(Icons.refresh, '重新定位')])` | | refresh = `useGps()` |
| Locating | `AppListRow(flushTrailing: true, leading: _Tint(child: AppSpinner()), primary: '定位中…', secondary: '正在取得目前位置', trailing: AppIconButton(…, onPressed: null))` | | `liveRegion` |
| Permission denied / denied forever | `StatusBanner(tone: StatusTone.permission)` in a block | 「未取得位置權限」 / 「位置權限已關閉」; text = existing `_guidance` (`location_screen.dart:99`) | 「前往設定」 → `_openSettings(context, Geolocator.openAppSettings)` (`location_screen.dart:91`); `RetryButton` |
| Service off | `StatusBanner(tone: StatusTone.error)` | 「定位服務已關閉」 + guidance | 「前往設定」 → `Geolocator.openLocationSettings`; 「重試」 |
| Position / address failed | `StatusBanner(tone: StatusTone.error)` | 「無法取得目前位置」 + guidance | 「重試」 |
| Footnote (failure only) | `_Note(Icons.info_outline)` | 「自動定位保持開啟；在取得權限前，App 使用「高雄市 苓雅區」。」 or 「…App 沒有可用地點。」 | |

## 7. Card 3 — 通知設定 (settings only; nothing is delivered)

| Element | Widget | Copy | Behaviour |
|---|---|---|---|
| Header | `SectionHeader` | 「通知設定」 · meta 「偏好已儲存」 / 「已關閉」 | Never 「已啟用通知」 |
| Master | `AppListRow(leading: _Tint(Icons.notifications_outlined, brand: on), primary: '通知', trailing: AppSwitch)` | 「總開關：關閉時下列設定保留但不套用」 / 「已關閉：下列設定保留但不套用」 | off → children `enabled: false`, `AppSwitch(onChanged: null)`, values kept |
| Sub-label | `_GroupLabel` | 「分區警特報通知」 | |
| Per place | `AppListRow(leading: _Tint(Icons.warning_amber_outlined), primary: place, secondary: '依臺北市的警特報', trailing: AppSwitch)` | | new place default off; removing a place drops its entry |
| No places | `AppListRow(enabled: false, primary: '尚無儲存的地點', secondary: '先在「儲存的地點」新增')` | | |
| Sub-label | `_GroupLabel` | 「其他」 | |
| 降雨提醒 | `AppListRow(leading: _Tint(Icons.umbrella_outlined), …, trailing: AppSwitch)` | 「目前地點未來 1 小時可能降雨時」 | |
| 靜音時段 | `AppListRow(leading: _Tint(Icons.bedtime_outlined), …, trailing: AppSwitch)` | 「22:00 至隔日 07:00 · 跨午夜」 / 「未開啟」 | on → next three items |
| Start / End | `AppListRow(leading: _Tint(Icons.schedule), primary: '開始'/'結束', trailing: Row(spacing: s8, [Row(spacing: s4, [if crossesMidnight && isEnd AppBadge('隔日'), Text('07:00', body1Strong fg1 tabular)]), Icon(Icons.chevron_right, 20)]))` | | `showTimePicker` with 24-hour format; minutes since midnight; `end < start` = crosses midnight |
| start == end | `StatusBanner(tone: error)` in a block | 「開始與結束時間相同，靜音時段無效。實際：22:00 至 22:00」 | rejected at the boundary, previous value kept |
| 24 h bar | page-local `_QuietHoursBar` in a block whose start padding is the text column (s16 + `AppSize.controlSm` + s12 = 60) | `Semantics(label: '靜音時段：22:00 至隔日 07:00')`, ticks 0/6/12/18/24 | track bg4, segments brandBg, height `AppSize.dot`, shape full; optional |
| Footnote | `_Note(Icons.info_outline)` | 「目前只儲存通知偏好，App 尚未發送任何通知。」 | always shown this round |
| Corrupt storage | `AppCard.error(title: '無法讀取通知設定', message: error, onRetry: reload)` | | same pattern as `RadarSetting` |

## 8. Card 4 — Token 設定 (five states)

| Element | Widget | Copy | Behaviour |
|---|---|---|---|
| Status row | `AppListRow(leading: _Tint(Icons.key_outlined, brand: status == 有效 or 驗證中), primary: '中央氣象署 API 授權碼', secondary, trailing: badge)` in `Semantics(liveRegion: true)` | see table | |
| Field (block) | `AppTextField(label: '授權碼', obscureText: !shown, prefixIcon: Icons.lock_outline, suffix: AppIconButton(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined, tooltip: shown ? '隱藏授權碼' : '顯示授權碼'), errorText / helperText, autocorrect: false, enableSuggestions: false, keyboardType: TextInputType.visiblePassword)` | hint 「貼上 CWA- 開頭的授權碼」 | masked by default |
| 儲存並驗證 | `AppButton(variant: primary)` | | parse at the boundary (trim; empty or inner whitespace → `errorText`, not saved); valid → persist, then verify |
| 重新驗證 | `AppButton(variant: secondary)` | | verifies the stored key with one real CWA call |
| 清除 | `AppButton(variant: subtle)` → `AlertDialog` | 「清除授權碼？」 / 「清除後所有資料頁都會停止更新，直到你重新輸入。」 / 「取消」「清除」 | → 未設定 |
| Apply help | `SelectableText` caption1 fg3 | 「申請方式：到「中央氣象署氣象資料開放平臺」opendata.cwa.gov.tw 註冊會員並登入，在會員資訊頁取得「API 授權碼」，複製後貼到上方欄位。」 | plain text |
| Footnote | `_Note(Icons.lock_outline)` | 「授權碼只存在這台裝置，只用來向中央氣象署請求資料。」 | |

| Status | Badge | Secondary | Field message | Buttons | Top banner / data pages |
|---|---|---|---|---|---|
| 未設定 | `AppBadge('未設定')` neutral | 「尚未輸入」 | — | 儲存並驗證 enabled once typed; others disabled | banner; data pages show the no-key `EmptyState` |
| 驗證中 | `AppSpinner` + `AppBadge('驗證中')` neutral | 「正在向中央氣象署送出一次測試請求…」 | — | all disabled, field read-only | unchanged |
| 有效 | `AppBadge('有效', tone: BadgeTone.success, icon: Icons.check_circle_outline)` | 「驗證於 14:32 · 測試請求成功」 | — | all enabled | none |
| 無效 (CWA rejected the key: HTTP 401/403, `ApiKeyIssue.rejected`) | `AppBadge('無效', tone: BadgeTone.danger, icon: Icons.error_outline)` | 「驗證於 14:35 · 中央氣象署拒絕此授權碼」 | `errorText` (danger): 「原因：HTTP 401，授權碼錯誤或已停用。請確認是否完整複製，或到開放平臺重新取得。」 | all enabled | banner 「API 授權碼無效」; data cards show the 無效 banner |
| **無法驗證** (network failure, timeout, DNS, 5xx: the key was **not** judged) | `AppBadge('無法驗證', tone: BadgeTone.warning, icon: Icons.cloud_off_outlined)` | 「14:40 嘗試驗證 · 未判定是否有效」 | `helperText` in warningFg: 「無法連線到中央氣象署：<原因原文>。授權碼已儲存，但尚未確認是否有效。請確認網路後按「重新驗證」。」 | all enabled | **no banner**; data pages keep using the stored key and show their own network errors |

### Data pages without a key

| State | Widget | Copy |
|---|---|---|
| No key (`ApiKeyIssue.missing` / `unreadable`) | whole-page `EmptyState(icon: Icons.key_outlined, title: '需要 API 授權碼', text: '尚未設定中央氣象署 API 授權碼，無法取得資料。請到「設定」輸入授權碼。', actions: [AppButton('前往設定', primary)])` (`status.dart:78`) | no `SourceLine` |
| Key rejected (`ApiKeyIssue.rejected`) | per card `StatusBanner(tone: error, title: 'API 授權碼無效', text: reason, actions: [AppButton('前往設定', small, primary)])` | |

「前往設定」 = `ref.read(appTabProvider.notifier).select(AppTab.settings)`.

## 9. New components and changes

| Component | Where | Why | Shape |
|---|---|---|---|
| `AppSwitch` | `lib/core/widgets/choices.dart` | No switch in `lib/core/widgets` | Material 3 `Switch` (track 52 × 32, thumb 16 off / 24 on), `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap` so its layout box is exactly 32 high and centres in the row (the row is the tap target); on track brandBg, thumb fgOnBrand; off track bg4 + 2 px outline strokeAccessible, thumb strokeAccessible; disabled bgDisabled/fgDisabled. `({required bool value, required ValueChanged<bool>? onChanged, required String semanticLabel})` |
| `AppTextField` | new `lib/core/widgets/inputs.dart` | search + token fields; promote `_SearchField` (`location_screen.dart:887`) and delete the private copy | `({String? label, String? hint, IconData? prefixIcon, Widget? suffix, bool readOnly, bool autofocus, bool obscureText, String? errorText, String? helperText, Color? helperColor, VoidCallback? onTap, ValueChanged<String>? onChanged, TextEditingController? controller})`; label body1Strong above; label→field s8, field→message s4. **Default `variant: AppTextFieldVariant.filled` = M3 filled text field**: `filled: true, fillColor: AppPalette.bg4`; `UnderlineInputBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.extraSmall)))` for every state (top corners 4, bottom square); active indicator `enabledBorder`/`disabledBorder` 1 px `strokeAccessible`, `focusedBorder` 2 px `brandStroke`, `errorBorder`/`focusedErrorBorder` 2 px `dangerFg`; `isDense: true`, `contentPadding: EdgeInsets.symmetric(horizontal: s12, vertical: s12)`, `textAlignVertical: TextAlignVertical.center`, `constraints: BoxConstraints(minHeight: AppSize.control)`, `prefixIconConstraints`/`suffixIconConstraints: BoxConstraints.tightFor(width: AppSize.touch, height: AppSize.control)` (icons centred, field exactly 44). `variant: AppTextFieldVariant.search` = M3 search bar: `fillColor: bg1`, `OutlineInputBorder(AppRadius.full)` 1 px `strokeAccessible` (focus 2 px `brandStroke`), padding h s16 |
| `BadgeTone.success / danger / warning` | `data_display.dart:6`, switch at `:18` | token 有效 / 無效 / 無法驗證; `alert3` is the rain-level red | success/danger/warning Bg, Fg, Stroke tokens |
| `AppList.children: List<Widget>` | `data_display.dart:177` | groups mix rows and blocks | type widening |
| `AppListRow.flushTrailing` (bool, default false) | `data_display.dart:203`, padding at `:241` | aligns icon-button glyphs with the other trailing glyphs (§10, fixes 3 and 16) | padding `flushTrailing ? EdgeInsets.fromLTRB(s16, s8, s4, s8) : EdgeInsets.symmetric(horizontal: s16, vertical: s12)` |
| `_PlaceWeather`, `_QuietHoursBar`, `_GroupLabel`, `_Block` | page-local | §4, §5, §7 | small helpers |
| `AppTheme.light` additions | `app_theme.dart` | dialog / time picker / snackbar shapes (§11) | `dialogTheme`, `timePickerTheme`, `snackBarTheme` shapes |

## 10. Spacing and alignment fixes (revision 2)

Audit result: shared lines are left 16 (title, icon, sub-label, footnote), text column 60, and right 16 (every trailing glyph and meta). Vertical rhythm: s4 within a field group, s8 within a group shell, s12 inside rows and blocks, s16 between groups.

| # | Element | Before | After | Why |
|---|---|---|---|---|
| 1 | Section title / meta horizontal inset | `SectionHeader` at 0 (title 16 px left of the row icons) | `Padding(horizontal: AppSpace.s16)` | title on the icon line, meta on the trailing line |
| 2 | Footnote (`_Note`) inset | 4 (`--space-4`) | `AppSpace.s16` | footnote icon on the same left line |
| 3 | Rows ending in an `AppIconButton` (trash, refresh) | end padding 16 → glyph right edge 28 from the edge (44 box, 20 glyph) while switch/chevron/badge edges were at 16 | `flushTrailing: true` → end padding `AppSpace.s4`; glyph edge 4 + 12 = 16 | one right edge for every trailing control |
| 4 | Gap between trailing items (badge, weather, button) | Dart `spacing: AppSpace.s4` (`location_screen.dart` `_savedRow` trailing Row) vs mockup 8 | `AppSpace.s8` everywhere; glyph↔temperature `AppSpace.s4` | consistent gap; the pair reads as one value |
| 5 | Temperature column | free width (`Text(temp)`) → digits drift between 9° and 28° | `SizedBox(width: AppSize.icon32)`, `TextAlign.end`, tabular | temperatures right-aligned in one column |
| 6 | Field label → field | 8 | **`AppSpace.s8`** (rev 2 briefly set s4; restored in fix 20) | label clearly separated from the field |
| 7 | Field → helper / error text | 8 | `AppSpace.s4` | message belongs to its field |
| 8 | Field group → button row (block items) | 8 | ~~`AppSpace.s12`~~ superseded by fix 23 (s16) | |
| 9 | 「隔日」 badge → time | 8 (generic trailing gap) | `AppSpace.s4` (badge + time in their own Row), then s8 to the chevron | badge qualifies the time value |
| 10 | Quiet-hours bar left edge | 16 (block padding; bar started under the icons) | `AppSpace.s16 + AppSize.controlSm + AppSpace.s12` = 60 | bar starts on the 開始/結束 text column |
| 11 | Token wide layout, secondary buttons | `small` (32 high) | normal (44 high) | all token buttons one height |
| 12 | Search field padding | start 12 / end 4 (shared with the token field's 44 suffix button) | `AppSpace.s16` both sides (pill shape needs the larger inset) | text inset symmetric; content clear of the round ends |
| 13 | Locating row leading | spinner directly in the row | spinner centered in the 32 `_Tint` | leading slot always 32 wide; text stays on the 60 line |
| 14 | Group→group gap (inside a cell vs between cells) | 16 in the mockup, not stated for Dart | `Column(spacing: AppSpace.s16)` = `AppLayout.gridGap` | equal gaps in 1- and 2-column layouts |

| 15 | Text inside buttons, badges, rows (Flutter) | `AppType` styles set `height` (e.g. body1 20/14) with Flutter's default `TextLeadingDistribution.proportional` → extra leading split by the font's ascent/descent ratio, so CJK labels sit 1–2 px off centre in 32/44 buttons | add `leadingDistribution: TextLeadingDistribution.even` to every `AppType` style (`app_tokens.dart`, `AppType`); this is what CSS does by default, so app and mockup match | button text vertically centred |
| 16 | Rows whose trailing has a 44 icon button (saved places, located, locating) | vertical padding 12 → 44 + 24 = 68 high, 8 taller than the switch rows next to them | `flushTrailing` rows: padding `fromLTRB(s16, s8, s4, s8)` → 60 | every two-line row is 60 |
| 17 | Token field height | 44 min + 44 suffix button + 2 × 1 px outline = 46; next to the 44 「儲存並驗證」 button the bottoms were 2 px apart | suffix button overlaps the outline (`margin-block: -1px` in CSS; Flutter: `suffixIconConstraints: BoxConstraints.tightFor(height: AppSize.control - 2 * AppStroke.thin)` with the 44 `IconButton` hit box kept via `OverflowBox`) → field 44 | field and buttons share top and bottom edges |
| 18 | Sub-label band (「分區警特報通知」, 「其他」) | padding top 8 / bottom 4 → text not centred in its band | `EdgeInsets.symmetric(horizontal: s16, vertical: s8)` | text centred, band 32 (= `AppSize.controlSm`) |
| 19 | Pill button text padding | horizontal 16 (small 12), carried over from the 4 px buttons; in a pill the label looks cramped against the round ends | M3 common button: `AppSpace.s24` (s16 on the icon side); small: `AppSpace.s16` (s12 on the icon side); `AppIconButton` unchanged | label clear of the round ends |

Revision 3 (vertical spacing was too tight; each item supersedes the earlier value):

| # | Element | Before | After | Why |
|---|---|---|---|---|
| 20 | Field label (「授權碼」, 「手動搜尋地點」) → field | s4 (fix 6) | **`AppSpace.s8`** | label no longer crowds the field; one label→field gap for every field |
| 21 | Field → helper / error text | s4 | s4 (unchanged) | M3 supporting text spacing; message stays attached to its field |
| 22 | Padded block (field, banner, help text, bar) padding | h s16 / v s12 | **`EdgeInsets.all(AppSpace.s16)`** | the field block no longer sits tight under the 授權碼 status row divider |
| 23 | Block → block, item → item inside a block (field group → button row, banner → banner) | s12 (fix 8) | **`AppSpace.s16`** | one block gap everywhere |
| 24 | Section header → list, list → footnote | s8 | **`AppSpace.s12`** | title and footnote get air; still clearly closer than group→group s16 |
| 25 | Quiet-hours bar block | v s12 | v s16 | same as every block (start padding stays on the 60 text column) |
| 26 | Row height | padding result: 56 / 60, icon-button rows 60 | fixed minimum **56 one-line / 64 two-line** (`AppSize.listRowOneLine` / `listRowTwoLine`), content centred | equal heights regardless of what the trailing holds; two-line rows get 4 px more air above and below |
| 27 | Switch | 40 × 20 custom | M3 `Switch` 52 × 32, shrink-wrapped tap target | matches Material 3; the 32 box centres exactly in a 64 row |

Unchanged on purpose: row horizontal padding s16 (s4 end for icon-button rows), leading→text s12, trailing gap s8, divider full-bleed, sub-label band s8 / s8, group→group s16 (= grid gap, so 1- and 2-column layouts match).

### 10b. Vertical centering rule (Flutter terms for the implementer)

Audit result: every row, chip, badge, button, switch row, icon + text pair and text field is centred on its row's cross axis. Apply these rules:

1. **Text height behaviour, app-wide.** Add `leadingDistribution: TextLeadingDistribution.even` to every `AppType` style (`app_tokens.dart`, `AppType`). Also wrap the app in `DefaultTextHeightBehavior(textHeightBehavior: TextHeightBehavior(leadingDistribution: TextLeadingDistribution.even), child: …)` (`MaterialApp.builder`). Material widgets that build their own `TextStyle` (TextField input and hint, button labels, `Tooltip`) then centre too. Without this, `height: 20/14` puts the extra leading under CJK glyphs, so they sit 1–2 px low.
2. **Rows.** `AppListRow`: `ConstrainedBox(minHeight: secondary == null ? AppSize.listRowOneLine : AppSize.listRowTwoLine)` → `Padding` (the padding is a floor) → `Row(crossAxisAlignment: CrossAxisAlignment.center)`. Leading `_Tint` is a fixed 32 × 32 box with its icon in `Center`. Content is a `Column(mainAxisSize: min, crossAxisAlignment: start)`. Trailing is a `Row(mainAxisSize: min, crossAxisAlignment: center, spacing: s8)`. No `CrossAxisAlignment.start` or `baseline` anywhere in a row.
3. **Fixed-size controls inside rows.** `AppIconButton` 44 × 44 with `padding: EdgeInsets.zero` (already). `AppSwitch` with `materialTapTargetSize: shrinkWrap` (layout box 52 × 32). `AppBadge` `minHeight: AppSize.icon20` with `Row(crossAxisAlignment: center)` (already). The time value is `Row(crossAxisAlignment: center, spacing: s4, [badge, text])`.
4. **Single-line icon + text pairs** (buttons, badges, chips, `_PlaceWeather`, nav labels): `Row(mainAxisSize: min, crossAxisAlignment: CrossAxisAlignment.center)`. The icon is no taller than the text line: 16 with caption1 (16 lh), 20 with body1 (20 lh).
5. **Multi-line icon + text pairs** (footnotes, `StatusBanner`): `Row(crossAxisAlignment: CrossAxisAlignment.start)`. The icon sits in `SizedBox(height: <first line's lh>, child: Center(child: icon))`, i.e. 16 for caption1 footnotes and 20 for a body1Strong banner title, so it centres on the first line.
6. **Buttons.** `AppButton` keeps `minimumSize` height 44 (small 32) and horizontal-only padding. Label `Row(mainAxisSize: min, crossAxisAlignment: center)`. Centring then comes from rule 1.
7. **Text field.** `textAlignVertical: TextAlignVertical.center`, `isDense: true`, `contentPadding` vertical s12 (20 lh + 2 × 12 = 44). Prefix and suffix constraints are `tightFor(width: AppSize.touch, height: AppSize.control)` so icons sit in the field's centre line.
8. **Section header.** `SectionHeader` row is already `minHeight: AppSize.controlSm` with a centred `Row`. The meta text (caption1) centres against the subtitle1 title.

New size tokens (frontend member adds them): `AppSize.listRowOneLine = 56`, `AppSize.listRowTwoLine = 64` in `app_tokens.dart` `AppSize`; `--size-list-row-1: 56px`, `--size-list-row-2: 64px` in `tokens-fluent2-light.css` sizes. The mockup previews both in its `:root` preview block.

**Token field (user decision, revision 3):** Material 3 **filled** text field: grey filled container, top corners 4 (extra-small), bottom corners square, bottom active indicator 1 px (2 px focused or error). Material Web: `--md-filled-text-field-container-shape: --md-sys-shape-corner-extra-small`, applied to the top corners only. The search field stays an M3 search bar (full).

## 11. Shape: Material 3 shape scale (app-wide)

### New tokens (frontend member applies; this designer did not edit them)

`lib/core/theme/app_tokens.dart` `AppRadius` (`:195-201`), replaced in full:

```dart
/// Material 3 shape scale (`--shape-*`).
abstract final class AppRadius {
  static const double none = 0;
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 28;
  static const double full = 9999;
}
```

`docs/design/tokens-fluent2-light.css` (`:197-201` and the header comment `:7`): replace the `--radius-*` block with

```css
  --shape-none: 0px;
  --shape-extra-small: 4px;   /* text fields, skeletons, swatches, tooltips, snackbars */
  --shape-small: 8px;         /* chips, inner panels and tiles inside a card */
  --shape-medium: 12px;       /* cards, list groups, banners, map clips */
  --shape-large: 16px;        /* FAB, navigation drawer */
  --shape-extra-large: 28px;  /* dialogs, time picker, bottom sheets */
  --shape-full: 9999px;       /* buttons, icon buttons, badges, switches, segmented, nav indicators */
```

The old names `sm`, `md`, `lg`, `circular` (and `--radius-*`) are removed, not aliased, so the compiler and grep catch every usage. Each usage must be re-chosen by role (table below), not renamed by value.

### Role table

| Element | M3 role | Token | Old |
|---|---|---|---|
| Card (`AppCard`, hero included) | medium | `AppRadius.medium` 12 | lg 12 |
| List group (`AppList`) | medium | medium 12 | md 8 |
| Status banner (`StatusBanner`, also `AppCard.error/empty`) | medium (replaces a card) | medium 12 | md 8 |
| Text field (`AppTextField`, default variant `filled`; token key) | **M3 filled text field**: extra-small **top** corners, bottom corners square | top 4 / bottom 0 (`UnderlineInputBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.extraSmall)))`); container `bg4`; active indicator 1 px `strokeAccessible`, 2 px `brandStroke` focused, 2 px `dangerFg` error | sm 4 all corners, white, Fluent bottom accent |
| Search field (`AppTextField(variant: search)`, opens the picker) | M3 search bar: full | full; same 44 height and 1 px outline; horizontal padding s16 | sm 4 |
| Time picker input boxes | M3 time-input: small | `timePickerTheme.hourMinuteShape` small 8 | default |
| Button (`AppButton` all variants) | full | full | sm 4 |
| Icon button (`AppIconButton`) | full | full (IconButton default circle) | circle |
| Badge (`AppBadge`) | full | full | circular |
| Chip (`AppChip`) | small | small 8 | StadiumBorder |
| Segmented (`AppSegmented` container + segment) | full | full | md 8 / sm 4 |
| Switch (`AppSwitch`) | full | full (Material 3 default, 52 × 32 track) | — |
| Dialog (`AlertDialog`, time picker) | extra-large | extraLarge 28 via `dialogTheme` / `timePickerTheme` | Material default |
| Snackbar, tooltip | extra-small | extraSmall 4 via theme | default |
| Metric tile, inner panels in a card | small | small 8 | sm 4 / md 8 |
| Skeleton, swatches, small chart clips | extra-small | extraSmall 4 | sm 4 |
| Navigation bar / rail indicator, progress bars, dots | full | full | Stadium / circular |
| FAB (`.fab`) | large | large 16 | md 8 |

### Usage map for `lib/` (old → new)

| File:line | Element | Old → new |
|---|---|---|
| `core/widgets/app_card.dart:137` | card | lg → medium |
| `core/widgets/data_display.dart:33` | badge | circular → full |
| `core/widgets/data_display.dart:108` | metric tile | sm → small |
| `core/widgets/data_display.dart:185` | list group | md → medium |
| `core/widgets/buttons.dart:67` | button | sm → full |
| `core/widgets/choices.dart:29` | chip `StadiumBorder` | → `RoundedRectangleBorder(BorderRadius.circular(AppRadius.small))` |
| `core/widgets/choices.dart:86` | segmented container | md → full |
| `core/widgets/choices.dart:122` | segment | sm → full |
| `core/widgets/status.dart:45` | status banner | md → medium |
| `core/widgets/status.dart:148` | skeleton | circular → full; sm → extraSmall |
| `core/widgets/page_scaffold.dart:143` | title tap ink | sm → small |
| `features/location/location_screen.dart:617` | `_RowTile` (row as card) | md → medium |
| `features/location/location_screen.dart:896` | search field (moves to `AppTextField(variant: search)`) | sm → full (M3 search bar); picker's in-page search field uses the same variant |
| `features/weather/weather_screen.dart:195` | ink over a status banner | md → medium (matches banner) |
| `features/weather/weather_screen.dart:341` | pill | circular → full |
| `features/weather/widgets/hero_card.dart:117` | rain panel inside hero | md → small |
| `features/weather/widgets/weekly_card.dart:194, :204` | temperature bar | circular → full |
| `features/weather/widgets/forecast_72h_card.dart:90` | stat tile in card | md → small |
| `features/weather/widgets/forecast_72h_card.dart:142` | chart clip | sm → extraSmall |
| `features/weather/widgets/forecast_72h_card.dart:178` | legend line | circular → full |
| `features/weather/widgets/forecast_72h_card.dart:197` | 8 px legend dot | sm → full |
| `features/radar/widgets/radar_legend.dart:31` | legend bar | circular → full |
| `features/radar/widgets/playback_card.dart:322` | frame slot tile | md → small |
| `features/radar/widgets/playback_card.dart:347` | bar | circular → full |
| `features/radar/widgets/playback_card.dart:384, :391` | settings panel + its ink | md → small |
| `features/radar/widgets/radar_map_view.dart:309` | map clip | md → medium |
| `features/radar/widgets/radar_map_view.dart:422` | on-map pill label | circular → full |
| `features/radar/widgets/radar_map_view.dart:458` | attribution plate | sm → extraSmall |
| `features/hazard/rainfall/observation_view.dart:118, :137` | bars / pills | circular → full |
| `features/hazard/rainfall/observation_view.dart:224` | swatch | sm → extraSmall |
| `features/hazard/rainfall/station_list.dart:241` | pill clip | circular → full |
| `features/hazard/rainfall/forecast_view.dart:216` | swatch | sm → extraSmall |
| `features/hazard/warnings/warning_card.dart:46` | card | lg → medium |
| `core/theme/app_theme.dart` (new) | dialog, time picker, snackbar, default `InputDecorationTheme` | add theme shapes: extraLarge, extraLarge (+ `hourMinuteShape` small), extraSmall; `inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: bg4, border: UnderlineInputBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.extraSmall))))` so any stray `TextField` also gets the M3 filled shape (replaces the `OutlineInputBorder` the frontend already added) |

### Usage map for `docs/design/components.css`

| Selector | Old → new |
|---|---|
| `.card` (`:151`), `.card--hero` (`:155`), `.list` (`:183`), `.status-banner` (`:444`), `.playback` (`:426`), `.map` (`:548`), `.map__overlay-panel` (`:560`) | md / lg → `--shape-medium` |
| `.btn` (`:246`), `.btn--icon` (`:267`), `.badge` (`:215`), `.level-dot` (`:231`), `.segmented` (`:357`), `.segmented__item` (`:363`), `.bottom-nav__icon` (`:138`), `.tab::after` (`:345`), slider track/thumb (`:391-412`), `.spinner` (`:483`), `.legend__bar` (`:499`), `.temp-range*` (`:523`, `:528`) | → `--shape-full` |
| `.chip` (`:299`), `.metric` (`:172`), `.bottom-nav__item` (`:128`) | → `--shape-small` |
| `.skeleton` (`:490`), `.legend__swatch` (`:520`) | sm → `--shape-extra-small` |
| `.fab` (`:282`) | md → `--shape-large` |
| `.field` (page-local in mockups; add to components.css with `AppTextField`) | M3 filled: `border-radius: var(--shape-extra-small) var(--shape-extra-small) 0 0`, background `--color-bg-4`, bottom indicator 1 px `--color-stroke-accessible`, 2 px focus/error; `.field--search` → `--shape-full` with a 1 px outline all round |

Older mockups that also use `--radius-*` (`docs/design/team-a/*.html`, `team-b/*.html`, `components.html`, `review/alignment-review.md`, `flutter-components.md`, other designers' `settings.html`) are history, not current UI. Recommendation: rename by value in the same change (`--radius-sm` → `--shape-extra-small`, `md` → `--shape-small`, `lg` → `--shape-medium`, `circular` → `--shape-full`, `none` → `--shape-none`), so they render as before. Update the radius row in `flutter-components.md` to the new names.

The mockup previews this scale in a clearly marked `:root` block at the top of `settings.html`. Delete that block after the tokens file changes.

## 12. Accessibility

- Touch: rows ≥ 44 (56/60 in practice). The whole row toggles its switch. Icon buttons and the field suffix are 44 × 44. `flushTrailing` changes only padding, not the 44 hit box.
- Semantics: one merged label per switch row (`toggled`). Saved-place rows read place, marker, weather and temperature. Loading rows say 「天氣載入中」. Time rows read 「靜音結束時間 隔日 07:00」.
- Live regions: token status row, locating row.
- Status never by colour alone: badges carry text + icon; the 無法驗證 message is text, not just a warning colour.
- Visible labels above both fields. The token field has autocorrect and suggestions off.
- Focus order follows reading order; in two columns, left column top to bottom, then right column.

## 13. State coverage in the mockup

| State | Frame |
|---|---|
| per-row weather: data / loading / network error / no 天氣現象 / no key | A, E / C / C / C / B |
| token 未設定 / 驗證中 / 有效 / 無效 / 無法驗證 / input error | B / C / A, E / C, D / C / C |
| clear confirmation dialog (extra-large shape) | C |
| GPS located / locating / permission denied / service off | A / C / B / C |
| notifications master off; quiet hours crossing midnight | B; A, E |
| empty saved places | C |
| phone 390 / wide 1280 | A–D / E |

## 14. Open questions

- Key format check is only "not empty, no whitespace"; the real CWA key format is not confirmed.
- Which network results count as 無法驗證 vs 無效: I propose only HTTP 401/403 (`ApiKeyIssue.rejected`) = 無效, and everything else (timeout, DNS, 5xx) = 無法驗證. Backend should confirm this matches `weather_repository.dart:96`.
- New saved places start with area warning notifications off (my default).
- Reorder is not shown (no provider support).
- The application steps were not checked against the live opendata site.
- App-wide shape change makes every button a pill and every list group 12 px. This affects all tabs, not only 設定.
