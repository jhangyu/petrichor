# 雨量頁 — Designer 2：共用時間軸

Mockup: `rainfall.html`（375 px 手機 ×6 狀態、≥1024 px 寬版 ×1）。契約：`docs/logs/rainfall-page-contract.md`。

## 核心想法
五張卡直接由上而下，無分頁。**小時累積與日累積共用同一個時間游標**（每 30 分鐘一格，窗口＝過去 24 小時）：一條播放軸同時驅動兩張地圖；小時卡顯示「游標前 1 小時」，日卡顯示「游標當日 00:00 至游標」。播放軸是浮在底部導覽列上方的單一控制（sticky dock），只有兩張累積卡其中一張在視窗內時才顯示；未來1hr預測沒有歷史影格，不受游標控制。地圖一律精簡高度（176 px，寬版 240 px）。

## 頁面骨架（`lib/features/hazard/rainfall_screen.dart`）
`PageScaffold`（`lib/core/widgets/page_scaffold.dart`）＋ `ListView` ＋ 一個 Stack 疊層放 dock。順序固定：

| # | 卡 | 實作 widget（檔案） | 變更 |
|---|---|---|---|
| 1 | 最近測站 | `ObservationHeroCard`（`lib/features/hazard/rainfall/observation_view.dart`），內含 `_ThresholdBar`、`MetricGrid`／`MetricTile`、`AppBadge`（`lib/core/widgets/data_display.dart`）、`RainLevelBadge`（`lib/features/hazard/rainfall/level_style.dart`）；門檻 80/200/350/500 來自 `rainfall_logic.dart` | 沿用；從觀測分頁拆出，直接置頂 |
| 2 | 未來1hr預測 | `ForecastMapCard`（`lib/features/hazard/rainfall/forecast_view.dart`）＋ `RadarMapView`（`lib/features/radar/widgets/radar_map_view.dart`，`overlayImages` 放預測 PNG，`chipText`＝「預測 14:00–15:00」）＋ `ForecastHeroCard` 的「目前地點數值」改為卡內一列 `AppBadge` | 沿用；Hero 與地圖合為一張卡 |
| 3 | 小時累積雨量 | 新 `RainfallAccumMapCard`（見下）＋ `RadarMapView` ＋ `_ForecastLegend`／`_MapLegend` 抽成共用圖例 | **新增** |
| 4 | 日累積雨量 | 同上（參數不同，`observation_view.dart` 的 `RainfallMapCard` 被取代並刪除） | **新增，取代 `RainfallMapCard`** |
| 5 | 測站今日累積雨量 | `StationListCard`（`lib/features/hazard/rainfall/station_list.dart`）：`AppList`／`AppListRow`（`data_display.dart`） | 沿用，置底 |
| dock | 共用時間軸 | `PlaybackCard`（`lib/features/radar/widgets/playback_card.dart`）精簡版 | 見「新元件」 |

每卡外框皆為 `AppCard`（`lib/core/widgets/app_card.dart`），標題用其 `title`／`meta`。

## 各卡細節
1. **最近測站**：大字今日累積（mm）＋警戒徽章（`RainLevelBadge`，低於 80 mm 顯示「無降雨」／無徽章）；兩格 `MetricTile`（過去 1／3 小時）；`_ThresholdBar` 顯示 0/80/200/350/500。meta＝「站名 · 距離」。
2. **未來1hr預測**：地圖 176 px，左上 chip 顯示預測區間，右下定位鈕；地圖下一列「目前地點：1–5 mm」；圖例（4 級桶，F-B0046-001 色階）；card meta＝發布時間。無播放。
3. **小時累積**：地圖 chip＝「13:00–14:00 累積」；目前地點數值；圖例（過去 1 小時 mm）；meta＝觀測時間。影格來自游標。
4. **日累積**：chip＝「00:00–14:00 累積」；圖例用 17 色 `AppPalette.rainfallMapScale`（`lib/core/theme/app_tokens.dart:151`；HTML 以 7 個 dbz token 示意，無對應 CSS token）；影格來自游標；游標跨午夜時日卡自動換到該日 00:00 起算，播放軸上以刻度標出日界。
5. **測站列表**：依距離排序，每列測站名＋距離＋迷你 `_LevelBar`＋mm；預設 5 列，「顯示更多」展開（沿用現有行為）。

## 狀態（HTML 框 B–F）
- 載入：最近測站與列表用 `Skeleton`（`lib/core/widgets/status.dart`），三張地圖卡用地圖高度的 `Skeleton`；dock 停用並顯示「緩衝中」。
- 錯誤：**逐卡**換成 `StatusBanner`(error)＋`RetryButton`（`status.dart`），其餘卡照常；游標仍驅動成功的那張。
- 無 token：`ApiKeyNotice`（`lib/core/widgets/api_key_notice.dart`）取代整頁五張卡與 dock，「前往設定」切到設定分頁。
- 無地點／定位被拒：最近測站卡改 `StatusBanner`(permission)＋「前往設定」；地圖仍顯示全台、`RadarMapView.me = null`（無圖釘、定位鈕停用）、不顯示「目前地點」列；dock 照常。
- 無降雨（全 0）：地圖無色塊（overlay 全透明，chip 仍顯示時間）、最近測站徽章「無降雨」、列表全 0.0。

## 新元件與理由
- **`RainfallAccumMapCard`**（新，`lib/features/hazard/rainfall/accum_map_card.dart`）：小時／日兩卡版型相同，只差資料來源、標題、圖例刻度，合為一個通用 widget（符合「相似功能單一模組」）。取代 `RainfallMapCard`。
- **共用時間游標狀態**（新 provider，同資料夾）：持有「游標時間、播放中、fps」，兩卡讀取同一值；影格清單取小時源與日源的時間交集，只有一源有圖的時間格不可選。理由：使用者要的是「同一時刻看兩種累積」，兩條獨立軸會互相錯位。
- **精簡 dock**：不新建 widget，由 `PlaybackCard` 增加精簡模式（只保留時間列、控制列、時間刻度，隱藏 fps／重複／窗口設定，設定收進長按或齒輪）；雷達頁行為不變。

## 三張地圖如何不沉重
- 懶載入：地圖卡進入視窗（距離 ≤ 1 個螢幕）才建立 `RadarMapView` 與抓圖；離開視窗兩個螢幕以上時釋放 tile 與解碼影格，只留靜態快照縮圖。
- 預測圖單張、無播放；兩張累積圖共用同一游標，影格預解碼沿用 `RadarMapView.upcoming`（上限 `radarPreDecodeCount`），因為兩圖同步，同時只解下一格各一張。
- 播放只在 dock 按下播放時進行，且僅可見的累積地圖更新；不可見者跳過解碼。
- 底圖 tile 由 OSM 快取共用，三張圖視窗位置相同（台灣全境），tile 重複命中。

## 捲動與地圖手勢衝突
- 精簡地圖預設**單指拖曳＝捲動頁面**；地圖只開雙指縮放／雙指平移（`InteractiveFlag.pinchZoom | pinchMove`），不開單指拖曳、不開旋轉。
- 地圖右下定位鈕可回到目前地點；需要細看時雙指放大即可，不需要另開模式。
- dock 內的拖曳條只在 dock 範圍內處理水平手勢，不與頁面垂直捲動競爭。

## 寬版（≥1024 px，`docs/design/adaptive/hazard.md` 規則）
內容置中、最大寬 1100：上排「最近測站｜未來1hr」兩欄；中段 dock 變成一般列（不浮動）橫跨整寬；其下「小時累積｜日累積」兩欄並排（地圖 240 px）；最底部測站列表整寬。兩張累積圖並排時共用游標的意義最明顯。

## 取捨與不確定項
- 共用游標讓日累積也只能回看 24 小時內的 30 分鐘影格；若 CWA 日圖歷史窗口短於小時圖（契約中歷史研究尚未定案），游標範圍取交集，需待研究結果。
- 小時源 O-B0045-001 與日源 O-A0040-003 的影格時間是否整點對齊未驗證；若不對齊，需「最近可用影格」對映規則。
- 圖例色階 HTML 僅為示意色，不代表最終色票。
