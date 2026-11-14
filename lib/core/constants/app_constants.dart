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

  /// 即時觀測（10 分鐘綜觀氣象，約 363 站）
  static const String observationDataset = 'O-A0003-001';

  /// 單次查詢觀測站數上限（涵蓋全部約 363 站）
  static const int observationStationLimit = 1000;

  /// 各縣市鄉鎮預報資料集：未來 3 天（逐 3 小時）與未來 1 週（逐 12 小時）。
  /// 來源：opendata.cwa.gov.tw/webapi/datasetSearch?q=鄉鎮天氣預報 的 datacname-3 欄位，
  /// 22 縣市逐一對照（3 天 ID = n，1 週 ID = n+2）。縣市名用「臺」不用「台」。
  static const Map<String, ({String threeDay, String oneWeek})> townshipForecastDatasets = {
    '宜蘭縣': (threeDay: 'F-D0047-001', oneWeek: 'F-D0047-003'),
    '桃園市': (threeDay: 'F-D0047-005', oneWeek: 'F-D0047-007'),
    '新竹縣': (threeDay: 'F-D0047-009', oneWeek: 'F-D0047-011'),
    '苗栗縣': (threeDay: 'F-D0047-013', oneWeek: 'F-D0047-015'),
    '彰化縣': (threeDay: 'F-D0047-017', oneWeek: 'F-D0047-019'),
    '南投縣': (threeDay: 'F-D0047-021', oneWeek: 'F-D0047-023'),
    '雲林縣': (threeDay: 'F-D0047-025', oneWeek: 'F-D0047-027'),
    '嘉義縣': (threeDay: 'F-D0047-029', oneWeek: 'F-D0047-031'),
    '屏東縣': (threeDay: 'F-D0047-033', oneWeek: 'F-D0047-035'),
    '臺東縣': (threeDay: 'F-D0047-037', oneWeek: 'F-D0047-039'),
    '花蓮縣': (threeDay: 'F-D0047-041', oneWeek: 'F-D0047-043'),
    '澎湖縣': (threeDay: 'F-D0047-045', oneWeek: 'F-D0047-047'),
    '基隆市': (threeDay: 'F-D0047-049', oneWeek: 'F-D0047-051'),
    '新竹市': (threeDay: 'F-D0047-053', oneWeek: 'F-D0047-055'),
    '嘉義市': (threeDay: 'F-D0047-057', oneWeek: 'F-D0047-059'),
    '臺北市': (threeDay: 'F-D0047-061', oneWeek: 'F-D0047-063'),
    '高雄市': (threeDay: 'F-D0047-065', oneWeek: 'F-D0047-067'),
    '新北市': (threeDay: 'F-D0047-069', oneWeek: 'F-D0047-071'),
    '臺中市': (threeDay: 'F-D0047-073', oneWeek: 'F-D0047-075'),
    '臺南市': (threeDay: 'F-D0047-077', oneWeek: 'F-D0047-079'),
    '連江縣': (threeDay: 'F-D0047-081', oneWeek: 'F-D0047-083'),
    '金門縣': (threeDay: 'F-D0047-085', oneWeek: 'F-D0047-087'),
  };

  /// 雨量觀測資料
  static const String dailyRainfallDataset = 'O-A0002-001';

  /// 累積雨量圖
  static const String dailyAccumulatedRainfallMap = 'O-A0040-002';

  // -------------------------------------------------------------------------
  // 雷達資料集（fileapi/v1/opendataapi）
  // -------------------------------------------------------------------------

  /// CWA Open Data fileapi base URL
  static const String cwaFileApiBaseUrl =
      'https://opendata.cwa.gov.tw/fileapi/v1/opendataapi/';

  /// 整合雷達圖（台灣大範圍）
  static const String radarTaiwan = 'O-A0058-001';

  /// 水利署雷達（新竹）
  static const String radarShulin = 'O-A0084-001';

  /// 水利署雷達（南屯）
  static const String radarNantun = 'O-A0084-002';

  /// 水利署雷達（林園）
  static const String radarLinyuan = 'O-A0084-003';

  /// 雷達 API query參數模板（不含 dataset ID）
  static String radarApiQueryParams(String apiKey) =>
      'Authorization=$apiKey&downloadType=WEB&format=JSON';

  /// 完整雷達 API URL
  static String radarApiUrl(String datasetId, String apiKey) =>
      '$cwaFileApiBaseUrl$datasetId?${radarApiQueryParams(apiKey)}';

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

  /// fileapi 先回 302 再回 200，最多跟隨的轉址次數
  static const int maxRedirects = 5;
}
