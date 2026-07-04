import '../config/api_config.dart';
import '../models/profile.dart';

class ProfileService {
  static Future<Profile> get() async {
    final response = await ApiConfig.dio.get('/profile');
    final data = response.data as Map<String, dynamic>;
    final profileData = data['profile'] as Map<String, dynamic>? ?? data;
    return Profile.fromJson(profileData);
  }

  static Future<Goals> getGoals() async {
    final response = await ApiConfig.dio.get('/profile/goals');
    return Goals.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<void> setupProfile({
    String? name,
    required int age,
    required String sex,
    required double heightCm,
    required double weightKg,
    required String activityLevel,
    required String goal,
    double? targetWeightKg,
  }) async {
    await ApiConfig.dio.post('/profile/setup', data: {
      'name': ?name,
      'age': age,
      'sex': sex,
      'height_cm': heightCm,
      'current_weight_kg': weightKg,
      'weight_kg': weightKg,
      'activity_level': activityLevel,
      'goal': goal,
      'target_weight_kg': ?targetWeightKg,
    });
  }

  static Future<Map<String, dynamic>> updateProfile({
    double? weightKg,
    double? targetWeightKg,
    String? activityLevel,
    String? goal,
  }) async {
    final response = await ApiConfig.dio.put('/profile', data: {
      'current_weight_kg': ?weightKg,
      'target_weight_kg': ?targetWeightKg,
      'activity_level': ?activityLevel,
      'goal': ?goal,
    });
    return response.data as Map<String, dynamic>;
  }

  static Future<void> updateGoals({
    int? dailyCalories,
    int? proteinG,
    int? carbsG,
    int? fatsG,
    int? waterMl,
  }) async {
    await ApiConfig.dio.put('/profile/goals', data: {
      'daily_calories': ?dailyCalories,
      'protein_g': ?proteinG,
      'carbs_g': ?carbsG,
      'fats_g': ?fatsG,
      'water_ml': ?waterMl,
    });
  }
}
