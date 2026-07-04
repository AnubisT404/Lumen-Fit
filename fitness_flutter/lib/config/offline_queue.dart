import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Offline request queue that saves failed mutating requests and retries on reconnection.
/// Only queues POST/PUT/DELETE (not GET — reads should show cached or empty state).
class OfflineQueue {
  OfflineQueue._();
  static final OfflineQueue instance = OfflineQueue._();

  static const _storageKey = 'offline_queue';
  static const _maxQueueSize = 50;

  bool _processing = false;

  /// Queue a failed request for later retry.
  Future<void> enqueue(RequestOptions options) async {
    if (!_isMutating(options.method)) return;

    final entry = {
      'method': options.method,
      'path': options.path,
      'data': options.data,
      'queryParameters': options.queryParameters,
      'timestamp': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    final queue = prefs.getStringList(_storageKey) ?? [];

    if (queue.length >= _maxQueueSize) {
      queue.removeAt(0); // Drop oldest if queue is full
    }

    queue.add(jsonEncode(entry));
    await prefs.setStringList(_storageKey, queue);

    if (kDebugMode) {
      debugPrint('[OfflineQueue] Queued ${options.method} ${options.path} (${queue.length} pending)');
    }
  }

  /// Get count of pending requests.
  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_storageKey) ?? []).length;
  }

  /// Process all queued requests. Call when connectivity is restored.
  Future<void> processQueue() async {
    if (_processing) return;
    _processing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_storageKey) ?? [];

      if (queue.isEmpty) return;

      if (kDebugMode) {
        debugPrint('[OfflineQueue] Processing ${queue.length} queued requests...');
      }

      final failed = <String>[];

      for (int i = 0; i < queue.length; i++) {
        final raw = queue[i];
        try {
          final entry = jsonDecode(raw) as Map<String, dynamic>;
          final method = entry['method'] as String;
          final path = entry['path'] as String;
          final data = entry['data'];
          final queryParams = (entry['queryParameters'] as Map<String, dynamic>?) ?? {};

          await ApiConfig.dio.request(
            path,
            data: data,
            queryParameters: queryParams,
            options: Options(method: method),
          );

          if (kDebugMode) {
            debugPrint('[OfflineQueue] ✓ Replayed $method $path');
          }
        } on DioException catch (e) {
          if (_isNetworkError(e)) {
            // Still offline — stop processing, keep remaining in queue
            failed.addAll(queue.sublist(i));
            break;
          }
          final statusCode = e.response?.statusCode ?? 0;
          if (statusCode >= 500) {
            // Server error — retain for retry later
            failed.add(raw);
            if (kDebugMode) {
              debugPrint('[OfflineQueue] ↻ Retained (server error $statusCode): $raw');
            }
          } else {
            // Client error (4xx) — discard, won't succeed on retry
            if (kDebugMode) {
              debugPrint('[OfflineQueue] ✗ Discarded (client error $statusCode): $raw');
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[OfflineQueue] ✗ Discarded (error): $e');
        }
      }

      await prefs.setStringList(_storageKey, failed);

      if (kDebugMode && failed.isEmpty) {
        debugPrint('[OfflineQueue] All queued requests processed successfully.');
      }
    } finally {
      _processing = false;
    }
  }

  /// Clear all queued requests.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  bool _isMutating(String method) {
    final m = method.toUpperCase();
    return m == 'POST' || m == 'PUT' || m == 'DELETE' || m == 'PATCH';
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError;
  }
}

/// Dio interceptor that automatically queues failed mutating requests.
class OfflineQueueInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isNetworkError(err) && _isMutating(err.requestOptions.method)) {
      OfflineQueue.instance.enqueue(err.requestOptions);
    }
    handler.next(err);
  }

  bool _isMutating(String method) {
    final m = method.toUpperCase();
    return m == 'POST' || m == 'PUT' || m == 'DELETE' || m == 'PATCH';
  }

  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
  }
}
