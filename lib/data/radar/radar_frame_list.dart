/// Frame list of the CWA website radar loop (www.cwa.gov.tw/V8/C/W/OBS_Radar.html).
///
/// The page loads [radarFrameListUrl], a JS object listing ~24 h of 10-minute
/// frames per image set. The app uses the set `CV1_3600_`: wide area, no terrain,
/// 3600x3600, pixel-identical to open-data O-A0058-001 (see
/// docs/logs/2026-11-14/radar-impl-notes.md).
library;

const radarFrameListUrl = 'https://www.cwa.gov.tw/Data/js/obs_img/Observe_radar.js';
const radarFrameBaseUrl = 'https://www.cwa.gov.tw/Data/radar/';
const radarFrameSetPrefix = 'CV1_3600_';

/// Frames shown in the loop: 2 hours at 10-minute steps.
const radarFrameWindowCount = 12;
const radarFrameWindowDuration = Duration(hours: 2);

/// File names carry Taiwan local time (UTC+8, no DST).
const _taiwanUtcOffset = Duration(hours: 8);

final _framePattern = RegExp("'$radarFrameSetPrefix(\\d{12})\\.png'");

/// One frame of the website loop.
class RadarFrameRef {
  /// Timestamp as written in the file name, `yyyyMMddHHmm` Taiwan time.
  final String stamp;

  /// Observation time in UTC.
  final DateTime time;

  RadarFrameRef(this.stamp) : time = _parseStamp(stamp);

  String get url => '$radarFrameBaseUrl$radarFrameSetPrefix$stamp.png';

  static DateTime _parseStamp(String s) => DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
        int.parse(s.substring(8, 10)),
        int.parse(s.substring(10, 12)),
      ).subtract(_taiwanUtcOffset);

  @override
  bool operator ==(Object other) => other is RadarFrameRef && other.stamp == stamp;

  @override
  int get hashCode => stamp.hashCode;

  @override
  String toString() => 'RadarFrameRef($stamp)';
}

/// Parses every `CV1_3600_` frame in [js] (the content of Observe_radar.js).
List<RadarFrameRef> parseRadarFrameList(String js) {
  final frames = _framePattern.allMatches(js).map((m) => RadarFrameRef(m.group(1)!)).toSet().toList();
  if (frames.isEmpty) {
    throw FormatException(
      "Observe_radar.js: expected entries matching '$radarFrameSetPrefix<yyyyMMddHHmm>.png', found none "
      '(${js.length} chars)',
    );
  }
  return frames;
}

/// The frames of the 2 h ending at the newest listed frame (at most
/// [radarFrameWindowCount], oldest first = playback order). Missing slots stay
/// missing. Returns nothing when the newest frame is older than
/// [radarFrameWindowDuration] before [now] (stale list).
List<RadarFrameRef> selectRadarFrameWindow(List<RadarFrameRef> frames, {required DateTime now}) {
  final sorted = [...frames]..sort((a, b) => a.time.compareTo(b.time));
  if (sorted.isEmpty || sorted.last.time.isBefore(now.toUtc().subtract(radarFrameWindowDuration))) return const [];
  final start = sorted.last.time.subtract(radarFrameWindowDuration);
  final window = sorted.where((f) => f.time.isAfter(start)).toList();
  return window.length <= radarFrameWindowCount ? window : window.sublist(window.length - radarFrameWindowCount);
}
