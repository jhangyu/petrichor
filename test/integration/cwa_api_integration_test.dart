/// CWA API 整合測試
///
/// 使用真實 API key 測試 WeatherRepository 與 CWA Open Data API 的整合。
/// 執行方式：
/// ```bash
/// cd /workspace/cwb_flutter
/// flutter test test/integration/cwa_api_integration_test.dart \
///   --dart-define=CWA_API_KEY=$CWA_API_KEY
/// ```
///
/// 注意：此測試使用真實網路呼叫，可能有網路延遲。
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cwb_flutter/data/repositories/weather_repository.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    // 初始化 ProviderContainer（API key 從 --dart-define 注入）
    container = ProviderContainer();
  });

  tearDownAll(() {
    container.dispose();
  });

  group('CWA API 整合測試', () {
    test('getWeeklyForecast - 取得一週預報', () async {
      final repo = container.read(weatherRepositoryProvider);

      final result = await repo.getWeeklyForecast('臺北市');

      // 驗證 API 回傳成功
      expect(result.isSuccess, true,
          reason: 'getWeeklyForecast 應回傳 Success');

      result.fold(
        onSuccess: (forecast) {
          // 驗證模型解析正確
          expect(forecast.locationName, isNotEmpty,
              reason: '地點名稱不應為空');
          expect(forecast.days, isNotEmpty,
              reason: '預報天數不應為空');

          // 驗證第一天的資料結構
          final firstDay = forecast.days.first;
          expect(firstDay.date, isNotNull, reason: '日期不應為空');
          expect(firstDay.weatherDescription, isNotEmpty,
              reason: '天氣描述不應為空');
        },
        onFailure: (message, statusCode) {
          fail('API呼叫失敗: $message (HTTP: $statusCode)');
        },
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('getCurrentWeather - 取得目前天氣', () async {
      final repo = container.read(weatherRepositoryProvider);

      final result = await repo.getCurrentWeather('新北市');

      // 驗證 API 回傳成功
      expect(result.isSuccess, true,
          reason: 'getCurrentWeather 應回傳 Success');

      result.fold(
        onSuccess: (current) {
          // 驗證模型欄位有資料
          expect(current.locationName, isNotEmpty,
              reason: '地點名稱不應為空');
          expect(current.weatherDescription, isNotEmpty,
              reason: '天氣描述不應為空');
          expect(current.temperature, isNotNull,
              reason: '溫度資料不應為空');
          expect(current.observationTime, isNotEmpty,
              reason: '觀測時間不應為空');
        },
        onFailure: (message, statusCode) {
          fail('API 呼叫失敗: $message (HTTP: $statusCode)');
        },
      );
    }, timeout: const Timeout(Duration(seconds: 30)));

    test('getRadarImageUrl - 取得雷達圖 URL（fileapi/v1/opendataapi）', () async {
      final repo = container.read(weatherRepositoryProvider);

      final result = await repo.getRadarImageUrl();

      // 驗證 API 回傳成功
      expect(result.isSuccess, true,
          reason: 'getRadarImageUrl 應回傳 Success');

      result.fold(
        onSuccess: (url) {
          // 驗證 URL 不為空
          expect(url, isNotEmpty, reason: '雷達圖 URL 不應為空');
          // 驗證 URL 格式（包含 http 或 https）
          expect(url, matches(RegExp(r'^https?://')),
              reason: 'URL 應為有效格式');
          // 驗證 URL 為實際 API 回傳的 ProductURL（非預設值）
          expect(url, isNot(equals('https://cwa.gov.tw/V8/C/W/Observe/Radar/Image')),
              reason: 'URL 不應為預設 fallback 值');
        },
        onFailure: (message, statusCode) {
          fail('雷達 API 呼叫失敗: $message (HTTP: $statusCode)');
        },
      );
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}
