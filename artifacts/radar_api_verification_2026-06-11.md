# 雷達 API 驗證報告 (2026-06-11)

## 探測結果

### 新 API URL
- **URL**: `https://opendata.cwa.gov.tw/fileapi/v1/opendataapi/O-A0058-001`
- **HTTP Code**: 200
- **認證方式**: Query param `Authorization={api_key}`
- **必要參數**: `&downloadType=WEB&format=JSON`

### 舊 API 狀態
- 舊 dataset ID（O-A0058-003、O-A0084-001/002/003）全部 404
- 已廢棄

## JSON 結構

```json
{
  "cwaopendata": {
    "dataset": {
      "resource": {
        "ProductURL": "https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Observation/O-A0058-001.png"
      }
    }
  }
}
```

### 關鍵欄位
- **雷達圖 URL**: `cwaopendata.dataset.resource.ProductURL`
- **格式**: PNG image
- **S3 URL**: `https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Observation/O-A0058-001.png`

## 程式碼變更

### 1. `lib/core/constants/app_constants.dart`
- 新增 `cwaFileApiBaseUrl` 常數
- 新增 `radarApiUrl()` 產生完整 URL
- 新增 `radarApiQueryParams()` 產生 query 參數
- 更新 `radarTaiwan` 為 `O-A0058-001`

### 2. `lib/core/api/dio_client.dart`
- 新增 `fileApiDioProvider` 獨立 Dio 實例
- 避免 baseUrl + queryParameters 衝突

### 3. `lib/data/repositories/weather_repository.dart`
- 重寫 `getRadarImageUrl()` 使用 fileapi 端點
- 解析 `cwaopendata.dataset.resource.ProductURL`
- 處理 String 或 Map 的 response.data

### 4. `lib/data/models/weather_models.dart`
- 修正 `WeeklyForecast.fromCwaJson()` 解析邏輯
- 使用中文元素名稱：`天氣現象`、`3小時降雨機率`、`溫度`
- 使用大寫 key：`Locations`、`Location`、`LocationName`、`ElementName`、`Time`

### 5. `test/unit/weather_repository_test.dart`
- 更新 mock 為正確 API 結構
- 新增 `MockFileApiDio`
- 更新 radar mock 為 `cwaopendata` 結構

### 6. `test/integration/cwa_api_integration_test.dart`
- 更新雷達測試敘述
- 驗證 URL 非 fallback 值

## 整合測試結果

```
flutter test test/integration/cwa_api_integration_test.dart
00:00 +3: All tests passed!
```

- `getWeeklyForecast`: PASS
- `getCurrentWeather`: PASS
- `getRadarImageUrl`: PASS

## Unit Test 結果

```
flutter test test/unit/weather_repository_test.dart
00:00 +20: All tests passed!
```

## 備註

- API 使用 HTTP 302 redirect，需設定 `followRedirects: true`
- 雷達圖 URL 直接指向 S3 PNG，無需再下載
