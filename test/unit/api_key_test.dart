import 'dart:typed_data';

import 'package:petrichor/core/api/api_key.dart';
import 'package:petrichor/core/api/dio_client.dart';
import 'package:petrichor/core/storage/stored_setting.dart';
import 'package:petrichor/core/api/result.dart';
import 'package:petrichor/data/repositories/weather_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/provider_container.dart';
import '../support/fake_cwa_adapter.dart';

const _sample = 'CWA-00000000-0000-0000-0000-000000000000';
const _storageKey = 'cwa.apiKey';
const _probeDataset = 'O-A0003-001';
const _townDataset = 'F-D0047-061'; // 臺北市 3 天預報（getTowns）

class _ConnectionErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) =>
      Future.error(DioException.connectionError(requestOptions: options, reason: 'offline'));

  @override
  void close({bool force = false}) {}
}

/// Container over mock prefs; the shared Dio talks to [adapter] instead of the network.
ProviderContainer _container(Map<String, Object> prefs, HttpClientAdapter adapter) {
  SharedPreferences.setMockInitialValues(prefs);
  final container = newContainer();
  container.read(dioProvider).httpClientAdapter = adapter;
  return container;
}

void main() {
  group('CwaApiKey.parse', () {
    test('accepts the real format and trims whitespace', () {
      expect(CwaApiKey.parse(_sample).value, _sample);
      expect(CwaApiKey.parse('  $_sample\n').value, _sample);
    });

    test('rejects lowercase, wrong length, missing prefix and empty without echoing the input', () {
      for (final bad in [
        'CWA-abcdef01-0000-0000-0000-000000000000',
        _sample.substring(0, _sample.length - 1),
        '${_sample}0',
        _sample.substring(4),
        '',
      ]) {
        expect(
          () => CwaApiKey.parse(bad),
          throwsA(isA<FormatException>().having((e) => e.message, 'message', allOf(contains('got ${bad.trim().length} chars'), bad.isEmpty ? anything : isNot(contains(bad))))),
          reason: 'input length ${bad.length}',
        );
      }
    });
  });

  group('cwaApiKeyProvider', () {
    test('save persists across containers and clear removes it', () async {
      SharedPreferences.setMockInitialValues({});
      final first = newContainer();
      expect(await first.read(cwaApiKeyProvider.future), isNull);
      await first.read(cwaApiKeyProvider.notifier).save(CwaApiKey.parse(_sample));

      final second = newContainer();
      expect((await second.read(cwaApiKeyProvider.future))?.value, _sample);

      await second.read(cwaApiKeyProvider.notifier).clear();
      final third = newContainer();
      expect(await third.read(cwaApiKeyProvider.future), isNull);
    });

    test('corrupt stored value is a StoredSettingException naming the key, and save recovers', () async {
      for (final Object bad in ['abc', 42]) {
        SharedPreferences.setMockInitialValues({_storageKey: bad});
        final container = newContainer();
        await expectLater(
          container.read(cwaApiKeyProvider.future),
          throwsA(isA<StoredSettingException>().having((e) => e.key, 'key', _storageKey)),
        );
        await container.read(cwaApiKeyProvider.notifier).save(CwaApiKey.parse(_sample));
        expect(container.read(cwaApiKeyProvider).value?.value, _sample);
      }
    });
  });

  group('dioProvider interceptor', () {
    test('no key → Failure(missing) and zero requests', () async {
      final adapter = FakeCwaAdapter()..serveStatus(_townDataset, 200);
      final container = _container({}, adapter);

      final r = await container.read(weatherRepositoryProvider).getTowns('臺北市');

      expect((r as Failure).apiKeyIssue, ApiKeyIssue.missing);
      expect(adapter.requests, isEmpty);
    });

    test('stored key goes out as the Authorization query parameter', () async {
      final adapter = FakeCwaAdapter()..serveStatus(_townDataset, 500);
      final container = _container({_storageKey: _sample}, adapter);

      final r = await container.read(weatherRepositoryProvider).getTowns('臺北市');

      expect((r as Failure).apiKeyIssue, isNull);
      expect(adapter.requests.single.queryParameters['Authorization'], _sample);
    });

    test('HTTP 401 → Failure(rejected)', () async {
      final adapter = FakeCwaAdapter()..serveStatus(_townDataset, 401);
      final container = _container({_storageKey: _sample}, adapter);

      final r = await container.read(weatherRepositoryProvider).getTowns('臺北市');

      expect((r as Failure).apiKeyIssue, ApiKeyIssue.rejected);
    });

    test('corrupt stored key → Failure(unreadable) and zero requests', () async {
      final adapter = FakeCwaAdapter()..serveStatus(_townDataset, 200);
      final container = _container({_storageKey: 'abc'}, adapter);

      final r = await container.read(weatherRepositoryProvider).getTowns('臺北市');

      expect((r as Failure).apiKeyIssue, ApiKeyIssue.unreadable);
      expect(adapter.requests, isEmpty);
    });
  });

  group('key change invalidation', () {
    test('save after startup rebuilds the repository', () async {
      final container = _container({}, FakeCwaAdapter());
      final before = container.read(weatherRepositoryProvider);
      await container.read(cwaApiKeyProvider.future);

      await container.read(cwaApiKeyProvider.notifier).save(CwaApiKey.parse(_sample));

      expect(identical(container.read(weatherRepositoryProvider), before), isFalse);
    });

    test('first load of a stored key does not rebuild and sends exactly one request', () async {
      final adapter = FakeCwaAdapter()..serveStatus(_townDataset, 500);
      final container = _container({_storageKey: _sample}, adapter);
      var rebuilds = 0;
      container.listen(weatherRepositoryProvider, (_, _) => rebuilds++);

      await container.read(weatherRepositoryProvider).getTowns('臺北市');

      expect(adapter.requests, hasLength(1));
      expect(rebuilds, 0);
    });
  });

  group('apiKeyStatusProvider.verify', () {
    test('200 + success "true" → Valid', () async {
      final adapter = FakeCwaAdapter()..routes[_probeDataset] = (200, '{"success":"true"}');
      final container = _container({_storageKey: _sample}, adapter);
      await container.read(cwaApiKeyProvider.future);
      expect(container.read(apiKeyStatusProvider), isA<ApiKeyUnchecked>());

      await container.read(apiKeyStatusProvider.notifier).verify();

      expect(container.read(apiKeyStatusProvider), isA<ApiKeyValid>());
      expect(adapter.requests.single.queryParameters['limit'], '1');
    });

    test('401 → Invalid(rejected)', () async {
      final adapter = FakeCwaAdapter()..serveStatus(_probeDataset, 401);
      final container = _container({_storageKey: _sample}, adapter);
      await container.read(cwaApiKeyProvider.future);

      await container.read(apiKeyStatusProvider.notifier).verify();

      expect(container.read(apiKeyStatusProvider), isA<ApiKeyInvalid>().having((s) => s.kind, 'kind', ApiKeyInvalidKind.rejected));
    });

    test('connection error → Invalid(unreachable)', () async {
      final container = _container({_storageKey: _sample}, _ConnectionErrorAdapter());
      await container.read(cwaApiKeyProvider.future);

      await container.read(apiKeyStatusProvider.notifier).verify();

      expect(container.read(apiKeyStatusProvider), isA<ApiKeyInvalid>().having((s) => s.kind, 'kind', ApiKeyInvalidKind.unreachable));
    });

    test('no key → NotSet and no request', () async {
      final adapter = FakeCwaAdapter();
      final container = _container({}, adapter);
      await container.read(cwaApiKeyProvider.future);

      await container.read(apiKeyStatusProvider.notifier).verify();

      expect(container.read(apiKeyStatusProvider), isA<ApiKeyNotSet>());
      expect(adapter.requests, isEmpty);
    });
  });
}
