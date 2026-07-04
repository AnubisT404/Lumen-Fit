class WorkoutSet {
  final int? id;
  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceKm;
  final String? notes;

  const WorkoutSet({
    this.id,
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceKm,
    this.notes,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    id: (json['id'] as num?)?.toInt(),
    setNumber: (json['set_number'] as num?)?.toInt() ?? 1,
    reps: (json['reps'] as num?)?.toInt(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'set_number': setNumber,
    if (reps != null) 'reps': reps,
    if (weightKg != null) 'weight_kg': weightKg,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    if (distanceKm != null) 'distance_km': distanceKm,
    if (notes != null) 'notes': notes,
  };
}

class WorkoutExercise {
  final int? id;
  final String exerciseName;
  final String? exerciseCategory;
  final List<WorkoutSet> sets;

  const WorkoutExercise({
    this.id,
    required this.exerciseName,
    this.exerciseCategory,
    required this.sets,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) => WorkoutExercise(
    id: (json['id'] as num?)?.toInt(),
    exerciseName: json['exercise_name'] as String? ?? '',
    exerciseCategory: json['exercise_category'] as String?,
    sets: (json['sets'] as List?)
        ?.map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>))
        .toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'exercise_name': exerciseName,
    if (exerciseCategory != null) 'exercise_category': exerciseCategory,
    'sets': sets.map((s) => s.toJson()).toList(),
  };
}

class Workout {
  final int? id;
  final String workoutType;
  final String? name;
  final int? durationMinutes;
  final int? caloriesBurned;
  final String? notes;
  final String? createdAt;
  final List<WorkoutExercise> exercises;
  // Cardio fields
  final String? exerciseType;
  final double? distanceKm;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final double? elevationM;
  final String? intensity;

  const Workout({
    this.id,
    required this.workoutType,
    this.name,
    this.durationMinutes,
    this.caloriesBurned,
    this.notes,
    this.createdAt,
    this.exercises = const [],
    this.exerciseType,
    this.distanceKm,
    this.avgHeartRate,
    this.maxHeartRate,
    this.elevationM,
    this.intensity,
  });

  factory Workout.fromJson(Map<String, dynamic> json) => Workout(
    id: (json['id'] as num?)?.toInt(),
    workoutType: json['workout_type'] as String? ?? 'strength',
    name: json['name'] as String?,
    durationMinutes: (json['duration_minutes'] as num?)?.toInt(),
    caloriesBurned: (json['calories_burned'] as num?)?.toInt(),
    notes: json['notes'] as String?,
    createdAt: json['created_at'] as String?,
    exercises: (json['exercises'] as List?)
        ?.map((e) => WorkoutExercise.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
    exerciseType: json['exercise_type'] as String?,
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    avgHeartRate: (json['avg_heart_rate'] as num?)?.toInt(),
    maxHeartRate: (json['max_heart_rate'] as num?)?.toInt(),
    elevationM: (json['elevation_m'] as num?)?.toDouble(),
    intensity: json['intensity'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'workout_type': workoutType,
    if (name != null) 'name': name,
    if (durationMinutes != null) 'duration_minutes': durationMinutes,
    if (caloriesBurned != null) 'calories_burned': caloriesBurned,
    if (notes != null) 'notes': notes,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };
}
