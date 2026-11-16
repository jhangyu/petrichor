import 'dart:math' as math;

import '../../core/time/taiwan_time.dart';

part 'warning_models.dart';
part 'rainfall_models.dart';

// ============================================================================
// JSON 邊界解析（錯誤一律為 FormatException，訊息含欄位路徑）
// ============================================================================

/// CWA 缺值標記（字串）
const String _missingMarker = '-99';

Map<String, dynamic> _asObject(Object? v, String path) {
  if (v is Map<String, dynamic>) return v;
  throw FormatException('expected object at $path, got ${v.runtimeType}');
}

List<dynamic> _asList(Object? v, String path) {
  if (v is List<dynamic>) return v;
  throw FormatException('expected array at $path, got ${v.runtimeType}');
}

String _asString(Object? v, String path) {
  if (v is String) return v;
  throw FormatException('expected string at $path, got ${v.runtimeType}');
}

/// 雨量字串；"-99" 與非數字（如微量 "T"）→ null（使用者裁決：只留數字值），非字串 → FormatException
double? _rainMillimeters(Object? v, String path) {
  final s = _asString(v, path);
  if (s == _missingMarker) return null;
  return double.tryParse(s);
}

double _asNumber(Object? v, String path) {
  final s = _asString(v, path);
  final n = double.tryParse(s);
  if (n == null) throw FormatException('expected number at $path, got "$s"');
  return n;
}

final _zonePattern = RegExp(r'[+-]\d\d:\d\d$');

/// "yyyy-MM-dd HH:mm:ss"（+08 本地）或 ISO 8601 → DateTime
DateTime _asInstant(Object? v, String path) {
  final s = _asString(v, path);
  final hasZone = s.endsWith('Z') || _zonePattern.hasMatch(s);
  final parsed = DateTime.tryParse(hasZone ? s : '${s.replaceFirst(' ', 'T')}$taiwanUtcOffsetText');
  if (parsed == null) throw FormatException('expected timestamp at $path, got "$s"');
  return parsed;
}
