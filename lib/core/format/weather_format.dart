import '../time/taiwan_time.dart';

const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

/// `11/14（六）` for a wall date (see [taiwanWall] / [taiwanDate]).
String monthDayWeekday(DateTime wall) => '${monthDayText(wall)}（${_weekdayNames[wall.weekday - 1]}）';

/// `11/14` for a wall date.
String monthDayText(DateTime wall) => '${wall.month}/${wall.day}';

/// `週六` for a wall date.
String weekdayName(DateTime wall) => '週${_weekdayNames[wall.weekday - 1]}';

/// Calendar days from [now]'s Taiwan date to [wall]'s date (0 = today).
int dayOffset(DateTime wall, DateTime now) {
  final today = taiwanWall(now);
  final a = DateTime.utc(wall.year, wall.month, wall.day);
  final b = DateTime.utc(today.year, today.month, today.day);
  return a.difference(b).inDays;
}

/// 今天／明天／後天, otherwise the weekday (`週二`).
String relativeDay(DateTime wall, DateTime now) => switch (dayOffset(wall, now)) {
  0 => '今天',
  1 => '明天',
  2 => '後天',
  _ => weekdayName(wall),
};

/// `10 小時 57 分`, or `7 分` under one hour.
String durationText(Duration d) {
  final minutes = d.inMinutes;
  final h = minutes ~/ Duration.minutesPerHour;
  final m = minutes % Duration.minutesPerHour;
  return h == 0 ? '$m 分' : '$h 小時 $m 分';
}

/// Rounded temperature `28°`, or 「—」 when the value is missing.
String temperatureText(double? t) => t == null ? '—' : '${t.round()}°';

/// `20%`, or 「—」 when missing.
String percentText(int? p) => p == null ? '—' : '$p%';

/// `3 m/s` / `3.2 m/s` (no trailing `.0`), or 「—」 when missing.
String speedText(double? v) {
  if (v == null) return '—';
  final text = v == v.roundToDouble() ? v.round().toString() : v.toString();
  return '$text m/s';
}

/// CWA 風向 `偏北風` / `東北風` → `偏北` / `東北` (chart label).
String windDirectionLabel(String? direction) {
  if (direction == null) return '—';
  return direction.endsWith('風') ? direction.substring(0, direction.length - 1) : direction;
}

/// `發布 11/14 17:00` (Taiwan time).
String issuedText(DateTime t) => '發布 ${monthDayText(taiwanWall(t))} ${clockText(t)}';
