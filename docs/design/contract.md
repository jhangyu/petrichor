# UI 重設計 Mockup 收斂契約（2026-11-14 凍結，只有使用者能改）

## 終態
每個 App 頁面各有兩版 Fluent 2 亮色風格 HTML mockup（A 團隊一版、B 團隊一版），已經對齊審查通過。

## In-scope 交付物
1. `docs/design/preflight/` 進度盤點三份報告（文件進度、程式碼／測試狀態、頁面功能盤點）。
2. `docs/design/tokens-fluent2-light.css`：兩團隊共用的 Fluent 2 亮色 design tokens（色彩、字級、間距 4px 格、圓角、陰影）。
3. `docs/design/team-a/<page>.html` 與 `docs/design/team-b/<page>.html`：每個頁面每團隊一份，皆 `<link>` 共用 tokens。
   頁面（檔名）：`home`（天氣主頁）、`radar`（雷達回波＋播放動畫）、`warnings`（警特報）、`rainfall`（雨量觀測＋降雨預測，分頁籤）、`location`（定位權限引導＋地點選擇）。
   另附 `components.html`：共用元件總表（tokens 設計者交付，兩隊沿用）。
4. `docs/design/review/alignment-review.md`：對齊／置中／間距審查報告。

## Out-of-scope
- 修改 `lib/` 任何 Flutter 程式碼、commit、暗色主題。

## 驗收條件
1. 每個 HTML 只用 tokens 檔的 CSS 變數表示色彩、間距、圓角（`grep` 不得出現 tokens 以外的 hex 色碼，資料視覺化色階除外並需註解）。
2. 無暗色主題：`grep -iE "prefers-color-scheme: *dark|data-theme=.dark|\.dark" docs/design -r` 為零命中。
3. 頁面涵蓋 preflight 功能盤點列出的每一項功能（每份 HTML 頂部註解列出對應功能清單）。
4. 同一團隊各頁共用同一套 header/卡片/按鈕元件樣式；兩團隊都依同一 tokens 檔。
5. 審查者對每份 HTML 用瀏覽器量測（headless 截圖＋getBoundingClientRect）檢查置中、間距是否為 4px 倍數、同列元素對齊；blocker 為零。
6. 375px 與 1280px 兩種寬度下無水平捲動。

## 輪次預算
3 輪（設計 → 審查 → 修正為一輪）。

## 使用者裁決（2026-11-14）
- 驗收 2 的檢查排除 contract.md 本身。
- 雨量頁拿掉 24 小時預測，只保留觀測與未來 1 小時（F-B0046-001，網格雨量值，以使用者位置取值＋網格圖）。
- 雷達播放影格來自官網時間戳記圖（過去 24 小時可回溯，預設播放最近 2 小時 12 格），畫面註明「資料來源：中央氣象署」。
- 警特報不做「已解除」分頁；警特報只到縣市層級。
- 雷達播放：預設回溯 4 小時（24 格），可調回溯時間（最長 24 小時）、fps、重複播放開關（開啟時播完固定等 3 秒再重播）。兩隊選項一致。
