/// CWA Open Data endpoints and HTTP client settings.
///
/// API key 不在此處：使用者於「設定」輸入，存在 shared_preferences（見 core/api/api_key.dart）。
class CwaHttpConfig {
  CwaHttpConfig._();

  // -------------------------------------------------------------------------
  // API設定
  // -------------------------------------------------------------------------

  /// CWA Open Data API base URL
  static const String cwaApiBaseUrl =
      'https://opendata.cwa.gov.tw/api/v1/rest/datastore/';

  /// CWA Open Data fileapi base URL
  static const String cwaFileApiBaseUrl =
      'https://opendata.cwa.gov.tw/fileapi/v1/opendataapi/';

  /// fileapi 資料集 URL。`format=JSON` 由 cwaDioProvider 的預設 query 提供、金鑰由其攔截器加入；
  /// 同名 query 重複會讓 CWA 回 404，所以這裡不能再寫。
  static String fileApiUrl(String datasetId) => '$cwaFileApiBaseUrl$datasetId?downloadType=WEB';

  // -------------------------------------------------------------------------
  //網路請求設定
  // -------------------------------------------------------------------------

  /// 連線逾時（毫秒）
  static const int connectTimeoutMilliseconds = 15000;

  /// 接收逾時（毫秒）
  static const int receiveTimeoutMilliseconds = 15000;

  /// fileapi 先回 302 再回 200，最多跟隨的轉址次數
  static const int maxRedirects = 5;
}
