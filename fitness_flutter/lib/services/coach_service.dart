import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/coach_message.dart';

class CoachService {
  static Future<Map<String, dynamic>> getDailyInsight() async {
    final response = await ApiConfig.dio.get('/coach/daily-insight');
    return response.data as Map<String, dynamic>;
  }

  static Future<List<CoachMessage>> getHistory({int page = 1, int perPage = 20}) async {
    final response = await ApiConfig.dio.get('/coach/history', queryParameters: {
      'page': page,
      'per_page': perPage,
    });
    final data = response.data;
    final list = data is Map ? (data['messages'] as List? ?? data['history'] as List? ?? []) : (data as List? ?? []);
    return list.map((m) => CoachMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<void> clearHistory() async {
    await ApiConfig.dio.delete('/coach/history');
  }

  /// Stream chat response via SSE — yields parsed JSON maps with event type info.
  static Stream<Map<String, dynamic>> chatStreamParsed(String message, {String? sessionId}) async* {
    final response = await ApiConfig.dio.post(
      '/coach/chat',
      data: {
        'message': message,
        if (sessionId != null) 'session_id': sessionId,
      },
      options: Options(responseType: ResponseType.stream),
    );
    final stream = response.data.stream as Stream<List<int>>;
    String buffer = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      final records = buffer.split('\n\n');
      buffer = records.removeLast();

      for (final record in records) {
        final parsed = _parseSSERecord(record);
        if (parsed != null) yield parsed;
      }
    }

    // Flush remaining buffer on stream close
    if (buffer.trim().isNotEmpty) {
      final parsed = _parseSSERecord(buffer);
      if (parsed != null) yield parsed;
    }
  }

  static Map<String, dynamic>? _parseSSERecord(String record) {
    if (record.trim().isEmpty) return null;
    String? eventType;
    final dataLines = <String>[];
    for (final line in record.split('\n')) {
      if (line.startsWith('event:')) eventType = line.substring(6).trim();
      if (line.startsWith('data:')) dataLines.add(line.substring(5).trim());
    }
    if (dataLines.isEmpty) return null;
    try {
      final json = jsonDecode(dataLines.join('\n')) as Map<String, dynamic>;
      if (eventType != null) json['_event'] = eventType;
      return json;
    } catch (_) {
      return null;
    }
  }

  /// Get list of chat sessions
  static Future<List<Map<String, dynamic>>> getSessions() async {
    final response = await ApiConfig.dio.get('/coach/sessions');
    final data = response.data as Map<String, dynamic>;
    return (data['sessions'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Get messages for a specific session
  static Future<List<CoachMessage>> getSessionMessages(String sessionId) async {
    final response = await ApiConfig.dio.get('/coach/sessions/$sessionId');
    final data = response.data as Map<String, dynamic>;
    final list = data['messages'] as List? ?? [];
    return list.map((m) => CoachMessage.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<List<Map<String, dynamic>>> getKnowledge() async {
    final response = await ApiConfig.dio.get('/coach/knowledge');
    final data = response.data;
    if (data is Map) return (data['documents'] as List? ?? []).cast<Map<String, dynamic>>();
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  static Future<void> deleteKnowledge(String id) async {
    await ApiConfig.dio.delete('/coach/knowledge/$id');
  }
}
