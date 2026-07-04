import 'package:flutter/material.dart';

/// Mutable set data used during workout composition.
class SetData {
  int setNumber;
  double? weightKg;
  int? reps;
  SetData({required this.setNumber, this.weightKg, this.reps});
}

/// Mutable exercise data used during workout composition.
class ExerciseData {
  String name;
  String category;
  List<SetData> sets;
  List<Map<String, dynamic>>? previousSets;
  ExerciseData({
    required this.name,
    required this.category,
    required this.sets,
    this.previousSets,
  });
}

/// Design tokens shared across workout widgets.
const workoutStrengthColor = Color(0xFFF97316); // AppColors.orange
const workoutCardioColor = Color(0xFF06B6D4);   // AppColors.catLegs
const workoutPlanColor = Color(0xFF6366F1);     // AppColors.primary

const cardioTypes = [
  'Running', 'Cycling', 'Swimming', 'Rowing', 'Elliptical',
  'Walking', 'HIIT', 'Jump Rope', 'Stair Climber', 'Sprints',
];
