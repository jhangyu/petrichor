/// Frame lists of the CWA website radar loops.
///
/// Composite (www.cwa.gov.tw/V8/C/W/OBS_Radar.html): [radarFrameListUrl], a JS
/// object listing ~24 h of 10-minute frames per image set. The app uses the set
/// `CV1_3600_`: wide area, no terrain, 3600x3600, pixel-identical to open-data
/// O-A0058-001 (see docs/logs/2026-11-14/radar-impl-notes.md).
///
/// Stations (www.cwa.gov.tw/V8/C/W/OBS_Radar_rain.html): [radarStationListUrl]
/// lists ~6.2 h of frames per station at irregular ~108 s intervals; file names
/// carry the time to the second and a hash that cannot be derived, so URLs come
/// from the list only (checked 2026-11-15, radar-perf-contract.md item 6).
library;

import '../../core/time/taiwan_time.dart';

const radarFrameListUrl = 'https://www.cwa.gov.tw/Data/js/obs_img/Observe_radar.js';
const _radarFrameBaseUrl = 'https://www.cwa.gov.tw/Data/radar/';
const _radarFrameSetPrefix = 'CV1_3600_';

/// Website frame cadence.
const radarFrameStep = Duration(minutes: 10);

/// Longest look-back of the website loop: all the site lists (144 frames).
const radarWebsiteMaxWindow = Duration(hours: 24);

const radarStationListUrl = 'https://www.cwa.gov.tw/Data/js/obs_img/Observe_radar_rain.js';
const radarStationBaseUrl = 'https://www.cwa.gov.tw/Data/radar_rain/';

/// Longest look-back of a station loop: what the station list covers (~6.2 h).
const radarStationMaxWindow = Duration(hours: 6);

final _framePattern = RegExp("'$_radarFrameSetPrefix(\\d{12})\\.png'");

/// One frame of a source: its time and the URL that names it (the frame PNG
/// of a radar loop; failures of the frame are reported against it).
class RadarFrameRef {
  /// Observation time in UTC.
  final DateTime time;
  final String url;

  RadarFrameRef({required DateTime time, required this.url}) : time = time.toUtc();

  /// Website frame from the timestamp in its file name.
  RadarFrameRef.website(String stamp)
      : this(time: radarStampTime(stamp), url: '$_radarFrameBaseUrl$_radarFrameSetPrefix$stamp.png');

  /// Cache file key: observation time `yyyyMMddHHmmss` UTC (station frames have irregular seconds).
  String get cacheKey => formatUtcStamp(time, seconds: true);

  @override
  bool operator ==(Object other) => other is RadarFrameRef && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'RadarFrameRef($time, $url)';
}

/// `yyyyMMddHHmm` (+`ss` when [seconds]) of [t] in UTC: cache file keys.
String formatUtcStamp(DateTime t, {required bool seconds}) {
  final u = t.toUtc();
  return '${u.year}${twoDigits(u.month)}${twoDigits(u.day)}${twoDigits(u.hour)}${twoDigits(u.minute)}'
      '${seconds ? twoDigits(u.second) : ''}';
}

/// Fields of a 12- or 14-digit `yyyyMMddHHmm[ss]` stamp as a UTC DateTime, no
/// offset applied. Callers match the stamp pattern first.
DateTime parseUtcStamp(String s) => DateTime.utc(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
      int.parse(s.substring(8, 10)),
      int.parse(s.substring(10, 12)),
      s.length == 14 ? int.parse(s.substring(12, 14)) : 0,
    );

final _stampPattern = RegExp(r'^\d{12}(\d{2})?$');

/// Time of a `yyyyMMddHHmm[ss]` Taiwan-time stamp, in UTC.
DateTime radarStampTime(String s) {
  if (!_stampPattern.hasMatch(s)) throw FormatException('radar stamp: expected yyyyMMddHHmm[ss], got "$s"');
  return parseUtcStamp(s).subtract(taiwanUtcOffset);
}

/// Parses every `CV1_3600_` frame in [js] (the content of Observe_radar.js).
List<RadarFrameRef> parseRadarFrameList(String js) {
  final frames = _framePattern.allMatches(js).map((m) => RadarFrameRef.website(m.group(1)!)).toSet().toList();
  if (frames.isEmpty) {
    throw FormatException(
      "Observe_radar.js: expected entries matching '$_radarFrameSetPrefix<yyyyMMddHHmm>.png', found none "
      '(${js.length} chars)',
    );
  }
  return frames;
}

/// Parses every 3600 px frame of the station with image-name code [code]
/// (RCSL, RCNT, RCLY) in [js] (the content of Observe_radar_rain.js).
List<RadarFrameRef> parseRadarStationList(String js, {required String code}) {
  final pattern = RegExp("'(CV1_${code}_3600/CV1_${code}_3600_(\\d{14})_[0-9a-f]{64}\\.png)'");
  final frames = pattern
      .allMatches(js)
      .map((m) => RadarFrameRef(time: radarStampTime(m.group(2)!), url: '$radarStationBaseUrl${m.group(1)}'))
      .toSet()
      .toList();
  if (frames.isEmpty) {
    throw FormatException(
      "Observe_radar_rain.js: expected entries matching 'CV1_${code}_3600/CV1_${code}_3600_<yyyyMMddHHmmss>_<hash>.png', "
      'found none (${js.length} chars)',
    );
  }
  return frames;
}

/// The frames of the [window] span ending at the newest listed frame, oldest
/// first = playback order; any source, any cadence (regular or not). Missing
/// frames stay missing. Returns nothing when the newest frame is older than
/// [window] before [now] (stale list).
List<RadarFrameRef> selectRadarFrameWindow(
  List<RadarFrameRef> frames, {
  required DateTime now,
  required Duration window,
}) {
  if (window <= Duration.zero) throw ArgumentError.value(window, 'window', 'expected a positive duration');
  final sorted = [...frames]..sort((a, b) => a.time.compareTo(b.time));
  if (sorted.isEmpty || sorted.last.time.isBefore(now.toUtc().subtract(window))) return const [];
  final start = sorted.last.time.subtract(window);
  return sorted.where((f) => f.time.isAfter(start)).toList();
}
