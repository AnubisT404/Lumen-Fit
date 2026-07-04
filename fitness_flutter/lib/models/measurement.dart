class Measurement {
  final int? id;
  final double weightKg;
  final double? bodyFatPercentage;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final String? notes;
  final String? createdAt;

  const Measurement({
    this.id,
    required this.weightKg,
    this.bodyFatPercentage,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.notes,
    this.createdAt,
  });

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
    id: (json['id'] as num?)?.toInt(),
    weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
    bodyFatPercentage: (json['body_fat_percentage'] as num?)?.toDouble(),
    chestCm: (json['chest_cm'] as num?)?.toDouble(),
    waistCm: (json['waist_cm'] as num?)?.toDouble(),
    hipsCm: (json['hips_cm'] as num?)?.toDouble(),
    notes: json['notes'] as String?,
    createdAt: json['created_at'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'weight_kg': weightKg,
    if (bodyFatPercentage != null) 'body_fat_percentage': bodyFatPercentage,
    if (chestCm != null) 'chest_cm': chestCm,
    if (waistCm != null) 'waist_cm': waistCm,
    if (hipsCm != null) 'hips_cm': hipsCm,
    if (notes != null) 'notes': notes,
  };
}
