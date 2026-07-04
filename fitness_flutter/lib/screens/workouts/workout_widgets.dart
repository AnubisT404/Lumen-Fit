import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../models/workout.dart';
import '../../utils/modal_utils.dart';
import '../../utils/weight_utils.dart';
import '../../widgets/app_card.dart';
import '../../widgets/picker_sheet.dart';
import 'workout_data.dart';

// ─── Composer Summary ────────────────────────────────────────────────

class ComposerSummary extends StatelessWidget {
  final int exercises;
  final int sets;
  final double volume;
  final String unit;
  const ComposerSummary({
    super.key,
    required this.exercises,
    required this.sets,
    required this.volume,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            workoutStrengthColor.withAlpha(12),
            workoutStrengthColor.withAlpha(6),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: workoutStrengthColor.withAlpha(15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _chip('$exercises', 'exercises'),
          Container(
            width: 1,
            height: 14,
            color: workoutStrengthColor.withAlpha(25),
          ),
          _chip('$sets', 'sets'),
          if (volume > 0) ...[
            Container(
              width: 1,
              height: 14,
              color: workoutStrengthColor.withAlpha(25),
            ),
            _chip('${volume.toStringAsFixed(0)}$unit', 'volume'),
          ],
        ],
      ),
    );
  }

  Widget _chip(String value, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: AppTextStyles.label.copyWith(
          color: workoutStrengthColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 3),
      Text(
        label,
        style: AppTextStyles.micro.copyWith(
          color: workoutStrengthColor.withAlpha(150),
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );
}

// ─── Exercise Form Card ──────────────────────────────────────────────

class ExerciseFormCard extends StatelessWidget {
  final ExerciseData exercise;
  final int index;
  final String unit;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const ExerciseFormCard({
    super.key,
    required this.exercise,
    required this.index,
    required this.unit,
    required this.onUpdate,
    required this.onRemove,
  });

  bool get _showWeight =>
      !['cardio', 'core'].contains(exercise.category.toLowerCase());
  Color get _catColor =>
      AppColors.categoryColors[exercise.category.toLowerCase()] ??
      AppColors.textMuted;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: _catColor.withAlpha(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with colored top strip
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: _catColor.withAlpha(10),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(44),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _catColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _catColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exercise.name, style: AppTextStyles.titleMedium),
                      if (exercise.category.isNotEmpty)
                        Text(
                          exercise.category,
                          style: AppTextStyles.micro.copyWith(
                            color: _catColor.withAlpha(180),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: AppGlassButton(
                    sfSymbol: SFSymbol('xmark', size: 11),
                    onPressed: onRemove,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Previous session
                if (exercise.previousSets != null &&
                    exercise.previousSets!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt.withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 12,
                          color: AppColors.iconMuted.withAlpha(130),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            exercise.previousSets!
                                .map(
                                  (s) {
                                    final rawKg = (s['weight_kg'] as num?)?.toDouble() ?? 0;
                                    final displayed = kgToDisplay(rawKg, unit) ?? 0;
                                    final wStr = displayed == displayed.truncateToDouble()
                                        ? displayed.toInt().toString()
                                        : displayed.toStringAsFixed(1);
                                    return '$wStr$unit × ${s['reps'] ?? 0}';
                                  },
                                )
                                .join('  ·  '),
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Set header
                if (exercise.sets.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            'SET',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        if (_showWeight)
                          Expanded(
                            child: Text(
                              'WEIGHT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: _showWeight ? 80 : 0,
                          child: _showWeight
                              ? Text(
                                  'REPS',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                )
                              : null,
                        ),
                        if (!_showWeight)
                          Expanded(
                            child: Text(
                              'REPS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 28),
                      ],
                    ),
                  ),
                ],

                // Set rows
                for (int i = 0; i < exercise.sets.length; i++)
                  SetRow(
                    set: exercise.sets[i],
                    showWeight: _showWeight,
                    unit: unit,
                    onUpdate: onUpdate,
                    onRemove: () {
                      exercise.sets.removeAt(i);
                      for (int j = 0; j < exercise.sets.length; j++) {
                        exercise.sets[j].setNumber = j + 1;
                      }
                      onUpdate();
                    },
                  ),

                // Add set
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: AppSize.buttonSmall,
                  child: AppGlassButton(
                    onPressed: () {
                      final last = exercise.sets.isNotEmpty
                          ? exercise.sets.last
                          : null;
                      exercise.sets.add(
                        SetData(
                          setNumber: exercise.sets.length + 1,
                          reps: last?.reps,
                          weightKg: last?.weightKg,
                        ),
                      );
                      onUpdate();
                    },
                    label: 'Add Set',
                    color: _catColor,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Set Row ─────────────────────────────────────────────────────────

class SetRow extends StatelessWidget {
  final SetData set;
  final bool showWeight;
  final String unit;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const SetRow({
    super.key,
    required this.set,
    required this.showWeight,
    required this.unit,
    required this.onUpdate,
    required this.onRemove,
  });

  String _fmtWeight(double? v) {
    if (v == null || v == 0) return '\u2013';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final hasWeight = set.weightKg != null && set.weightKg! > 0;
    final hasReps = set.reps != null && set.reps! > 0;
    final hasBoth = hasWeight && hasReps;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: workoutStrengthColor.withAlpha(hasBoth ? 18 : 8),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '${set.setNumber}',
                style: AppTextStyles.micro.copyWith(
                  fontWeight: FontWeight.w800,
                  color: workoutStrengthColor.withAlpha(hasBoth ? 220 : 140),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _openDualWheel(context),
              child: Container(
                height: AppSize.buttonMedium,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: hasBoth
                      ? workoutStrengthColor.withAlpha(7)
                      : AppColors.surfaceAlt.withAlpha(180),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasBoth
                        ? workoutStrengthColor.withAlpha(18)
                        : AppColors.textMuted.withAlpha(15),
                  ),
                ),
                child: Row(
                  children: [
                    if (showWeight) ...[
                      Text(
                        _fmtWeight(set.weightKg),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: hasWeight
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        ' $unit',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.textMuted.withAlpha(150),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '\u00D7',
                          style: AppTextStyles.label.copyWith(
                            color: workoutStrengthColor.withAlpha(100),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                    Text(
                      hasReps ? '${set.reps}' : '\u2013',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: hasReps
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      ' reps',
                      style: AppTextStyles.micro.copyWith(
                        color: AppColors.textMuted.withAlpha(150),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: workoutStrengthColor.withAlpha(80),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            height: 28,
            child: AppGlassButton(
              sfSymbol: SFSymbol('minus', size: 11),
              onPressed: onRemove,
              color: AppColors.danger,
              size: AdaptiveButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }

  void _openDualWheel(BuildContext context) {
    showWeightRepsPicker(
      context: context,
      setNumber: set.setNumber,
      unit: unit,
      currentWeight: set.weightKg,
      currentReps: set.reps,
      accentColor: workoutStrengthColor,
      showWeight: showWeight,
      onConfirm: (weight, reps) {
        set.weightKg = weight;
        set.reps = reps;
        onUpdate();
      },
    );
  }
}

// ─── Read-only Workout Card ──────────────────────────────────────────

class WorkoutHistoryCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onDelete;
  final Future<void> Function(int exerciseId)? onDeleteExercise;
  final void Function(WorkoutExercise ex, WorkoutSet set)? onEditSet;
  final void Function(WorkoutExercise ex, WorkoutSet set)? onDeleteSet;
  final String unit;
  const WorkoutHistoryCard({
    super.key,
    required this.workout,
    required this.onDelete,
    this.onDeleteExercise,
    this.onEditSet,
    this.onDeleteSet,
    this.unit = 'kg',
  });

  Workout get w => workout;
  bool get isStrength => w.workoutType == 'strength';
  Color get _accent => isStrength ? workoutStrengthColor : workoutCardioColor;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.textMuted;
    return AdaptiveContextMenu(
      actions: [
        AdaptiveContextMenuAction(
          title: 'Delete Workout',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onPressed: onDelete,
        ),
      ],
      child: AppCard(
        padding: EdgeInsets.zero,
        borderColor: _accent.withAlpha(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _accent.withAlpha(10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isStrength
                          ? Icons.fitness_center_rounded
                          : Icons.directions_run_rounded,
                      color: _accent.withAlpha(140),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.name ?? _workoutLabel(w.workoutType),
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isStrength && w.exercises.isNotEmpty)
                              Text(
                                '${w.exercises.length} exercises · ${w.exercises.fold(0, (s, e) => s + e.sets.length)} sets',
                                style: AppTextStyles.micro.copyWith(
                                  color: muted.withAlpha(160),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            if (w.durationMinutes != null) ...[
                              if (isStrength && w.exercises.isNotEmpty)
                                Text(
                                  '  ·  ',
                                  style: AppTextStyles.micro.copyWith(
                                    color: muted.withAlpha(100),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              Icon(
                                Icons.timer_outlined,
                                size: 11,
                                color: muted.withAlpha(140),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${w.durationMinutes}m',
                                style: AppTextStyles.micro.copyWith(
                                  color: muted.withAlpha(160),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            if (w.caloriesBurned != null) ...[
                              Text(
                                '  ·  ',
                                style: AppTextStyles.micro.copyWith(
                                  color: muted.withAlpha(100),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Icon(
                                Icons.local_fire_department_outlined,
                                size: 11,
                                color: AppColors.danger.withAlpha(120),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${w.caloriesBurned} cal',
                                style: AppTextStyles.micro.copyWith(
                                  color: muted.withAlpha(160),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('xmark', size: 11),
                      onPressed: onDelete,
                      size: AdaptiveButtonSize.small,
                    ),
                  ),
                ],
              ),
            ),

            // Exercises list
            if (isStrength && w.exercises.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14),
                height: 0.5,
                color: AppColors.surfaceAlt,
              ),
              const SizedBox(height: 4),
              for (int i = 0; i < w.exercises.length; i++) ...[
                _buildExRow(w.exercises[i], i + 1),
                if (i < w.exercises.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(height: 0.5, color: AppColors.surfaceAlt),
                  ),
              ],
              const SizedBox(height: 6),
            ],

            // Cardio details
            if (!isStrength && _hasCardioDetails) _buildCardioDetails(),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildExRow(WorkoutExercise ex, int index) {
    final canDelete = ex.id != null && onDeleteExercise != null;

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _accent.withAlpha(12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: AppTextStyles.micro.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _accent.withAlpha(160),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(ex.exerciseName, style: AppTextStyles.titleMedium),
              ),
            ],
          ),
          if (ex.sets.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 32),
              child: Column(
                children: ex.sets.map((s) {
                  final hasWeight = s.weightKg != null && s.weightKg! > 0;
                  final hasReps = s.reps != null && s.reps! > 0;
                  final vol = (hasWeight && hasReps)
                      ? (kgToDisplay(s.weightKg!, unit)! * s.reps!).round()
                      : null;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: GestureDetector(
                      onTap: onEditSet != null ? () => onEditSet!(ex, s) : null,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            child: Text(
                              '${s.setNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted.withAlpha(140),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: Text(
                              hasWeight
                                  ? '${_fmtNum(kgToDisplay(s.weightKg!, unit)!)}$unit'
                                  : '–',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hasWeight
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '×',
                            style: AppTextStyles.micro.copyWith(
                              color: AppColors.textMuted.withAlpha(120),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 32,
                            child: Text(
                              hasReps ? '${s.reps}' : '–',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: hasReps
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          if (vol != null) ...[
                            const Spacer(),
                            Text(
                              '$vol$unit vol',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted.withAlpha(120),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                          if (onDeleteSet != null) ...[
                            if (vol == null) const Spacer(),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => onDeleteSet!(ex, s),
                              child: Icon(
                                Icons.close_rounded,
                                size: 12,
                                color: AppColors.iconMuted.withAlpha(100),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );

    if (!canDelete) return content;

    return Dismissible(
      key: ValueKey(ex.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.dangerBg,
        child: Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color: AppColors.danger.withAlpha(180),
        ),
      ),
      confirmDismiss: (_) async {
        onDeleteExercise!(ex.id!);
        return false;
      },
      child: content,
    );
  }

  Widget _buildCardioDetails() {
    final muted = AppColors.textMuted;
    final chips = <String>[];
    if (w.distanceKm != null) chips.add('${w.distanceKm} km');
    if (w.avgHeartRate != null) chips.add('${w.avgHeartRate} bpm');
    if (w.intensity != null && w.intensity!.isNotEmpty) {
      chips.add(w.intensity![0].toUpperCase() + w.intensity!.substring(1));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: chips
            .map(
              (c) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  c,
                  style: AppTextStyles.micro.copyWith(
                    color: muted.withAlpha(200),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  bool get _hasCardioDetails =>
      w.distanceKm != null || w.avgHeartRate != null || w.intensity != null;
  String _workoutLabel(String type) {
    switch (type) {
      case 'strength':
        return 'Strength Training';
      case 'cardio':
        return 'Cardio';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

// ─── Cardio Widgets ──────────────────────────────────────────────────

class CardioTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final TextInputType keyboardType;
  const CardioTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveTextField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.titleMedium,
      placeholder: label,
      suffix: Text(
        suffix,
        style: AppTextStyles.micro.copyWith(
          color: AppColors.textMuted.withAlpha(140),
          fontWeight: FontWeight.w400,
        ),
      ),
      cupertinoDecoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class CardioTypeSelector extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const CardioTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });
  @override
  State<CardioTypeSelector> createState() => _CardioTypeSelectorState();
}

class _CardioTypeSelectorState extends State<CardioTypeSelector> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: Text(widget.value, style: AppTextStyles.body)),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.iconMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_open)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: cardioTypes
                  .map(
                    (t) => GestureDetector(
                      onTap: () {
                        widget.onChanged(t);
                        setState(() => _open = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        color: t == widget.value
                            ? workoutCardioColor.withAlpha(20)
                            : null,
                        child: Text(
                          t,
                          style: AppTextStyles.body.copyWith(
                            color: t == widget.value
                                ? workoutCardioColor
                                : AppColors.textSecondary,
                            fontWeight: t == widget.value
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class PaceRow extends StatelessWidget {
  final double durationMin;
  final double distanceKm;
  const PaceRow({
    super.key,
    required this.durationMin,
    required this.distanceKm,
  });
  @override
  Widget build(BuildContext context) {
    if (distanceKm <= 0 || durationMin <= 0) return const SizedBox.shrink();
    final minPerKm = durationMin / distanceKm;
    final kmh = distanceKm / (durationMin / 60);
    String fmt(double v) =>
        '${v.floor()}:${((v % 1) * 60).round().toString().padLeft(2, '0')}';
    return Row(
      children: [
        Text(
          '${fmt(minPerKm)} /km',
          style: AppTextStyles.small.copyWith(
            color: workoutCardioColor.withAlpha(200),
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          '  ·  ',
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400),
        ),
        Text(
          '${kmh.toStringAsFixed(1)} km/h',
          style: AppTextStyles.small.copyWith(
            color: workoutCardioColor.withAlpha(200),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Plan Banner ─────────────────────────────────────────────────────

class PlanBanner extends StatelessWidget {
  final Map<String, dynamic>? plan;
  final VoidCallback? onReturn;
  final bool _isRestDay;
  final String? _restDayPlanName;

  const PlanBanner({
    super.key,
    required Map<String, dynamic> this.plan,
    this.onReturn,
  }) : _isRestDay = false,
       _restDayPlanName = null;

  const PlanBanner.restDay({super.key, required String planName})
    : plan = null,
      onReturn = null,
      _isRestDay = true,
      _restDayPlanName = planName;

  @override
  Widget build(BuildContext context) {
    if (_isRestDay) return _buildRestDay(context);
    return _buildWorkoutDay(context);
  }

  Widget _buildRestDay(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.self_improvement_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REST DAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _restDayPlanName ?? 'Workout Plan',
                  style: AppTextStyles.titleMedium,
                ),
                Text(
                  'Recovery & rest scheduled',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutDay(BuildContext context) {
    final name =
        plan!['routine_name'] as String? ??
        plan!['plan_name'] as String? ??
        'Workout Plan';
    final exerciseCount = (plan!['exercises'] as List?)?.length ?? 0;
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: workoutPlanColor.withAlpha(25),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: workoutPlanColor.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.event_note_rounded,
              color: workoutPlanColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: workoutPlanColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SCHEDULED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: workoutPlanColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(name, style: AppTextStyles.titleMedium),
                Text(
                  '$exerciseCount exercises',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 72,
            height: AppSize.buttonSmall,
            child: AppGlassButton(
              onPressed: () {
                final routineId = plan!['routine_id']?.toString();
                final query = routineId != null ? '?type=strength&plan=$routineId' : '?type=strength';
                context.push('/new-workout$query').then(
                  (_) {
                    onReturn?.call();
                  },
                );
              },
              label: 'Start',
              color: workoutPlanColor,
              size: AdaptiveButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shimmer Loading ─────────────────────────────────────────────────

class WorkoutShimmer extends StatelessWidget {
  const WorkoutShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.border,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            3,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
