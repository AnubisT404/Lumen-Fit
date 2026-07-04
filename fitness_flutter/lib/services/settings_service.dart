import '../config/api_config.dart';
import '../models/settings.dart';

class SettingsService {
  static Future<AppSettings> get() async {
    final response = await ApiConfig.dio.get('/settings/');
    return AppSettings.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> update(Map<String, dynamic> data) async {
    await ApiConfig.dio.put('/settings/', data: data);
  }
}
