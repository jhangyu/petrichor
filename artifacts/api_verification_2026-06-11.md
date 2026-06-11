# CWA API 驗證報告
**日期**: 2026-06-11
**驗證者**: api-verifier

---

## API Key 狀態
- **狀態**: ✅ 有效
- **Key 格式**: `CWA-REDACTED-API-KEY`
- **授權結果**: 所有已認證的端點皆正常回應

---

## 端點測試結果

### ✅ 可用端點

| 端點 | Dataset ID | HTTP | 回應 |
|------|-----------|------|------|
| 24小時預報 | F-D0047-089 | 200 | `success: "true"`, 包含完整天氣預報資料 |
| 雨量觀測 | O-A0002-001 | 200 | `success: "true"`, 包含全台雨量站觀測資料 |
| 天氣警特報 | W-C0033-001 | 200 | `success: "true"`, 包含大雨特報等警訊 |

### ❌ 無效端點（404）

| 端點 | Dataset ID | 錯誤訊息 |
|------|-----------|----------|
| 台灣雷達站 | O-A0058-003 | Resource not found |
| 水利署雷達（新竹） | O-A0084-001 | Resource not found |
| 水利署雷達（南屯） | O-A0084-002 | Resource not found |
| 水利署雷達（林園） | O-A0084-003 | Resource not found |
| 累積雨量圖 | O-A0040-002 | Resource not found |
| 降雨預測（1小時） | F-B0046-001 | Resource not found |
| 降雨預測（24小時） | F-C0034-006 | Resource not found |

---

## WeatherRepository 整合測試

### ✅ getWeeklyForecast (已驗證)
- **Method**: `repo.getWeeklyForecast('臺北市')`
- **結果**: Success
- **解析**: `WeeklyForecast` 包含 `locationName` 和 3 天預報資料
- **JSON 結構驗證**:
  ```json
  {
    "LocationsName": "台灣",
    "Location": [{
      "LocationName": "連江縣",
      "WeatherElement": [{ "ElementName": "溫度", ... }]
    }]
  }
  ```

### ✅ getCurrentWeather (已驗證)
- **Method**: `repo.getCurrentWeather('新北市')`
- **結果**: Success
- **解析**: `CurrentWeather` 從預報資料衍生，包含溫度、天氣描述等欄位

### ⚠️ getRadarImageUrl (需修正)
- **Method**: `repo.getRadarImageUrl()`
- **結果**: Success（但 URL 為預設值，非 API 取得）
- **原因**: O-A0058-003 等雷達端點返回 404
- **目前回傳**: `'https://cwa.gov.tw/V8/C/W/Observe/Radar/Image'`

---

## 關鍵 JSON 欄位截錄

### 24小時預報 (F-D0047-089)
```json
{
  "success": "true",
  "result": {
    "resource_id": "F-D0047-089",
    "fields": [
      "Temperature", "RelativeHumidity", "WindSpeed",
      "ProbabilityOfPrecipitation", "Weather", "WeatherCode"
    ]
  },
  "records": {
    "Locations": [{
      "LocationsName": "台灣",
      "Location": [{
        "LocationName": "連江縣",
        "WeatherElement": [{
          "Time": [{ "DataTime": "...", "ElementValue": [{ "Temperature": "23" }] }]
        }]
      }]
    }]
  }
}
```

### 雨量觀測 (O-A0002-001)
```json
{
  "success": "true",
  "records": {
    "Station": [{
      "StationName": "九份二山",
      "ObsTime": { "DateTime": "2026-06-11T23:10:00+08:00" },
      "RainfallElement": {
        "Now": { "Precipitation": "27.0" },
        "Past1hr": { "Precipitation": "0.0" },
        "Past24hr": { "Precipitation": "27.0" }
      }
    }]
  }
}
```

---

## 失敗項目分析

### 雷達 API (O-A0058-003, O-A0084-001/002/003)
1. **現象**: 所有雷達端點返回 `Resource not found (404)`
2. **可能原因**:
   - Dataset ID 已過期或變更
   - API 端點需要更換為新版 ID
   - API 授權不足（需額外申請）
3. **建議**: 更新 `app_constants.dart` 中的雷達 Dataset ID，或改用替代端點

### 其他 404 端點
- `O-A0040-002` (累積雨量圖)
- `F-B0046-001` (降雨預測 1小時)
- `F-C0034-006` (降雨預測 24小時)

---

## 整合測試檔案

- **位置**: `/workspace/cwb_flutter/test/integration/cwa_api_integration_test.dart`
- **內容**: 3 個測試 case（getWeeklyForecast, getCurrentWeather, getRadarImageUrl）
- **執行方式**:
  ```bash
  cd /workspace/cwb_flutter
  flutter test test/integration/cwa_api_integration_test.dart \
    --dart-define=CWA_API_KEY=$CWA_API_KEY
  ```

---

## 總結

| 項目 | 狀態 | 說明 |
|------|------|------|
| API Key | ✅ 有效 | 可正常授權 |
| 預報 API (F-D0047-089) | ✅ 可用 | WeatherRepository.getWeeklyForecast 正常 |
| 目前天氣 | ✅ 可用 | WeatherRepository.getCurrentWeather 正常 |
| 雨量 API (O-A0002-001) | ✅ 可用 | 可整合至雨量顯示功能 |
| 警特報 API (W-C0033-001) | ✅ 可用 | 可整合至警特報功能 |
| 雷達 API | ❌ 需修正 | Dataset ID 可能已變更 |

---

## 建議修正

### 1. 雷達 Dataset ID 更新
建議更新 `lib/core/constants/app_constants.dart` 中的雷達 ID，或確認正確的 API endpoint。

### 2. 替代雷達資料來源
若 CWA 雷達 API 確實無法使用，可考慮：
- 使用其他氣象雷達資料源
- 使用靜態圖片資源
- 或從雨量觀測資料衍生雷達資訊