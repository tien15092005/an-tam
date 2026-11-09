import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/server_config.dart';
import '../../reminder/schedule_sync.dart';
import '../groups/groups_api.dart';

/// The signed-in account on this phone. Tokens live in Android's encrypted storage.
class Session {
  const Session({required this.accessToken, required this.refreshToken});

  final String accessToken;
  final String refreshToken;

  Map<String, String> toJson() => {'accessToken': accessToken, 'refreshToken': refreshToken};

  factory Session.fromTokenResponse(Map<String, dynamic> json) =>
      Session(accessToken: json['accessToken'] as String, refreshToken: json['refreshToken'] as String);
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
      return Session(accessToken: m['accessToken'] as String, refreshToken: m['refreshToken'] as String);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Session s) => _storage.write(key: _key, value: jsonEncode(s.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Dio without the auth interceptor, used for sign-in and token refresh themselves.
final authDioProvider = Provider<Dio>((ref) => Dio(BaseOptions(
      baseUrl: ref.watch(serverUrlProvider),
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
    )));

/// Null when signed out. Screens and the router watch this.
class SessionNotifier extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.read(sessionStoreProvider).read();

  Future<void> _save(Map<String, dynamic> tokenJson) async {
    final s = Session.fromTokenResponse(tokenJson);
    await ref.read(sessionStoreProvider).write(s);
    state = AsyncData(s);
  }

  Future<void> register({required String email, required String password, required String displayName, String? phone}) async {
    final r = await ref.read(authDioProvider).post<Map<String, dynamic>>('/api/auth/register', data: {
      'email': email,
      'password': password,
      'displayName': displayName,
      'phone': phone,
      'deviceName': 'Android',
    });
    await _save(r.data!);
  }

  Future<void> login(String email, String password) async {
    final r = await ref.read(authDioProvider).post<Map<String, dynamic>>('/api/auth/login',
        data: {'email': email, 'password': password, 'deviceName': 'Android'});
    await _save(r.data!);
  }

  Future<void> pairElder(String code) async {
    final r = await ref.read(authDioProvider).post<Map<String, dynamic>>('/api/auth/elder-pair',
        data: {'code': code, 'deviceName': 'Điện thoại người già'});
    await _save(r.data!);
  }

  /// Exchanges the refresh token. Returns the new access token, or null if the session is over.
  Future<String?> refresh() async {
    final current = state.value;
    if (current == null) return null;
    try {
      final r = await ref.read(authDioProvider).post<Map<String, dynamic>>('/api/auth/refresh',
          data: {'refreshToken': current.refreshToken});
      await _save(r.data!);
      return state.value?.accessToken;
    } on DioException catch (e) {
      // Only a definite "no" from the server ends the session; being offline must not sign the elder out.
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) await signOutLocally();
      return null;
    }
  }

  Future<void> logout() async {
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

  Future<void> signOutLocally() async {
    // Signed out (or replaced by a newly paired phone): this phone must stop reminding.
    try {
      await ref.read(elderScheduleProvider.notifier).clear();
    } catch (_) {
      // No saved schedule (caregiver phone, tests).
    }
    await forgetCachedMe(ref.read(sharedPreferencesProvider));
    await ref.read(sessionStoreProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionProvider = AsyncNotifierProvider<SessionNotifier, Session?>(SessionNotifier.new);
