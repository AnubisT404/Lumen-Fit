// Strength form widgets: ExerciseCard, SetRow, AlternativesDropdown, SummaryChip.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../utils/modal_utils.dart';
import '../../widgets/app_card.dart';
import '../../widgets/picker_sheet.dart';
import 'workout_form_models.dart';

const _orange = AppColors.orange;

// ─── Summary Chip ────────────────────────────────────────────────────

class SummaryChip extends StatelessWidget {
  final String text;
  const SummaryChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(color: _orange.withAlpha(200)),
    );
  }
}

// ─── Exercise Card ───────────────────────────────────────────────────

class ExerciseCard extends StatelessWidget {
  final ExerciseData exercise;
  final String unit;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.unit,
    required this.onUpdate,
    required this.onRemove,
  });

  bool get _showWeight =>
      !['cardio', 'core'].contains(exercise.category.toLowerCase());

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (exercise.alternatives != null &&
                        exercise.alternatives!.isNotEmpty)
                      AlternativesDropdown(
                        exercise: exercise,
                        onUpdate: onUpdate,
                      )
                    else
                      Text(
                        exercise.name,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (exercise.category.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          exercise.category,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Previous session
          if (exercise.previousSets != null &&
              exercise.previousSets!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LAST SESSION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise.previousSets!
                        .map((s) =>
                            '${s['weight_kg'] ?? 0}$unit × ${s['reps'] ?? 0}')
                        .join(', '),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Set header
          if (exercise.sets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 34,
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
                          style: AppTextStyles.micro,
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
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 4),
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
                if (exercise.sets.isEmpty) {
                  onRemove();
                } else {
                  for (int j = 0; j < exercise.sets.length; j++) {
                    exercise.sets[j].setNumber = j + 1;
                  }
                  onUpdate();
                }
              },
            ),

          // Add set
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: AppSize.buttonSmall,
            child: AppGlassButton(
              label: '+ Add Set',
              size: AdaptiveButtonSize.small,
              color: AppColors.primary,
              onPressed: () {
                HapticFeedback.selectionClick();
                final last =
                    exercise.sets.isNotEmpty ? exercise.sets.last : null;
                exercise.sets.add(
                  SetData(
                    setNumber: exercise.sets.length + 1,
                    reps: last?.reps,
                    weightKg: last?.weightKg,
                  ),
                );
                onUpdate();
              },
            ),
          ),

          // Duration
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: AppColors.iconMuted),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 30,
                child: TextFormField(
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    exercise.durationMinutes = int.tryParse(v);
                    onUpdate();
                  },
                  initialValue: exercise.durationMinutes?.toString() ?? '',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    filled: true,
                    fillColor: AppColors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'min',
                style: AppTextStyles.small.copyWith(
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    final weightText = set.weightKg != null
        ? '${set.weightKg == set.weightKg!.roundToDouble() ? set.weightKg!.toInt() : set.weightKg!.toStringAsFixed(1)}$unit'
        : '—';
    final repsText = set.reps != null ? '${set.reps} reps' : '—';
    final isEmpty = set.weightKg == null && set.reps == null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${set.setNumber}',
              textAlign: TextAlign.center,
              style: AppTextStyles.label,
            ),
          ),
          Expanded(
            child: Semantics(
              label: isEmpty
                  ? 'Log set ${set.setNumber}'
                  : 'Edit set ${set.setNumber}: $weightText, $repsText',
              button: true,
              child: GestureDetector(
                onTap: () => _openPicker(context),
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isEmpty)
                        Text(
                          'Tap to log',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w400,
                            color: AppColors.textHint,
                          ),
                        )
                      else ...[
                        if (showWeight) ...[
                          Text(
                            weightText,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              color: set.weightKg != null
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '×',
                            style: AppTextStyles.small.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Text(
                          repsText,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: set.reps != null
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Semantics(
                label: 'Remove set ${set.setNumber}',
                button: true,
                child: AppGlassButton(
                  sfSymbol: SFSymbol('xmark', size: 11),
                  size: AdaptiveButtonSize.small,
                  color: AppColors.danger,
                  onPressed: onRemove,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showWeightRepsPicker(
      context: context,
      setNumber: set.setNumber,
      unit: unit,
      currentWeight: set.weightKg,
      currentReps: set.reps,
      accentColor: _orange,
      showWeight: showWeight,
      onConfirm: (weight, reps) {
        set.weightKg = weight;
        set.reps = reps;
        onUpdate();
      },
    );
  }
}

// ─── Alternatives Dropdown ───────────────────────────────────────────

class AlternativesDropdown extends StatelessWidget {
  final ExerciseData exercise;
  final VoidCallback onUpdate;
  const AlternativesDropdown(
      {super.key, required this.exercise, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return AppPopupMenu<String>(
      label: exercise.name,
      items: [
        for (final alt in exercise.alternatives!)
          AdaptivePopupMenuItem<String>(label: alt, value: alt),
      ],
      onSelected: (_, item) {
        final newName = item.value as String;
        final oldName = exercise.name;
        exercise.alternatives!.remove(newName);
        exercise.alternatives!.add(oldName);
        exercise.name = newName;
        onUpdate();
      },
    );
  }
}
