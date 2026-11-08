import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/session.dart';
import '../config/server_config.dart';

/// Dio for the signed-in API: adds the access token and, on 401, refreshes it once and retries.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ref.watch(serverUrlProvider),
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 15),
  ));
  // Queued so that several requests failing at once trigger a single refresh.
  dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(sessionProvider).value?.accessToken;
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onError: (error, handler) async {
      final retried = error.requestOptions.extra['retried'] == true;
      if (error.response?.statusCode != 401 || retried) return handler.next(error);
      final newToken = await ref.read(sessionProvider.notifier).refresh();
      if (newToken == null) return handler.next(error);
      final opts = error.requestOptions
        ..headers['Authorization'] = 'Bearer $newToken'
        ..extra['retried'] = true;
      try {
        handler.resolve(await dio.fetch(opts));
      } on DioException catch (e) {
        handler.next(e);
      }
    },
  ));
  return dio;
});

/// A short Vietnamese message for the UI: the server's own explanation when it gave one.
String describeNetworkError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['detail'] is String) return data['detail'] as String;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Máy chủ không phản hồi. Kiểm tra laptop và đường hầm còn chạy không.';
      case DioExceptionType.connectionError:
        return 'Không kết nối được máy chủ. Kiểm tra địa chỉ và mạng.';
      case DioExceptionType.badResponse:
        return 'Máy chủ báo lỗi ${error.response?.statusCode ?? ''}.'.trim();
      default:
        return 'Lỗi mạng, thử lại sau.';
    }
  }
  return 'Có lỗi xảy ra.';
}

/// The server's machine-readable error code (e.g. "confirm_delete_required"), if any.
String? errorCode(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['code'] is String) return data['code'] as String;
  }
  return null;
}
