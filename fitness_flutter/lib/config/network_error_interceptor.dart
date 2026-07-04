import 'package:dio/dio.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'router.dart';

/// Dio interceptor that shows user-facing error feedback for network failures.
/// Debounces to avoid spamming when multiple requests fail simultaneously.
class NetworkErrorInterceptor extends Interceptor {
  DateTime? _lastErrorShown;
  static const _debounce = Duration(seconds: 3);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _maybeShowError(err);
    handler.next(err);
  }

  void _maybeShowError(DioException err) {
    // Only show for network-level failures (not 4xx client errors)
    if (!_isNetworkError(err)) return;

    // Debounce
    final now = DateTime.now();
    if (_lastErrorShown != null && now.difference(_lastErrorShown!) < _debounce) {
      return;
    }
    _lastErrorShown = now;

    // Show error via root navigator context
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final message = _userMessage(err);
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: AdaptiveSnackBarType.error,
      duration: const Duration(seconds: 4),
    );
  }

  bool _isNetworkError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = err.response?.statusCode ?? 0;
        return code >= 500; // Only show for server errors
      default:
        return false;
    }
  }

  String _userMessage(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'No internet connection';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out';
      case DioExceptionType.badResponse:
        return 'Server error. Please try again later.';
      default:
        return 'Connection failed';
    }
  }
}
