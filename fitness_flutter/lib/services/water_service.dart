import '../config/api_config.dart';

class WaterService {
  static Future<void> log(int amountMl) async {
    await ApiConfig.dio.post('/water/', data: {'amount_ml': amountMl});
  }

  static Future<Map<String, dynamic>> getToday() async {
    final response = await ApiConfig.dio.get('/water/today');
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  static Future<void> resetToday() async {
    await ApiConfig.dio.delete('/water/today/reset');
  }
}
