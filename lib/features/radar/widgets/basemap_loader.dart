part of 'radar_map_view.dart';

/// OpenStreetMap's own keyless vector layer (Shortbread schema, SVWD03 style).
/// The style ships no glyphs, so labels use each device's system fonts.
const _styleUrl = 'https://vector.openstreetmap.org/styles/svwd/svwd03style.json';

/// OSMF vector tile policy: a User-Agent that identifies the app.
const _userAgent = 'us.jhangy.petrichor';

const _logTag = 'basemap';

typedef _Basemap = ({vt.Style style, vt.Theme theme, vt.TileProviders tiles});

/// The basemap style load shared by every map. Only [retryRadarBasemap]
/// replaces it (after a failure), and every mounted map follows.
// ponytail: a loaded style is never disposed; it lives as long as the app.
final _basemapLoad = ValueNotifier<Future<_Basemap>>(_startLoad());
var _basemapFailed = false;

/// Loads the basemap style again if the last load failed; no-op while a load
/// is running or after it succeeded. Mounting a map calls it; the radar
/// screen's refresh should too.
void retryRadarBasemap() {
  if (!_basemapFailed) return;
  _basemapLoad.value = _startLoad();
}

/// A load whose failure is already reported (and shown by the map), so the
/// future itself is marked handled: until a map's FutureBuilder subscribes
/// it would otherwise surface a second time as an uncaught error.
Future<_Basemap> _startLoad() => _loadBasemap()..ignore();

Future<_Basemap> _loadBasemap() async {
  _basemapFailed = false;
  appLog(_logTag, 'style load start $_styleUrl content scale $_basemapContentScale');
  try {
    final style = await vt.StyleReader(
      uri: _styleUrl,
      headers: const {'User-Agent': _userAgent},
      logger: const vt.Logger.custom(onLog: _pluginLog, onWarn: _pluginWarn),
    ).read();
    final sources = style.providers.providers;
    appLog(_logTag, 'style load ok, sources ${sources.keys.join(',')}');
    final tiles = vt.TileProviders({
      for (final MapEntry(:key, :value) in sources.entries) key: _LoggedTiles(key, value),
    }, promoteIds: style.providers.promoteIds);
    final patternFree = withoutPatterns(style.theme);
    appLog(
      _logTag,
      'sprite patterns removed: ${patternFree.recoloured} fill-pattern layers recoloured, '
      '${patternFree.dropped.length} patterned layers dropped (${patternFree.dropped.join(',')})',
    );
    return (style: style, theme: patternFree.theme, tiles: tiles);
  } catch (error, stack) {
    _basemapFailed = true;
    appLog(_logTag, 'style load failed: $error');
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'radar basemap',
        context: ErrorDescription('loading $_styleUrl'),
      ),
    );
    rethrow;
  }
}

void _pluginLog(String message) => appLog(_logTag, message);
void _pluginWarn(String message) => appLog(_logTag, 'warning: $message');

/// Passes every tile load through and logs its outcome (cancelled loads
/// are not logged). Disk-cache hits never reach a provider, so these are
/// network loads.
class _LoggedTiles extends vt.VectorTileProvider {
  _LoggedTiles(this._source, this._inner);

  final String _source;
  final vt.VectorTileProvider _inner;

  @override
  int get maximumZoom => _inner.maximumZoom;
  @override
  int get minimumZoom => _inner.minimumZoom;
  @override
  String get cacheKey => _inner.cacheKey;
  @override
  bool get cacheBytesToDisk => _inner.cacheBytesToDisk;

  @override
  Future<vt.TileResponse> load(vt.TileKey tile, {vt.CancellationToken? cancellation}) async {
    final response = await _inner.load(tile, cancellation: cancellation);
    final where = '$_source ${tile.z}/${tile.x}/${tile.y}';
    switch (response) {
      case vt.TileResponseData(:final bytes):
        appLog(_logTag, 'tile ok $where ${bytes.length} B');
      case vt.TileResponseNotFound():
        appLog(_logTag, 'tile not found $where');
      case vt.TileResponseError(:final error):
        appLog(_logTag, 'tile failed $where: $error');
      case vt.TileResponseCancelled():
        break;
    }
    return response;
  }

  @override
  void dispose() => _inner.dispose();
}
