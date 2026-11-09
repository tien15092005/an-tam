import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Firebase settings come from `--dart-define` at build time (docs/SETUP.md), so no Firebase file is
/// committed. Without them pushes are off and the app refreshes on open and on a timer instead.
abstract final class PushSettings {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get configured => apiKey.isNotEmpty && appId.isNotEmpty && senderId.isNotEmpty && projectId.isNotEmpty;
}

/// Shows a short message for pushes that arrive while the app is open (Android shows the rest).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// A push the app reacts to: `kind` matches the backend's Notifier.Kind.
typedef PushHandler = void Function(String kind, Map<String, dynamic> data);

class Push {
  Push(this._ref);
  final Ref _ref;
  bool _started = false;
  String? _token;
  final List<StreamSubscription<Object?>> _subs = [];

  /// After sign-in: ask permission, register this phone with the backend, and listen.
  Future<void> start(PushHandler onMessage) async {
    if (_started || !PushSettings.configured) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: PushSettings.apiKey,
            appId: PushSettings.appId,
            messagingSenderId: PushSettings.senderId,
            projectId: PushSettings.projectId,
          ),
        );
      }
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      // Registration tokens are what the backend's Admin SDK sends to (Message.setToken). firebase_messaging 17
      // deprecates them in favour of FID direct-send, which the backend does not use yet (docs/DECISIONS.md).
      // ignore: deprecated_member_use
      _token = await fm.getToken();
      if (_token != null) await _register(_token!);
      // ignore: deprecated_member_use
      _subs.add(fm.onTokenRefresh.listen((t) {
        _token = t;
        _register(t);
      }));
      _subs.add(FirebaseMessaging.onMessage.listen((m) {
        final kind = m.data['kind'] as String?;
        if (kind != null) onMessage(kind, m.data);
        final n = m.notification;
        if (n?.title != null) {
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(content: Text([n!.title, n.body].whereType<String>().join('\n'))));
        }
      }));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final kind = m.data['kind'] as String?;
        if (kind != null) onMessage(kind, m.data);
      }));
    } catch (e) {
      // Pushes are a convenience; the app works without them.
      debugPrint('push setup failed: $e');
      _started = false;
    }
  }

  /// Before sign-out, so this phone stops getting the account's notifications.
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final t = _token;
    _started = false;
    _token = null;
    if (t == null) return;
    try {
      await _ref.read(dioProvider).delete<void>('/api/me/device', data: {'fcmToken': t});
    } catch (_) {
      // Best effort: the backend also forgets tokens FCM reports as dead.
    }
  }

  Future<void> _register(String token) async {
    try {
      await _ref.read(dioProvider).put<void>('/api/me/device', data: {'fcmToken': token, 'platform': 'ANDROID'});
    } catch (e) {
      debugPrint('push token not registered yet: $e');
    }
  }
}

final pushProvider = Provider<Push>(Push.new);
