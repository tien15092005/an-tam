import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';

class ServerHealth {
  const ServerHealth({required this.backendUp, required this.aiUp, required this.serverTime});

  final bool backendUp;
  final bool aiUp;
  final DateTime? serverTime;

  factory ServerHealth.fromJson(Map<String, dynamic> json) => ServerHealth(
        backendUp: json['status'] == 'UP',
        aiUp: json['ai'] == 'UP',
        serverTime: DateTime.tryParse(json['serverTime'] as String? ?? ''),
      );
}

/// GET /api/health. Re-runs automatically when the server URL changes; call ref.invalidate to retry.
/// Automatic retry is off: this screen exists to show connection failures immediately.
final serverHealthProvider = FutureProvider.autoDispose<ServerHealth>(
  (ref) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get<Map<String, dynamic>>('/api/health');
    return ServerHealth.fromJson(response.data ?? const {});
  },
  retry: (retryCount, error) => null,
);
