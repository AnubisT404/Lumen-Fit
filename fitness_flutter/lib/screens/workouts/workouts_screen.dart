import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../models/workout.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/workouts_provider.dart';
import '../../services/workouts_service.dart';
import '../../utils/modal_utils.dart';
import '../../utils/weight_utils.dart';
import '../../widgets/date_navigator.dart';
import '../../widgets/first_time_hint.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/exercise_search_sheet.dart';
import '../../widgets/app_card.dart';
import '../../widgets/picker_sheet.dart';
import 'workout_data.dart';
import 'workout_widgets.dart';

class WorkoutsScreen extends ConsumerStatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  ConsumerState<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends ConsumerState<WorkoutsScreen> {
  String? _lastDate;

  String get _unit {
    final settings = ref.read(settingsProvider).valueOrNull;
    return settings?.weightUnit ?? 'kg';
  }

  Future<void> _startStrength() async {
    HapticFeedback.selectionClick();
    final result = await ExerciseSearchSheet.show(context);
    if (result != null && mounted) {
      final name = Uri.encodeComponent(result['name']!);
      final cat = Uri.encodeComponent(result['category'] ?? '');
      await context.push('/new-workout?type=strength&exercise=$name&category=$cat');
      if (!mounted) return;
      ref.invalidate(workoutsProvider);
    }
  }

  Future<void> _startCardio() async {
    HapticFeedback.selectionClick();
    await context.push('/new-workout?type=cardio');
    if (!mounted) return;
    ref.invalidate(workoutsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final date = ref.watch(workoutDateProvider);
    final workoutsAsync = ref.watch(workoutsProvider);
    final planAsync = ref.watch(todayPlanProvider);
    ref.watch(settingsProvider);

    if (_lastDate != null && _lastDate != date) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.invalidate(workoutsProvider);
        }
      });
    }
    _lastDate = date;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DateNavigator(
              date: date,
              onDateChange: (delta) {
                final current = DateTime.tryParse(date) ?? DateTime.now();
                final next = current.add(Duration(days: delta));
                ref.read(workoutDateProvider.notifier).state =
                    '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
              },
              onPickDate: (picked) {
                ref.read(workoutDateProvider.notifier).state =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              },
            ),
            Expanded(
              child: workoutsAsync.when(
                loading: () => const WorkoutShimmer(),
                error: (err, _) => ErrorState(
                  message: 'Could not load workouts.',
                  onRetry: () => ref.invalidate(workoutsProvider),
                ),
                data: (workouts) => _buildBody(workouts, planAsync.valueOrNull),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<Workout> workouts, Map<String, dynamic>? plan) {
    final hasPlan = plan != null && plan['has_plan'] == true;
    final isRestDay = hasPlan && plan['is_rest_day'] == true;
    final hasRoutine = hasPlan && !isRestDay && plan['routine_id'] != null;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workoutsProvider);
        ref.invalidate(todayPlanProvider);
        await ref.read(workoutsProvider.future);
      },
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 100),
        children: [
          const FirstTimeHint(
            hintKey: 'workouts_welcome',
            message: 'Tap + to start a new workout. Your plan for today appears at the top. Swipe left on exercises to delete.',
            icon: Icons.fitness_center,
          ),
          const SizedBox(height: 6),
          if (hasRoutine) ...[
            PlanBanner(
              plan: plan,
              onReturn: () => ref.invalidate(workoutsProvider),
            ),
            const SizedBox(height: 10),
          ] else if (isRestDay) ...[
            PlanBanner.restDay(
              planName: plan['plan_name'] as String? ?? 'Workout Plan',
            ),
            const SizedBox(height: 10),
          ],
          _buildStartWorkoutCTA(),
          if (workouts.isNotEmpty) ...[
            const SizedBox(height: 22),
            ..._buildGroupedWorkouts(workouts),
          ] else if (!hasRoutine && !isRestDay) ...[
            const SizedBox(height: 22),
            const EmptyState(
              icon: Icons.fitness_center_rounded,
              title: 'Ready to train?',
              subtitle:
                  'Start a strength or cardio workout to build your history.',
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStartWorkoutCTA() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start Workout',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: AppGlassButton(
                    onPressed: _startStrength,
                    label: 'Strength',
                    color: workoutStrengthColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: AppGlassButton(
                    onPressed: _startCardio,
                    label: 'Cardio',
                    color: workoutCardioColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedWorkouts(List<Workout> workouts) {
    final strengthWorkouts = workouts
        .where((w) => w.workoutType == 'strength')
        .toList();
    final cardioWorkouts = workouts
        .where((w) => w.workoutType != 'strength')
        .toList();
    final widgets = <Widget>[];

    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(
              '${workouts.length} ${workouts.length == 1 ? 'session' : 'sessions'} today',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted.withAlpha(130),
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.history_rounded,
              size: 13,
              color: AppColors.iconMuted.withAlpha(80),
            ),
          ],
        ),
      ),
    );

    if (strengthWorkouts.isNotEmpty) {
      final allExercises = <WorkoutExercise>[];
      for (final workout in strengthWorkouts) {
        allExercises.addAll(workout.exercises);
      }
      final merged = Workout(
        id: strengthWorkouts.first.id,
        workoutType: 'strength',
        name: strengthWorkouts.first.name ?? 'Strength Training',
        exercises: allExercises,
        createdAt: strengthWorkouts.first.createdAt,
      );
      widgets.add(
        WorkoutHistoryCard(
          workout: merged,
          unit: _unit,
          onDelete: () {
            for (final workout in strengthWorkouts) {
              _deleteWorkout(workout);
            }
          },
          onDeleteExercise: (exerciseId) =>
              _deleteExercise(exerciseId, parentWorkouts: strengthWorkouts),
          onEditSet: (exercise, set) =>
              _openEditSetSheet(strengthWorkouts, exercise, set),
          onDeleteSet: (exercise, set) =>
              _deleteSetFromWorkout(strengthWorkouts, exercise, set),
        ),
      );
    }

    for (int i = 0; i < cardioWorkouts.length; i++) {
      if (widgets.length > 1) {
        widgets.add(const SizedBox(height: 10));
      }
      widgets.add(
        WorkoutHistoryCard(
          workout: cardioWorkouts[i],
          unit: _unit,
          onDelete: () => _deleteWorkout(cardioWorkouts[i]),
        ),
      );
    }

    return widgets;
  }

  Future<void> _deleteWorkout(Workout workout) async {
    if (workout.id == null) return;
    try {
      await WorkoutsService.delete(workout.id!);
      ref.invalidate(workoutsProvider);
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: '${workout.name ?? workout.workoutType} removed',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to delete. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _deleteExercise(
    int exerciseId, {
    List<Workout>? parentWorkouts,
  }) async {
    try {
      HapticFeedback.mediumImpact();
      await WorkoutsService.deleteExercise(exerciseId);

      if (parentWorkouts != null) {
        for (final workout in parentWorkouts) {
          final remaining = workout.exercises
              .where((e) => e.id != exerciseId)
              .length;
          if (remaining == 0 && workout.id != null) {
            await WorkoutsService.delete(workout.id!);
          }
        }
      }

      ref.invalidate(workoutsProvider);
      if (mounted) {
        HapticFeedback.lightImpact();
        AdaptiveSnackBar.show(
          context,
          message: 'Exercise removed',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to delete. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  void _openEditSetSheet(
    List<Workout> allWorkouts,
    WorkoutExercise exercise,
    WorkoutSet targetSet,
  ) {
    final unit = _unit;
    final displayWeight = kgToDisplay(targetSet.weightKg, unit) ?? 0;

    Workout? parentWorkout;
    for (final workout in allWorkouts) {
      if (workout.exercises.any((e) => e.id == exercise.id)) {
        parentWorkout = workout;
        break;
      }
    }
    if (parentWorkout == null || parentWorkout.id == null) return;

    showWeightRepsPicker(
      context: context,
      setNumber: targetSet.setNumber,
      unit: unit,
      currentWeight: displayWeight > 0 ? displayWeight : null,
      currentReps: targetSet.reps,
      accentColor: workoutStrengthColor,
      onConfirm: (weight, reps) {
        _saveEditedSet(
          parentWorkout!,
          exercise,
          targetSet,
          weight != null ? displayToKg(weight, unit) : null,
          reps,
        );
      },
    );
  }

  Future<void> _saveEditedSet(
    Workout parentWorkout,
    WorkoutExercise exercise,
    WorkoutSet targetSet,
    double? newWeight,
    int? newReps,
  ) async {
    try {
      final updatedExercises = parentWorkout.exercises.map((currentExercise) {
        final updatedSets = currentExercise.sets.map((set) {
          if (currentExercise.id == exercise.id &&
              set.setNumber == targetSet.setNumber) {
            return {
              'set_number': set.setNumber,
              'reps': ?newReps,
              'weight_kg': ?newWeight,
              if (set.durationSeconds != null)
                'duration_seconds': set.durationSeconds,
              if (set.distanceKm != null) 'distance_km': set.distanceKm,
            };
          }
          return set.toJson();
        }).toList();
        return {
          'exercise_name': currentExercise.exerciseName,
          if (currentExercise.exerciseCategory != null)
            'exercise_category': currentExercise.exerciseCategory,
          'sets': updatedSets,
        };
      }).toList();

      final payload = {
        'workout_type': parentWorkout.workoutType,
        if (parentWorkout.name != null) 'name': parentWorkout.name,
        if (parentWorkout.durationMinutes != null)
          'duration_minutes': parentWorkout.durationMinutes,
        if (parentWorkout.caloriesBurned != null)
          'calories_burned': parentWorkout.caloriesBurned,
        'exercises': updatedExercises,
      };

      await WorkoutsService.update(parentWorkout.id!, payload);
      ref.invalidate(workoutsProvider);
      if (mounted) {
        HapticFeedback.lightImpact();
        AdaptiveSnackBar.show(
          context,
          message: 'Set updated',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to update. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  void _deleteSetFromWorkout(
    List<Workout> allWorkouts,
    WorkoutExercise exercise,
    WorkoutSet targetSet,
  ) async {
    Workout? parentWorkout;
    for (final workout in allWorkouts) {
      if (workout.exercises.any((e) => e.id == exercise.id)) {
        parentWorkout = workout;
        break;
      }
    }
    if (parentWorkout == null || parentWorkout.id == null) return;

    try {
      HapticFeedback.mediumImpact();
      final updatedExercises = parentWorkout.exercises
          .map((currentExercise) {
            final filteredSets = currentExercise.sets
                .where(
                  (set) =>
                      !(currentExercise.id == exercise.id &&
                          set.setNumber == targetSet.setNumber),
                )
                .toList();
            for (int i = 0; i < filteredSets.length; i++) {
              filteredSets[i] = WorkoutSet(
                id: filteredSets[i].id,
                setNumber: i + 1,
                reps: filteredSets[i].reps,
                weightKg: filteredSets[i].weightKg,
                durationSeconds: filteredSets[i].durationSeconds,
                distanceKm: filteredSets[i].distanceKm,
              );
            }
            return {
              'exercise_name': currentExercise.exerciseName,
              if (currentExercise.exerciseCategory != null)
                'exercise_category': currentExercise.exerciseCategory,
              'sets': filteredSets.map((set) => set.toJson()).toList(),
              '_setCount': filteredSets.length,
            };
          })
          .where((exerciseData) => (exerciseData['_setCount'] as int) > 0)
          .map((exerciseData) {
            final map = Map<String, dynamic>.from(exerciseData);
            map.remove('_setCount');
            return map;
          })
          .toList();

      if (updatedExercises.isEmpty) {
        await WorkoutsService.delete(parentWorkout.id!);
        ref.invalidate(workoutsProvider);
        if (mounted) {
          HapticFeedback.lightImpact();
          AdaptiveSnackBar.show(
            context,
            message: 'Workout deleted',
            type: AdaptiveSnackBarType.success,
          );
        }
        return;
      }

      final payload = {
        'workout_type': parentWorkout.workoutType,
        if (parentWorkout.name != null) 'name': parentWorkout.name,
        if (parentWorkout.durationMinutes != null)
          'duration_minutes': parentWorkout.durationMinutes,
        if (parentWorkout.caloriesBurned != null)
          'calories_burned': parentWorkout.caloriesBurned,
        'exercises': updatedExercises,
      };

      await WorkoutsService.update(parentWorkout.id!, payload);
      ref.invalidate(workoutsProvider);
      if (mounted) {
        HapticFeedback.lightImpact();
        AdaptiveSnackBar.show(
          context,
          message: 'Set deleted',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to delete set. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }
}
