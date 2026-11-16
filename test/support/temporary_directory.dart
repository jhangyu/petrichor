import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A fresh system temp directory, deleted recursively when the current test ends.
Directory newTemporaryDirectory(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  addTearDown(() => dir.deleteSync(recursive: true));
  return dir;
}
