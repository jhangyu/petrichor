# 設定 tab: designer-2, Bento 狀態儀表板

Mockup: `settings.html` (same folder). Spec: `docs/logs/settings-tab-contract.md`.
Frames in the mockup: phone 390 default, first run with no token, token verifying and token invalid, GPS permission denied, location service off, auto-locate off with a search result, notifications master switch off, corrupt stored settings, data page with no token, wide 1280 default, and wide 1280 with an invalid token.

## Idea

Each card opens with a **status lead**: an icon in a tinted circle, one large line that gives the state, and a caption. A badge in the card header repeats the state as a tag. The controls come after the lead. A user who scans the page reads four facts: the current place, the locate state, whether the token is valid, and how many areas have notifications on. On wide windows the cards are a bento with deliberate spans. The two content-heavy cards (the saved places list and notifications) take 2 columns. The two short cards (地點設定 and token) take 1 column each.

## Shell changes (`lib/app_shell.dart`)

- `AppTab.location` → rename to `AppTab.settings`. Label `地點` → `設定`. Icon `Icons.location_on_outlined` → `Icons.settings_outlined` (app_shell.dart:40-45). The order stays 天氣｜雷達｜雨量｜警特報｜設定.
- `LocationScreen` → `SettingsScreen` (new file `lib/features/settings/settings_screen.dart`). Move its page-local parts from `location_screen.dart`. Delete the old screen. The project keeps no backward compatibility.

## Page layout

```
AppPageScaffold(                                   page_scaffold.dart:18
  header: AppPageHeader(title: '設定', subtitle: '變更會自動儲存'),   page_scaffold.dart:108
  children: [
    if (token missing/invalid) AppGridItem.full(child: tokenBanner),  adaptive.dart:62
    AppGridItem.full(child: AppGrid(maxColumns: _bentoColumns, children: [   adaptive.dart:81
      AppGridItem(span: 2, child: SavedPlacesCard()),               adaptive.dart:60
      LocationSettingsCard(),
      TokenCard(),
      AppGridItem(span: 2, child: NotificationCard()),
    ])),
  ],
)
```

- `_bentoColumns = 3` is a screen-local named constant. The cards use 6 span units. Without this cap, the page grid gives 5 columns at 1920 wide, and row 1 (2+1+1) leaves a hole before the span-2 notification card. With the cap, wide windows always show two rows of 3 units. No `SourceLine`: this page shows no CWA data except the saved places temperatures, and those already come from the shared observation provider. If the reviewer wants the credit line, add `SourceLine(datasetIds: ['O-A0003-001'])` only when a temperature shows.
- No width literals and no window checks in the screen. Spans are clamped by `AppGrid`.

| Window (content width) | Columns | Rows |
|---|---|---|
| compact 360–599 (≤ 567) | 1 | banner · 儲存的地點 · 地點設定 · token · 通知 |
| medium 720 (592) | 1 | same as compact |
| expanded 960 (816) | 2 | 儲存的地點 (full) · [地點設定 \| token] · 通知 (full) |
| 1280 (1136) / 1920 (1776) | 3 | [儲存的地點 ×2 \| 地點設定] · [token \| 通知 ×2] |

Reading order stays 儲存的地點 → 地點設定 → token → 通知 in every arrangement. A short-height window scrolls as one page (no `.fill`).

Interior switch for span-2 cards: `LayoutBuilder` on the card child, `c.maxWidth >= AppLayout.cardWideWidth` (520) → wide interior.

## Shared parts used by all four cards

| Element | Widget | Notes |
|---|---|---|
| Card frame, title, header badge | `AppCard(title:, trailing: AppBadge(...), child:)` app_card.dart:16 | Radius 12, padding 16/16/20, gap 16 come from AppCard. |
| Card loading (provider still reading prefs) | `AppCard.loading(title:, skeletonHeight:)` app_card.dart:30 | Each card uses its own named skeleton height. |
| Corrupt stored value | `AppCard.error(title:, message:, onRetry:)` app_card.dart:45 | See "Corrupt data" below. |
| Header badge | `AppBadge(label:, tone:)` data_display.dart:10 | Tones: neutral, brand (使用中 / 驗證中), alert2 (GPS problems), alert3 (token 無效), **success (new tone, see below)**. |
| Status lead | **new** page-local `_StatusLead({icon, tone, value, caption})` | Justified below. |
| On/off row | **new** shared `AppSwitchRow({label, hint, value, onChanged})` in `choices.dart` | Justified below. |
| Divider between groups | `Divider(height: AppStroke.thin, thickness: AppStroke.thin, color: AppPalette.stroke3)` | Same colour as the `AppList` row separator. |
| Short note / help text | `Text(..., style: AppType.caption1.copyWith(color: AppPalette.fg3))`, same as `_Meta` location_screen.dart:999 | Capped at `AppLayout.readingWidth`. |

### New component 1: `_StatusLead` (page-local, settings_screen.dart)

- Layout: a `Row` with a 44 (`AppSize.touch`) circle (`AppRadius.circular`), an icon of `AppSize.icon24`, then a `Column` with value (`AppType.title3`, fg1) and caption (`AppType.caption1`, fg3; dangerFg when the tone is bad).
- Tones map to existing palette pairs: info = `brandBgSubtle`/`brandFg`; ok = `successBg`/`successFg`; warn = `warningBg`/`warningFg`; bad = `dangerBg`/`dangerFg`; off = `bg4`/`fg3`. The loading state puts `AppSpinner` (status.dart:117) in the circle.
- Why new: no shared widget shows "state as a big value plus a caption". `MetricTile` (data_display.dart:88) is one line, ellipsized, and has no tone. `StatusBanner` is a coloured box that would make every card look like an alert. The settings page is the only user, so the widget stays page-local (system.md §5 rule). It generalizes `_Tint` (location_screen.dart:869), which it replaces.
- Semantics: `Semantics(container: true, label: '$value，$caption')`, so a screen reader announces the state once.

### New component 2: `AppSwitchRow` (shared, `lib/core/widgets/choices.dart`)

- It is the radar 重複播放 row moved out of the radar code (playback_card.dart:455-479): label (`body1Strong`, fg1) plus an optional hint (`caption1`, fg3), and a trailing Material `Switch` with the same token colours (`activeTrackColor: brandBg`, `inactiveTrackColor: strokeAccessible`, thumb `bg1`, transparent outline).
- Why shared: radar and settings both use it (two screens meet the foundation rule). It replaces the inline radar copy, so `playback_card.dart` uses it too. There are not two versions.
- Params: `label` (String, required), `hint` (String?), `value` (bool, required), `onChanged` (ValueChanged<bool>?; null = disabled, label and hint in `fgDisabled`).
- Touch and accessibility: the whole row is the tap target (`InkWell` → `onChanged(!value)`), min height `AppSize.touch`. `MergeSemantics` so the label is read with the switch state. No separate tooltip is needed.

### New badge tone: `BadgeTone.success`

- Add one value to `BadgeTone` (data_display.dart:6), mapped to `successBg`/`successFg`/`successStroke`, which already exist in `AppPalette`. It is used for 有效 and 已定位. Why: the only green-free alternative is `brand`, which already means 使用中 on the same page. `alert*` tones mean hazard levels and must not mean "OK".

## Card 1: 儲存的地點 (span 2)

| Element | Widget | Copy |
|---|---|---|
| Header | `AppCard(title: '儲存的地點', trailing: AppBadge(label: '${n} 個地點'))` | 儲存的地點 · 4 個地點 |
| Lead | `_StatusLead(tone: info, icon: Icons.place_outlined)` | value = current place 「新北市 樹林區」; caption 「目前地點 · 來自 GPS 定位」 or 「目前地點 · 手動選擇」. No place: tone off, 「尚無目前地點」 / 「開啟自動定位或在「地點設定」搜尋」 |
| Rows, narrow (< 520) | `AppList` data_display.dart:175 of `AppListRow` data_display.dart:204 | Built exactly like the current `_savedRow` (location_screen.dart:677): leading tint, primary 「縣市 區」, secondary = weather text, trailing = `AppBadge('使用中', brand)` + temperature + `AppIconButton(Icons.delete_outline, tooltip: '移除{地點}')` buttons.dart:109. `selected` = current place. `onTap` = `currentPlaceProvider.select`. |
| Rows, wide (≥ 520) | `AppGrid(minColumnWidth: AppLayout.paneMinWidth, children: [_RowTile(...)])` | `_RowTile` (location_screen.dart:606) moves with the screen. At 1280 this gives 2 tiles per row. |
| Footnote | caption text | 「點一下地點設為目前地點；要新增地點，請在下方「地點設定」搜尋。」 (wide: 「在「地點設定」搜尋」) |
| Loading | `AppCard.loading(title: '儲存的地點', skeletonHeight: _placesSkeletonHeight)` | |
| Read error | `AppCard.error(title: '無法讀取已儲存的地點', message: Failure.message, onRetry: invalidate)` | |
| Empty | lead in the off tone; no list | |
| Row temperature without a token | secondary 「需要授權碼」, trailing 「—」 | No fake values. |

- **Reorder: not shown.** `SavedPlacesNotifier` (place_provider.dart:208-227) supports only save and remove, and the contract says "reorder if already supported".
- **Delete** has no confirm dialog (same as today). Undo is out of scope.
- Accessibility: each delete button has its own tooltip with the place name. The selected row sets `selected` so `AppListRow` paints `brandBgSubtle`, and the 使用中 badge carries the meaning in text, not only in colour.

## Card 2: 地點設定 (span 1)

| Element | Widget | Copy |
|---|---|---|
| Header | `AppCard(title: '地點設定', trailing: AppBadge(...))` | badge by state: 已定位 (success) · 定位中 (brand) · 權限被拒 (alert2) · 定位服務關閉 (alert2) · 手動 (neutral) |
| Lead | `_StatusLead` | located: ok, 「自動定位開啟」 / 「新北市 樹林區 · 14:10 定位」 · locating: spinner, 「定位中…」 · denied: warn, 「無法自動定位」 / 「目前沿用：{上次地點}」 · service off: warn, 「定位服務未開啟」 / same caption · off: off, 「自動定位關閉」 / 「目前地點：{地點}（手動選擇）」 |
| Auto-locate switch | `AppSwitchRow(label: '自動定位', hint: '以裝置位置作為目前地點')` | On → `currentPlaceProvider.useGps()` (place_provider.dart:178). Off → persist the flag false and keep the current place. |
| Re-locate | `AppButton(label: '重新定位', icon: Icons.my_location, small: true)` buttons.dart:11, right-aligned | Shown only when located. Disabled while locating. |
| Permission denied | `StatusBanner(tone: permission, title: '未取得位置權限', text: '請到系統設定允許「CWA 天氣」使用位置，或用下方搜尋手動選擇。', actions: [AppButton('前往系統設定', primary, small) → Geolocator.openAppSettings])` status.dart:12 | Same handler as today (location_screen.dart:246). |
| Service off | `StatusBanner(tone: permission, title: '裝置的定位服務已關閉', text: '開啟後按「重試」。', actions: [AppButton('前往系統設定') → Geolocator.openLocationSettings, RetryButton(onPressed: useGps)])` status.dart:156 | |
| Divider | see shared parts | |
| Search field | `_SearchField` (location_screen.dart:887) moved here, with a **visible label** above it: `Text('手動搜尋地點', style: caption1 w600 fg2)` and hint 「輸入縣市或鄉鎮市區，例如 板橋」 | The label is not only a placeholder (form rule). |
| Help text | caption | 「選擇搜尋結果會設為目前地點並關閉自動定位；按書籤可儲存。」 |
| Results | `AppList` of `AppListRow(primary: '新北市 板橋區', secondary: '點一下設為目前地點', trailing: AppIconButton(Icons.bookmark_border, tooltip: '儲存新北市 板橋區'))` | Tap → `select(place)` and auto-locate off. Bookmark → `savedPlacesProvider.save`. Already saved → `Icons.bookmark` and the button is disabled with tooltip 「已儲存」. |
| No match | `AppCard.empty`-style `StatusBanner(tone: empty, title: '找不到「{q}」')` | |

The search matches county and town names over the existing town data (`townsProvider`, place_provider.dart:229). The architecture plan owns how the index is built. The county-chip picker from the old screen is removed: one search field replaces it, as the contract asks.

## Card 3: token 設定 (span 1)

| Element | Widget | Copy |
|---|---|---|
| Header | `AppCard(title: 'token 設定', trailing: AppBadge(...))` | 未設定 (neutral) · 驗證中 (brand) · 有效 (success) · 無效 (alert3) |
| Lead | `_StatusLead` | 未設定: off, 「尚未設定授權碼」 / 「貼上授權碼後按「儲存」，會自動驗證一次」 · 驗證中: spinner, 「驗證中…」 / 「正在向中央氣象署確認授權碼」 · 有效: ok, 「授權碼有效」 / 「{MM/dd HH:mm} 驗證通過」 · 無效: bad, 「授權碼無效」 / 「{MM/dd HH:mm} 驗證失敗」 |
| Field label | caption1 w600 fg2 | 「中央氣象署 API 授權碼」 |
| Field | **page-local `_TokenField`**: a `TextField` with the same `InputDecoration` as `_SearchField` (location_screen.dart:902-920), `obscureText: !_visible`, `autocorrect: false`, `enableSuggestions: false`, prefix `Icons.key_outlined`, suffix `AppIconButton(icon: visible ? Icons.visibility_off_outlined : Icons.visibility_outlined, tooltip: visible ? '隱藏授權碼' : '顯示授權碼')` | Hint 「CWA-XXXXXXXX-XXXX-XXXX」. Invalid → `errorText` = the reason, error border `dangerFg` thick. Why page-local: one field on one page. `_SearchField` and `_TokenField` share a private `_fieldDecoration()` helper in the same file, so the decoration exists only once. |
| Help under field | caption fg3 | 「授權碼只存在這台裝置。」 |
| Invalid reason | `errorText` under the field (dangerFg, with an error icon) | The text from the verify `Failure.message` as-is, e.g. 「中央氣象署回應 401：授權碼不存在或已停用。請確認是否完整複製。」 |
| Buttons | `Row` capped at `readingWidth`: `Expanded(AppButton('儲存', primary))`, `Expanded(AppButton('驗證' / '重新驗證' / '驗證中…', secondary))`, `AppButton('清除', subtle)` | 儲存 is enabled only when the field differs from the stored key and is not blank. It saves and then runs one verify. 驗證 is enabled when a key is stored. 清除 is enabled when a key is stored; it deletes the key, and the state becomes 未設定 (no confirm; the user can paste again). While verifying, all three are disabled and the field is read-only. |
| How to apply (plain text, not a link) | caption, selectable (`SelectableText`) | 「**如何取得授權碼：**到中央氣象署「氣象資料開放平臺」opendata.cwa.gov.tw 註冊並登入，在會員頁面的「取得授權碼」複製後貼到上方。」 |

Page banner (outside the card, `AppGridItem.full` at the top, only when the key is missing or invalid):
`StatusBanner(tone: error, title: '尚未設定 API 授權碼' | 'API 授權碼無效', text: '天氣、雷達、雨量、警特報都需要中央氣象署授權碼才能載入資料。' | '中央氣象署拒絕了目前的授權碼，所有資料頁暫停載入。', actions: [AppButton('前往輸入' | '前往修正', primary, small)])`. The button calls `Scrollable.ensureVisible` on the token card's `GlobalKey` and focuses the field. The token card does not move, so the layout does not jump.

Other data pages (天氣, 雷達, 雨量, 警特報) with no key or an invalid key: a full-row `EmptyState(icon: Icons.key_outlined, title: '需要中央氣象署授權碼', text: '尚未設定授權碼，無法載入{頁面}資料。請到「設定」輸入授權碼。' | '授權碼無效，…', actions: [AppButton('前往設定', primary) → appTabProvider.select(AppTab.settings)])` status.dart:79. They show no `SourceLine` and no default data.

## Card 4: 通知設定 (span 2)

| Element | Widget | Copy |
|---|---|---|
| Header | `AppCard(title: '通知設定', trailing: AppBadge(label: '僅儲存偏好'))` | The badge is always shown in this round. |
| Lead | `_StatusLead` | on: info, `Icons.notifications_outlined`, 「{n} 區開啟」 / 「降雨提醒{開/關} · 靜音 {HH:mm}–{HH:mm}」 (「靜音關閉」 when off) · master off: off, `Icons.notifications_off_outlined`, 「通知已關閉」 / 「下方設定已保留，重新開啟即恢復」 |
| Honesty note | a `Container` with bg2, `AppRadius.md`, info icon 16 + caption fg3, capped at readingWidth | 「此版本只會儲存你的通知偏好，尚未發送任何通知。」 No copy says a notification will be or was delivered. |
| Master | `AppSwitchRow(label: '啟用通知', hint: '總開關；關閉時保留下方設定')` | Off → every row below gets `onChanged: null` (disabled look). Values are kept. |
| Per-area group title | caption1 w600 fg2 | 「分區警特報通知（每個儲存的地點為一區）」 |
| Per-area rows | one `AppSwitchRow(label: '{縣市 區}')` per saved place, in saved order | Saved list empty → caption 「尚無儲存的地點；在「地點設定」搜尋並儲存後即可設定。」 Removing a place removes its entry. |
| 降雨提醒 | `AppSwitchRow(label: '降雨提醒', hint: '目前地點即將下雨時提醒')` | |
| 靜音時段 | `AppSwitchRow(label: '靜音時段', hint: '這段時間內不提醒')` | |
| Start / end | two `Expanded(AppButton(label: '開始  22:00' / '結束  07:00', icon: Icons.schedule, variant: secondary))` in a `Row(spacing: AppSpace.s8)` | Tap → Material `showTimePicker` (built-in, `initialEntryMode: TimePickerEntryMode.input` on desktop). Disabled when 靜音時段 or the master switch is off. Start equal to end is rejected inline (caption dangerFg 「開始與結束不可相同」), and the value is not saved. |
| Day bar | **page-local `_QuietHoursBar`**: a 8-high rounded track (`bg4`) with one or two `brand120` fills, and tick labels 0 6 12 18 24 (`caption2`, fg3, tabular) | Why: the bar shows at a glance that 22:00 → 07:00 wraps past midnight. It is two `FractionallySizedBox` blocks in a `Stack`, without a painter. It is decorative: `ExcludeSemantics`. The text below carries the meaning. |
| Crossing text | caption fg3 | start < end: 「{start} 至 {end}，共 {h} 小時」 · start > end: 「跨日：{start} 至隔天 {end}，共 {h} 小時」 |

Wide interior (card width ≥ `cardWideWidth`): two `Expanded` columns with `AppLayout.gridGap` between them. Left: master, 降雨提醒, 靜音時段 with times and bar. Right: per-area list. Narrow: one column in the order master → per-area → 降雨提醒 → 靜音時段.

## Corrupt data (all persisted settings)

The contract asks for a strict parse, where a corrupt value is an error state, as in `RadarSetting`. A card whose stored value fails to parse is replaced by `StatusBanner(tone: error, title: '無法讀取{通知設定 | 地點設定 | 授權碼}', text: <parse error as-is, e.g. 儲存的通知設定格式錯誤（quietStart: "25:00"）>, actions: [AppButton('重設{通知設定 | 地點設定 | 授權碼}', small: true)])`. Reset deletes the stored value and rebuilds the provider. `AppCard.error` is not used here: its only action is 重試, and a retry cannot fix a corrupt value. The page shows no default values in place of the corrupt one.

## Copy rules

- Tab and page title: 設定. Header subtitle: 「變更會自動儲存」 (switch and time changes persist at once; only the token needs 儲存).
- Times use 24-hour `HH:mm` with tabular digits (`AppType.tabular`).
- No claims about delivered notifications.

## Accessibility

- Touch targets: `AppSwitchRow` (whole row, min height `AppSize.touch`), `AppIconButton` (44), and the full-size `AppButton` (44) all meet 44. Known gap: the small `AppButton`s (重新定位 and the banner actions) are 32 high (`AppSize.controlSm`), the same as on the current location screen. If the user wants strict 44, use full-size buttons there. This costs height only.
- Visible labels on both text fields. The token field's show/hide button announces its state through the tooltip text (顯示授權碼 / 隱藏授權碼).
- State is never colour-only: every badge and lead has text.
- The page and card banners for errors use `StatusBanner`. The invalid reason sits next to the field (`errorText`).
- Each switch row is one semantics node: 「新北市 樹林區，開關，已開啟」.
- Light theme only.

## Widget inventory

Existing: `AppPageScaffold`, `AppPageHeader`, `AppGrid`, `AppGridItem`, `AppCard` (+ `.loading`, `.error`), `AppBadge`, `AppList`, `AppListRow`, `AppButton`, `AppIconButton`, `StatusBanner`, `EmptyState`, `AppSpinner`, `RetryButton`, Material `Switch` (token-styled, as in radar), Material `showTimePicker`, `TextField`.
Moved from the old location screen: `_SearchField`, `_RowTile`, the `_savedRow` logic.
New: `AppSwitchRow` (shared, also used by radar), `BadgeTone.success`, and page-local `_StatusLead`, `_TokenField`, `_QuietHoursBar`.
Removed: `location_screen.dart` and its explainer, picker and hero views, together with their tests, if any exist.
