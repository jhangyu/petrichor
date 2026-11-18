# 專案進度盤點（文件 vs git vs 程式碼）

盤點基準：HEAD `fc3a430`，工作樹有未提交改動（weather_repository.dart、test/unit/weather_repository_test.dart、兩份 macos entitlements）。
方法：靜態讀程式碼與 git，**未執行** flutter analyze/test/build（執行被權限擋下），故「通過/失敗」類結論僅來自 `artifacts/gate_results_2026-06-11.md`（舊紀錄）與靜態判讀。

## 1. 各 Phase：文件宣稱 vs 驗證狀態

| Phase | 文件宣稱（docs/SOP/plan.md） | 驗證狀態 | 證據 |
|---|---|---|---|
| 0 Bootstrap | ✅ 完成 | **完成** | lib/ 結構與依賴存在：pubspec.yaml:30-41；7 份維護文件存在於根目錄 |
| 1 核心天氣 | 🟡 進行中，「結果：待實作完成」(docs/SOP/plan.md:232) | **程式碼大致完成、未驗收**：天氣畫面、provider、repository 已存在並串接；但只用 24h 預報資料，且存在已知缺陷（見下） | weather_screen.dart:44-98 三態＋目前/24h/週預報區塊；weather_provider.dart:46-58；weather_repository.dart:225-246 |
| 2 雷達圖 | 💤 規劃、尚未開始 (docs/SOP/plan.md:242) | **實際已有初版**（文件過時）：RadarScreen 含 flutter_map＋OSM 底圖＋圖片疊加＋來源切換＋透明度滑桿；缺動畫播放；疊圖邊界為硬編碼估計值 | radar_screen.dart:19-172；邊界 radar_screen.dart:149-152；從天氣頁進入 weather_screen.dart:133-135 |
| 3 定位 | 🟡 規劃、「待實作」(docs/SOP/plan.md:259) | **實際已實作服務並接入天氣流程**（文件過時）；但平台權限宣告缺漏、有棄用 API 與靜默吞例外 | location_service.dart:30-84；weather_provider.dart:50；AndroidManifest.xml 與 ios/Runner/Info.plist 均無 location 權限字串（grep 零命中）；macos 僅加 network.client（未提交 diff） |
| 4 測試/CI | 💤 規劃 (docs/SOP/plan.md:274) | **部分完成**：已有 5 個測試檔（unit 2、widget 2、integration 1，共約 1100 行）；無 CI（無 .github）；覆蓋率 80% 無量測紀錄 | test/ 目錄；`ls .github` 不存在 |

## 2. docs/SOP/task.md 未完成項目驗證

| docs/SOP/task.md 項目 | 文件狀態 | 驗證 |
|---|---|---|
| ACTIVE：Phase 1 整合驗收（verifying，環境缺 Flutter SDK） | 未跑 4 個 gate | **前提不實**：本機有 Flutter SDK（`<flutter-sdk>/bin/flutter`）。gate 其實已跑過一次（artifacts/gate_results_2026-06-11.md，Flutter 3.44.1，analyze 29 errors），之後 feea766 宣稱修掉 29 errors，但**修後沒有重跑紀錄**。build_runner：.g.dart/.freezed.dart 已存在（lib/data/models/）→ 實質已跑 |
| flutter analyze 0 errors | 未跑 | **未驗證**（本次未執行）；最後紀錄 29 errors，修補 commit feea766 未附重跑結果 |
| flutter test（29 案例） | 未跑 | **未驗證**；測試於 feea766 與工作樹未提交改動又有變動 |
| flutter build apk --debug | 未跑 | **未驗證**；`build/` 目錄不存在 → 從未在此 checkout 建置過 |
| 撤銷 CWA API Key | 待使用者 | **無法由程式碼驗證**；docs/SOP/handover.md:163 稱 key 曾進 639d72f 與 reflog，仍待使用者確認 |
| Phase 2 雷達整合（等 Phase1） | 未開始 | **已開工**，見上表 |
| Phase 3 定位（規劃） | 未開始 | **已實作服務**，缺權限宣告 |
| Phase 4 widget/integration test、CI | 未開始 | 測試已存在；CI 未做 |
| ACTIVE 引用 log `Task_P1_Backend_API.md`「待建立」 | — | 檔案實名為 docs/logs/2026-06-11/Task_1_Backend_API.md 與 Task_P1_Phase1_Implementation.md，連結失效 |

## 3. 文件 vs 程式碼矛盾

1. **HEAD 過期**：docs/SOP/handover.md:140 寫 HEAD=9500a19、工作樹 clean (docs/SOP/handover.md:142)；實際 HEAD=fc3a430，且有 4 個檔案未提交修改。docs/SOP/plan.md:172 的「最新 commit: init (bootstrap)」亦過期。
2. **環境缺 SDK**：docs/SOP/task.md:122-125、docs/SOP/handover.md:151-154、docs/SOP/handover.md:162 稱無 Flutter SDK；實際有，且 gate_results 已記錄 Flutter 3.44.1 執行結果。
3. **Phase 2/3 狀態**：docs/SOP/plan.md/task.md 稱未開始，程式碼已有 radar_screen.dart（172 行）與 location_service.dart（85 行）並接入。
4. **radar_screen.dart 與 repository 簽章**：gate_results 記錄 radar_screen.dart:12 `getRadarImageUrl` 引數不符；現行 radar_screen.dart:12 以 `datasetId:` 具名參數呼叫、repository 簽章 weather_repository.dart:177 一致 → 已修。
5. **雷達資料集 ID**：app_constants.dart:57-63 的 O-A0084-001/002/003（樹林/南屯/林園）；artifacts/radar_api_verification_2026-06-11.md 記載舊 ID 含 O-A0084-001/002/003 全部 404 已廢棄 → 常數與驗證紀錄**互相矛盾**；radar_screen.dart:81-88 三個分站按鈕很可能取不到圖（未實測）。
6. **docs/SOP/plan.md 待確認項已有答案**：「是否需 API key／雷達 URL 格式」(docs/SOP/plan.md:294-295) 已解：key 由設定頁 App 內輸入（lib/core/api/api_key.dart），雷達走 fileapi ProductURL（weather_repository.dart:177-210）。
7. **docs/SOP/plan.md 架構圖**：radar_screen 註記「待實作」(docs/SOP/plan.md:146)；且未列 core/theme/、core/constants/。
8. **Phase 1 範圍「一週預報」**：UI 的週預報區塊與 24h 區塊吃同一份 `get24hForecast`（weather_provider.dart:52、weather_screen.dart:274），而該方法標 `@Deprecated`（weather_repository.dart:224）並內部改呼叫 getWeeklyForecast；`getCurrentWeather` 與 `getWarnings`（常數 warningsDataset 僅定義 app_constants.dart:82）**無任何 UI 呼叫端**（grep 零命中）。「目前天氣」實為預報第一筆。
9. **主題**：main.dart:21-23 註冊 darkTheme＋ThemeMode.system；畫面本身硬編碼深藍漸層與白字（weather_screen.dart:48-52），主題檔實質未驅動畫面。
10. **docs/SOP/memory.md/handover「玻璃擬態 3 狀態 UI」**：屬實（loading/error/empty/content 四分支，weather_screen.dart:57-68）。

## 4. 已知程式碼缺陷（靜態判讀，未實跑）

- weather_provider.dart:20-27 `copyWith` 無法把 `error` 清回 null（`error ?? this.error`）。
- weather_screen.dart:77-80 RefreshIndicator 的 onRefresh 為空實作（無實際重新整理）。
- weather_provider.dart:58 與 repository `onFailure: (_, _) => []`（weather_repository.dart:243）：API 失敗被轉成空清單，UI 只會顯示「empty」而非錯誤（違反 fail loudly）。
- location_service.dart:53 使用 `desiredAccuracy`（geolocator 14 已棄用）；location_service.dart:76-78 空 catch 靜默回預設位置；:62-66 `administrativeArea` 回傳「台北市」類寫法，與 CWA「臺北市」不一致（未提交 diff 以 `_normalizeCountyName` 補救，僅 4 個縣市，其餘如「新北市」無問題但未全面驗證）。
- weather_screen.dart 使用 `Colors.white.withOpacity`（棄用 API，分析層級 info）。
- radar_screen.dart:48 `getCurrentLocation()` 在 build 內呼叫，每次 rebuild 重新定位（調整透明度滑桿就會觸發）。
- radar_screen.dart:149-152 疊圖邊界為示意值（程式註解自述 "for demonstration"），圖像地理對位不準。
- 使用者位置顯示的是「縣市」層級的預報（repository 以 city 查詢，district 參數被忽略，weather_repository.dart:229），district 僅用於標題顯示。

## 5. Next steps（達成 plan 目標還需要）

1. **先建立可信基線**：實際跑 `flutter analyze`、`flutter test`、`flutter build`（macOS 與 apk），把結果落檔；更新 handover/task/plan 的過期宣稱（HEAD、SDK、Phase 2/3 狀態）。
2. **處理未提交改動**：weather_repository 縣市正規化、測試修正、macOS network.client entitlements——驗證後提交。
3. **Phase 1 收尾**：目前天氣改用 `getCurrentWeather`、週預報改用真正的週資料（或移除重複區塊）、下拉重新整理接線、錯誤不吞成空清單、`copyWith` 清錯誤。
4. **Phase 3 收尾**：補 Android 權限（AndroidManifest）、iOS NSLocationWhenInUseUsageDescription、改用 `LocationSettings`、移除空 catch、縣市名稱對映完整化。
5. **Phase 2 收尾**：實測四個雷達資料集是否可用（尤其 O-A0084-* 是否已廢棄）、取得正確地理邊界、播放動畫、圖層切換 UI；移除 build 內重複定位。
6. **Phase 4**：確認測試政策（保留類別、單測 ≤1s、無 sleep）、建立測試入口腳本；CI（GitHub Actions）尚未建立；80% 覆蓋率目標與使用者測試政策（不設覆蓋率目標）相衝，需使用者裁決是否刪除。
7. **UI 重設計前置**：先決定重設計是否同步重寫 WeatherScreen/RadarScreen（目前皆硬編碼深色漸層，與 Fluent 2 亮色方向不相容），並處理 main.dart 內的 darkTheme 註冊。
8. **安全**：由使用者確認舊 CWA API Key 已撤銷；`token.txt` 在專案根目錄，確認已 gitignore 且未被追蹤。

## 6. 不確定項

- 所有「是否通過」均未實跑；analyze/test/build 目前真實狀態未知。
- O-A0084-* 雷達資料集是否可用，僅有兩份互相矛盾的文件，未打 API。
- 覆蓋率與 29 案例數字未重新計數。
