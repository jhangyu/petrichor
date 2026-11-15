import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fresh [ProviderContainer] that is disposed when the current test ends.
ProviderContainer newContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  return container;
}
