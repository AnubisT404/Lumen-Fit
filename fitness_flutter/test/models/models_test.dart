import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/models/dashboard_data.dart';
import 'package:fitness_app/models/food_item.dart';
import 'package:fitness_app/models/meal_entry.dart';
import 'package:fitness_app/models/measurement.dart';
import 'package:fitness_app/models/profile.dart';
import 'package:fitness_app/models/settings.dart';
import 'package:fitness_app/models/workout.dart';

void main() {
  group('NutritionValues.fromJson', () {
    test('parses valid JSON', () {
      final v = NutritionValues.fromJson({
        'calories': 2000,
        'protein_g': 150.5,
        'carbs_g': 250,
        'fats_g': 70.2,
      });
      expect(v.calories, 2000.0);
      expect(v.proteinG, 150.5);
      expect(v.carbsG, 250.0);
      expect(v.fatsG, 70.2);
    });

    test('handles empty map', () {
      final v = NutritionValues.fromJson({});
      expect(v.calories, 0);
      expect(v.proteinG, 0);
      expect(v.carbsG, 0);
      expect(v.fatsG, 0);
    });

    test('handles null values', () {
      final v = NutritionValues.fromJson({
        'calories': null,
        'protein_g': null,
        'carbs_g': null,
        'fats_g': null,
      });
      expect(v.calories, 0);
      expect(v.proteinG, 0);
    });

    test('handles wrong types gracefully', () {
      // String instead of num — should fall through to ?? 0
      expect(
        () => NutritionValues.fromJson({'calories': 'abc'}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('DashboardData.fromJson', () {
    test('parses full valid response', () {
      final d = DashboardData.fromJson({
        'date': '2025-06-10',
        'nutrition': {
          'consumed': {'calories': 1500, 'protein_g': 100, 'carbs_g': 200, 'fats_g': 50},
          'goals': {'calories': 2000, 'protein_g': 150, 'carbs_g': 250, 'fats_g': 70},
          'remaining': {'calories': 500, 'protein_g': 50, 'carbs_g': 50, 'fats_g': 20},
          'percentage': {'calories': 75, 'protein_g': 66, 'carbs_g': 80, 'fats_g': 71},
        },
        'water': {'consumed_ml': 1500, 'goal_ml': 2500, 'percentage': 60, 'remaining_ml': 1000},
        'exercise': {'total_workouts': 1, 'total_minutes': 45, 'calories_burned': 300},
        'weight': {'current_kg': 80.5, 'last_measured': '2025-06-09'},
        'meals_logged': 3,
        'week_streak': [
          {'day': 'Mon', 'date': '2025-06-09', 'logged': true, 'future': false},
        ],
      });
      expect(d.date, '2025-06-10');
      expect(d.nutrition.consumed.calories, 1500);
      expect(d.water.consumedMl, 1500);
      expect(d.exercise.totalMinutes, 45);
      expect(d.weight.currentKg, 80.5);
      expect(d.mealsLogged, 3);
      expect(d.weekStreak.length, 1);
      expect(d.weekStreak[0].day, 'Mon');
    });

    test('handles completely empty map', () {
      final d = DashboardData.fromJson({});
      expect(d.date, '');
      expect(d.nutrition.consumed.calories, 0);
      expect(d.water.goalMl, 2000);
      expect(d.exercise.totalWorkouts, 0);
      expect(d.weight.currentKg, null);
      expect(d.mealsLogged, 0);
      expect(d.weekStreak, isEmpty);
    });

    test('handles null nested objects', () {
      final d = DashboardData.fromJson({
        'nutrition': null,
        'water': null,
        'exercise': null,
        'weight': null,
        'week_streak': null,
      });
      expect(d.nutrition.consumed.calories, 0);
      expect(d.water.consumedMl, 0);
      expect(d.weekStreak, isEmpty);
    });
  });

  group('WaterData.fromJson', () {
    test('parses valid', () {
      final w = WaterData.fromJson({'consumed_ml': 1000, 'goal_ml': 3000, 'percentage': 33.3, 'remaining_ml': 2000});
      expect(w.consumedMl, 1000);
      expect(w.goalMl, 3000);
      expect(w.percentage, 33.3);
    });

    test('defaults goal to 2000', () {
      final w = WaterData.fromJson({});
      expect(w.goalMl, 2000);
    });
  });

  group('Workout.fromJson', () {
    test('parses strength workout', () {
      final w = Workout.fromJson({
        'id': 1,
        'workout_type': 'strength',
        'name': 'Push Day',
        'duration_minutes': 60,
        'calories_burned': 400,
        'exercises': [
          {
            'id': 10,
            'exercise_name': 'Bench Press',
            'exercise_category': 'chest',
            'sets': [
              {'set_number': 1, 'reps': 10, 'weight_kg': 80.0},
              {'set_number': 2, 'reps': 8, 'weight_kg': 85.0},
            ],
          },
        ],
      });
      expect(w.id, 1);
      expect(w.workoutType, 'strength');
      expect(w.name, 'Push Day');
      expect(w.exercises.length, 1);
      expect(w.exercises[0].exerciseName, 'Bench Press');
      expect(w.exercises[0].sets.length, 2);
      expect(w.exercises[0].sets[1].weightKg, 85.0);
    });

    test('parses cardio workout', () {
      final w = Workout.fromJson({
        'workout_type': 'cardio',
        'exercise_type': 'running',
        'duration_minutes': 30,
        'distance_km': 5.2,
        'avg_heart_rate': 155,
        'intensity': 'high',
      });
      expect(w.workoutType, 'cardio');
      expect(w.exerciseType, 'running');
      expect(w.distanceKm, 5.2);
      expect(w.avgHeartRate, 155);
      expect(w.exercises, isEmpty);
    });

    test('handles empty map', () {
      final w = Workout.fromJson({});
      expect(w.workoutType, 'strength');
      expect(w.exercises, isEmpty);
      expect(w.id, null);
    });

    test('handles null exercises list', () {
      final w = Workout.fromJson({'exercises': null});
      expect(w.exercises, isEmpty);
    });
  });

  group('WorkoutSet.fromJson', () {
    test('parses valid', () {
      final s = WorkoutSet.fromJson({
        'id': 5,
        'set_number': 3,
        'reps': 12,
        'weight_kg': 60.5,
        'notes': 'Easy',
      });
      expect(s.id, 5);
      expect(s.setNumber, 3);
      expect(s.reps, 12);
      expect(s.weightKg, 60.5);
      expect(s.notes, 'Easy');
    });

    test('defaults set_number to 1', () {
      final s = WorkoutSet.fromJson({});
      expect(s.setNumber, 1);
      expect(s.reps, null);
      expect(s.weightKg, null);
    });
  });

  group('WorkoutSet.toJson', () {
    test('omits null fields', () {
      final s = WorkoutSet(setNumber: 1, reps: 10, weightKg: 50);
      final j = s.toJson();
      expect(j['set_number'], 1);
      expect(j['reps'], 10);
      expect(j['weight_kg'], 50);
      expect(j.containsKey('duration_seconds'), false);
      expect(j.containsKey('notes'), false);
    });
  });

  group('Measurement.fromJson', () {
    test('parses valid', () {
      final m = Measurement.fromJson({
        'id': 1,
        'weight_kg': 82.3,
        'body_fat_percentage': 18.5,
        'notes': 'Morning',
        'created_at': '2025-06-10T08:00:00',
      });
      expect(m.id, 1);
      expect(m.weightKg, 82.3);
      expect(m.bodyFatPercentage, 18.5);
      expect(m.notes, 'Morning');
    });

    test('handles empty map — defaults weight to 0', () {
      final m = Measurement.fromJson({});
      expect(m.weightKg, 0);
      expect(m.bodyFatPercentage, null);
      expect(m.id, null);
    });
  });

  group('Profile.fromJson', () {
    test('parses valid', () {
      final p = Profile.fromJson({
        'name': 'John',
        'age': 30,
        'sex': 'male',
        'height_cm': 180.0,
        'weight_kg': 80.0,
        'target_weight_kg': 75.0,
        'activity_level': 'moderate',
        'goal': 'lose',
        'is_setup': true,
      });
      expect(p.name, 'John');
      expect(p.age, 30);
      expect(p.heightCm, 180.0);
      expect(p.weightKg, 80.0);
      expect(p.isSetup, true);
    });

    test('handles empty map', () {
      final p = Profile.fromJson({});
      expect(p.name, null);
      expect(p.age, null);
      expect(p.isSetup, false);
    });

    test('isSetup inferred from name presence', () {
      final p = Profile.fromJson({'name': 'Auto'});
      expect(p.isSetup, true);
    });
  });

  group('Goals.fromJson', () {
    test('parses valid', () {
      final g = Goals.fromJson({
        'daily_calories': 2000,
        'protein_g': 150,
        'carbs_g': 250,
        'fats_g': 70,
        'water_ml': 2500,
      });
      expect(g.dailyCalories, 2000);
      expect(g.proteinG, 150);
      expect(g.waterMl, 2500);
    });

    test('handles empty map', () {
      final g = Goals.fromJson({});
      expect(g.dailyCalories, 2000);
      expect(g.waterMl, 2000);
    });
  });

  group('AppSettings.fromJson', () {
    test('parses valid', () {
      final s = AppSettings.fromJson({
        'weight_unit': 'lb',
        'ai_provider': 'openai',
        'ai_api_key_set': true,
        'scholar_search_enabled': true,
      });
      expect(s.weightUnit, 'lb');
      expect(s.aiProvider, 'openai');
      expect(s.aiApiKeySet, true);
      expect(s.scholarSearchEnabled, true);
    });

    test('handles empty map with defaults', () {
      final s = AppSettings.fromJson({});
      expect(s.weightUnit, 'kg');
      expect(s.aiApiKeySet, false);
      expect(s.scholarSearchEnabled, false);
    });
  });

  group('MealEntry.fromJson', () {
    test('parses valid', () {
      final m = MealEntry.fromJson({
        'id': 42,
        'meal_type': 'lunch',
        'food_name': 'Chicken Breast',
        'calories': 250.0,
        'protein': 45.0,
        'carbs': 0.0,
        'fat': 6.0,
        'serving_size': 150,
        'servings': 1.0,
        'created_at': '2025-06-10',
      });
      expect(m.id, 42);
      expect(m.mealType, 'lunch');
      expect(m.foodName, 'Chicken Breast');
      expect(m.calories, 250.0);
      expect(m.protein, 45.0);
    });

    test('throws on missing id (required field)', () {
      expect(
        () => MealEntry.fromJson({}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('FoodItem.fromJson', () {
    test('parses valid with portions', () {
      final f = FoodItem.fromJson({
        'name': 'Rice',
        'brand': 'Generic',
        'calories': 130,
        'protein_g': 2.7,
        'carbs_g': 28,
        'fats_g': 0.3,
        'serving_size': 100,
        'serving_unit': 'g',
        'source': 'usda',
        'portions': [
          {'description': '1 cup', 'gram_weight': 185, 'amount': 1},
        ],
      });
      expect(f.displayName, 'Rice');
      expect(f.brand, 'Generic');
      expect(f.calories, 130.0);
      expect(f.source, 'usda');
      expect(f.portions?.length, 1);
    });

    test('handles missing optional fields', () {
      final f = FoodItem.fromJson({'name': 'Apple'});
      expect(f.displayName, 'Apple');
      expect(f.brand, null);
      expect(f.portions, null);
      expect(f.calories, null);
    });

    test('displayName falls back to productName', () {
      final f = FoodItem.fromJson({'product_name': 'Banana'});
      expect(f.displayName, 'Banana');
    });

    test('displayName falls back to Unknown', () {
      final f = FoodItem.fromJson({});
      expect(f.displayName, 'Unknown');
    });
  });

  group('MealTemplate.fromJson', () {
    test('parses valid', () {
      final t = MealTemplate.fromJson({
        'id': 1,
        'name': 'Breakfast',
        'items': [
          {'id': 1, 'food_id': 10, 'food_name': 'Oats', 'servings': 1.5},
        ],
        'total_calories': 150,
      });
      expect(t.id, 1);
      expect(t.name, 'Breakfast');
      expect(t.items.length, 1);
      expect(t.items[0].foodName, 'Oats');
    });

    test('handles empty items list', () {
      final t = MealTemplate.fromJson({'id': 2, 'name': 'Empty', 'items': []});
      expect(t.items, isEmpty);
    });

    test('throws on missing id', () {
      expect(
        () => MealTemplate.fromJson({'name': 'No ID'}),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
