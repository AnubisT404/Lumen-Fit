class Profile {
  final String? name;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final String? goal;
  final double? targetWeightKg;
  final bool isSetup;

  const Profile({
    this.name,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.goal,
    this.targetWeightKg,
    this.isSetup = false,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    name: json['name'] as String?,
    age: (json['age'] as num?)?.toInt(),
    sex: json['sex'] as String?,
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    activityLevel: json['activity_level'] as String?,
    goal: json['goal'] as String?,
    targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
    isSetup: json['is_setup'] as bool? ?? (json['name'] != null),
  );
}

class Goals {
  final int dailyCalories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  final int waterMl;

  const Goals({
    this.dailyCalories = 2000,
    this.proteinG = 150,
    this.carbsG = 200,
    this.fatsG = 65,
    this.waterMl = 2000,
  });

  factory Goals.fromJson(Map<String, dynamic> json) => Goals(
    dailyCalories: (json['daily_calories'] as num?)?.toInt() ?? 2000,
    proteinG: (json['protein_g'] as num?)?.toInt() ?? 150,
    carbsG: (json['carbs_g'] as num?)?.toInt() ?? 200,
    fatsG: (json['fats_g'] as num?)?.toInt() ?? 65,
    waterMl: (json['water_ml'] as num?)?.toInt() ?? 2000,
  );
}

class MealTemplate {
  final int id;
  final String name;
  final List<TemplateItem> items;
  final double totalCalories;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatsG;
  final int itemCount;

  const MealTemplate({
    required this.id,
    required this.name,
    required this.items,
    required this.totalCalories,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatsG,
    required this.itemCount,
  });

  factory MealTemplate.fromJson(Map<String, dynamic> json) => MealTemplate(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    items: (json['items'] as List?)
        ?.map((i) => TemplateItem.fromJson(i as Map<String, dynamic>))
        .toList() ?? [],
    totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0,
    totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0,
    totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0,
    totalFatsG: (json['total_fats_g'] as num?)?.toDouble() ?? 0,
    itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
  );
}

class TemplateItem {
  final int id;
  final int foodId;
  final String foodName;
  final String? brand;
  final double servings;
  final double? servingSize;
  final String? servingUnit;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatsG;

  const TemplateItem({
    required this.id,
    required this.foodId,
    required this.foodName,
    this.brand,
    required this.servings,
    this.servingSize,
    this.servingUnit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
  });

  factory TemplateItem.fromJson(Map<String, dynamic> json) => TemplateItem(
    id: (json['id'] as num).toInt(),
    foodId: (json['food_id'] as num).toInt(),
    foodName: json['food_name'] as String? ?? '',
    brand: json['brand'] as String?,
    servings: (json['servings'] as num?)?.toDouble() ?? 1,
    servingSize: (json['serving_size'] as num?)?.toDouble(),
    servingUnit: json['serving_unit'] as String?,
    calories: (json['calories'] as num?)?.toDouble() ?? 0,
    proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
    carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
    fatsG: (json['fats_g'] as num?)?.toDouble() ?? 0,
  );
}
