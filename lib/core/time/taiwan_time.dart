/// CWA data, radar file names, the CWA site and the mockup use Taiwan time (UTC+8, no DST).
const taiwanUtcOffset = Duration(hours: 8);

/// Taiwan wall-clock fields of [t], carried in a UTC DateTime.
DateTime taiwanWall(DateTime t) => t.toUtc().add(taiwanUtcOffset);

/// Instant of a Taiwan wall-clock time carried in a UTC DateTime (inverse of [taiwanWall]).
DateTime fromTaiwanWall(DateTime wall) => wall.subtract(taiwanUtcOffset);

/// CWA calendar date `2026-11-14` → its wall-clock midnight (UTC carrier).
DateTime taiwanDate(String date) => DateTime.parse('${date}T00:00:00Z');

/// `7` → `07`.
String twoDigits(int v) => v.toString().padLeft(2, '0');

/// `14:00` (Taiwan time).
String clockText(DateTime t) {
  final w = taiwanWall(t);
  return '${twoDigits(w.hour)}:${twoDigits(w.minute)}';
}

/// `2026-11-14` for a wall date (year padded to 4 digits).
String isoDate(DateTime wall) => '${wall.year.toString().padLeft(4, '0')}-${twoDigits(wall.month)}-${twoDigits(wall.day)}';

/// `11/14 14:00` (Taiwan time).
String formatTaiwanMonthDayClock(DateTime t) {
  final w = taiwanWall(t);
  return '${twoDigits(w.month)}/${twoDigits(w.day)} ${clockText(t)}';
}

/// `2026-11-14 14:00` (Taiwan time).
String formatTaiwanFull(DateTime t) {
  final w = taiwanWall(t);
  return '${w.year}-${twoDigits(w.month)}-${twoDigits(w.day)} ${clockText(t)}';
}
