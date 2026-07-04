import '../config/api_config.dart';
import '../models/food_item.dart';
import '../models/meal_entry.dart';
import '../models/profile.dart';

class MealsService {
  static Future<List<FoodItem>> searchFood(String query, {String source = 'all'}) async {
    final response = await ApiConfig.dio.get('/meals/search-food', queryParameters: {
      'query': query,
      'source': source,
    });
    final results = response.data['results'] as List? ?? response.data as List? ?? [];
    return results.map((r) => FoodItem.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Fast barcode lookup: local DB first, then OFF product API.
  static Future<List<FoodItem>> lookupBarcode(String barcode) async {
    final response = await ApiConfig.dio.get('/meals/barcode/$barcode');
    final data = response.data as Map<String, dynamic>;
    if (data['found'] != true) return [];
    final results = data['results'] as List? ?? [];
    return results.map((r) => FoodItem.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<void> quickAdd({
    required String mealType,
    required String foodName,
    String? brand,
    String? barcode,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatsG,
    double? fiberG,
    double? sugarG,
    double? sodiumMg,
    double? saturatedFatG,
    double? servingSize,
    String? servingUnit,
    double? servings,
    String? source,
  }) async {
    await ApiConfig.dio.post('/meals/quick-add', data: {
      'meal_type': mealType,
      'food_name': foodName,
      'brand': ?brand,
      'barcode': ?barcode,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fats_g': fatsG,
      'fiber_g': ?fiberG,
      'sugar_g': ?sugarG,
      'sodium_mg': ?sodiumMg,
      'saturated_fat_g': ?saturatedFatG,
      'serving_size': ?servingSize,
      'serving_unit': ?servingUnit,
      'servings': ?servings,
      'source': ?source,
    });
  }

  static Future<List<MealEntry>> getToday() async {
    final response = await ApiConfig.dio.get('/meals/today');
    final data = response.data;
    final list = data is Map ? (data['meals'] as List? ?? []) : (data as List? ?? []);
    return list.map((m) => MealEntry.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<List<MealEntry>> getByDate(String date) async {
    final response = await ApiConfig.dio.get('/meals/by-date', queryParameters: {'date': date});
    final data = response.data;
    final list = data is Map ? (data['meals'] as List? ?? []) : (data as List? ?? []);
    return list.map((m) => MealEntry.fromJson(m as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, List<FoodItem>>> getRecentFoods() async {
    final response = await ApiConfig.dio.get('/meals/recent-foods');
    final data = response.data;
    if (data is! Map<String, dynamic>) return {'recent': [], 'frequent': []};
    final recent = (data['recent'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((f) => FoodItem.fromJson(f))
        .toList();
    final frequent = (data['frequent'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((f) => FoodItem.fromJson(f))
        .toList();
    return {'recent': recent, 'frequent': frequent};
  }

  static Future<void> deleteItem(int itemId) async {
    await ApiConfig.dio.delete('/meals/items/$itemId');
  }

  static Future<void> updateItem(int itemId, Map<String, dynamic> data) async {
    await ApiConfig.dio.put('/meals/items/$itemId', data: data);
  }

  static Future<Map<String, dynamic>> getNutritionDetail(String startDate, {String? endDate}) async {
    final response = await ApiConfig.dio.get('/meals/nutrition-detail', queryParameters: {
      'start_date': startDate,
      'end_date': endDate ?? startDate,
    });
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    return const {};
  }

  // Templates
  static Future<List<MealTemplate>> getTemplates() async {
    final response = await ApiConfig.dio.get('/meals/templates');
    final list = response.data as List? ?? [];
    return list.map((t) => MealTemplate.fromJson(t as Map<String, dynamic>)).toList();
  }

  static Future<void> createTemplate({required String name, required List<Map<String, dynamic>> items}) async {
    await ApiConfig.dio.post('/meals/templates', data: {'name': name, 'items': items});
  }

  static Future<void> logTemplate(int templateId, {required String mealType, required String date}) async {
    await ApiConfig.dio.post('/meals/templates/$templateId/log', data: {'meal_type': mealType, 'date': date});
  }

  static Future<void> deleteTemplate(int templateId) async {
    await ApiConfig.dio.delete('/meals/templates/$templateId');
  }

  static Future<void> updateTemplate(int templateId, Map<String, dynamic> data) async {
    await ApiConfig.dio.put('/meals/templates/$templateId', data: data);
  }
}
