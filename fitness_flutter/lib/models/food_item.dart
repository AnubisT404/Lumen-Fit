class Portion {
  final String description;
  final double gramWeight;
  final double amount;

  const Portion({
    required this.description,
    required this.gramWeight,
    required this.amount,
  });

  factory Portion.fromJson(Map<String, dynamic> json) => Portion(
    description: json['description'] as String? ?? '',
    gramWeight: (json['gram_weight'] as num?)?.toDouble() ?? 0,
    amount: (json['amount'] as num?)?.toDouble() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'description': description,
    'gram_weight': gramWeight,
    'amount': amount,
  };
}

class FoodItem {
  final String? id;
  final String? name;
  final String? productName;
  final String? brand;
  final String? brands;
  final String? barcode;
  final int? fdcId;
  final String? mfpId;
  final double? servingSize;
  final String? servingUnit;
  final String? servingDescription;
  final List<Portion>? portions;
  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatsG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;
  final double? saturatedFatG;
  final double? monounsaturatedFatG;
  final double? polyunsaturatedFatG;
  final double? transFatG;
  final double? cholesterolMg;
  final double? potassiumMg;
  final double? calciumMg;
  final double? ironMg;
  final double? vitaminAMcg;
  final double? vitaminCMg;
  final double? vitaminDMcg;
  final String? source;
  final String? sourceQuality;
  final double? trustScore;
  final String? category;

  const FoodItem({
    this.id,
    this.name,
    this.productName,
    this.brand,
    this.brands,
    this.barcode,
    this.fdcId,
    this.mfpId,
    this.servingSize,
    this.servingUnit,
    this.servingDescription,
    this.portions,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatsG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.saturatedFatG,
    this.monounsaturatedFatG,
    this.polyunsaturatedFatG,
    this.transFatG,
    this.cholesterolMg,
    this.potassiumMg,
    this.calciumMg,
    this.ironMg,
    this.vitaminAMcg,
    this.vitaminCMg,
    this.vitaminDMcg,
    this.source,
    this.sourceQuality,
    this.trustScore,
    this.category,
  });

  String get displayName => name ?? productName ?? 'Unknown';
  String get displayBrand => brand ?? brands ?? '';

  factory FoodItem.fromJson(Map<String, dynamic> json) => FoodItem(
    id: json['id']?.toString(),
    name: json['name'] as String?,
    productName: json['product_name'] as String?,
    brand: json['brand'] as String?,
    brands: json['brands'] as String?,
    barcode: json['barcode'] as String?,
    fdcId: json['fdc_id'] as int?,
    mfpId: json['mfp_id'] as String?,
    servingSize: (json['serving_size'] as num?)?.toDouble(),
    servingUnit: json['serving_unit'] as String?,
    servingDescription: json['serving_description'] as String?,
    portions: (json['portions'] as List?)?.map((p) => Portion.fromJson(p as Map<String, dynamic>)).toList(),
    calories: (json['calories'] as num?)?.toDouble(),
    proteinG: (json['protein_g'] as num?)?.toDouble(),
    carbsG: (json['carbs_g'] as num?)?.toDouble(),
    fatsG: (json['fats_g'] as num?)?.toDouble(),
    fiberG: (json['fiber_g'] as num?)?.toDouble(),
    sugarG: (json['sugar_g'] as num?)?.toDouble(),
    sodiumMg: (json['sodium_mg'] as num?)?.toDouble(),
    saturatedFatG: (json['saturated_fat_g'] as num?)?.toDouble(),
    monounsaturatedFatG: (json['monounsaturated_fat_g'] as num?)?.toDouble(),
    polyunsaturatedFatG: (json['polyunsaturated_fat_g'] as num?)?.toDouble(),
    transFatG: (json['trans_fat_g'] as num?)?.toDouble(),
    cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble(),
    potassiumMg: (json['potassium_mg'] as num?)?.toDouble(),
    calciumMg: (json['calcium_mg'] as num?)?.toDouble(),
    ironMg: (json['iron_mg'] as num?)?.toDouble(),
    vitaminAMcg: (json['vitamin_a_mcg'] as num?)?.toDouble(),
    vitaminCMg: (json['vitamin_c_mg'] as num?)?.toDouble(),
    vitaminDMcg: (json['vitamin_d_mcg'] as num?)?.toDouble(),
    source: json['source'] as String?,
    sourceQuality: json['source_quality'] as String?,
    trustScore: (json['trust_score'] as num?)?.toDouble(),
    category: json['category'] as String?,
  );

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    if (name != null) 'name': name,
    if (productName != null) 'product_name': productName,
    if (brand != null) 'brand': brand,
    if (brands != null) 'brands': brands,
    if (barcode != null) 'barcode': barcode,
    if (fdcId != null) 'fdc_id': fdcId,
    if (mfpId != null) 'mfp_id': mfpId,
    if (servingSize != null) 'serving_size': servingSize,
    if (servingUnit != null) 'serving_unit': servingUnit,
    if (servingDescription != null) 'serving_description': servingDescription,
    if (portions != null) 'portions': portions!.map((p) => p.toJson()).toList(),
    if (calories != null) 'calories': calories,
    if (proteinG != null) 'protein_g': proteinG,
    if (carbsG != null) 'carbs_g': carbsG,
    if (fatsG != null) 'fats_g': fatsG,
    if (fiberG != null) 'fiber_g': fiberG,
    if (sugarG != null) 'sugar_g': sugarG,
    if (sodiumMg != null) 'sodium_mg': sodiumMg,
    if (saturatedFatG != null) 'saturated_fat_g': saturatedFatG,
    if (source != null) 'source': source,
    if (category != null) 'category': category,
  };
}
