import 'package:dio/dio.dart';
import '../services/auth_service.dart';
import 'network_error_interceptor.dart';
import 'offline_queue.dart';

class ApiConfig {
  // Use 10.0.2.2 for Android emulator, localhost for iOS simulator
  static const String defaultBaseUrl = 'http://127.0.0.1:8000/api/v1';

  static String baseUrl = defaultBaseUrl;

  static String get chatStreamUrl => '$baseUrl/coach/chat';

  static Dio createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth interceptor — attaches Bearer token and handles 401 refresh
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = AuthService.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && AuthService.isLoggedIn) {
          // Try refreshing token
          final refreshed = await AuthService.refreshTokens();
          if (refreshed) {
            // Retry original request with new token
            final opts = error.requestOptions;
            opts.headers['Authorization'] = 'Bearer ${AuthService.accessToken}';
            try {
              final resp = await dio.fetch(opts);
              return handler.resolve(resp);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        handler.next(error);
      },
    ));

    // Network error user feedback (debounced)
    dio.interceptors.add(NetworkErrorInterceptor());

    // Offline queue — saves failed POST/PUT/DELETE for retry
    dio.interceptors.add(OfflineQueueInterceptor());

    return dio;
  }

  static final Dio dio = createDio();
}
