# 雨量頁 — Designer 1：堆疊卡片，每張地圖卡自帶小地圖與內嵌播放

Mockup: `rainfall.html`（同資料夾）。契約：`docs/logs/rainfall-page-contract.md`。Brief：`docs/design/rainfall/brief.md`。
Tokens：`lib/core/theme/app_tokens.dart`。版面規則：`docs/design/adaptive/hazard.md`、`system.md`。

## 1. 設計理念

- 五張卡片依序直接顯示，沒有 觀測｜未來1小時 切換：最近測站 → 未來1hr預測 → 小時累積雨量 → 日累積雨量 → 測站今日累積雨量。
- 「看數字」在上、「看地圖」在中、「查清單」在下。三張地圖卡長得一樣：標題列 → 4:3 小地圖（左上時間 chip、定位針、回我的位置鈕）→ 圖例；兩張累積圖多一條自己的播放列。
- 每張卡片獨立載入、獨立失敗、獨立重試：一張地圖卡失敗，只換掉該卡的地圖區並給「重試」，其他卡片照常。只有「測站資料」整個失敗時，最近測站與測站清單才一起進入錯誤狀態。
- 沒有新資料概念：全部是現有元件的組合，只新增一個頁面內元件與一個播放列抽取（見 §4）。

## 2. 頁面骨架與版面

| 元素 | Widget | 備註 |
|---|---|---|
| 頁框 | `AppPageScaffold`（`lib/core/widgets/page_scaffold.dart:17`） | 沿用 `rainfall_screen.dart` 現有的 `source`、`onRefresh`；`children` 改為五個 cell，**移除** `AppSegmented` 切換列。 |
| 標題列 | `AppPageHeader`（`page_scaffold.dart:122`） | `title: '雨量'`，`subtitle`：「臺北市 中正區 · 更新 14:30」／「尚無目前地點」／「尚未設定授權碼」。 |
| 狀態橫幅 | `StatusBanner`（`lib/core/widgets/status.dart:11`），含授權碼情況用 `ApiKeyNotice`（`lib/core/widgets/api_key_notice.dart:11`） | 放在五張卡片之上，`AppGridItem.full`。 |

| 視窗 | 欄數 | 順序 |
|---|---|---|
| 手機 375（compact，底部導覽） | 1 | 1 → 2 → 3 → 4 → 5 |
| ≥ 776（medium/expanded，側欄，內容 ≥ 696） | 2 | 最近測站橫跨整列；預測｜小時累積；日累積｜測站清單。DOM 順序不變，由左至右、由上至下。 |

`AppGrid` 最多 2 欄（`system.md` §2），格子頂端對齊、不等高。寬螢幕下最近測站卡內部：名稱＋大數字＋兩個 `MetricTile` 限寬 640，不拉滿。地圖卡內部寬螢幕不變，只是每張地圖變成約 540 px 寬。

## 3. 卡片逐張規格

### 卡 1 最近測站
| 部位 | Widget | 備註 |
|---|---|---|
| 容器 | `AppCard`（`app_card.dart:15`）`title: '最近測站'`、`meta: '14:30 更新'` | 載入用 `AppCard.loading`、無地點用 `AppCard.empty`。 |
| 名稱＋距離＋等級 | 頁面內 Row + `RainLevelBadge`（`lib/features/hazard/rainfall/level_style.dart:18`） | 0 = 「未達警戒」中性徽章。 |
| 今日累積大數字 | 沿用 `ObservationHeroCard`（`observation_view.dart:17`）的大數字 Text | 單位 mm 放旁邊；顏色用 `AppPalette.rainFg`。 |
| 過去 1／3 小時 | `MetricGrid`＋`MetricTile`（`lib/core/widgets/data_display.dart:214` / `:151`） | 兩格。 |
| 警戒門檻條 | `_ThresholdBar`（`observation_view.dart:119`） | 80／200／350／500 mm；門檻來自 `rainWarningThresholds`（`rainfall_logic.dart:4`），線段寬度 `thresholdSegmentPercents`。 |

### 卡 2 未來1hr預測
| 部位 | Widget | 備註 |
|---|---|---|
| 容器 | 新元件 `RainMapCard`（§4）外層是 `AppCard(flush: true)`（`app_card.dart:15`） | `meta`: 「14:30 發布」。 |
| 地圖 | `RadarMapView`（`lib/features/radar/widgets/radar_map_view.dart:207`），`overlayImages` = `forecast_view.dart` 現有的 `OverlayImage`（4 色格點） | `chipText`: 「14:30 發布」；`me` 為 null 時不畫針。 |
| 此處預測值 | 頁面內 Row：`Text`（caption）＋ `Text`（`5–10 mm`，subtitle，`rainFg`） | 無地點顯示「— 需要目前地點」。 |
| 圖例 | `_ForecastLegend`（`forecast_view.dart:239`） | 4 格：1–5／5–10／10–20／≥ 20 mm。 |
| 播放 | 無（單一時間點） | |

### 卡 3 小時累積雨量
| 部位 | Widget | 備註 |
|---|---|---|
| 容器、地圖 | `RainMapCard` ＋ `RadarMapView`，`overlayImages` 為當前幀、`upcoming` 為後續待解碼幀（`radar_map_view.dart:196`） | `chipText`: 「14:30 · 過去 1 小時」。 |
| 播放列 | `InlinePlaybackBar`（§4，由 `playback_card.dart` 抽出），餵 `PlaybackFrames`（`playback_card.dart:19`） | 每 30 分鐘一幀、約 48 幀（過去 24 小時）；時間軸刻度 昨 14:30／06:30／現在。 |
| 圖例 | `RainfallScaleLegend`：把 `observation_view.dart:249` 的 `_MapLegend` 公開並共用 | 17 色取自 `AppPalette.rainfallMapScale`（`app_tokens.dart:151`），標號取自 `rainfallMapScaleLabels`（`rainfall_logic.dart:15`）。 |

### 卡 4 日累積雨量
同卡 3，差異只有：`chipText`: 「14:30 · 自 00:00」、幀範圍是今天 00:00 到最新（約 30 幀）、`meta`: 「自 00:00 累積」。圖例同一個 `RainfallScaleLegend`。

### 卡 5 測站今日累積雨量
| 部位 | Widget | 備註 |
|---|---|---|
| 整卡 | `StationListCard`（`lib/features/hazard/rainfall/station_list.dart:20`）原樣保留 | 縣市 `AppChip`（`lib/core/widgets/choices.dart:9`）、排序、顯示全部／收合、每列等級條 `_LevelBar`（`station_list.dart:305`）都不動。 |
| 無地點 | 預設縣市＝「全部縣市」 | 沒有「最近」標記。 |

## 4. 新元件與理由

1. **`RainMapCard`**（頁面內，放 `lib/features/hazard/rainfall/rain_map_card.dart`）。三張地圖卡結構相同（標題列、固定 4:3 地圖、圖例、可選播放列），目前 `ForecastMapCard` 與 `RainfallMapCard` 各自重複 `AppCard`＋地圖＋圖例；合併成一個以參數區分（overlay、legend、可選 playback）的元件，符合「相似功能單一通用模組」。取代 `forecast_view.dart:149` 的 `ForecastMapCard` 與 `observation_view.dart:204` 的 `RainfallMapCard`（舊的連同測試一併刪除）。
2. **`InlinePlaybackBar`**。`PlaybackCard`（`playback_card.dart:90`）內有 `_Controls`（`:178`）與 `_Timeline`（`:260`）；把這兩段抽成公開的精簡列（播放鍵＋滑桿＋時間戳＋刻度，不含 `AppCard` 外殼與設定面板），`PlaybackCard` 內部改用它，雷達頁行為不變。理由：卡片內要的是簡單播放，不需要雷達頁的速度／透明度設定。
3. **`RainfallScaleLegend`**：僅是把現有私有圖例公開，不是新設計。

`RadarMapView` 需要小改：新增 `interactive` 旗標（見 §6）。

## 5. 三張地圖不變重的做法

- **各自一張地圖，但共用底圖資源**：三張卡初始鏡頭相同（台灣全島），底圖圖磚由同一個 provider／快取提供，同一鏡頭下第二、三張地圖不會重複下載圖磚。
- **懶掛載**：地圖卡捲進視窗前只顯示固定高度的骨架（高度與地圖相同，版面不跳）；進入視窗一次後才建立 `RadarMapView` 並抓影格清單。離開視窗後地圖保留、播放暫停。
- **影格按需抓**：進入視窗只抓「最新一幀」；按播放或拖滑桿時才抓其餘幀，並只預解碼接下來的幾幀（沿用 `upcoming` 的上限 `radarPreDecodeCount`）。
- **同時只播一個**：任一張開始播放時，其他張自動暫停（頁面層持有一個「目前播放中」的值）。
- **預測圖是單張圖**：不抓影格清單，成本最低。

## 6. 捲動與手勢衝突

- 地圖在頁面垂直捲動區內。預設**單指拖曳＝捲動頁面**，**雙指＝縮放與移動地圖**（`RadarMapView` 新增 `interactive` 旗標，flutter_map 互動旗標只開雙指縮放／雙指平移與雙擊縮放，關閉單指拖曳）；地圖左下角常駐提示「雙指移動／縮放地圖」，用過一次雙指手勢後淡出。
- 「回到我的位置」鈕（`_LocateFab`，`radar_map_view.dart:565`）仍可點，用來重設被移動的鏡頭。
- 播放滑桿在地圖**下方**、不與地圖重疊，橫向拖滑桿不會觸發頁面捲動（滑桿本身吃橫向手勢）。
- 滑鼠／觸控板（寬螢幕）：滾輪預設捲動頁面，按住 Ctrl／⌘ 才縮放地圖，避免捲頁時地圖亂縮。

## 7. 狀態（HTML 框 B–F）

| 狀態 | 呈現 | Widget |
|---|---|---|
| 載入中 | 五張卡片骨架；地圖區預留相同高度 | `AppCard.loading`（`app_card.dart:30`）、`Skeleton`（`status.dart:201`） |
| 錯誤 | 該卡地圖區變淡並疊「無法取得…／重試」；其他卡片不受影響。測站資料失敗時卡 1、卡 5 顯示 `AppCard.error` | `StatusBanner(tone: error)`、`RetryButton`（`status.dart:229`）、`AppCard.error`（`app_card.dart:45`） |
| 沒有授權碼 | 頂部 `ApiKeyNotice`「前往設定」；五張卡片停用但保留版位（地圖變淡、chip「需要授權碼」） | `ApiKeyNotice`、`StatusBanner(tone: permission)` |
| 沒有地點／定位被拒 | 頂部橫幅（到設定選擇地點／重新定位）；卡 1 空狀態；卡 2 無定位針、「此處預測」顯示需要地點；卡 3、4 地圖照常；卡 5 預設全部縣市 | `StatusBanner`、`AppCard.empty`、`EmptyState`（`status.dart:125`） |
| 無降雨 | 全部 0：卡 1 顯示 0.0 mm「未達警戒」；地圖無色塊，chip 寫「無降雨」；播放列與圖例仍在；測站清單全 0.0 並註明「今日各測站皆無降雨」 | 同上元件，不隱藏任何卡片 |

## 8. 已知取捨與不確定項

- 垂直長度：手機上五張卡約 4.5 個螢幕高；換來每張地圖都有自己的播放，不必來回切換。若使用者覺得太長，可改選 designer-4（縮圖摺疊）。
- 小時累積圖例在 375 px 寬時，17 色標號採「每色下限」且隔一個顯示，寬螢幕才全顯示；螢幕閱讀器朗讀全部。
- 影格數（48／30）與「過去 24 小時」是依契約「以檔名規則推得歷史影格」的假設；實際保留時間以歷史研究結果為準。
- 上述 Flutter 互動旗標與快取共用屬設計意圖，實作時需實測確認（本提案未跑 app）。
