# 設定 tab — designer-5「地點為主角」

Mockup: `settings.html` (same folder). Contract: `docs/logs/settings-tab-contract.md`.
Layout rules: `docs/design/adaptive/system.md`. Widget table: `docs/design/flutter-components.md`.

## 1. Idea

- Saved places are the hero. Each saved place is a rich card: name, source (GPS 目前位置 / 手動加入), current temperature, and its own 警特報通知 switch.
- The per-area notification setting lives on the place card, not in a separate list. A place and its area alert setting are one object for the user.
- The 通知設定 card holds only the global settings: 通知總開關, 降雨提醒, 靜音時段.
- Search and auto-locate (地點設定) sit directly above the places.
- Reorder is not offered: the current code cannot reorder saved places (`SavedPlacesNotifier` in `lib/features/location/place_provider.dart` has only `save` and `remove`).

## 2. Shell and page

| Item | Spec | Widget |
|---|---|---|
| Tab | Label 地點 → **設定**, icon `Icons.settings_outlined`. Enum value `AppTab.location` → `AppTab.settings`. | `lib/app_shell.dart:13` (enum), `:44` (tab entry) |
| Page | Scrolling grid. No `.fill`. | `AppPageScaffold` `lib/core/widgets/page_scaffold.dart:17` |
| Header | title 設定; subtitle 「目前地點：臺北市 信義區」, or 「目前地點：臺中市 西屯區（手動）」, or 「尚未設定授權碼」 when there is no key (the key outranks the place). No header actions; 重新定位 moves into the 地點設定 card. | `AppPageHeader` `page_scaffold.dart:107` |
| Source line | None. The page shows settings, not CWA data. The place cards show temperatures, but the dataset is credited on the home page. | — |
| Picker | 「手動搜尋地點」 opens the existing picker (`_PickerView`, `lib/features/location/location_screen.dart:423`) unchanged: back arrow, county chips, towns, 儲存 / 設為目前地點. | existing |

### Grid (children of `AppPageScaffold`, in reading order)

| # | Child | Span |
|---|---|---|
| 0 | Missing-token banner (only when the key is 未設定 or 無效) | `AppGridItem.full` |
| 1 | Place area: 地點設定 + 儲存的地點 | `AppGridItem.full` with a `LayoutBuilder`: `AppTwoPane.fits(w)` → `AppTwoPane(sideFirst: true, side: 地點設定, main: 儲存的地點)`; else a `Column(spacing: AppSpace.s16)` with the two cards stacked |
| 2 | Global settings: 通知設定 + token 設定 | `AppGridItem.full(child: AppGrid(children: [通知設定, token設定]))` — two halves when both fit `AppLayout.gridMinColumn`, else stacked |

`AppGridItem` `lib/core/layout/adaptive.dart:59`, `AppGrid` `:81`, `AppTwoPane` `:151`.

Why full rows instead of four 1-column cells: four cells on a 3-column window (1280) leave one cell empty in the second row, and at 2 columns the short 地點設定 card would sit beside the tall place list. Full rows give the same picture at every width.

| Window | Columns / panes | Result |
|---|---|---|
| compact (390) | 1 column | 地點設定 → 儲存的地點 → 通知設定 → token 設定 |
| medium (720, content 592) | `AppTwoPane.fits` false; inner `AppGrid` 1 column | same as phone |
| expanded (960, content 816) | two panes (side 320, main ≈ 480); halves | place tiles use the narrow interior |
| large (1280, content 1136) | two panes (side 448, main 672); halves | place tiles use the wide interior (one row each) |

Inner text, fields and button groups are capped at `AppLayout.readingWidth` (640) with `ConstrainedBox`. No width literals in the screen file.

## 3. Card 1 — 地點設定

| Element | Copy | Widget |
|---|---|---|
| Card | title 地點設定 | `AppCard` `lib/core/widgets/app_card.dart:15` |
| Search label + field | label 「手動搜尋地點」, hint 「搜尋縣市或鄉鎮市區」, read-only, tap opens the picker with the search focused | **new `AppTextField`** (§7), `readOnly: true`, `prefixIcon: Icons.search` |
| Auto-locate row | primary 自動定位; secondary 「開啟後以 GPS 所在鄉鎮為目前地點」 (on, failed: 「開啟中，但無法定位」); leading tint `Icons.my_location` (off/failed: `Icons.location_disabled_outlined`) | `AppList` `lib/core/widgets/data_display.dart:174` with one `AppListRow` `data_display.dart:203`, `trailing:` **new `AppSwitch`**, `onTap` toggles. Leading = the existing page-local `_Tint` (`location_screen.dart:869`) |
| Located line | 「已定位：臺北市 信義區 · 14:10」 with a check icon | page-local `Text` caption1 fg2 (like `_Note`, `location_screen.dart:978`) |
| Locating | 「正在取得你的位置…」 | `StatusBanner(tone: StatusTone.loading)` `lib/core/widgets/status.dart:11` |
| Permission denied | title 未取得位置權限; text 「尚未允許定位權限，請允許後重試，或手動選擇地點。目前使用「臺中市 西屯區」。」; actions 前往設定 (primary), 重試 | `StatusBanner(tone: StatusTone.permission)` + `AppButton` `lib/core/widgets/buttons.dart:10` + `RetryButton` `status.dart:155`. Text reuses `locationFailureMessage` (`place_provider.dart`) |
| Denied forever | title 位置權限已關閉; text 「定位權限已被永久拒絕，請到系統設定開啟，或手動選擇地點」; action 前往設定 | same |
| Service off | title 裝置的定位服務已關閉; text 「請開啟定位服務後重試，或手動選擇地點。」; action 重試 | same |
| Position / address failure | title 無法取得目前位置; text from `locationFailureMessage` + 「原因：…」 | same, `StatusBanner(tone: StatusTone.error)` |

Behaviour: switch on = `CurrentPlaceNotifier.useGps()` (asks for permission when not yet decided). Switch off = stop using GPS; the current place becomes the first saved place, or 「尚未設定地點」 when there is none. Turning off needs a new store method (today `PlaceStore.saveUseGps` can only write `true`) — for the architects. Failure banners appear inside this card, directly under the switch, so the cause sits next to the control that caused it. The switch stays on during a failure: the user's choice is kept, the banner says why it does not work.

## 4. Card 2 — 儲存的地點 (hero)

| Element | Copy | Widget |
|---|---|---|
| Card | title 儲存的地點; meta 「點地點設為目前地點 · 各地點可單獨開關警特報通知」 | `AppCard(title:, meta:)` |
| Tile list | one tile per place, gap `AppSpace.s12` | `Column` (narrow) — no `AppList`, because tiles are separate rounded cards |
| Place tile | see below | **page-local `_PlaceTile`** (§7), same family as `_RowTile` `location_screen.dart:606` |
| Empty | title 還沒有儲存的地點; text 「用上方「手動搜尋地點」加入縣市與鄉鎮，就能在這裡切換並設定警特報通知。」 | `EmptyState(icon: Icons.place_outlined)` `status.dart:78` inside the card |
| Loading | — | `AppCard.loading(title: '儲存的地點', skeletonHeight: …)` `app_card.dart:30` |
| Corrupt | title 無法讀取已儲存的地點; message = exception text as-is | `AppCard.error` `app_card.dart:45` (retry = re-read) |

### `_PlaceTile` anatomy

| Part | Copy | Built from |
|---|---|---|
| Leading | `Icons.my_location` (GPS tile) or `Icons.place_outlined` | `_Tint` (brand tint on the current place) |
| Source label | 「GPS 目前位置」 / 「手動加入」 | caption1 fg3; brandFgStrong semibold on the current place |
| Name | 「臺北市 信義區」 | subtitle2 fg1 |
| Current marker | 使用中 | `AppBadge(tone: BadgeTone.brand)` `data_display.dart:9` |
| Now | 「23°」 (title3, tabular) + 「多雲 · 降雨 20%」 | data from `placeObservationProvider` (existing); failure → 「—」 + message in caption1 (as today in `_MyPlaces`, `location_screen.dart:677`) |
| Alert switch | bell icon + 「警特報通知」 + switch | `InkWell` row (min height `AppSize.touch`) + **`AppSwitch`**; icon `Icons.notifications_outlined` / `Icons.notifications_off_outlined` |
| Remove | trash icon | `AppIconButton(icon: Icons.delete_outline, tooltip: '移除臺中市西屯區')` `buttons.dart:108`. Not shown on the GPS tile |
| Select | tap anywhere outside the switch / trash | `CurrentPlaceNotifier.select(place)` |

Visual states: current place = `AppPalette.brandBgSubtle` fill, `brandStrokeSubtle` border and a 3 px (`AppStroke.thicker`) brand start edge. Others = `bg1`, `stroke2` border, `AppRadius.md`.

Interior: narrow (column: top row, now, divider, switch row) below `AppLayout.cardWideWidth`; wide (one row: place · now · switch + trash, divider is vertical) at or above it. Decide with the tile's own `LayoutBuilder`.

GPS tile: shown first when auto-locate is on and a fix exists. Its alert switch is for "where I am now" (follows the located area). Hidden when auto-locate is off or failed; the card meta then says 「GPS 目前位置暫時無法使用」.

Master off: every tile switch is disabled but keeps its value; card meta becomes 「通知總開關已關閉，各地點的選擇仍會保留」; the bell becomes the off bell and the label `fgDisabled`.

## 5. Card 3 — 通知設定

| Element | Copy | Widget |
|---|---|---|
| Card | title 通知設定; meta 「分區警特報開關在每個地點卡片上」 | `AppCard(title:, meta:)` |
| Switch list | three rows in one `AppList` | `AppList` + `AppListRow(trailing: AppSwitch)` |
| Master | 通知總開關; secondary 「2 個地點開啟警特報通知」 (count of tiles on) / off: 「已關閉：所有提醒暫停，設定保留」 | `AppListRow` |
| Rain | 降雨提醒; 「目前地點即將下雨時提醒」 | `AppListRow(enabled: master)` |
| Quiet | 靜音時段; 「時段內不發出提醒」 (master off: shows the range 「22:00 至隔天 07:00」) | `AppListRow(enabled: master)` |
| Start / end | labels 開始 / 結束; values 「22:00」 / 「隔天 07:00」 | two `AppButton(variant: secondary, icon: Icons.schedule, block: true)` in a 2-column `Row` of `Expanded`; tap → Material `showTimePicker` (24-hour). Shown only while 靜音時段 is on |
| Range summary | 「每天 22:00 至隔天 07:00 靜音（共 9 小時）」; same day: 「每天 13:00 至 15:00 靜音（共 2 小時）」 | caption1 `Text` |
| Not-delivered note | 「目前只保存這些設定，App 尚未實際發送通知。」 | `_Note` pattern (icon `Icons.info_outline`) |
| Corrupt | title 無法讀取通知設定; text = parse error as-is (e.g. 「儲存資料損毀：靜音開始時間期望 HH:mm，實際「25:99」」); action 重設通知設定 | `StatusBanner(tone: StatusTone.error)` + `AppButton(small: true)` |

Crossing midnight: when end ≤ start, the end value and summary say 「隔天」. Start = end is rejected at the boundary (zero-length range): the picker result is not saved and the field shows the error caption 「開始與結束不能相同」.

Master off disables rows (rain, quiet, time buttons, all place-tile switches) but keeps their values. The master row stays enabled.

## 6. Card 4 — token 設定

| Element | Copy | Widget |
|---|---|---|
| Card | title token 設定; trailing status badge | `AppCard(title:, trailing:)` |
| Status badge | 未設定 / 驗證中 / 有效 / 無效 | `AppBadge`: 未設定 = `neutral`; 驗證中 = `brand`; 有效 = `brand` with `Icons.check`; 無效 = `alert3` |
| Field | label 「中央氣象署 API 授權碼」; hint 「貼上授權碼，例如 CWA-XXXXXXXX-…」; obscured by default | **`AppTextField`** with `obscureText`, `prefixIcon: Icons.key_outlined`, suffix `AppIconButton(Icons.visibility_outlined / visibility_off_outlined, tooltip: 顯示授權碼 / 隱藏授權碼)` |
| Help line | 有效: 「已於 14:02 驗證成功 · 授權碼只存在本機」; 未設定: 「儲存後會用一次真實查詢驗證」 | `AppTextField.helperText` |
| Error line | 無效: 「中央氣象署拒絕此授權碼（HTTP 401）。請確認是否完整複製，或到開放資料平臺重新取得。」 | `AppTextField.errorText` (danger border) |
| Actions | 儲存 (primary; enabled when the field differs from the stored key), 驗證 (secondary; enabled when a key is stored), 清除 (subtle; enabled when a key is stored). 無效 renames 驗證 → 再驗證一次 | `Wrap` of `AppButton`s, capped at `readingWidth` |
| Verifying | 「正在向中央氣象署驗證…」; all buttons disabled | `StatusBanner(tone: StatusTone.loading)` |
| Network failure | 「無法驗證：網路連線失敗」; status keeps the last result (not marked 無效) | `StatusBanner(tone: StatusTone.error)` + `RetryButton` |
| Where to apply | 「如何取得授權碼」 + 「到 opendata.cwa.gov.tw（中央氣象署開放資料平臺）註冊並登入，在「會員資訊 › 取得授權碼」複製後貼上。」 Plain text, selectable, no link. | `SelectableText` in a `bg2` box, `AppRadius.md` (page-local) |
| Corrupt | `AppCard.error(title: '無法讀取授權碼', message: …)` | `app_card.dart:45` |

儲存 saves then runs the verification once. 清除 removes the key, sets 未設定, and every data page switches to the missing-token state.

### Missing-token state (this page and the other tabs)

- 設定 page: `StatusBanner(tone: StatusTone.permission, icon: Icons.key_outlined)` as grid child 0, title 「尚未設定中央氣象署授權碼」 (無效: 「中央氣象署授權碼無效」), text 「天氣、雷達、雨量、警特報都需要授權碼才能載入。」, action 輸入授權碼 → `Scrollable.ensureVisible` on the token card and focus the field.
- Data pages (天氣, 雷達, 雨量, 警特報): `EmptyState(icon: Icons.key_outlined, title: '需要中央氣象署授權碼', text: '到「設定」輸入授權碼後，就能載入天氣資料。', actions: [AppButton(label: '前往設定', variant: primary)])` as an `AppGridItem.full`; 前往設定 = `appTabProvider.notifier.select(AppTab.settings)`. Place tiles show 「—」.

## 7. New components (justified)

| Component | Where | Why it is new | Spec |
|---|---|---|---|
| `AppSwitch` | `lib/core/widgets/choices.dart` | A token-themed `Switch` already exists inline in `lib/features/radar/widgets/playback_card.dart:470`. This page adds a second screen that needs it (≈ 10 switches), which meets the "two screens" rule in `adaptive/system.md` §5. Promote it; radar then uses the shared one. | `AppSwitch({required bool value, required ValueChanged<bool>? onChanged, required String semanticLabel})`; colours as in radar (active track `brandBg`, inactive track `strokeAccessible`, thumb `bg1`, no outline); `onChanged: null` = disabled. Inside an `AppListRow`, wrap the row in `MergeSemantics` so the row reads as one switch. |
| `AppTextField` | `lib/core/widgets/inputs.dart` (new file) | The search field is page-local `_SearchField` (`location_screen.dart:887`). The token input needs the same field plus label, obscure, suffix and error. Two users → shared. | `AppTextField({String? label, String? hint, IconData? prefixIcon, Widget? suffix, bool obscureText = false, bool readOnly = false, String? helperText, String? errorText, TextEditingController? controller, VoidCallback? onTap, ValueChanged<String>? onChanged, bool autofocus = false})`. Visible label above (caption1 semibold fg2); min height `AppSize.control`; borders as `_SearchField`; error border `dangerStroke` + `dangerFg` bottom. Token field: `autocorrect: false`, `enableSuggestions: false`. |
| `_PlaceTile` (page-local) | the settings screen file | Only this page shows a place with an inline switch; `AppListRow` has one trailing slot and no second line of controls. | §4 |
| Time picker theme | `lib/core/theme/app_theme.dart` | `showTimePicker` is a Material dialog; give it `timePickerTheme` colours from `AppPalette` so no literal colours leak. Not a widget. | 24-hour (`MediaQuery(alwaysUse24HourFormat: true)`) |

No new tokens, colours or fonts. The mockup's `.badge--ok` is how `AppBadge(tone: brand, icon: check)` should look in a subtle variant; if the implementer keeps the solid brand badge, that is acceptable — no new `BadgeTone` is required.

## 8. Accessibility

- Touch: every switch row and tile switch row is ≥ `AppSize.touch` (44) tall and the whole row toggles; trash and show/hide are `AppIconButton` (44 circle). Time buttons are full-height `AppButton` (44), not `small`. `small` buttons (32) appear only inside status banners, same as today.
- Labels: each switch has a semantic label naming its area, e.g. 「臺中市西屯區 警特報通知」; disabled ones add 「，總開關關閉中」. Trash tooltip 「移除臺中市西屯區」. Show/hide tooltip toggles 顯示授權碼 / 隱藏授權碼.
- Fields have visible labels (not placeholder-only). The error text is the field's `errorText`, so screen readers announce it with the field.
- Status changes (驗證中 → 有效/無效, locate result) use `SemanticsService.announce` or a live region (`Semantics(liveRegion: true)` on the badge).
- Colour is never the only signal: the current place has the 使用中 badge, the token status is a text badge, disabled rows also change their text.
- Keyboard (desktop): tab order follows the reading order; Enter in the token field = 儲存.
- Text scaling: tiles wrap (`overflow-wrap` on names), no fixed heights.

## 9. Open points for the architects

1. GPS tile alert switch: needs one stored flag for "current GPS area" next to the per-saved-place flags. If the data model keeps per-place flags only, drop the switch from the GPS tile; the rest of the design is unchanged.
2. Turning auto-locate off needs a new store write (today only `true` can be stored).
3. Removing a saved place should also delete its stored alert flag (no orphan keys).
