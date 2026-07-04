import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout.dart';
import '../services/workouts_service.dart';
import '../utils/date_utils.dart';

final workoutDateProvider = StateProvider<String>((ref) => todayDateString());

final workoutsProvider =
    FutureProvider.autoDispose<List<Workout>>((ref) async {
  final date = ref.watch(workoutDateProvider);
  return WorkoutsService.getByDate(date);
});

final todayPlanProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return WorkoutsService.getTodayPlan();
});
