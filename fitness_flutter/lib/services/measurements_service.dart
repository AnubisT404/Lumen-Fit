import '../config/api_config.dart';
import '../models/measurement.dart';

class MeasurementsService {
  static Future<void> log(Measurement m) async {
    await ApiConfig.dio.post('/measurements/', data: m.toJson());
  }

  static Future<List<Measurement>> getAll({int? limit}) async {
    final response = await ApiConfig.dio.get('/measurements/', queryParameters: {
      'limit': ?limit,
    });
    final list = response.data as List? ?? [];
    return list.map((m) => Measurement.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getStats() async {
    final response = await ApiConfig.dio.get('/measurements/stats');
    return response.data as Map<String, dynamic>;
  }

  static Future<void> delete(int id) async {
    await ApiConfig.dio.delete('/measurements/$id');
  }
}
