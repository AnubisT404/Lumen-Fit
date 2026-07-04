import '../config/api_config.dart';
import '../models/workout.dart';

class WorkoutsService {
  static Future<List<Map<String, dynamic>>> getExercises() async {
    final response = await ApiConfig.dio.get('/workouts/exercises');
    final data = response.data;
    // API returns {"chest": [...], "back": [...], ...} — flatten all categories
    if (data is Map) {
      final List<Map<String, dynamic>> all = [];
      for (final category in data.values) {
        if (category is List) {
          for (final ex in category) {
            if (ex is Map<String, dynamic>) all.add(ex);
          }
        }
      }
      return all;
    }
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> searchExercises(String query) async {
    final response = await ApiConfig.dio.get('/workouts/exercises/search', queryParameters: {'q': query});
    final data = response.data;
    if (data is Map) {
      return (data['exercises'] as List? ?? data['results'] as List? ?? []).cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  static Future<List<Workout>> getByDate(String date) async {
    final response = await ApiConfig.dio.get('/workouts/by-date', queryParameters: {'target_date': date});
    final data = response.data;
    final list = data is Map ? (data['workouts'] as List? ?? []) : (data as List? ?? []);
    return list.map((w) => Workout.fromJson(w as Map<String, dynamic>)).toList();
  }

  static Future<void> log(Map<String, dynamic> data) async {
    await ApiConfig.dio.post('/workouts/', data: data);
  }

  static Future<void> quickCardio(Map<String, dynamic> data) async {
    await ApiConfig.dio.post('/workouts/quick-cardio', data: data);
  }

  static Future<void> delete(int id) async {
    await ApiConfig.dio.delete('/workouts/$id');
  }

  static Future<void> deleteExercise(int exerciseId) async {
    await ApiConfig.dio.delete('/workouts/exercise/$exerciseId');
  }

  static Future<void> update(int id, Map<String, dynamic> data) async {
    await ApiConfig.dio.put('/workouts/$id', data: data);
  }

  static Future<Workout> get(int id) async {
    final response = await ApiConfig.dio.get('/workouts/$id');
    return Workout.fromJson(response.data as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> getPreviousSession(String exerciseName) async {
    final response = await ApiConfig.dio.get('/workouts/exercises/previous',
        queryParameters: {'exercise_name': exerciseName});
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getRoutine(int id) async {
    final response = await ApiConfig.dio.get('/workouts/routines/$id');
    return response.data as Map<String, dynamic>;
  }

  static Future<void> updateCardio(int id, Map<String, dynamic> data) async {
    await ApiConfig.dio.put('/workouts/$id/cardio', data: data);
  }

  static Future<Map<String, dynamic>?> getTodayPlan() async {
    try {
      final response = await ApiConfig.dio.get('/workouts/plans/active/today');
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // ─── Plans ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listPlans() async {
    final response = await ApiConfig.dio.get('/workouts/plans/');
    final data = response.data;
    if (data is Map) return (data['plans'] as List? ?? []).cast<Map<String, dynamic>>();
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  static Future<Map<String, dynamic>> getPlan(int id) async {
    final response = await ApiConfig.dio.get('/workouts/plans/$id');
    return response.data as Map<String, dynamic>;
  }

  static Future<void> createPlan(Map<String, dynamic> data) async {
    await ApiConfig.dio.post('/workouts/plans/', data: data);
  }

  static Future<void> updatePlan(int id, Map<String, dynamic> data) async {
    await ApiConfig.dio.put('/workouts/plans/$id', data: data);
  }

  static Future<void> deletePlan(int id) async {
    await ApiConfig.dio.delete('/workouts/plans/$id');
  }

  static Future<void> activatePlan(int id) async {
    await ApiConfig.dio.post('/workouts/plans/$id/activate');
  }

  static Future<void> deactivatePlan(int id) async {
    await ApiConfig.dio.post('/workouts/plans/$id/deactivate');
  }

  // ─── Routines ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> listRoutines() async {
    final response = await ApiConfig.dio.get('/workouts/routines/');
    final data = response.data;
    if (data is Map) return (data['routines'] as List? ?? []).cast<Map<String, dynamic>>();
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  static Future<Map<String, dynamic>> createRoutine(
      Map<String, dynamic> data) async {
    final response =
        await ApiConfig.dio.post('/workouts/routines/', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateRoutine(
      int id, Map<String, dynamic> data) async {
    final response =
        await ApiConfig.dio.put('/workouts/routines/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  static Future<void> deleteRoutine(int id) async {
    await ApiConfig.dio.delete('/workouts/routines/$id');
  }
}
