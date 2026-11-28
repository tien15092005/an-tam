import 'dart:convert';

import '../../core/push/push.dart';
import '../../reminder/alarm_channel.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/server_config.dart';
import '../../core/network/api_client.dart';
import '../../reminder/schedule_sync.dart';
import '../groups/groups_api.dart';

/// The signed-in account on this phone. Tokens live in Android's encrypted storage.
class Session {
  const Session({required this.accessToken, required this.refreshToken, this.expired = false});

  final String accessToken;
  final String refreshToken;

  /// An elder phone whose session the server refused. It keeps its saved schedule, alarms and unsent
  /// answers, and asks for a new pairing code instead of going blank.
  final bool expired;

  Map<String, Object> toJson() => {'accessToken': accessToken, 'refreshToken': refreshToken, 'expired': expired};

  factory Session.fromTokenResponse(Map<String, dynamic> json) =>
      Session(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);

  Session asExpired() => Session(accessToken: accessToken, refreshToken: refreshToken, expired: true);

  /// Claims of the access token, read without checking the signature (only the server trusts them).
  Map<String, dynamic> get _claims {
    try {
      final part = accessToken.split('.')[1];
      return jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part)))) as Map<String, dynamic>;
    } catch (_) {
      return const {};
    }
  }

  bool get isElder => _claims['typ'] == 'ELDER';

  /// The account id ("sub"), to tell whether a new pairing is the same parent.
  String? get userId => _claims['sub'] as String?;
}

class SessionStore {
  SessionStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'session';
  final FlutterSecureStorage _storage;

  Future<Session?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return Session(
        accessToken: m['accessToken'] as String,
        refreshToken: m['refreshToken'] as String,
        expired: m['expired'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Session s) => _storage.write(key: _key, value: jsonEncode(s.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Dio without the auth interceptor, used for sign-in and token refresh themselves.
final authDioProvider = Provider<Dio>(
  (ref) => Dio(
    BaseOptions(
      baseUrl: ref.watch(serverUrlProvider),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    ),
  ),
);

/// Null when signed out. Screens and the router watch this.
class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.read(sessionStoreProvider).read();

  Future<void> _save(Map<String, dynamic> tokenJson) async {
    final s = Session.fromTokenResponse(tokenJson);
    await ref.read(sessionStoreProvider).write(s);
    state = AsyncData(s);
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async {
    final r = await ref
        .read(authDioProvider)
        .post<Map<String, dynamic>>(
          '/api/auth/register',
          data: {
            'email': email,
            'password': password,
            'displayName': displayName,
            'phone': phone,
            'deviceName': 'Android',
          },
        );
    await _save(r.data!);
  }

  Future<void> login(String email, String password) async {
    final r = await ref
        .read(authDioProvider)
        .post<Map<String, dynamic>>(
          '/api/auth/login',
          data: {'email': email, 'password': password, 'deviceName': 'Android'},
        );
    await _save(r.data!);
  }

  Future<void> pairElder(String code) async {
    final before = state.value;
    final r = await ref
        .read(authDioProvider)
        .post<Map<String, dynamic>>('/api/auth/elder-pair', data: {'code': code, 'deviceName': 'Điện thoại người già'});
    final next = Session.fromTokenResponse(r.data!);
    // Re-pairing after an expired session: keep the saved schedule and unsent answers when it is the same
    // parent; another parent's must never be sent with this account.
    if (before != null && before.userId != next.userId) await _clearPhoneData();
    await _save(r.data!);
    await forgetCachedMe(ref.read(sharedPreferencesProvider));
    ref.invalidate(meProvider);
    try {
      await ref.read(elderScheduleProvider.notifier).refresh();
    } catch (_) {
      // Retried when the home screen opens.
    }
  }

  /// Changing the password signs out every other phone; this one gets a fresh session.
  Future<void> changePassword(String current, String next) async {
    final r = await ref.read(dioProvider).post<Map<String, dynamic>>(
        '/api/me/password', data: {'currentPassword': current, 'newPassword': next, 'deviceName': 'Android'});
    await _save(r.data!);
  }

  /// A forgotten password, with the one-time code a sibling created. Signs in on this phone.
  Future<void> resetPassword(String email, String code, String next) async {
    final r = await ref.read(authDioProvider).post<Map<String, dynamic>>(
        '/api/auth/password-reset', data: {'email': email, 'code': code, 'newPassword': next, 'deviceName': 'Android'});
    await _save(r.data!);
  }

  /// Exchanges the refresh token. Returns the new access token, or null if the session is over.
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) return null;
    try {
      final r = await ref
          .read(authDioProvider)
          .post<Map<String, dynamic>>('/api/auth/refresh', data: {'refreshToken': current.refreshToken});
      await _save(r.data!);
      return state.value?.accessToken;
    } on DioException catch (e) {
      // Only a definite "no" from the server ends the session; being offline must not sign the elder out.
      final code = e.response?.statusCode;
      if (code == 401 && current.isElder) {
        // An elder phone must keep reminding from its saved copy: mark it, ask for a new code, clear nothing.
        final expired = current.asExpired();
        await ref.read(sessionStoreProvider).write(expired);
        state = AsyncData(expired);
      } else if (code == 401 || code == 403) {
        await signOutLocally();
      }
      return null;
    }
  }

  Future<void> logout() async {
    await ref.read(pushProvider).stop();
    final current = state.value;
    if (current != null) {
      try {
        await ref.read(authDioProvider).post<void>('/api/auth/logout', data: {'refreshToken': current.refreshToken});
      } catch (_) {
        // Signing out locally still matters if the server cannot be reached.
      }
    }
    await signOutLocally();
  }

  /// Signed out on purpose (the "Đăng xuất" button, or a caregiver account the server refused):
  /// this phone stops reminding and forgets everything.
  Future<void> signOutLocally() async {
    await AlarmChannel.setBackgroundSync(false);
    await _clearPhoneData();
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }

  Future<void> _clearPhoneData() async {
    try {
      await ref.read(elderScheduleProvider.notifier).clear();
    } catch (_) {
      // No saved schedule (caregiver phone, tests).
    }
    await forgetCachedMe(ref.read(sharedPreferencesProvider));
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
