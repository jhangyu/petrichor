/// App 常數與 API 端點設定
///
/// API key 不在此處：使用者於「設定」輸入，存在 shared_preferences（見 core/api/api_key.dart）。
class AppConstants {
  AppConstants._();

  // -------------------------------------------------------------------------
  // API設定
  // -------------------------------------------------------------------------

  /// CWA Open Data API base URL
  static const String cwaApiBaseUrl =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore/';

  // -------------------------------------------------------------------------
  // Dataset IDs（氣象資料集）
  // -------------------------------------------------------------------------

  /// 即時觀測（10 分鐘綜觀氣象，約 363 站）
  static const String observationDataset = 'O-A0003-001';

  /// GPS 判定所在縣市用的測站清單（自動氣象站，約 870 站，比 [observationDataset] 密）
  static const String countyLookupDataset = 'O-A0001-001';

  /// 各縣市逐日日出日沒時刻（含民用曙暮光）
  static const String sunTimesDataset = 'A-B0062-001';

  /// 警特報：各縣市生效特報
  static const String warningsByCountyDataset = 'W-C0033-001';

  /// 警特報：公告（發布時間、有效期間、內文、影響縣市）
  static const String warningBulletinsDataset = 'W-C0033-002';

  /// 雨量站今日累積（datastore）
  static const String rainObservationDataset = 'O-A0002-001';

  /// 未來 1 小時雨量預測格點（fileapi 專屬）
  static const String rainForecast1hDataset = 'F-B0046-001';

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

  /// fileapi 資料集 URL。`format=JSON` 由 dioProvider 的預設 query 提供、金鑰由其攔截器加入；
  /// 同名 query 重複會讓 CWA 回 404，所以這裡不能再寫。
  static String fileApiUrl(String datasetId) => '$cwaFileApiBaseUrl$datasetId?downloadType=WEB';

  // -------------------------------------------------------------------------
  //網路請求設定
  // -------------------------------------------------------------------------

  /// 連線逾時（毫秒）
  static const int connectTimeoutMs = 15000;

  /// 接收逾時（毫秒）
  static const int receiveTimeoutMs = 15000;

  /// fileapi 先回 302 再回 200，最多跟隨的轉址次數
  static const int maxRedirects = 5;

  // -------------------------------------------------------------------------
  // 地理
  // -------------------------------------------------------------------------

  /// 地球平均半徑（公里，IUGG）
  static const double earthRadiusKm = 6371.0088;
}
