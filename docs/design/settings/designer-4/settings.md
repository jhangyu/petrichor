# 設定 tab: Designer 4「就緒優先」

Mockup: `settings.html` (same folder). Spec: `docs/logs/settings-tab-contract.md`.
Widget references are `file:line` in `lib/` at commit `1ee16b2`.

## 1. Idea

The page is ordered by what stops the app from working. The CWA token and the current place block every data page. Notifications block nothing.

- **Setup mode**: the token is 未設定, or there is no current place. The page shows a setup card (a step list with progress), then only the card for the current step. The token always comes first because the town list in the place picker is fetched from CWA (`townsProvider`, `place_provider.dart:229`), so a place cannot be picked without a token. Notifications are listed as an optional step and are never required.
- **Ready mode**: the token is 有效 and a place exists. The page shows four cards. The token card is collapsed into a single status row at the top.
- **Repair mode**: a stored token later fails verification (無效) while a place exists. The token card opens and moves to the top with an error banner. The other cards stay below it.

```
mode = token == 未設定 || place is NoPlace     → setup
     : token == 無效                           → repair
     : ready                                    (驗證中 keeps the previous mode)
```

## 2. Shell and page frame

| Item | Widget | Spec |
|---|---|---|
| Tab | `AppShell._tabs` `lib/app_shell.dart:44` | `('設定', Icons.settings_outlined, SettingsScreen())`. The enum value `AppTab.location` becomes `AppTab.settings`. Every caller of `select(AppTab.location)` changes too. |
| Page | `AppPageScaffold` `page_scaffold.dart:17` | Scrolling grid. No `.fill`. |
| Header | `AppPageHeader` `page_scaffold.dart:107` | title `設定`. subtitle per mode: setup `尚未完成設定 · 還差 N 步` (`subtitleIcon: Icons.error_outline`, `subtitleIconColor: AppPalette.warningFg`); ready `全部就緒` (`Icons.check_circle_outline`, `AppPalette.successFg`); repair `授權碼無效 · 資料頁已停止載入` (warning). No actions. |
| Credit | `SourceLine` `page_scaffold.dart:208` | `['O-A0003-001']` only in ready mode, because the saved-place temperatures come from it. No credit line in setup or repair mode. |

## 3. Layout per breakpoint (`AppGrid` `adaptive.dart:81`, `AppGridItem` `adaptive.dart:59`)

Widths come only from `WindowSizeClass` (`adaptive.dart:18`) and `AppLayout` (`app_tokens.dart:243`).

| Mode | Cells in order | compact (<600, 1 col) | medium/expanded (2 col at 600–1035 content) | 1280 window (1136 content, 3 col) |
|---|---|---|---|---|
| setup, step 1 | setup card (1) · token card `AppGridItem(span: 2)` | stacked | setup card on row 1; the token card needs 2 columns, so it wraps to row 2 at full width | setup card \| token card spanning 2 (W1) |
| setup, step 2 | setup card (1) · 地點設定 `AppGridItem(span: 2)` | stacked | same as step 1 | same as step 1 |
| ready | token row `AppGridItem.full` · 儲存的地點 · 地點設定 · 通知設定 | stacked in this order | token row; 儲存的地點 \| 地點設定; 通知設定 alone | token row; three cards side by side (W2) |
| repair | token card `AppGridItem.full` · 儲存的地點 · 地點設定 · 通知設定 | stacked | as in ready | as in ready |

Inside cells, the text field, help text, button row and the "how to get a key" box are capped at `AppLayout.readingWidth` (`app_tokens.dart:256`) with `Align(centerLeft)` + `ConstrainedBox`. This is the same pattern as the picker search field (`location_screen.dart:514-520`). Cards fill their cell.

## 4. Cards

### 4.1 Setup card (setup mode only)

| Element | Widget | Copy / state |
|---|---|---|
| Card | `AppCard(hero: true, title, meta)` `app_card.dart:16` | title: `開始使用前還差 2 步` / `再選一個地點就完成`. meta: `授權碼與地點是所有資料頁的必要設定` / `授權碼已驗證`. |
| Progress | `LinearProgressIndicator` themed with tokens (`AppPalette.brandBg` on `bg5`, height `AppSpace.s4`, radius circular). It is wrapped in `Semantics(label: '已完成 1 / 2 步')`. | The mockup draws two segments. One determinate bar with value done/2 is acceptable. |
| Step list | `AppList` `data_display.dart:174` of `AppListRow` `data_display.dart:203` | Row 1 `輸入中央氣象署授權碼` / `天氣、雷達、雨量、警特報都需要它`. Row 2 `選擇目前地點` / `完成第 1 步後才能選：鄉鎮清單來自中央氣象署` (`enabled: false` until step 1 is done). Row 3 `通知偏好（選填）` / `完成設定後再調整即可`. The current step has `selected: true` and trailing `AppBadge('目前步驟', tone: brand)`. A done step has trailing `AppBadge('完成', tone: success)` and secondary `有效 · 驗證於 HH:mm`. |
| Step marker (leading) | **`StepMarker`, page-local (new)**: moved from `_Step`'s circle `location_screen.dart:924-944` | 24 px circle in four states: number on `bg4` (waiting), number on `brandBg` (active), check on `successSolid` (done), dashed `strokeAccessible` ring (optional). |

Rows are not tappable. The step card below the setup card is the action. Only one primary button is visible on the page at a time.

### 4.2 token 設定 (中央氣象署授權碼)

Expanded card (setup step 1, repair mode, or ready mode after the user taps the row):

| Element | Widget | Copy / state |
|---|---|---|
| Card | `AppCard(title: '中央氣象署授權碼', meta, trailing: AppBadge)` | meta: `只存在這台裝置上` (未設定) · `驗證於 MM/dd HH:mm` (有效) · `驗證失敗於 …` (無效). In ready mode a collapse `AppIconButton` (`buttons.dart:108`, tooltip `收合`) follows the badge. |
| Status badge | `AppBadge` `data_display.dart:9` | 未設定 = `neutral`. 驗證中 = `brand`. 有效 = **`BadgeTone.success` (new tone)**. 無效 = **`BadgeTone.danger` (new tone)**. |
| Key field | **`AppTextField` (new shared widget, see §5)** | label `授權碼`. hint `CWA- 開頭的授權碼`. prefix `Icons.key`. `obscureText` defaults to true. suffix `AppIconButton(Icons.visibility / visibility_off, tooltip: '顯示授權碼' / '隱藏授權碼')`. help `貼上後按「儲存並驗證」，App 會向中央氣象署送出一次查詢確認可用。`. On 無效 the field gets `errorText` = the reason. Settings: `autocorrect: false`, `enableSuggestions: false`, `keyboardType: TextInputType.visiblePassword`. Input is trimmed on save. |
| Verifying | `StatusBanner(tone: loading)` `status.dart:11` | `正在向中央氣象署驗證…` / `送出一次即時觀測查詢（O-A0003-001）`. The field and all buttons are disabled. The banner is a live region. |
| Invalid (repair) | `StatusBanner(tone: error)` | `授權碼已無法使用` / `中央氣象署拒絕授權（HTTP 403）。授權碼可能已被停用，請到開放平臺確認或換一組。` |
| Buttons | `AppButton` `buttons.dart:10` in a `Row` of `Expanded`, capped at reading width | `儲存並驗證` (primary): saves, then makes one CWA call. It is disabled when the field is empty or equals the stored key. `重新驗證` (secondary): only when a key is stored; it makes one CWA call and does not save. `清除` (subtle): only when a key is stored. |
| Clear confirm | Inline `StatusBanner(tone: error, title: '清除授權碼？', text: '清除後天氣、雷達、雨量、警特報都會停止載入，直到重新輸入。', actions: [AppButton('確定清除', small), AppButton('取消', small)])` | Inline, not a dialog. It replaces the button row until the user chooses. After clearing, the token is 未設定 and the page returns to setup mode. |
| How to get a key | Plain `Text` (caption1, fg2) in a `Container(color: bg2, radius md, padding s12)` | `如何取得授權碼` / `到「中央氣象署 氣象資料開放平臺」opendata.cwa.gov.tw 註冊並登入會員，在「會員資訊」頁的「API 授權碼」取得。` Plain text, not a link. |

Reason copy for 無效. The repository maps HTTP status to text (today `hazard_repository.dart:177` has the 401/403 case):

- 401/403: `授權碼錯誤或已停用（HTTP 401）。請確認貼上的是完整授權碼。`
- other HTTP: `中央氣象署回應異常（HTTP 500），請稍後重新驗證。`
- network: `無法連線到中央氣象署，尚未確認授權碼：<原因>` (see §7).

Collapsed row (ready mode): `AppList([AppListRow(leading: _Tint(Icons.key), primary: '中央氣象署授權碼', secondary: 'CWA-••••-<last 4> · 驗證於 MM/dd HH:mm', trailing: Row[AppBadge('有效', success), Icon(chevron_right)], onTap: expand)])`. Expanded/collapsed is local widget state. `_Tint` is `location_screen.dart:869`, moved with the screen.

### 4.3 儲存的地點

| Element | Widget | Copy / state |
|---|---|---|
| Card | `AppCard(title: '儲存的地點', meta: '點一下設為目前地點', trailing: AppButton('加入', icon: Icons.add, subtle, small))` | `加入` opens the picker (§4.4). |
| GPS row (when auto-locate is on and located) | `AppListRow(leading: _Tint(Icons.my_location), primary: '臺北市 中正區', secondary: '自動定位 · 多雲', selected: true, trailing: [AppBadge('使用中', brand), temp])` | Same as today's GPS row (`location_screen.dart:200-213`). |
| Saved row | `_savedRow` today `location_screen.dart:677-705`: `AppListRow(leading: _Tint(Icons.place_outlined), primary: '縣市 鄉鎮', secondary: weather or Failure.message, selected: inUse, onTap: select, trailing: [AppBadge('使用中')?, Text('24°'), AppIconButton(Icons.delete_outline, tooltip: '移除臺中市 西屯區')])` | Current-place marker = `selected` + `使用中` badge. Temperature is `—` while loading, on failure, or without a valid token. |
| Reorder | — | Not offered. `SavedPlacesNotifier` (`place_provider.dart:208`) has no reorder, and the contract only asks for it "if already supported". |
| Empty | `EmptyState(icon: Icons.bookmark_border, title: '還沒有儲存的地點', text: '在「地點設定」搜尋鄉鎮後按「儲存」。')` `status.dart:78` inside the card | |
| Loading | `AppCard.loading(title: '儲存的地點', skeletonHeight: AppSize.touch * 3)` `app_card.dart:30` | |
| Corrupt store | `StatusBanner(tone: error, title: '無法讀取已儲存的地點', text: '$error')` | Same as today's `location_screen.dart:671`. |

### 4.4 地點設定 (manual search + auto-locate in one card)

| Element | Widget | Copy / state |
|---|---|---|
| Card | `AppCard(title: '地點設定', meta, trailing: AppIconButton(Icons.refresh, tooltip: '重新定位'))` | meta: `定位於 HH:mm` (GPS) · `目前地點：臺中市 西屯區（手動）` · `搜尋鄉鎮，或讓 App 自動定位` (no place). The refresh button only shows when auto-locate is on. |
| Search field | `AppTextField(label: '搜尋地點', hint: '搜尋縣市或鄉鎮市區', prefix: Icons.search, readOnly: true, onTap: openPicker)` | Opens the existing picker `_PickerView` (`location_screen.dart:423`, moved to the settings feature unchanged) with the search focused. In setup step 2, `設為目前地點` there completes the step. |
| Auto-locate | `AppList([AppListRow(leading: _Tint(Icons.my_location), primary: '自動定位', secondary: <state>, trailing: AppSwitch, onTap: toggle)])` | ON calls `useGps()` (`place_provider.dart:178`). OFF keeps the current place as a manual one. The flag is persisted (contract). |
| State: located | secondary `已定位：臺北市 中正區` | |
| State: locating | secondary `定位中…`, `AppSpinner` (`status.dart:116`) before the switch | |
| State: off | secondary `關閉：使用儲存或搜尋的地點` | |
| State: permission denied | `StatusBanner(tone: permission, title: '未取得位置權限', text: _guidance(none), actions: [AppButton('前往設定', primary, small), RetryButton()])` | `_guidance` = `location_screen.dart:99` (`locationFailureMessage` + `原因：`). `前往設定` → `_openSettings(context, Geolocator.openAppSettings)` `location_screen.dart:91`. |
| State: denied forever | same banner, only `前往設定` | text from `locationFailureMessage(permissionDeniedForever)` `place_provider.dart:62` |
| State: service off | `StatusBanner(tone: error, title: '無法取得目前位置', …, actions: [前往設定 → openLocationSettings, RetryButton()])` | |
| State: position unavailable / address unresolved | `StatusBanner(tone: error, …, actions: [RetryButton(primary: true)])` | |
| Privacy note | `_Note(Icons.lock_outline, '位置只在這台裝置上用來查詢天氣，不會上傳或分享。')` `location_screen.dart:978` | |

### 4.5 通知設定 (settings only)

The copy never says a notification was sent. The card meta and a footer note both say only the preference is stored.

| Element | Widget | Copy / state |
|---|---|---|
| Card | `AppCard(title: '通知設定', meta: '先儲存偏好，通知功能尚未推出')` | |
| Master | `AppList([AppListRow(leading: _Tint(Icons.notifications_outlined), primary: '允許通知', secondary: on ? '關閉時以下設定全部暫停' : '已關閉，以下設定保留但暫停', trailing: AppSwitch)])` | Off → every row below is `enabled: false` and its `AppSwitch` gets `onChanged: null`. Stored values are kept. |
| Group label | `Text` caption1 semibold fg2 (same style as `_fieldLabel` `playback_card.dart:490`) | `分區警特報通知`, `其他` |
| Per place | `AppList` of `AppListRow(primary: '縣市 鄉鎮', trailing: AppSwitch)`, one per saved place in saved order | Removing a saved place also drops its setting. No saved places: `Text('沒有儲存的地點。在「儲存的地點」加入後可個別開啟。')` caption1 fg3. |
| 降雨提醒 | `AppListRow(leading: _Tint(Icons.umbrella_outlined), primary: '降雨提醒', secondary: '目前地點即將下雨時', trailing: AppSwitch)` | |
| 靜音時段 | `AppListRow(leading: _Tint(Icons.bedtime_outlined), primary: '靜音時段', secondary: summary, trailing: AppSwitch)` | summary: `22:00 到隔天 07:00，共 9 小時` when end ≤ start, otherwise `13:00 到 15:00，共 2 小時`. |
| 開始 / 結束 | `AppListRow(leading: _Tint(Icons.schedule), primary: '開始' / '結束', trailing: [AppBadge('隔天')?, Text('07:00' tabular), Icon(chevron_right)], onTap: pickTime, enabled: quietOn && masterOn)` | `pickTime` = Flutter `showTimePicker` with `MediaQuery(alwaysUse24HourFormat: true)` in its `builder`. `隔天` badge on 結束 when end ≤ start. |
| Same start and end | `StatusBanner(tone: error, title: '開始與結束時間不能相同', text: '已保留原本的 22:00 到 07:00')` under the rows | The new value is rejected and not saved. |
| Footer note | `_Note(Icons.info_outline, '目前只儲存你的偏好，App 還不會發送通知。')` | |

### 4.6 Data pages without a valid token (all other tabs)

`EmptyState(icon: Icons.key, title: '尚未設定中央氣象署授權碼', text: '<頁面>資料需要授權碼。到「設定」輸入後即可載入。', actions: [AppButton('前往設定', primary, onPressed: () => ref.read(appTabProvider.notifier).select(AppTab.settings))])`. For 無效: `error: true`, title `中央氣象署授權碼無效`, text = the reason. No default or cached data is shown (frame P7).

## 5. New components (only these)

| Component | Where | Why an existing widget does not cover it |
|---|---|---|
| `AppSwitch` | `lib/core/widgets/choices.dart` | No shared switch exists. A tokenised `Switch` is already hand-styled in `playback_card.dart:470-477`. This page needs 8+ of them. Extract that exact styling: `activeTrackColor: brandBg`, `inactiveTrackColor: strokeAccessible`, thumbs `bg1`, no outline. Migrate radar to it so there is one copy. Use it as the `trailing` of an `AppListRow`. The row's `onTap` toggles, and the row is wrapped in `MergeSemantics` so it reads as one switch. |
| `AppTextField` | `lib/core/widgets/inputs.dart` (new file) | The only field today is the page-local `_SearchField` (`location_screen.dart:887-921`). It has no label, obscure text, suffix action or error text. Generalise it with `label`, `hint`, `prefixIcon`, `suffix`, `obscureText`, `readOnly`, `onTap`, `onChanged`, `onSubmitted`, `controller`, `helpText`, `errorText`. It keeps the same tokens (stroke1 border, brandStroke 2 px on focus) and adds a dangerFg 2 px border on error. `_SearchField` is deleted and the picker uses `AppTextField`. |
| `BadgeTone.success`, `BadgeTone.danger` | enum `data_display.dart:6` + switch `data_display.dart:18` | Token status needs a green 有效 and a red 無效. Reusing `alert3` for "invalid" would mean the rain level 大豪雨. Map them to `successBg/Fg/Stroke` and `dangerBg/Fg/Stroke` (all in `AppPalette`). |
| `StepMarker` (page-local, not shared) | settings screen file | The `_Step` circle (`location_screen.dart:924`) gains active, done and optional states. Only the setup card uses it. |

Not new: setting rows and time rows are `AppListRow`. The time picker is the Flutter SDK `showTimePicker`. The banners are `StatusBanner`. The empty states are `EmptyState`.

## 6. Accessibility

- Touch targets: every row is an `AppListRow`, at least `AppSize.touch` 44 tall (`data_display.dart:239`). Icon buttons are 44×44 (`buttons.dart:130`). Buttons are 44 high. Small banner buttons are 32 high but sit inside a 44+ row.
- Switch rows: wrap in `MergeSemantics` so a screen reader says "自動定位，開關，已開啟". Tapping anywhere on the row toggles. When disabled, the switch and the row text both use `fgDisabled`.
- Time rows: `Semantics(label: '靜音結束時間 隔天 07:00', button: true, hint: '點兩下修改')`.
- Token field: visible label (no placeholder-only label). The eye button tooltip switches between 顯示授權碼 and 隱藏授權碼. The error text sits under the field with `liveRegion: true`. Enter runs `儲存並驗證`. The key is never logged or put in a semantics label, which reads only the masked form.
- Setup steps: `Semantics(label: '第 1 步，共 2 步，目前步驟：輸入中央氣象署授權碼')`. The progress bar has a semantics label.
- Verifying banner and invalid banner are live regions.
- Status never relies on colour alone: every badge has text (有效/無效/驗證中/未設定) and the `隔天` marker is text.
- Focus order follows the card order, which follows the mode order (the blocker comes first).

## 7. Open points for the architects

1. A network failure during verification is not "the key is wrong". This design shows it as 無效 with the reason `無法連線到中央氣象署，尚未確認授權碼…` because the contract fixes four statuses. A separate status such as 無法驗證 would be more accurate but needs a contract change.
2. Setup mode needs the token status to be known at start-up. A stored key that was never verified (for example after a reinstall restore) should display as 未驗證 or be verified on launch. That choice belongs to the architecture plan.
3. The CWA key format (`CWA-` + 8-4-4-4-12 hex) is used only as the hint text. Strict client-side format validation is not proposed because the real CWA call is the source of truth.
