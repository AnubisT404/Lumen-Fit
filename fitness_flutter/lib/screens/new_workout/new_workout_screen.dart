// New Workout screen — thin coordinator that delegates UI to extracted widgets.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../providers/settings_provider.dart';
import '../../providers/workouts_provider.dart';
import '../../services/workouts_service.dart';
import '../../utils/modal_utils.dart';
import '../../utils/weight_utils.dart';
import '../../widgets/exercise_search_sheet.dart';
import 'cardio_form_widgets.dart';
import 'strength_form_widgets.dart';
import 'workout_draft_manager.dart';
import 'workout_form_models.dart';

class NewWorkoutScreen extends ConsumerStatefulWidget {
  final String initialType;
  final String? planRoutineId;
  final String? initialExercise;
  final String? initialCategory;

  const NewWorkoutScreen({
    super.key,
    this.initialType = 'strength',
    this.planRoutineId,
    this.initialExercise,
    this.initialCategory,
  });

  @override
  ConsumerState<NewWorkoutScreen> createState() => _NewWorkoutScreenState();
}

class _NewWorkoutScreenState extends ConsumerState<NewWorkoutScreen> {
  late String _activeTab;
  bool _saving = false;

  // Strength state
  final List<ExerciseData> _exercises = [];
  bool _strengthInitialized = false;

  // Rest timer
  final int _restSeconds = 90;
  int _restRemaining = 0;
  bool _restTimerActive = false;
  Timer? _restTimer;

  // Workout duration auto-tracker
  late final DateTime _workoutStartTime;
  Timer? _durationTimer;
  int _elapsedMinutes = 0;

  // Cardio state
  String _cardioType = 'Running';
  final _durationCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _avgHrCtrl = TextEditingController();
  final _maxHrCtrl = TextEditingController();
  final _elevationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _intensity = '';

  Map<String, dynamic>? _planRoutine;

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialType == 'cardio' ? 'cardio' : 'strength';
    _workoutStartTime = DateTime.now();
    _durationTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _elapsedMinutes = DateTime.now().difference(_workoutStartTime).inMinutes);
      }
    });
    _loadData();
    _loadDraft();
    if (widget.initialExercise != null) {
      _addExercise(widget.initialExercise!, widget.initialCategory ?? '');
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _durationTimer?.cancel();
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    _caloriesCtrl.dispose();
    _avgHrCtrl.dispose();
    _maxHrCtrl.dispose();
    _elevationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String get _unit {
    final settings = ref.read(settingsProvider).valueOrNull;
    return settings?.weightUnit ?? 'kg';
  }

  // ─── Data Loading ──────────────────────────────────────────────────

  Future<void> _loadData() async {
    if (widget.planRoutineId != null) {
      try {
        final routineId = int.tryParse(widget.planRoutineId!);
        if (routineId == null) return;
        final r = await WorkoutsService.getRoutine(routineId);
        if (!mounted) return;
        setState(() => _planRoutine = r);
        _populatePlanData(r);
      } catch (_) {}
    }
  }

  Future<void> _populatePlanData(Map<String, dynamic> routine) async {
    if (_strengthInitialized) return;
    final unit = _unit;
    final exercisesList = routine['exercises'] as List? ?? [];

    final exerciseMeta = <Map<String, dynamic>>[];
    for (final ex in exercisesList) {
      final options = ex['options'] as List? ?? [];
      final defaultOpt = options.firstWhere(
        (o) => o['is_default'] == true,
        orElse: () =>
            options.isNotEmpty ? options.first : {'exercise_name': 'Unknown'},
      );
      exerciseMeta.add({
        'ex': ex,
        'defaultOpt': defaultOpt,
        'options': options,
      });
    }

    final prevFutures = exerciseMeta.map((meta) {
      final name = meta['defaultOpt']['exercise_name'] as String? ?? 'Unknown';
      return WorkoutsService.getPreviousSession(name)
          .catchError((_) => <String, dynamic>{});
    }).toList();
    final prevResults = await Future.wait(prevFutures);
    if (!mounted) return;

    for (int i = 0; i < exerciseMeta.length; i++) {
      final meta = exerciseMeta[i];
      final ex = meta['ex'];
      final defaultOpt = meta['defaultOpt'];
      final options = meta['options'] as List;
      final name = defaultOpt['exercise_name'] as String? ?? 'Unknown';
      final category = ex['exercise_category'] as String? ?? '';

      List<Map<String, dynamic>>? prevSets;
      final prev = prevResults[i];
      if (prev['found'] == true) {
        prevSets = (prev['sets'] as List).map((s) {
          final m = Map<String, dynamic>.from(s as Map);
          m['weight_kg'] =
              kgToDisplay((m['weight_kg'] as num?)?.toDouble(), unit);
          return m;
        }).toList();
      }

      final targetSets = (ex['target_sets'] as num?)?.toInt() ?? 3;
      final targetReps = (ex['target_reps'] as num?)?.toInt();
      final sets = List.generate(
        targetSets,
        (i) => SetData(
          setNumber: i + 1,
          reps: targetReps,
          weightKg: (prevSets != null && i < prevSets.length)
              ? (prevSets[i]['weight_kg'] as num?)?.toDouble()
              : null,
        ),
      );

      final alternatives = options
          .map((o) => o['exercise_name'] as String)
          .where((n) => n != name)
          .toList();

      _exercises.add(ExerciseData(
        name: name,
        category: category,
        sets: sets,
        previousSets: prevSets,
        alternatives: alternatives.isNotEmpty ? alternatives : null,
      ));
    }
    _strengthInitialized = true;
    if (mounted) setState(() {});
  }

  // ─── Draft Persistence ─────────────────────────────────────────────

  Future<void> _saveDraft() => WorkoutDraftManager.save(
        activeTab: _activeTab,
        exercises: _exercises,
        cardioType: _cardioType,
        duration: _durationCtrl.text,
        distance: _distanceCtrl.text,
        calories: _caloriesCtrl.text,
        notes: _notesCtrl.text,
        intensity: _intensity,
      );

  Future<void> _loadDraft() async {
    if (widget.planRoutineId != null || widget.initialExercise != null) return;
    final draft = await WorkoutDraftManager.load();
    if (draft == null || !mounted) return;
    setState(() {
      _activeTab = draft['tab'] ?? 'strength';
      _exercises.addAll(WorkoutDraftManager.parseExercises(draft));
      _cardioType = draft['cardioType'] ?? 'Running';
      _durationCtrl.text = draft['duration'] ?? '';
      _distanceCtrl.text = draft['distance'] ?? '';
      _caloriesCtrl.text = draft['calories'] ?? '';
      _notesCtrl.text = draft['notes'] ?? '';
      _intensity = draft['intensity'] ?? '';
      if (_exercises.isNotEmpty) _strengthInitialized = true;
    });
  }

  // ─── Rest Timer ────────────────────────────────────────────────────

  void _startRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restRemaining = _restSeconds;
      _restTimerActive = true;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _restTimerActive = false;
            _restRemaining = 0;
          });
          HapticFeedback.mediumImpact();
        }
      } else {
        if (mounted) setState(() => _restRemaining--);
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _restTimerActive = false;
      _restRemaining = 0;
    });
  }

  // ─── Save ──────────────────────────────────────────────────────────

  bool get _canSaveStrength =>
      _exercises.isNotEmpty &&
      _exercises.any(
        (e) => e.sets.any((s) => s.reps != null && s.weightKg != null),
      );

  bool get _canSaveCardio {
    final d = int.tryParse(_durationCtrl.text);
    return d != null && d > 0;
  }

  bool get _canSave =>
      _activeTab == 'strength' ? _canSaveStrength : _canSaveCardio;

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    setState(() => _saving = true);
    try {
      if (_activeTab == 'strength') {
        await _saveStrength();
        // Check for personal records
        final prs = await _detectPRs();
        if (prs.isNotEmpty && mounted) {
          AdaptiveSnackBar.show(
            context,
            message: '🏆 New PR! ${prs.join(", ")}',
            type: AdaptiveSnackBarType.success,
            duration: const Duration(seconds: 4),
          );
        }
      } else {
        await _saveCardio();
      }
      await WorkoutDraftManager.clear();
      if (!mounted) return;
      ref.invalidate(workoutsProvider);
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: 'Workout saved!',
        type: AdaptiveSnackBarType.success,
      );
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/workouts');
      }
    } catch (e, st) {
      debugPrint('[WorkoutSave] ERROR: $e\n$st');
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to save. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveStrength() async {
    final unit = _unit;
    final autoMinutes = DateTime.now().difference(_workoutStartTime).inMinutes;
    final totalDuration = autoMinutes > 0 ? autoMinutes :
        _exercises.fold<int>(0, (s, e) => s + (e.durationMinutes ?? 0));
    final exercises = _exercises
        .map((e) {
          final sets = e.sets
              .where((s) => s.reps != null && s.weightKg != null)
              .map((s) => <String, dynamic>{
                    'set_number': s.setNumber,
                    if (s.reps != null) 'reps': s.reps,
                    if (s.weightKg != null)
                      'weight_kg': displayToKg(s.weightKg!, unit),
                  })
              .toList();
          return <String, dynamic>{
            'exercise_name': e.name,
            if (e.category.isNotEmpty) 'exercise_category': e.category,
            'sets': sets,
          };
        })
        .where((e) => (e['sets'] as List).isNotEmpty)
        .toList();

    await WorkoutsService.log(<String, dynamic>{
      'workout_type': 'strength',
      'name': _planRoutine != null
          ? (_planRoutine!['name'] as String? ?? 'Strength Workout')
          : 'Strength Workout',
      if (totalDuration > 0) 'duration_minutes': totalDuration,
      'exercises': exercises,
    });
  }

  Future<void> _saveCardio() async {
    final duration = int.tryParse(_durationCtrl.text);
    if (duration == null || duration <= 0) {
      if (mounted) {
        AdaptiveSnackBar.show(context,
            message: 'Enter a valid duration',
            type: AdaptiveSnackBarType.error);
      }
      return;
    }
    final data = <String, dynamic>{
      'exercise_type': _cardioType,
      'duration_minutes': duration,
    };
    final distance = double.tryParse(_distanceCtrl.text);
    if (distance != null && distance > 0) data['distance_km'] = distance;
    final calories = double.tryParse(_caloriesCtrl.text);
    if (calories != null && calories > 0) data['calories_burned'] = calories;
    final avgHr = int.tryParse(_avgHrCtrl.text);
    if (avgHr != null && avgHr > 0) data['avg_heart_rate'] = avgHr;
    final maxHr = int.tryParse(_maxHrCtrl.text);
    if (maxHr != null && maxHr > 0) data['max_heart_rate'] = maxHr;
    final elevation = double.tryParse(_elevationCtrl.text);
    if (elevation != null && elevation > 0) data['elevation_m'] = elevation;
    if (_intensity.isNotEmpty) data['intensity'] = _intensity;
    if (_notesCtrl.text.isNotEmpty) data['notes'] = _notesCtrl.text;
    await WorkoutsService.quickCardio(data);
  }

  /// Compare current session's max weights to previous sessions per exercise.
  Future<List<String>> _detectPRs() async {
    final prs = <String>[];
    for (final ex in _exercises) {
      final maxWeight = ex.sets
          .where((s) => s.weightKg != null)
          .fold<double>(0, (m, s) => s.weightKg! > m ? s.weightKg! : m);
      if (maxWeight <= 0) continue;
      try {
        final prev = await WorkoutsService.getPreviousSession(ex.name);
        final prevSets = prev['sets'] as List? ?? [];
        final prevMax = prevSets.fold<double>(0, (m, s) {
          final w = (s['weight_kg'] as num?)?.toDouble() ?? 0;
          return w > m ? w : m;
        });
        if (maxWeight > prevMax && prevMax > 0) {
          prs.add('${ex.name} ${maxWeight.round()}kg');
        }
      } catch (_) {
        // No previous data — first time, not a PR
      }
    }
    return prs;
  }

  // ─── Exercise Management ───────────────────────────────────────────

  Future<void> _openExerciseSearch() async {
    final result = await ExerciseSearchSheet.show(context);
    if (result != null && mounted) {
      await _addExercise(result['name']!, result['category'] ?? '');
    }
  }

  Future<void> _addExercise(String name, String category) async {
    final unit = _unit;
    List<Map<String, dynamic>>? prevSets;
    try {
      final prev = await WorkoutsService.getPreviousSession(name);
      if (prev['found'] == true) {
        prevSets = (prev['sets'] as List).map((s) {
          final m = Map<String, dynamic>.from(s as Map);
          m['weight_kg'] =
              kgToDisplay((m['weight_kg'] as num?)?.toDouble(), unit);
          return m;
        }).toList();
      }
    } catch (_) {}

    _exercises.add(ExerciseData(
      name: name,
      category: category,
      sets: [
        SetData(
          setNumber: 1,
          reps: (prevSets != null && prevSets.isNotEmpty)
              ? (prevSets[0]['reps'] as num?)?.toInt()
              : null,
          weightKg: (prevSets != null && prevSets.isNotEmpty)
              ? (prevSets[0]['weight_kg'] as num?)?.toDouble()
              : null,
        ),
      ],
      previousSets: prevSets,
    ));
    setState(() {});
    _saveDraft();
  }

  // ─── Computed Properties ───────────────────────────────────────────

  int get _totalSets => _exercises.fold(
      0,
      (s, e) =>
          s + e.sets.where((st) => st.reps != null || st.weightKg != null).length);

  double get _totalVolume => _exercises.fold(
      0.0,
      (s, e) =>
          s +
          e.sets.fold(0.0, (ss, st) => ss + (st.reps ?? 0) * (st.weightKg ?? 0)));

  bool get _hasUnsavedData {
    if (_activeTab == 'strength') {
      return _exercises.isNotEmpty &&
          _exercises.any(
            (e) => e.sets.any((s) => s.reps != null || s.weightKg != null),
          );
    }
    return _durationCtrl.text.isNotEmpty &&
        (int.tryParse(_durationCtrl.text) ?? 0) > 0;
  }

  Future<bool> _confirmExit() async {
    if (!_hasUnsavedData) return true;
    bool confirmed = false;
    await showAppAlert(
      context: context,
      title: 'Discard Workout?',
      message: 'You have unsaved workout data. Are you sure you want to leave?',
      actions: [
        AlertAction(
          title: 'Keep Editing',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Discard',
          style: AlertActionStyle.destructive,
          onPressed: () {
            confirmed = true;
            WorkoutDraftManager.clear();
          },
        ),
      ],
    );
    return confirmed;
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsProvider);
    final accent =
        _activeTab == 'strength' ? AppColors.orange : AppColors.catLegs;
    final title = _planRoutine != null
        ? (_planRoutine!['name'] as String? ?? 'Log Workout')
        : 'Log Workout';
    final unit = _unit;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (!mounted) return;
        if (shouldExit) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/workouts');
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Header
              _buildHeader(title, accent),
              const SizedBox(height: 12),

              // Strength / Cardio toggle
              if (_planRoutine == null && widget.initialType != 'cardio')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: AppSegmentedControl(
                    labels: const ['Strength', 'Cardio'],
                    selectedIndex: _activeTab == 'strength' ? 0 : 1,
                    onValueChanged: (i) =>
                        setState(() => _activeTab = i == 0 ? 'strength' : 'cardio'),
                  ),
                ),
              const SizedBox(height: 14),

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: _activeTab == 'strength'
                      ? _buildStrengthForm(unit)
                      : CardioForm(
                          cardioType: _cardioType,
                          onCardioTypeChanged: (v) =>
                              setState(() => _cardioType = v),
                          durationCtrl: _durationCtrl,
                          distanceCtrl: _distanceCtrl,
                          caloriesCtrl: _caloriesCtrl,
                          avgHrCtrl: _avgHrCtrl,
                          maxHrCtrl: _maxHrCtrl,
                          elevationCtrl: _elevationCtrl,
                          notesCtrl: _notesCtrl,
                          intensity: _intensity,
                          onIntensityChanged: (v) =>
                              setState(() => _intensity = v),
                          onChanged: () => setState(() {}),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: AppGlassButton(
              sfSymbol: SFSymbol('xmark', size: 14),
              size: AdaptiveButtonSize.small,
              onPressed: () async {
                final shouldExit = await _confirmExit();
                if (shouldExit && mounted) {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/workouts');
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppTextStyles.headline, textAlign: TextAlign.center),
                if (_elapsedMinutes > 0)
                  Text(
                    '${_elapsedMinutes}min',
                    style: AppTextStyles.micro.copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            height: 36,
            child: AppGlassButton(
              onPressed: _canSave && !_saving ? _save : null,
              label: _saving ? '...' : 'Save',
              color: accent,
              enabled: _canSave && !_saving,
              size: AdaptiveButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthForm(String unit) {
    return Column(
      children: [
        // Rest timer banner
        if (_restTimerActive)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withAlpha(60)),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rest: ${_restRemaining ~/ 60}:${(_restRemaining % 60).toString().padLeft(2, '0')}',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _stopRestTimer,
                  child: Semantics(
                    label: 'Skip rest timer',
                    button: true,
                    child: Text(
                      'Skip',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Summary strip
        if (_exercises.isNotEmpty && _totalSets > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.orange.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SummaryChip('${_exercises.length} exercises'),
                const SizedBox(width: 20),
                SummaryChip('$_totalSets sets'),
                if (_totalVolume > 0) ...[
                  const SizedBox(width: 20),
                  SummaryChip('${_totalVolume.toStringAsFixed(0)}$unit vol'),
                ],
              ],
            ),
          ),

        // Exercise cards
        for (int i = 0; i < _exercises.length; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Dismissible(
              key: ValueKey('${_exercises[i].name}_$i'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                final removed = _exercises[i];
                final removedIndex = i;
                setState(() => _exercises.removeAt(i));
                _saveDraft();
                if (!mounted) return false;
                AdaptiveSnackBar.show(
                  context,
                  message: '${removed.name} removed',
                  type: AdaptiveSnackBarType.info,
                  action: 'Undo',
                  onActionPressed: () {
                    setState(() => _exercises.insert(removedIndex, removed));
                    _saveDraft();
                  },
                );
                return false;
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.delete_rounded, color: AppColors.danger, size: 22),
              ),
              child: ExerciseCard(
                exercise: _exercises[i],
                unit: unit,
                onUpdate: () {
                  setState(() {});
                  _saveDraft();
                  _startRestTimer();
                },
                onRemove: () {
                  setState(() => _exercises.removeAt(i));
                  _saveDraft();
                },
              ),
            ),
          ),

        // Add exercise button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: AppGlassButton(
              onPressed: _openExerciseSearch,
              label: _exercises.isNotEmpty ? 'Add More' : 'Add Exercise',
            ),
          ),
        ),
      ],
    );
  }
}
