// Workout draft persistence via SharedPreferences.
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'workout_form_models.dart';

class WorkoutDraftManager {
  static const _draftKey = 'workout_draft';

  static Future<void> save({
    required String activeTab,
    required List<ExerciseData> exercises,
    required String cardioType,
    required String duration,
    required String distance,
    required String calories,
    required String notes,
    required String intensity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'tab': activeTab,
      'exercises': exercises
          .map((e) => {
                'name': e.name,
                'category': e.category,
                'sets': e.sets
                    .map((s) => {
                          'setNumber': s.setNumber,
                          'weightKg': s.weightKg,
                          'reps': s.reps,
                        })
                    .toList(),
              })
          .toList(),
      'cardioType': cardioType,
      'duration': duration,
      'distance': distance,
      'calories': calories,
      'notes': notes,
      'intensity': intensity,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  /// Returns null if no draft or draft expired (>24h).
  static Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return null;
    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(draft['savedAt'] ?? '');
      if (savedAt != null && DateTime.now().difference(savedAt).inHours > 24) {
        await clear();
        return null;
      }
      return draft;
    } catch (_) {
      await clear();
      return null;
    }
  }

  /// Parses a raw draft map into ExerciseData list.
  static List<ExerciseData> parseExercises(Map<String, dynamic> draft) {
    final exercises = <ExerciseData>[];
    final rawExercises = draft['exercises'] as List? ?? [];
    for (final ex in rawExercises) {
      final sets = (ex['sets'] as List? ?? [])
          .map((s) => SetData(
                setNumber: s['setNumber'] ?? 1,
                weightKg: (s['weightKg'] as num?)?.toDouble(),
                reps: s['reps'] as int?,
              ))
          .toList();
      exercises.add(ExerciseData(
        name: ex['name'] ?? '',
        category: ex['category'] ?? '',
        sets: sets.isEmpty ? [SetData(setNumber: 1)] : sets,
      ));
    }
    return exercises;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }
}
