import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_entry.dart';
import '../services/meals_service.dart';
import '../utils/date_utils.dart';

final selectedDateProvider = StateProvider<String>((ref) => todayDateString());

final mealsProvider = FutureProvider.autoDispose<List<MealEntry>>((ref) async {
  final date = ref.watch(selectedDateProvider);
  final today = todayDateString();
  if (date == today) {
    return MealsService.getToday();
  }
  return MealsService.getByDate(date);
});
