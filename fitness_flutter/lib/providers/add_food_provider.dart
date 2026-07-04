import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/food_item.dart';
import '../models/profile.dart';
import '../services/meals_service.dart';

final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');
final searchSourceProvider = StateProvider.autoDispose<String>((ref) => 'all');

final foodSearchProvider =
    FutureProvider.autoDispose.family<List<FoodItem>, String>((ref, query) async {
  if (query.length < 2) return [];
  final source = ref.watch(searchSourceProvider);
  return MealsService.searchFood(query, source: source);
});

final recentFoodsProvider = FutureProvider.autoDispose<Map<String, List<FoodItem>>>((ref) async {
  return MealsService.getRecentFoods();
});

final mealTemplatesProvider = FutureProvider.autoDispose<List<MealTemplate>>((ref) async {
  return MealsService.getTemplates();
});
