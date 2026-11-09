import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Default backend address: `--dart-define=API_BASE_URL=...` at build time, otherwise the
/// Android emulator's alias for the laptop running docker compose.
const defaultServerUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8080');

const _prefsKey = 'server_url';

/// Provided in main() after SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

/// The backend URL. The tunnel address can change between runs, so the user can edit it in the app.
class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(sharedPreferencesProvider).getString(_prefsKey) ?? defaultServerUrl;

  /// Returns an error message, or null when the URL was saved.
  Future<String?> save(String input) async {
    final url = input.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      return 'Địa chỉ phải bắt đầu bằng http:// hoặc https://';
    }
    // Release builds talk to the server over HTTPS only (plan §11); Android refuses plain HTTP there anyway.
    if (kReleaseMode && !uri.isScheme('https')) return 'Bản chính thức chỉ dùng địa chỉ https://';
    await ref.read(sharedPreferencesProvider).setString(_prefsKey, url);
    state = url;
    return null;
  }

  Future<void> reset() async {
    await ref.read(sharedPreferencesProvider).remove(_prefsKey);
    state = defaultServerUrl;
  }
}

final serverUrlProvider = NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);
