import '../config/api_config.dart';
import '../models/dashboard_data.dart';

class DashboardService {
  static Future<DashboardData> getToday() async {
    final response = await ApiConfig.dio.get('/dashboard/today');
    final data = response.data;
    if (data is Map<String, dynamic>) return DashboardData.fromJson(data);
    return DashboardData.fromJson(const {});
  }

  static Future<DashboardData> getByDate(String date) async {
    final response = await ApiConfig.dio.get('/dashboard/$date');
    final data = response.data;
    if (data is Map<String, dynamic>) return DashboardData.fromJson(data);
    return DashboardData.fromJson(const {});
  }
}
