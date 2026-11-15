# 雨量頁 — Designer 4：一眼讀完，地圖收成縮圖

Mock: `rainfall.html`（A 正常、B/C 全螢幕地圖、D 載入、E 失敗、F 無授權碼、G 無地點、H 無降雨、I 寬螢幕）。契約：`docs/logs/rainfall-page-contract.md`。

## 核心想法
首屏只放數字：最近測站的大數字，加三列「縮圖＋目前地點數值」。地圖不內嵌在頁面捲動區，點縮圖才推入全螢幕地圖頁（圖例、觀測時間、播放都在那裡），所以頁面不會有地圖與捲動的手勢衝突，也不會同時掛三張地圖。

## 逐卡規格（順序固定，無分頁／分段）

| # | 卡 | 內容 | 現有 widget（檔案） |
|---|---|---|---|
| 1 | 最近測站 | 測站名＋距離、今日 mm 大字（`AppType` large title）、過去1h／3h 兩格、警戒等級 badge、0/80/200/350/500 門檻條＋目前位置標線 | `AppCard`（`lib/core/widgets/app_card.dart`）、`MetricGrid`／`AppBadge`（`lib/core/widgets/data_display.dart`）、`RainLevelBadge`（`lib/features/hazard/rainfall/level_style.dart`）、門檻條沿用 `_ThresholdBar`（`lib/features/hazard/rainfall/observation_view.dart`），門檻值 `lib/features/hazard/rainfall/rainfall_logic.dart` |
| 2 | 未來1hr預測 | 縮圖列：4 級色塊縮圖、你的位置預報級距（如 5–10 mm）、4 格圖例、發布時間 | 新元件 `MapGlanceCard`（見下）；圖例沿用 `_ForecastLegend`（`lib/features/hazard/rainfall/forecast_view.dart`）；全螢幕頁用 `ForecastMapCard` 的地圖與 `RadarMapView`（`lib/features/radar/widgets/radar_map_view.dart`） |
| 3 | 小時累積雨量 | 縮圖列：你的位置 1h 累積 mm、色階條、觀測時間、「可播放」 | `MapGlanceCard`；全螢幕頁：`RadarMapView`（`overlayImages`＋`upcoming`）＋`PlaybackCard`（`lib/features/radar/widgets/playback_card.dart`） |
| 4 | 日累積雨量 | 縮圖列：你的位置今日 mm 級距、17 色階條（`AppPalette.rainfallMapScale`，`lib/core/theme/app_tokens.dart:155`）、觀測時間 | 同上；圖例沿用 `_MapLegend`（`observation_view.dart`），可抽成共用 |
| 5 | 測站今日累積雨量 | 預設前 6 站（依距離；無地點時依雨量）＋每列迷你長條＋「顯示全部」 | `StationListCard`（`lib/features/hazard/rainfall/station_list.dart`，已有收合 6 列行為）、`AppList`／`AppListRow`（`lib/core/widgets/data_display.dart`） |

全螢幕地圖頁（B、C）：`AppPageHeader`（`lib/core/widgets/page_scaffold.dart`，帶返回）＋`RadarMapView`（`chipText` 顯示目前位置數值，沿用 `me` 定位鈕）＋底部面板：日／小時累積放 `PlaybackCard`（每 30 分鐘一格、播放、時間軸）＋圖例；未來1hr 只放圖例與發布時間，不放播放。

## 新元件：`MapGlanceCard`
- 用途：縮圖（96 px 寬）＋標題＋你的位置數值＋圖例＋時間，整列可點，三張地圖卡共用。
- 為何新增：`AppCard` 與 `MetricTile` 都沒有「縮圖＋摘要」的版型；三張卡版型相同，單一通用元件，避免各自維護。
- 檔案建議位置：`lib/features/hazard/rainfall/map_glance_card.dart`（只有雨量頁用；若其他頁要用再移 `lib/core/widgets/`）。
- 縮圖來源：同一張已下載的疊圖 PNG，以 `Image`＋`FittedBox`／`BoxFit.cover` 疊在底色上，不建立 `RadarMapView`、不載 OSM 磁磚。
- 你的位置數值：在疊圖像素上以目前位置經緯度取樣（預報／小時圖為格點值；日累積圖為色階反查級距）。**未驗證：** 日累積透明 PNG 以色階反查級距是否穩定，需實作時實測；失敗時退成只顯示觀測時間與色階條，不顯示數值。

## 三張地圖如何不重
1. 頁面上零張即時地圖：縮圖是靜態圖片，進全螢幕頁才建立一個 `RadarMapView`（一次只存在一張）。
2. 圖片延遲抓取：縮圖只需最新一格；歷史影格（小時、日累積）在進入全螢幕頁後才開始預解碼 `upcoming`。
3. 播放只存在於全螢幕頁，一次一個 `PlaybackCard`；離開頁面即釋放。
4. 各卡獨立載入／失敗，失敗的卡就地顯示 `StatusBanner`＋`RetryButton`（`lib/core/widgets/status.dart`），不拖累其他卡。

## 捲動與手勢
頁面是單純垂直捲動，無內嵌地圖，所以沒有手勢衝突：縮圖只接受點擊。全螢幕地圖頁不捲動（`AppPageScaffold.fill`），地圖拿全部拖曳／縮放手勢，底部面板固定。

## 狀態
- 載入（D）：每卡骨架（`Skeleton`，`lib/core/widgets/status.dart`），先到先顯示。
- 失敗（E）：失敗卡換成 `StatusBanner`（error）＋重試，其他卡照常。
- 無授權碼（F）：整頁只顯示 `ApiKeyNotice`（`lib/core/widgets/api_key_notice.dart`），按鈕前往設定；不渲染卡。
- 無地點／定位被拒（G）：頂部 `StatusBanner`（permission）；與地點相關數值顯示「—」，縮圖不畫位置標記；測站列表改依雨量排序；全台地圖仍可點開。
- 無降雨（H）：數字顯示 0／<1，縮圖僅底圖，門檻條灰色，測站列表換成一句 `StatusBanner`（empty）。

## 自適應（≥1024 px，I）
兩欄：左欄 360 px 放數字（最近測站＋測站列表）；右欄為單一共用地圖工作區：三張縮圖卡並排當選擇器（`aria-pressed`，不是分頁／分段），選中者在下方展開成大地圖（含播放與圖例）。同一時間只掛一張地圖。遵循 `docs/design/adaptive/hazard.md` 的欄寬規則（未逐條比對，實作時需核對）。

## 不確定項
- 縮圖數值取樣（見上）。
- 小時累積 1h 數值若採 O-B0045-001 格點，需確認單位與無資料值。
- 縮圖列右側資訊在 320 px 窄機是否擠壓，需實機檢查（mock 只驗 375）。
