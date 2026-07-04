class MealEntry {
  final int id;
  final int? mealId;
  final int? foodId;
  final String foodName;
  final String mealType;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSize;
  final String? servingUnit;
  final double servings;
  final double? baseCalories;
  final double? baseProtein;
  final double? baseCarbs;
  final double? baseFat;
  final String createdAt;

  const MealEntry({
    required this.id,
    this.mealId,
    this.foodId,
    required this.foodName,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    this.servingUnit,
    required this.servings,
    this.baseCalories,
    this.baseProtein,
    this.baseCarbs,
    this.baseFat,
    required this.createdAt,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) => MealEntry(
    id: (json['id'] as num).toInt(),
    mealId: (json['meal_id'] as num?)?.toInt(),
    foodId: (json['food_id'] as num?)?.toInt(),
    foodName: json['food_name'] as String? ?? 'Unknown',
    mealType: json['meal_type'] as String? ?? 'snack',
    calories: (json['calories'] as num?)?.toDouble() ?? 0,
    protein: (json['protein'] as num?)?.toDouble() ?? 0,
    carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
    fat: (json['fat'] as num?)?.toDouble() ?? 0,
    servingSize: (json['serving_size'] as num?)?.toDouble() ?? 1,
    servingUnit: json['serving_unit'] as String?,
    servings: (json['servings'] as num?)?.toDouble() ?? 1,
    baseCalories: (json['base_calories'] as num?)?.toDouble(),
    baseProtein: (json['base_protein'] as num?)?.toDouble(),
    baseCarbs: (json['base_carbs'] as num?)?.toDouble(),
    baseFat: (json['base_fat'] as num?)?.toDouble(),
    createdAt: json['created_at'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'meal_id': mealId,
    'food_id': foodId,
    'food_name': foodName,
    'meal_type': mealType,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'serving_size': servingSize,
    'serving_unit': servingUnit,
    'servings': servings,
    'base_calories': baseCalories,
    'base_protein': baseProtein,
    'base_carbs': baseCarbs,
    'base_fat': baseFat,
    'created_at': createdAt,
  };
}
