import 'dart:convert';
import 'dart:io';

/// Largest size the active log file may reach before it is rotated.
const int logMaximumBytes = 512 * 1024;

/// Name of the active log file inside the log directory.
const String logFileName = 'app.log';

/// Name the active file is renamed to on rotation (one generation kept).
const String rotatedLogFileName = 'app.log.1';

/// Marker file that exists while a session is running and is removed on a
/// clean exit. Finding it at startup means the previous session did not end
/// cleanly (crash, kill, power loss).
const String sessionMarkerFileName = 'session.running';

/// Append-only log file. Every line is written and flushed synchronously so the
/// last lines survive a hard crash.
class AppLogSink {
  AppLogSink(this._dir, {this.now = DateTime.now});

  final Directory _dir;
  final DateTime Function() now;
  RandomAccessFile? _file;
  int _size = 0;

  File get _active => File('${_dir.path}/$logFileName');

  /// Opens the log and reports whether the previous session ended cleanly.
  /// A first run (no log yet) counts as clean.
  bool open() {
    _dir.createSync(recursive: true);
    final marker = File('${_dir.path}/$sessionMarkerFileName');
    final previousClean = !marker.existsSync();
    marker.writeAsStringSync(now().toIso8601String(), flush: true);
    _openActive();
    return previousClean;
  }

  void _openActive() {
    final f = _active;
    _file = f.openSync(mode: FileMode.append);
    _size = f.lengthSync();
  }

  void write(String tag, String message) {
    final file = _file;
    if (file == null) {
      throw StateError('AppLogSink.write before open(): [$tag] $message');
    }
    final line = '${now().toIso8601String()} [$tag] $message\n';
    if (_size >= logMaximumBytes) _rotate();
    final bytes = utf8.encode(line);
    _file!.writeFromSync(bytes);
    _file!.flushSync();
    _size += bytes.length;
  }

  void _rotate() {
    _file!.closeSync();
    _active.renameSync('${_dir.path}/$rotatedLogFileName');
    _openActive();
  }

  /// Removes the session marker: the next start sees a clean exit.
  void markCleanExit() {
    final marker = File('${_dir.path}/$sessionMarkerFileName');
    if (marker.existsSync()) marker.deleteSync();
  }
}
