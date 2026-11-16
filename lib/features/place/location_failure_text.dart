import '../../data/location/location_service.dart';

/// 定位失敗 → 頁面標題（全 App 唯一對照）
String locationFailureTitle(LocationFailure failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '定位服務已關閉',
    LocationFailure.permissionDenied => '未取得位置權限',
    LocationFailure.permissionDeniedForever => '位置權限已關閉',
    LocationFailure.positionUnavailable || LocationFailure.addressUnresolved => '無法取得目前位置',
  };
}

/// 無法開啟系統設定頁（[what] 如「應用程式設定」）時的提示
String openSettingsFailedMessage(String what) => '無法開啟$what，請手動前往系統設定';

/// 定位失敗 → 使用者可讀訊息（含下一步）
String locationFailureMessage(LocationFailure failure) {
  return switch (failure) {
    LocationFailure.serviceDisabled => '裝置的定位服務已關閉，請開啟後重試，或手動選擇地點',
    LocationFailure.permissionDenied => '尚未允許定位權限，請允許後重試，或手動選擇地點',
    LocationFailure.permissionDeniedForever => '定位權限已被永久拒絕，請到系統設定開啟，或手動選擇地點',
    LocationFailure.positionUnavailable => '無法取得目前位置，請稍後重試，或手動選擇地點',
    LocationFailure.addressUnresolved => '無法判斷所在縣市與鄉鎮，請稍後重試，或手動選擇地點',
  };
}
