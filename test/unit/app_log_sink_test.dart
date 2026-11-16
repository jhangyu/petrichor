import 'dart:io';

import 'package:petrichor/core/logging/app_log_sink.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/temporary_directory.dart';

void main() {
  late Directory dir;
  setUp(() => dir = newTemporaryDirectory('applog_test'));

  test('each line is readable from disk right after write (flushed)', () {
    final sink = AppLogSink(dir)..open();
    sink.write('t', 'hello');
    final text = File('${dir.path}/$kLogFileName').readAsStringSync();
    expect(text, contains('[t] hello'));
  });

  test('rotates once the cap is reached and keeps one old generation', () {
    final sink = AppLogSink(dir)..open();
    final chunk = 'x' * 1024;
    for (var i = 0; i < kLogMaxBytes ~/ 1024 + 2; i++) {
      sink.write('fill', chunk);
    }
    sink.write('after', 'rotation');
    expect(File('${dir.path}/$kLogRotatedFileName').existsSync(), isTrue);
    final active = File('${dir.path}/$kLogFileName').readAsStringSync();
    expect(active, contains('[after] rotation'));
    expect(File('${dir.path}/$kLogFileName').lengthSync(),
        lessThan(kLogMaxBytes));
  });

  test('previous session is unclean unless the marker was removed', () {
    expect(AppLogSink(dir).open(), isTrue); // first run
    expect(AppLogSink(dir).open(), isFalse); // no clean exit in between
    final sink = AppLogSink(dir)..open();
    sink.markCleanExit();
    expect(AppLogSink(dir).open(), isTrue);
  });

  test('write before open fails loudly', () {
    expect(() => AppLogSink(dir).write('t', 'm'), throwsStateError);
  });
}
