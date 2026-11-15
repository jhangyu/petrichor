# 雨量頁寬版 — Designer 2

Mock: `rainfall-wide.html`（1280 寬）。尺寸全依雷達圖（見 §2）；本稿差異只在右欄分組：每列右欄拆成「標題＋時距」「播放」兩張獨立卡（預測列：「標題＋你的位置」一張），說明文字作卡外小字；圖例留在地圖卡內地圖正下方（同雷達圖）。

## 1. 斷點（沿用雷達圖）
`radar_screen.dart:162-168` 的條件：`WindowSizeClass.usesRail && !isShortHeight && AppTwoPane.fits(寬)`。
雨量頁在 `AppGridItem.full` 內，已扣過頁邊距，故用 `AppTwoPane.fits(box.maxWidth)`（≥ 2×320+16 = 656）。即：寬度 ≥ 600（有 rail）、內容 ≥ 656、高度 ≥ 480。不另設常數。
不符合 → 完全走現有窄版（堆疊、方形、鎖定地圖），不變。

## 2. 尺寸（全部沿用雷達圖，不自訂）
| 項目 | 雷達圖值 | 出處 |
|---|---|---|
| 頁邊距（寬版） | 32（expanded/large）；medium 24 | `adaptive.dart:49-53`、`app_tokens.dart:254-256` |
| 頁面上緣 | 8 | `page_scaffold.dart:56` |
| 欄間距 | 16（`AppLayout.gridGap`） | `app_tokens.dart:251`、`adaptive.dart:172` |
| 右欄寬 | 可用寬 ×0.4，夾 320–480 | `adaptive.dart:167-168`、`app_tokens.dart:270-272`（1280 視窗：1152×0.4≈461） |
| 地圖欄 | 其餘（Expanded） | `adaptive.dart:169` |
| 地圖高度 | `max(320, 窗格高 − 140)`；140 = `_heroChromeHeight`，視窗綁定，非長寬比 | `radar_screen.dart:50-51,183` |
| 卡片內距 | 16/16/20，卡內間距 16 | `app_card.dart:101`、`radar_screen.dart:417` |
| 右欄卡片間距 | 16 | `radar_screen.dart:189` |
| 地圖卡 | `AppCard(hero: true)`，內含地圖＋圖例 | `radar_screen.dart:413-444` |
| 右欄 | 多張獨立卡垂直堆疊 | `radar_screen.dart:186-192` |

地圖不再用 `radarMapDefaultAspectRatio`（5/6，`radar_map_view.dart:208`），改明確高度 `SizedBox(height: …)` 如雷達圖。窗格高在雨量頁（頁面捲動、無界高）需取可視主體高：`MediaQuery.sizeOf.height` 扣頂欄／頁首；實作時要定一個取法並與雷達圖共用同一函式（待定項）。每列地圖約一屏高，使用者用右欄捲到下一列。
mock 的 560px 為 ~800 高視窗示意值。

## 3. 控制項去向
累積雨量列
| 元件 | 位置 |
|---|---|
| 標題「累積雨量」＋ meta（觀測時間／更新頻率） | 右欄第 1 卡頂端 |
| 累積時距 chips（1…168） | 右欄第 1 卡 |
| 時間列、播放/上下一張、時間軸、播放設定（fps、循環）＝`PlaybackBody`（`playback_card.dart:132`） | 右欄第 2 卡，原樣整塊放入 |
| 影格時間 chip | 地圖左上（地圖內，原樣） |
| 圖例（`RainLegend`） | 地圖卡內、地圖正下方 |
| 資料來源／低於 1 mm 說明 | 右欄卡外小字（同雷達圖 sourceLine） |
| 部分影格失敗／資料未更新 `StatusBanner` | 右面板，時間列上方（地圖仍顯示） |
| 載入中 | 地圖 muted＋面板 `PlaybackBody(loading)`；整卡首次載入沿用 `AppCard.loading` 全寬 |
| 設定讀取失敗、網頁版無法取得 | 該列退回單一全寬 `AppCard`（不分欄），文案不變 |
| 載入失敗（`_failureBody`） | 右面板放錯誤 banner＋重試，地圖 muted |

未來 1hr 預測列
| 元件 | 位置 |
|---|---|
| 標題＋預測時段 meta | 右面板頂端 |
| 你的位置雨量 `_HereRow` | 右面板 §1 |
| 圖例、時段 chip | 地圖卡內／地圖左上 |
| 空白格說明 | 右面板底端 |
| 網格繪製失敗 `AppCard.error` | 該列全寬，不分欄 |

測站相關卡（最近測站 hero、測站今日累積雨量清單、門檻說明）：維持全寬、位置與內容不變，不在本次範圍。

## 4. 卡片順序
最近測站 hero → **累積雨量列 → 未來1hr預測列** → 測站清單 → 門檻說明。（預測列在 `forecastCard` 為 null 時整列不出現。）

## 5. 滾輪
| 區域 | 行為 |
|---|---|
| 地圖 | 縮放（`InteractiveFlag.all`，`radar_map_view.dart:378`） |
| 右面板、圖例、地圖卡邊距 | 捲頁面 |
| 面板內 Slider／chips | 不吃滾輪，轉給頁面 |

Flutter 機制：
- 右欄**不得**放任何 `Scrollable`（`SingleChildScrollView`/`ListView`/橫向捲動 chips）。雷達圖寬版右欄的 `SingleChildScrollView` 是因視窗高度綁定才需要；雨量頁是頁面捲動，右欄用普通 `Column`，滾輪事件自然落到頁面的 `Scrollable`。
- `AppTwoPane` 的 `constraints.hasBoundedHeight` 為 false → `CrossAxisAlignment.start`，不會被 stretch 成 viewport 高。
- 地圖是唯一消費 `PointerSignal` 的子樹；`flutter_map` 在地圖外不攔截。需實機（滑鼠）確認右欄無任何子元件註冊 `PointerSignalResolver`。

## 6. 共用版型 widget
雷達圖已有寬版版型：`AppTwoPane`（地圖 main｜控制 side）。雨量**不新建第二份**，直接重用：
- 新增 `RainMapCard` 變體，或把 `RainMapCard` 拆成 `main`（地圖＋圖例）與 `side`（標題＋控制）兩個插槽，由 `AppTwoPane` 排版；窄版仍用 `AppCard` 把兩者疊在同一卡內（現行外觀）。
- 刪除 `_MapRow`（`rainfall_screen.dart:240`）與兩圖同步相機的並排路徑；`cameraLink`／並排 `RadarCameraLink` 隨之移除（同步地圖 toggle 屬 parking-lot，不做）。
- `RainMapView` 需把「寬版＝未鎖定、固定高」與「窄版＝方形鎖定」改由寬/窄旗標決定（現由 `cameraLink == null` 兼任，語意要拆開）。

## 不確定項
- 標題放右面板而非地圖上方：地圖卡無標題，視覺上標題離地圖較遠；備案是標題放在整列上方（兩欄之上）。
- 預測列右欄內容很少，高度遠小於地圖，下方留白；不補假內容。
- 地圖高度的「可視主體高」取法（頁面捲動下無界高）需在實作時定，並與雷達圖共用。
- 滾輪行為需實機驗證，本稿未啟動 App。
