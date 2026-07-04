// Data models and utility functions for the Add Food screen.
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/food_item.dart';

// ─── Serving Option model ────────────────────────────────────────────

class ServingOption {
  final String label;
  final String shortLabel;
  final double gramWeight;
  const ServingOption({
    required this.label,
    required this.shortLabel,
    required this.gramWeight,
  });
}

// ─── Building Item for template builder ──────────────────────────────

class BuildingItem {
  final FoodItem food;
  final double servings;
  final double servingSize;
  final String servingUnit;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatsG;
  const BuildingItem({
    required this.food,
    required this.servings,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatsG,
  });
}

// ─── Serving Options Utility ─────────────────────────────────────────

/// Generates serving options from a FoodItem's metadata and portions.
/// Ported from the React getServingOptions implementation.
List<ServingOption> getServingOptions(FoodItem food) {
  final options = <ServingOption>[];
  final servingG = food.servingSize ?? 100;
  final hasPortions = food.portions != null && food.portions!.isNotEmpty;

  bool isNonDescriptive(String s) {
    if (s.isEmpty) return true;
    final t = s.trim();
    if (RegExp(r'^(g|GRM|grm|ml|MLT|serving)$', caseSensitive: false)
        .hasMatch(t)) return true;
    if (RegExp(r'^\d+(\.\d+)?\s*(g|ml|grams?)?$', caseSensitive: false)
        .hasMatch(t)) return true;
    return false;
  }

  String stripNums(String s) =>
      s.replaceAll(RegExp(r'^(\d{2,}(\.\d+)?\s+)+'), '').trim();
  String cleanUnit(String s) => s
      .replaceAll(RegExp(r'\bONZ\b', caseSensitive: false), 'oz')
      .replaceAll(RegExp(r'\bGRM\b', caseSensitive: false), 'g')
      .replaceAll('(s)', '')
      .replaceAll(
        RegExp(r'\s*\(\d+\.?\d*\s*g\)\s*$', caseSensitive: false),
        '',
      )
      .trim();

  final rawUnit = food.servingUnit ?? '';
  final rawDesc = food.servingDescription ?? '';
  final cleanedUnit = cleanUnit(stripNums(rawUnit));
  final cleanedDesc = cleanUnit(stripNums(rawDesc));

  var servingLabel = '';
  var embeddedGrams = 0.0;
  if (!isNonDescriptive(cleanedUnit)) {
    final gm = RegExp(r'\((\d+\.?\d*)\s*g\)', caseSensitive: false)
        .firstMatch(rawUnit);
    if (gm != null) embeddedGrams = double.tryParse(gm.group(1)!) ?? 0;
    servingLabel = cleanedUnit;
  } else if (!isNonDescriptive(cleanedDesc)) {
    final gm = RegExp(r'\((\d+\.?\d*)\s*g\)', caseSensitive: false)
        .firstMatch(rawDesc);
    if (gm != null) embeddedGrams = double.tryParse(gm.group(1)!) ?? 0;
    servingLabel = cleanedDesc;
  }
  final primaryGrams = embeddedGrams > 0 ? embeddedGrams : servingG;

  // Validate against known unit ranges
  const unitRanges = <String, List<double>>{
    'lb': [400, 500],
    'pound': [400, 500],
    'oz': [20, 36],
    'ounce': [20, 36],
    'cup': [80, 350],
    'tbsp': [8, 22],
    'tablespoon': [8, 22],
    'tsp': [2, 8],
    'teaspoon': [2, 8],
  };
  final bareUnit =
      servingLabel.replaceAll(RegExp(r'^\d+\s*'), '').toLowerCase();
  final range = unitRanges[bareUnit];
  if (range != null && (primaryGrams < range[0] || primaryGrams > range[1])) {
    servingLabel = '';
  }

  if (servingLabel.isEmpty && hasPortions) {
    final match = food.portions!
        .where((p) => (p.gramWeight - servingG).abs() < 2 && p.gramWeight > 0)
        .toList();
    if (match.isNotEmpty) servingLabel = match.first.description;
  }

  if (servingLabel.isNotEmpty) {
    options.add(ServingOption(
      label: '$servingLabel (${primaryGrams.round()}g)',
      shortLabel: servingLabel,
      gramWeight: primaryGrams,
    ));
  } else if (servingG != 100 || !hasPortions) {
    options.add(ServingOption(
      label: '1 serving (${servingG.round()}g)',
      shortLabel: '1 serving',
      gramWeight: servingG,
    ));
  }

  final seenLabels = <String>{...options.map((o) => o.shortLabel.toLowerCase())};
  final seenWeights = <int>{...options.map((o) => o.gramWeight.round())};

  final unitGrams = <MapEntry<RegExp, double>>[
    MapEntry(RegExp(r'\boz\b|\bounces?\b', caseSensitive: false), 28.35),
    MapEntry(RegExp(r'\blb\b|\bpounds?\b', caseSensitive: false), 453.6),
    MapEntry(RegExp(r'\bkg\b|\bkilograms?\b', caseSensitive: false), 1000),
    MapEntry(RegExp(r'\bcups?\b', caseSensitive: false), 240),
    MapEntry(RegExp(r'\btbsp\b|\btablespoons?\b', caseSensitive: false), 15),
    MapEntry(RegExp(r'\btsp\b|\bteaspoons?\b', caseSensitive: false), 5),
  ];

  if (hasPortions) {
    for (final p in food.portions!) {
      var gw = p.gramWeight;
      final pLabel = p.description.toLowerCase().replaceAll('(s)', '').trim();

      if (RegExp(
        r'^(1\s+)?(gram\(?s?\)?|g|milligram|mg|millili[t]?[er]+|ml)$',
        caseSensitive: false,
      ).hasMatch(pLabel)) continue;
      if (RegExp(
        r'^\d+\s*(gram|g|milligram|mg|millili[t]?[er]+|ml)s?$',
        caseSensitive: false,
      ).hasMatch(pLabel)) continue;

      final embeddedMatch = RegExp(r'\((\d+\.?\d*)\s*g\)', caseSensitive: false)
          .firstMatch(p.description);
      if (embeddedMatch != null) {
        final embeddedG = double.tryParse(embeddedMatch.group(1)!) ?? 0;
        if (embeddedG > 1 &&
            (gw < 2 || (gw - embeddedG).abs() > embeddedG * 0.5)) {
          gw = embeddedG;
        }
      }

      final qty = double.tryParse(pLabel.split(RegExp(r'\s+')).first) ?? 1;
      var unitFail = false;
      for (final entry in unitGrams) {
        final expected = qty * entry.value;
        if (entry.key.hasMatch(pLabel) &&
            (gw < expected * 0.4 || gw > expected * 2)) {
          unitFail = true;
          break;
        }
      }
      if (unitFail) continue;
      if (gw < 20) continue;

      final roundedW = gw.round();
      if (roundedW <= 0 || seenWeights.contains(roundedW)) continue;
      seenWeights.add(roundedW);
      final cleanedP = p.description.replaceAll('(s)', '').trim();
      seenLabels.add(cleanedP.toLowerCase());
      final hasGramAnnotation = RegExp(
        r'\(\d+\.?\d*\s*g(ram)?s?\)',
        caseSensitive: false,
      ).hasMatch(cleanedP);
      final label =
          hasGramAnnotation ? cleanedP : '$cleanedP (${roundedW}g)';
      options.add(
        ServingOption(label: label, shortLabel: cleanedP, gramWeight: gw),
      );
    }
  }

  if (!seenWeights.contains(1)) {
    options.add(const ServingOption(
      label: '1 gram (g)',
      shortLabel: 'g',
      gramWeight: 1,
    ));
  }

  final hasOz = seenLabels.any(
    (l) => l.contains('oz') || l.contains('ounce'),
  );
  if (!hasOz) {
    options.add(const ServingOption(
      label: '1 ounce (28g)',
      shortLabel: 'oz',
      gramWeight: 28.35,
    ));
  }

  return options;
}

// ─── Nutrition Calculation ────────────────────────────────────────────

/// Calculates nutrition values for the given food at the selected serving.
Map<String, double> calcNutrition(
  FoodItem food,
  List<ServingOption> options,
  int selectedServingIdx,
  double servingAmount,
) {
  final safeIdx =
      options.isNotEmpty ? selectedServingIdx.clamp(0, options.length - 1) : 0;
  final selected = options.isNotEmpty ? options[safeIdx] : null;
  if (selected == null) {
    return {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'totalGrams': 0};
  }
  final totalGrams = selected.gramWeight * servingAmount;
  final base = (food.source == 'MFP' || food.source == 'local')
      ? (food.servingSize ?? 100)
      : 100.0;
  final multiplier = totalGrams / base;
  return {
    'calories': ((food.calories ?? 0) * multiplier).roundToDouble(),
    'protein': ((food.proteinG ?? 0) * multiplier).roundToDouble(),
    'carbs': ((food.carbsG ?? 0) * multiplier).roundToDouble(),
    'fat': ((food.fatsG ?? 0) * multiplier).roundToDouble(),
    'totalGrams': totalGrams,
  };
}

// ─── Source Badge ────────────────────────────────────────────────────

/// Returns a colored badge widget for the food source, or null.
Widget? sourceBadge(FoodItem food) {
  final src = food.source ?? '';
  final isVerified = food.sourceQuality == 'verified';
  Color? badgeColor;
  Color? badgeTextColor;
  String? badgeLabel;

  if (src.startsWith('USDA')) {
    badgeColor = AppColors.successBg;
    badgeTextColor = AppColors.successDark;
    badgeLabel = 'USDA';
  } else if (src == 'MFP' && isVerified) {
    badgeColor = AppColors.primaryUltraLight;
    badgeTextColor = AppColors.blue;
    badgeLabel = '✓ MFP';
  } else if (src == 'MFP') {
    badgeColor = AppColors.surfaceAlt;
    badgeTextColor = AppColors.textSecondary;
    badgeLabel = 'MFP';
  } else if (src == 'OFF' || src == 'OpenFoodFacts') {
    badgeColor = AppColors.warningBg;
    badgeTextColor = AppColors.warningDark;
    badgeLabel = 'OFF';
  }

  if (badgeLabel == null) return null;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: badgeColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      badgeLabel,
      style: AppTextStyles.micro.copyWith(color: badgeTextColor),
    ),
  );
}

// ─── Formatting Helpers ──────────────────────────────────────────────

/// Rounds any decimal numbers in the label to max 1 decimal place.
String fmtServingLabel(String label) {
  return label.replaceAllMapped(RegExp(r'(\d+\.\d{2,})'), (m) {
    final v = double.tryParse(m.group(0)!);
    if (v == null) return m.group(0)!;
    return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
  });
}

const mealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snacks',
};
