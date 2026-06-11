/// App 常數與 API 端點設定
///
/// API key 從編譯時透過 `--dart-define=CWA_API_KEY=your_key` 注入，
/// 避免將金鑰寫入原始碼。
class AppConstants {
  AppConstants._();

  // -------------------------------------------------------------------------
  // API設定
  // -------------------------------------------------------------------------

  /// CWA Open Data API base URL
  static const String cwaApiBaseUrl =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore/';

  /// CWA API 授權金鑰（從編譯時 `--dart-define` 注入）
  /// 使用方式：`flutter run --dart-define=CWA_API_KEY=your_key`
  static String get cwaApiKey => const String.fromEnvironment(
        'CWA_API_KEY',
        defaultValue: '',
      );

  /// 檢查 API key 是否已設定
  static bool get hasApiKey => cwaApiKey.isNotEmpty;

  // -------------------------------------------------------------------------
  // Dataset IDs（氣象資料集）
  // -------------------------------------------------------------------------

  /// 鄉鎮天氣預報（24小時）-適用於各鄉鎮市區
  static const String forecast24hDataset = 'F-D0047-089';

  /// 雨量觀測資料
  static const String dailyRainfallDataset = 'O-A0002-001';

  /// 累積雨量圖
  static const String dailyAccumulatedRainfallMap = 'O-A0040-002';

  // -------------------------------------------------------------------------
  // 雷達資料集
  // -------------------------------------------------------------------------

  /// 台灣雷達站
  static const String radarTaiwan = 'O-A0058-003';

  ///水利署雷達（新竹）
  static const String radarShulin = 'O-A0084-001';

  /// 水利署雷達（南屯）
  static const String radarNantun = 'O-A0084-002';

  /// 水利署雷達（林園）
  static const String radarLinyuan = 'O-A0084-003';

  // -------------------------------------------------------------------------
  // 預報資料集
  // -------------------------------------------------------------------------

  /// 降雨預測（1小時）
  static const String rainPredict1hr = 'F-B0046-001';

  /// 降雨預測（24小時）
  static const String rainPredict24hr = 'F-C0034-006';

  // -------------------------------------------------------------------------
  //警特報資料集
  // -------------------------------------------------------------------------

  /// 天氣警特報
  static const String warningsDataset = 'W-C0033-001';

  // -------------------------------------------------------------------------
  //網路請求設定
  // -------------------------------------------------------------------------

  /// 連線逾時（毫秒）
  static const int connectTimeoutMs = 15000;

  /// 接收逾時（毫秒）
  static const int receiveTimeoutMs = 15000;
}
