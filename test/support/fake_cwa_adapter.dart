import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:petrichor/core/api/cwa_http_config.dart';
import 'package:dio/dio.dart';

/// 離線 HTTP 轉接器：依資料集代號（路徑最後一段）回傳 test/fixtures/cwa 內的範例回應。
class FakeCwaAdapter implements HttpClientAdapter {
  /// 資料集代號 → (HTTP 狀態碼, 回應本文)
  final Map<String, (int, String)> routes = {};

  /// 已收到的請求 URI（供斷言查詢參數）
  final List<Uri> requests = [];

  /// 以 [fixture] 檔回應 [dataset] 請求（township 資料集與縣市級樣本結構相同，可借用）。
  void serveFixture(String fixture, [Object? Function(Map<String, dynamic>)? edit, String? dataset]) {
    final json = jsonDecode(File('test/fixtures/cwa/$fixture.json').readAsStringSync()) as Map<String, dynamic>;
    edit?.call(json);
    routes[dataset ?? fixture] = (200, jsonEncode(json));
  }

  void serveStatus(String dataset, int status) => routes[dataset] = (status, '{}');

  Dio createDio() => Dio(BaseOptions(baseUrl: CwaHttpConfig.cwaApiBaseUrl))..httpClientAdapter = this;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.uri);
    final dataset = options.uri.pathSegments.last;
    final route = routes[dataset];
    if (route == null) throw StateError('FakeCwaAdapter：未設定資料集 $dataset 的回應');
    return ResponseBody.fromString(route.$2, route.$1, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
