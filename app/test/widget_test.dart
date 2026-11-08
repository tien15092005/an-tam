import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app/core/config/server_config.dart';
import 'package:app/features/system/connection_screen.dart';
import 'package:app/features/system/server_health.dart';

Future<ProviderContainer> _container({Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sp = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(sp)]);
}

Widget _screen(Future<ServerHealth> Function() health) => ProviderScope(
      overrides: [serverHealthProvider.overrideWith((ref) => health())],
      child: const MaterialApp(home: ConnectionScreen()),
    );

void main() {
  group('ServerUrlNotifier', () {
    test('falls back to the default address', () async {
      final c = await _container();
      expect(c.read(serverUrlProvider), defaultServerUrl);
    });

    test('saves a valid URL without trailing slash and keeps it', () async {
      final c = await _container();
      final error = await c.read(serverUrlProvider.notifier).save(' https://abc.trycloudflare.com/ ');
      expect(error, isNull);
      expect(c.read(serverUrlProvider), 'https://abc.trycloudflare.com');
      final sp = c.read(sharedPreferencesProvider);
      expect(sp.getString('server_url'), 'https://abc.trycloudflare.com');
    });

    test('rejects addresses that are not http or https', () async {
      final c = await _container(prefs: {'server_url': 'http://10.0.2.2:8080'});
      final error = await c.read(serverUrlProvider.notifier).save('abc.com');
      expect(error, isNotNull);
      expect(c.read(serverUrlProvider), 'http://10.0.2.2:8080');
    });
  });

  testWidgets('shows backend and AI as working when health is UP', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      child: _screen(() async => const ServerHealth(backendUp: true, aiUp: true, serverTime: null)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Máy chủ'), findsOneWidget);
    expect(find.text('Dịch vụ AI'), findsOneWidget);
    expect(find.text('Hoạt động'), findsNWidgets(2));
  });

  testWidgets('shows an error when the server cannot be reached', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sp = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(sp)],
      child: _screen(() async => throw Exception('offline')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Không kết nối'), findsOneWidget);
  });
}
