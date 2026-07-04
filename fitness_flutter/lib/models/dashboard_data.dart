class NutritionValues {
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;

  const NutritionValues({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
  });

  factory NutritionValues.fromJson(Map<String, dynamic> json) => NutritionValues(
    calories: (json['calories'] as num?)?.toDouble() ?? 0,
    proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
    carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
    fatsG: (json['fats_g'] as num?)?.toDouble() ?? 0,
  );
}

class NutritionData {
  final NutritionValues consumed;
  final NutritionValues goals;
  final NutritionValues remaining;
  final NutritionValues percentage;

  const NutritionData({
    required this.consumed,
    required this.goals,
    required this.remaining,
    required this.percentage,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) => NutritionData(
    consumed: NutritionValues.fromJson(
      (json['consumed'] as Map<String, dynamic>?) ?? const {},
    ),
    goals: NutritionValues.fromJson(
      (json['goals'] as Map<String, dynamic>?) ?? const {},
    ),
    remaining: NutritionValues.fromJson(
      (json['remaining'] as Map<String, dynamic>?) ?? const {},
    ),
    percentage: NutritionValues.fromJson(
      (json['percentage'] as Map<String, dynamic>?) ?? const {},
    ),
  );
}

class WaterData {
  final int consumedMl;
  final int goalMl;
  final double percentage;
  final int remainingMl;

  const WaterData({
    required this.consumedMl,
    required this.goalMl,
    required this.percentage,
    required this.remainingMl,
  });

  factory WaterData.fromJson(Map<String, dynamic> json) => WaterData(
    consumedMl: (json['consumed_ml'] as num?)?.toInt() ?? 0,
    goalMl: (json['goal_ml'] as num?)?.toInt() ?? 2000,
    percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    remainingMl: (json['remaining_ml'] as num?)?.toInt() ?? 2000,
  );
}

class ExerciseData {
  final int totalWorkouts;
  final int totalMinutes;
  final int caloriesBurned;

  const ExerciseData({
    required this.totalWorkouts,
    required this.totalMinutes,
    required this.caloriesBurned,
  });

  factory ExerciseData.fromJson(Map<String, dynamic> json) => ExerciseData(
    totalWorkouts: (json['total_workouts'] as num?)?.toInt() ?? 0,
    totalMinutes: (json['total_minutes'] as num?)?.toInt() ?? 0,
    caloriesBurned: (json['calories_burned'] as num?)?.toInt() ?? 0,
  );
}

class WeightData {
  final double? currentKg;
  final String? lastMeasured;

  const WeightData({this.currentKg, this.lastMeasured});

  factory WeightData.fromJson(Map<String, dynamic> json) => WeightData(
    currentKg: (json['current_kg'] as num?)?.toDouble(),
    lastMeasured: json['last_measured'] as String?,
  );
}

class WeekDay {
  final String day;
  final String date;
  final bool logged;
  final bool future;

  const WeekDay({
    required this.day,
    required this.date,
    required this.logged,
    required this.future,
  });

  factory WeekDay.fromJson(Map<String, dynamic> json) => WeekDay(
    day: json['day'] as String? ?? '',
    date: json['date'] as String? ?? '',
    logged: json['logged'] as bool? ?? false,
    future: json['future'] as bool? ?? false,
  );
}

class DashboardData {
  final String date;
  final NutritionData nutrition;
  final WaterData water;
  final ExerciseData exercise;
  final WeightData weight;
  final int mealsLogged;
  final List<WeekDay> weekStreak;

  const DashboardData({
    required this.date,
    required this.nutrition,
    required this.water,
    required this.exercise,
    required this.weight,
    required this.mealsLogged,
    required this.weekStreak,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    date: json['date'] as String? ?? '',
    nutrition: NutritionData.fromJson(
      (json['nutrition'] as Map<String, dynamic>?) ?? const {},
    ),
    water: WaterData.fromJson(
      (json['water'] as Map<String, dynamic>?) ?? const {},
    ),
    exercise: ExerciseData.fromJson(
      (json['exercise'] as Map<String, dynamic>?) ?? const {},
    ),
    weight: WeightData.fromJson(
      (json['weight'] as Map<String, dynamic>?) ?? const {},
    ),
    mealsLogged: (json['meals_logged'] as num?)?.toInt() ?? 0,
    weekStreak: (json['week_streak'] as List?)
        ?.map((d) => WeekDay.fromJson(d as Map<String, dynamic>))
        .toList() ?? [],
  );
}
