# 設定 tab — Designer 3（主從式）

Mockup: `settings.html` (same folder; phone frames P1–P6 at 390 px, wide frames W1–W3 at 1280 px).
Spec source: `docs/logs/settings-tab-contract.md`. Widget refs are `file:line` of the class declaration in `lib/`.

## 1. Idea

- Wide windows: a **section index** on the left (地點 / 通知 / token). Each entry also shows that section's live status, so the index works as a status board. The selected section's card(s) fill the right pane.
- Phone and narrow windows: the same sections stacked as cards in a fixed order, with a chip row at the top that jumps to a section.
- 儲存的地點 is always first: the first card on phone, the first card of the default 地點 section on wide.
- Token problems are never hidden: a full-width banner at the top of the page whenever the token is 未設定 or 無效, on every width.

## 2. Tab and page frame

| Item | Spec |
|---|---|
| Tab | `AppShell` tab map `lib/app_shell.dart:39`: label 地點 → **設定**, icon `Icons.location_on_outlined` → `Icons.settings_outlined`. Rename enum value `AppTab.location` → `AppTab.settings` (`app_shell.dart:13`) and update the callers that switch to it (the 「手動選擇」 links from other pages). |
| Page | `AppPageScaffold` `lib/core/widgets/page_scaffold.dart:17`, scrolling grid mode (not `.fill`). No `source` line: this page shows no CWA dataset except the saved-place temperatures; keep `SourceLine` (`page_scaffold.dart:208`) with `O-A0003-001` only when at least one saved place shows a temperature, as today. |
| Header | `AppPageHeader` `page_scaffold.dart:107`: title 「設定」; subtitle = page summary, priority order: 「尚未設定 token」 / 「token 無效」 / 「未取得位置權限」 / 「通知已關閉」 / otherwise 「N 個地點 · token 有效」. No header actions (重新定位 moves into the 地點設定 card). |

## 3. Layout per breakpoint

Decision is made from the available width, not the window: one `AppGridItem.full` (`lib/core/layout/adaptive.dart:59`) holds a `LayoutBuilder`; `AppTwoPane.fits(width)` (`adaptive.dart:161`, ≥ 656) picks the mode.

| Window (examples) | Content width | Mode | Arrangement |
|---|---|---|---|
| compact < 600 (360, 390, 412) | 328–380 | **Stacked** | `[token banner if needed]` · jump chips · 儲存的地點 · 地點設定 · 通知設定 · token 設定 — every cell `AppGridItem.full`, one column |
| medium 600–839, e.g. 720 | 592 | **Stacked** | same as compact (`fits` is false) |
| medium 839 / expanded 960 | 711 / 816 | **Master–detail** | `AppTwoPane(sideFirst: true)` (`adaptive.dart:151`): index pane 320 / 326, detail pane 375 / 474 |
| large 1280 | 1136 | **Master–detail** | index 454 (= 0.4 × 1136), detail 666 |
| large 1920 | 1776 | **Master–detail** | index 480 (clamped by `AppLayout.paneMaxWidth`), detail 1280. In the 地點 section the detail pane holds an inner `AppGrid` (`adaptive.dart:81`) so 儲存的地點 and 地點設定 sit side by side once the pane fits two 340 columns (≥ 696) |

Rules:
- Token banner (未設定 / 無效) is an `AppGridItem.full` above the mode switch, in both modes.
- In master–detail both panes are top-aligned and scroll with the page (scrolling grid; no inner scroll areas). Short windows (`WindowSizeClass.isShortHeight`) need no special case.
- Text blocks, helper text, banner text and button rows inside a card are capped at `AppLayout.readingWidth` (640). Cards fill their pane.
- Selected section = page-local UI state (not persisted). Initial value: **token** when the token is 未設定 or 無效, else **地點**.
- Stacked mode: jump chips use `Scrollable.ensureVisible` on a `GlobalKey` per card. The chip of the card nearest the top is shown as selected. No section state is kept in stacked mode.
- No width literals in the screen file: only `WindowSizeClass`, `AppTwoPane.fits`, `AppLayout.*`.

## 4. Section index (wide only) and jump chips (stacked only)

| Element | Widget | Content |
|---|---|---|
| Index list | `AppList` `lib/core/widgets/data_display.dart:174` | 3 rows, in this order |
| Index row | `AppListRow` `data_display.dart:203`, `selected` = current section, `onTap` = select | leading: tint circle (`_Tint`, now page-local at `lib/features/location/location_screen.dart:869`; moves with the page) with the section icon; brand tint when selected |
| 地點 row | | primary 「地點」; secondary 「N 個儲存的地點 · 自動定位開啟（臺北市 信義區）」 / 「… · 自動定位關閉」 / 「… · 未取得位置權限」; trailing chevron icon |
| 通知 row | | primary 「通知」; secondary 「已開啟 · K 個分區 · 靜音 22:00–07:00」 / 「已關閉」; icon `notifications_outlined`, or `notifications_off_outlined` when off |
| token row | | primary 「token」; secondary 「驗證於 14:08」 / 「HTTP 401 · 驗證於 14:12」 / 「尚未輸入」; trailing `AppBadge` (`data_display.dart:9`) with the status (see §8) |
| Note under the index | page-local `_Note` (`location_screen.dart:978`) | 🔒 「所有設定只保存在此裝置。」 |
| Jump chips (stacked) | `AppChip` (`lib/core/widgets/choices.dart:9`) in a horizontal `SingleChildScrollView` + `Row(spacing: AppSpace.s8)` | 「地點」 `place_outlined`, 「通知」 `notifications_outlined`, 「token」 `key_outlined` |

Semantics: index rows are announced as selectable buttons (`AppListRow` → `Semantics(selected: …)`; see §10).

## 5. Card: 儲存的地點

`AppCard` (`lib/core/widgets/app_card.dart:15`), title 「儲存的地點」, meta 「點選設為目前地點」.

| Element | Widget | Copy / behaviour |
|---|---|---|
| List | `AppList` (`data_display.dart:174`) | GPS row first (only when auto-locate is on), then saved places in save order |
| GPS row, located | `AppListRow`, `selected: true` | leading tint `my_location`; primary 「目前位置」; secondary 「臺北市 信義區 · 自動定位」; trailing `AppBadge(label: '使用中', tone: BadgeTone.brand)` + `AppIconButton` (`lib/core/widgets/buttons.dart:108`) `bookmark_add_outlined`, tooltip 「儲存目前位置 臺北市 信義區」 (hidden when already saved) |
| GPS row, not available | `AppListRow(enabled: false)` = existing `_disabledGpsRow` (`location_screen.dart:632`) | secondary 「定位不可用 · 未授權」 / 「… · 定位服務關閉」 / 「… · 無法定位」; trailing `AppBadge('已停用')` |
| GPS row, locating | `AppListRow` with `Skeleton` (`lib/core/widgets/status.dart:134`) trailing | secondary 「定位中…」 |
| Saved place row | `AppListRow`, `selected` when it is the current place; `onTap` = `currentPlaceProvider.notifier.select(p)` | leading tint `place_outlined`; primary 「臺中市 西屯區」; secondary = observation weather text or the Failure message as-is; trailing: `AppBadge('使用中')` when current, temperature 「26°」 (or 「—」), `AppIconButton` `delete_outline` tooltip 「移除臺中市 西屯區」 |
| Empty | `EmptyState` (`status.dart:78`) inside the card | icon `bookmark_border`; 「尚未儲存地點」; 「在「地點設定」搜尋鄉鎮，選好後按「儲存」。」 |
| No current place | `_Note` under the list | 「尚無目前地點：點一個儲存的地點，或在下方搜尋。」 |
| Loading | `AppCard.loading(title: '儲存的地點', skeletonHeight: AppSize.touch * 3)` | |
| Corrupt storage | `StatusBanner(tone: StatusTone.error)` (`status.dart:11`) replaces the list | 「無法讀取已儲存的地點」 + the `StoredSettingException` text as-is; action 「重新選擇」 = opens the picker (writing overwrites the corrupt value) |

Reorder: not shown. `SavedPlacesNotifier` (`lib/features/location/place_provider.dart:244`) has no reorder today, and the contract allows reorder only if already supported.
Delete: immediate, like today. No confirm dialog. Undo is out of scope.

## 6. Card: 地點設定 (manual search + auto-locate in one card)

`AppCard`, title 「地點設定」, meta 「搜尋地點，或讓 App 自動定位」. Two blocks split by a 1 px `stroke3` divider.

| Element | Widget | Copy / behaviour |
|---|---|---|
| Search label + field | **`AppTextField`** (new, §9) in search mode, read-only; promoted from `_SearchField` `location_screen.dart:887` | label 「手動搜尋」; hint 「搜尋縣市或鄉鎮市區」; helper 「選好鄉鎮後可「儲存」或「設為目前地點」」. Tap opens the existing picker `_PickerView` (`location_screen.dart:423`) with the search focused. On wide, the picker replaces the detail pane (back button returns to the 地點 section). On phone, it replaces the page, as today. The picker itself is unchanged. |
| Auto-locate switch | **`AppSwitchRow`** (new, §9) | label 「自動定位」; caption 「開啟時，App 啟動會以 GPS 取得所在鄉鎮」. On → `useGps()` (requests permission when undecided). Off → stop using GPS (the provider plan decides what becomes current; see §11). |
| Located line | `Row`: icon `my_location` 16 brand + caption text + `AppButton(variant: subtle, small: true, icon: Icons.refresh, label: '重新定位')` (`buttons.dart:10`) | 「已定位：臺北市 信義區 · 14:10」 |
| Locating | `StatusBanner(tone: StatusTone.loading)` | 「正在取得你的位置…」 / 「通常需要數秒」 |
| Permission denied | `StatusBanner(tone: StatusTone.permission)` | title 「未取得位置權限」; text = `locationFailureMessage()` (`place_provider.dart:81`) + 「\n原因：」 + cause; actions 「前往系統設定」 (primary small → `Geolocator.openAppSettings`) and 「重試」 (`RetryButton`, `status.dart:155`) |
| Denied forever | same banner | title 「位置權限已關閉」; text 「系統不再詢問位置權限，請到系統設定開啟，或手動選擇地點」 + cause; action 「前往系統設定」 only |
| Service off | `StatusBanner(tone: StatusTone.error)` | title 「無法取得目前位置」; text from `locationFailureMessage`; actions 「前往設定」 (`openLocationSettings`) + 「重試」 |
| Position / address failed | `StatusBanner(tone: StatusTone.error)` | same title; actions 「重試」 |
| Auto-locate off | no status line | caption changes to 「關閉中：使用你選擇的地點」 |

The status banner sits directly under the switch so the cause stays next to the control.

## 7. Card: 通知設定 (settings only)

`AppCard`, title 「通知設定」, meta 「偏好會保存，重開 App 後保留」, trailing `AppBadge('已關閉')` only when the master switch is off.

| Element | Widget | Copy / behaviour |
|---|---|---|
| Honesty note | `_Note` with `info_outline` | 「目前版本只儲存這些偏好，尚未發送任何通知。」 (always shown: the card never claims delivery) |
| Master | `AppSwitchRow` | 「啟用通知」; caption on: 「關閉後下列設定保留，但全部不生效」; off: 「已關閉：下列設定保留，但全部不生效」 |
| Group label | caption1 semibold fg2 text (same style as radar `_fieldLabel`, `lib/features/radar/widgets/playback_card.dart:487`) | 「分區警特報通知」 |
| Per-area rows | `AppList` of `AppListRow`, trailing = `AppSwitchRow`'s switch alone (`AppSwitch`, §9) | one row per saved place: primary 「臺中市 西屯區」, secondary 「臺中市的警特報」 (warnings are county level). Switch semantic label 「臺中市 西屯區 警特報通知」 |
| No saved places | `_Note` | 「尚未儲存地點。每個儲存的地點就是一個通知分區，請先在「儲存的地點」加入。」 |
| Rain reminder | `AppSwitchRow` | 「降雨提醒」 / 「目前地點預報即將下雨時提醒」 |
| Quiet hours | `AppSwitchRow` | 「靜音時段」; caption = range text, e.g. 「22:00 至隔天 07:00（9 小時）」 or 「13:00 至 15:00（2 小時）」 |
| Start / end | two page-local `_TimeTile`s in a 2-column `Row` capped at `readingWidth`. A tile = `Material` + `InkWell`, radius sm, stroke1 border, bg1, min height 56: caption 「開始」 / 「結束」 / 「結束（隔天）」 (fg3) above the time (subtitle2, tabular, icon 16 `bedtime_outlined` / `schedule`). Page-local because only this card uses it (`AppButton` holds one label line only). Tap → `showTimePicker` (Material, 24-hour via `MediaQuery(alwaysUse24HourFormat: true)`) | visible only when quiet hours is on; disabled (bgDisabled, fgDisabled) when the master is off |
| Crossing midnight | caption + end label | end < start means the end is on the next day: label 「結束（隔天）」, caption 「22:00 至隔天 07:00（9 小時）」. Duration = (end − start) mod 24 h |
| Start = end | inline error under the tiles (danger caption1 with `error_outline`) | 「開始與結束時間不能相同（期望不同時刻，實際都是 07:00）；此變更未儲存」. The picked value is rejected; the stored value is kept |
| Master off | every child: `AppListRow(enabled: false)`, switches and time tiles disabled (`onChanged: null`) | values kept and shown; index row secondary 「已關閉」 |
| Corrupt stored value | `AppCard.error(title: '無法讀取通知設定', message: <parse error as-is>, onRetry: …)` (`app_card.dart:45`) plus an action 「重設通知設定」 that writes defaults (explicit user action, not a silent fallback) | |
| Loading | `AppCard.loading(title: '通知設定', skeletonHeight: …)` | |

Per-area switches are keyed by place identity. When a saved place is removed, its switch disappears with it (the provider plan owns the cleanup).

## 8. Card: token 設定

`AppCard`, title 「token 設定」, meta 「中央氣象署開放資料授權碼」, trailing `AppBadge` = status.

| Status | Badge (`BadgeTone`, `data_display.dart:6`) | Status block |
|---|---|---|
| 未設定 | 「未設定」 `alert2` (warning colours) | none in the card. The page banner explains it (below) |
| 驗證中 | 「驗證中」 `neutral` | `StatusBanner(tone: loading)` 「驗證中…」 / 「正在向中央氣象署查詢一次資料」 |
| 有效 | 「有效」 **success** (new tone, §9) | `StatusBanner(tone: success)` 「token 有效」 / 「驗證於 14:08 · 已成功取得氣象資料」 |
| 無效 | 「無效」 `alert3` (danger colours) | `StatusBanner(tone: error)` 「token 無效」 / 「原因：HTTP 401 Unauthorized（…）。請確認授權碼完整複製，或到開放資料平臺重新取得。驗證於 14:12。」 + `RetryButton` |
| 無法驗證 (network or server error, not a rejection) | 「未驗證」 `neutral` | `StatusBanner(tone: error)` 「無法驗證 token」 + Failure message as-is + 「重試」. The token is **not** marked invalid |

| Element | Widget | Copy / behaviour |
|---|---|---|
| Input | **`AppTextField`** (new) with `obscureText`, `autocorrect: false`, `enableSuggestions: false`, monospace digits (`AppType.tabular`) | label 「授權碼」; hint 「貼上 CWA- 開頭的授權碼」; helper 「輸入後按「儲存並驗證」，App 會實際向中央氣象署查詢一次」. Saved key shown masked; field error text 「中央氣象署拒絕這組授權碼」 when 無效 |
| Show / hide | `AppIconButton` as the field suffix | `visibility_outlined` tooltip 「顯示授權碼」 ↔ `visibility_off_outlined` 「隱藏授權碼」 |
| Save | `AppButton(variant: primary, label: '儲存並驗證')`, `Expanded` | disabled when the field is empty, unchanged from the stored key, or while verifying. Saves (trimmed, format check at the boundary) then runs **one** real CWA call |
| Re-verify | `AppButton(variant: secondary, icon: Icons.refresh, label: '重新驗證')` | shown only when a key is stored and the field is unchanged |
| Clear | `AppButton(variant: subtle, label: '清除')` | removes the stored key. Inline confirm: the button becomes 「確定清除？」 (danger text) for one tap. Disabled when nothing is stored |
| Where to apply | plain text block on `bg2` (radius sm), `SelectableText` | 「如何取得授權碼」 1. 到中央氣象署開放資料平臺 opendata.cwa.gov.tw 註冊並登入會員 2. 在「會員資訊」頁面取得「API 授權碼」 3. 複製授權碼貼到上方欄位，按「儲存並驗證」. Plain text, no link |
| Privacy | `_Note` with `lock_outline` | 「授權碼只保存在此裝置，只用來向中央氣象署取得資料。」 |
| Corrupt stored value | `AppCard.error(title: '無法讀取 token', message: …)`; 「清除」 stays available to recover | |

Page banner (both modes, `AppGridItem.full`, above everything):
- 未設定: `StatusBanner(tone: permission, icon: Icons.key_outlined)` 「尚未設定 token」 / 「天氣、雷達、雨量、警特報都需要中央氣象署授權碼才能載入。」, action 「前往 token 設定」 (primary small): on wide selects the token section, on stacked scrolls to the card and focuses the field.
- 無效: `StatusBanner(tone: error, icon: Icons.key_outlined)` 「token 無效，所有資料頁暫停載入」 / 「請在 token 分區更新授權碼。」 (same action on stacked).

Data pages (outside this card, shown as P6 for context): `EmptyState(icon: Icons.key_outlined, title: '尚未設定 token', text: '本頁資料來自中央氣象署開放資料，需要你的授權碼。請到「設定」輸入 token。', actions: [AppButton(primary, '前往設定輸入 token')])`; 無效 → `error: true`, title 「token 無效」, text with the reason. The button calls `appTabProvider.notifier.select(AppTab.settings)` and requests the token section.

## 9. New shared components (justified)

| Component | Where | Why it is shared | Spec |
|---|---|---|---|
| `AppSwitch` + `AppSwitchRow` | `lib/core/widgets/choices.dart` | 5+ uses on this page (auto-locate, master, rain, quiet hours, per-area) plus the radar 「重複播放」 row, which today builds the same thing by hand (`playback_card.dart:470`). One token-styled switch instead of copies | `AppSwitch({required bool value, required ValueChanged<bool>? onChanged, required String semanticLabel})`: Material `Switch` with the radar colours (active track `brandBg`, inactive `strokeAccessible`, thumb `bg1`, no outline); disabled track `bgDisabled`. Hit area ≥ 44×44. `AppSwitchRow({required String label, String? caption, required bool value, required ValueChanged<bool>? onChanged})`: row min height `AppSize.touch`, label body1Strong, caption caption1 fg3, whole row toggles (`MergeSemantics` + `InkWell`), null `onChanged` = disabled (fgDisabled text) |
| `AppTextField` | new `lib/core/widgets/inputs.dart` | two users here (place search, token) and it replaces the page-local `_SearchField` (`location_screen.dart:887`) | `AppTextField({String? label, String? hint, String? helper, String? error, TextEditingController? controller, bool obscure = false, bool readOnly = false, bool autofocus = false, IconData? prefixIcon, Widget? suffix, VoidCallback? onTap, ValueChanged<String>? onChanged})`. Visible label above (body1Strong), field min height `AppSize.control`, radius sm, borders as `_SearchField` (stroke1 / focus brandStroke 2 px / error dangerFg 2 px), helper or error caption below (error replaces helper, `error_outline` icon, `Semantics(liveRegion: true)`). The token field passes `obscure`, `autocorrect: false`, `enableSuggestions: false`, `keyboardType: TextInputType.visiblePassword` |
| `StatusTone.success` and `BadgeTone.success` | `status.dart:7`, `data_display.dart:6` | token 有效 needs a positive state; there is none today. Colours already exist (`AppPalette.successBg/Fg/Stroke`, `lib/core/theme/app_tokens.dart:70`) | banner: successBg / successStroke / successFg, default icon `check_circle_outline`. Badge: successBg / successFg / successStroke |

Not new: section index (= `AppList` + `AppListRow`), jump chips (= `AppChip`), time tiles (= `AppButton` + caption label), notes (= page-local `_Note`), tint (= page-local `_Tint`).

## 10. Accessibility

- Every control ≥ 44×44 (`AppSize.touch`): list rows, switch hit area, icon buttons, time tiles (56 high), `AppButton`. Small buttons (32) only inside banners and the located line, matching existing banners.
- Every input has a visible label (授權碼, 手動搜尋); the hint is never the only label.
- Switches: `AppSwitchRow` merges label + caption + state into one semantics node; per-area switches carry 「<地點> 警特報通知」.
- Show/hide button: tooltip = accessible name, and the name flips with the state.
- Errors: token error and quiet-hours error are live regions; the field gets the error text as its semantics hint.
- Time tiles announce 「靜音開始時間 22:00」 / 「靜音結束時間 隔天 07:00」.
- Section index rows: `Semantics(selected: true)` on the active row (`AppListRow.selected`); the detail pane has a heading of the section name for screen readers.
- Status is never colour-only: every badge and banner has text (未設定 / 驗證中 / 有效 / 無效).
- Contrast: all text uses fg1–fg3, brandFgStrong, successFg, dangerFg, warningFg on their paired backgrounds (all ≥ 4.5:1 per the token file).
- The token is never shown in full unless the user taps 「顯示授權碼」. Logs and error messages never contain the key.

## 11. Open points for the provider plan (not decided here)

1. Auto-locate **off** with no manual place: the in-flight provider already has `NoPlace.autoLocateOff()` (`lib/features/location/place_provider.dart:66`). This design shows it as the 儲存的地點 note 「尚無目前地點：點一個儲存的地點，或在下方搜尋。」 and no banner (it is the user's choice, not a failure). The last GPS place is not silently kept as a manual place.
2. Format check for the token at the boundary (allowed characters, `CWA-` prefix). The mockup hint assumes the `CWA-` prefix, which matches current CWA keys but is not verified here.
3. Which dataset the verify call uses (a small one, e.g. `O-A0003-001` with `limit=1`). How HTTP 401/403 vs network errors map to 無效 vs 無法驗證.
4. Per-area notification keys: by place identity (county + town). Cleanup when a place is removed.
