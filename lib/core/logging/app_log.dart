import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'app_log_sink.dart';

AppLogSink? _sink;

/// Writes one line to the crash log file, flushed immediately.
/// If the log is not initialised or the write fails, the line goes to the
/// console with the failure reason (never dropped silently).
void appLog(String tag, String message) {
  final sink = _sink;
  if (sink == null) {
    debugPrint('[applog-uninitialised] [$tag] $message');
    return;
  }
  try {
    sink.write(tag, message);
  } catch (error, stackTrace) {
    debugPrint('[applog-write-failed] $error\n$stackTrace\n'
        'lost line: [$tag] $message');
  }
}

/// Opens the log, records the startup line and routes uncaught errors into it.
/// Call once from main() before runApp.
Future<void> initAppLog() async {
  WidgetsFlutterBinding.ensureInitialized();
  final support = await getApplicationSupportDirectory();
  final sink = AppLogSink(Directory('${support.path}/logs'));
  final previousClean = sink.open();
  _sink = sink;

  final info = await PackageInfo.fromPlatform();
  appLog(
    'startup',
    'version=${info.version}+${info.buildNumber} '
        'platform=${Platform.operatingSystem} os=${Platform.operatingSystemVersion} '
        'mode=${kReleaseMode ? 'release' : kProfileMode ? 'profile' : 'debug'} '
        'previousSessionCleanExit=$previousClean',
  );

  final presentError = FlutterError.onError;
  FlutterError.onError = (details) {
    appLog('flutter-error', '${details.exceptionAsString()}\n${details.stack}');
    presentError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog('uncaught', '$error\n$stack');
    return true;
  };
  // Uncaught errors of the main isolate that bypass the two handlers above.
  Isolate.current.addErrorListener(RawReceivePort((dynamic pair) {
    final list = pair as List<dynamic>;
    appLog('isolate-error', '${list[0]}\n${list[1]}');
  }).sendPort);

  WidgetsBinding.instance.addObserver(_LifecycleLogger(sink));
}

class _LifecycleLogger with WidgetsBindingObserver {
  _LifecycleLogger(this._sink);

  final AppLogSink _sink;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appLog('lifecycle', state.name);
    if (state == AppLifecycleState.detached) _sink.markCleanExit();
  }

  @override
  void didHaveMemoryPressure() => appLog('lifecycle', 'memory-pressure');
}
