import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meals_service.dart';
import '../utils/date_utils.dart';

String _addDays(String dateStr, int days) {
  final next = DateTime.parse(dateStr).add(Duration(days: days));
  return formatDateString(next);
}

String _getMonday(String dateStr) {
  final d = DateTime.parse(dateStr);
  final monday = d.subtract(Duration(days: d.weekday - 1));
  return formatDateString(monday);
}

final nutritionDateProvider = StateProvider<String>((ref) => todayDateString());
final nutritionModeProvider = StateProvider<String>((ref) => 'day');

final nutritionDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final date = ref.watch(nutritionDateProvider);
  final mode = ref.watch(nutritionModeProvider);

  String startDate;
  String endDate;
  if (mode == 'week') {
    startDate = _getMonday(date);
    endDate = _addDays(startDate, 6);
  } else {
    startDate = date;
    endDate = date;
  }

  return MealsService.getNutritionDetail(startDate, endDate: endDate);
});

// Meal-level data for calorie breakdown (day mode only)
final nutritionMealsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final date = ref.watch(nutritionDateProvider);
  final mode = ref.watch(nutritionModeProvider);
  final today = todayDateString();
  if (mode != 'day' || date != today) return [];
  final meals = await MealsService.getToday();
  return meals.cast<Map<String, dynamic>>();
});

// Always fetch the week containing the selected date for chart display
final nutritionWeekChartProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final date = ref.watch(nutritionDateProvider);
  final monday = _getMonday(date);
  final sunday = _addDays(monday, 6);
  final data = await MealsService.getNutritionDetail(monday, endDate: sunday);
  return ((data['days'] as List?) ?? []).cast<Map<String, dynamic>>();
});
