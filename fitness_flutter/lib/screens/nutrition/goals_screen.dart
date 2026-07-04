import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../utils/modal_utils.dart';
import '../../config/theme.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/picker_sheet.dart';
import 'goals_widgets.dart';

// ─────────────────────────────────────────────────────────────
// Goals Screen – MFP-style settings list
// ─────────────────────────────────────────────────────────────

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _loading = true;
  String? _error;

  double _currentWeight = 170;
  double _goalWeight = 170;
  String _weeklyGoal = 'maintain';
  String _activityLevel = 'lightly_active';

  int _calories = 2000;
  int _protein = 150;
  int _carbs = 200;
  int _fat = 65;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ProfileService.get(),
        ProfileService.getGoals(),
      ]);
      final profile = results[0] as Profile;
      final goals = results[1] as Goals;
      if (!mounted) return;
      setState(() {
        _currentWeight = _kgToLbs(profile.weightKg ?? 77);
        _goalWeight = _kgToLbs(
          profile.targetWeightKg ?? profile.weightKg ?? 77,
        );
        _weeklyGoal = profile.goal ?? 'maintain';
        _activityLevel = profile.activityLevel ?? 'lightly_active';
        _calories = goals.dailyCalories;
        _protein = goals.proteinG;
        _carbs = goals.carbsG;
        _fat = goals.fatsG;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load goals. Please try again.';
      });
    }
  }

  double _kgToLbs(double kg) => (kg * 2.20462).roundToDouble();
  double _lbsToKg(double lbs) => lbs / 2.20462;

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            goalsScreenBuildHeader(context, 'Goals'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: AppColors.textSecondary)),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: () {
                                  setState(() { _loading = true; _error = null; });
                                  _load();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                  : ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        _settingsRow(
                          'Current Weight',
                          '${_currentWeight.round()} lbs',
                          () => _showWeightPicker(
                            'Current Weight',
                            _currentWeight,
                            (v) {
                              setState(() => _currentWeight = v);
                              _syncProfile();
                            },
                          ),
                        ),
                        _divider(),
                        _settingsRow(
                          'Goal Weight',
                          '${_goalWeight.round()} lbs',
                          () => _showWeightPicker('Goal Weight', _goalWeight, (
                            v,
                          ) {
                            setState(() => _goalWeight = v);
                            _syncProfile();
                          }),
                        ),
                        _divider(),
                        _settingsRow(
                          'Weekly Goal',
                          _weeklyGoalLabel(_weeklyGoal),
                          _pickWeeklyGoal,
                        ),
                        _divider(),
                        _settingsRow(
                          'Activity Level',
                          _activityLabel(_activityLevel),
                          _pickActivityLevel,
                        ),

                        // Nutrition Goals
                        _sectionHeader('Nutrition Goals'),
                        _navRow(
                          'Calorie, Carbs, Protein and Fat Goals',
                          'Customize your default or daily goals.',
                          _openMacroGoals,
                        ),
                        _divider(),
                        _navRow(
                          'Additional Nutrient Goals',
                          null,
                          _openNutrientGoals,
                        ),

                        // Fitness Goals
                        _sectionHeader('Fitness Goals'),
                        _settingsRow('Workouts/Week', '0', () {
                          _showNumberPicker(
                            'Workouts/Week',
                            0,
                            0,
                            7,
                            1,
                            (v) {},
                          );
                        }),
                        _divider(),
                        _settingsRow('Minutes/Workout', '0', () {
                          _showNumberPicker(
                            'Minutes/Workout',
                            0,
                            0,
                            180,
                            5,
                            (v) {},
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared widgets ──

  Widget _sectionHeader(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    color: AppColors.border,
    child: Text(
      text,
      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _settingsRow(String label, String? value, VoidCallback? onTap) =>
      Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.subheading.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (value != null)
                  Text(
                    value,
                    style: AppTextStyles.subheading.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

  Widget _navRow(String label, String? sub, VoidCallback onTap) => Material(
    color: AppColors.surface,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.subheading.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (sub != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        sub,
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.iconMuted,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _divider() => Container(
    height: 0.5,
    color: AppColors.border,
    margin: const EdgeInsets.only(left: 16),
  );

  // ── Labels ──

  String _weeklyGoalLabel(String g) {
    const m = {
      'lose_2': 'Lose 2 lbs/week',
      'lose_1.5': 'Lose 1.5 lbs/week',
      'lose_1': 'Lose 1 lb/week',
      'lose_0.5': 'Lose 0.5 lbs/week',
      'lose': 'Lose weight',
      'maintain': 'Maintain weight',
      'gain_0.5': 'Gain 0.5 lbs/week',
      'gain_1': 'Gain 1 lb/week',
      'gain': 'Gain weight',
    };
    return m[g] ?? g;
  }

  String _activityLabel(String l) {
    const m = {
      'sedentary': 'Not Very Active',
      'lightly_active': 'Lightly Active',
      'moderately_active': 'Active',
      'very_active': 'Very Active',
    };
    return m[l] ?? l;
  }

  // ═══════════════════════════════════════════════════════
  //  WEIGHT PICKER – horizontal ruler scale (MFP style)
  // ═══════════════════════════════════════════════════════

  void _showWeightPicker(
    String title,
    double current,
    ValueChanged<double> onSave,
  ) {
    double selected = current.roundToDouble();
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setBS) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PickerIconToolbar(
                    title: title,
                    onCancel: () => Navigator.pop(ctx),
                    onConfirm: () {
                      onSave(selected);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    '${selected.round()} lbs',
                    style: AppTextStyles.display.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 80,
                    child: WeightRuler(
                      value: selected,
                      min: 50,
                      max: 500,
                      onChanged: (v) => setBS(() => selected = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  //  LIST PICKERS – Weekly Goal / Activity Level
  // ═══════════════════════════════════════════════════════

  void _pickWeeklyGoal() {
    final opts = [
      ('lose_0.5', 'Lose 0.5 lbs per week'),
      ('lose_1', 'Lose 1 lb per week'),
      ('lose_1.5', 'Lose 1.5 lbs per week'),
      ('lose_2', 'Lose 2 lbs per week'),
      ('maintain', 'Maintain weight'),
      ('gain_0.5', 'Gain 0.5 lbs per week'),
      ('gain_1', 'Gain 1 lb per week'),
    ];
    _showListPicker('Weekly Goal', opts, _weeklyGoal, (v) async {
      setState(() => _weeklyGoal = v);
      await _syncProfile();
      await _load();
    });
  }

  void _pickActivityLevel() {
    final opts = [
      ('sedentary', 'Not Very Active'),
      ('lightly_active', 'Lightly Active'),
      ('moderately_active', 'Active'),
      ('very_active', 'Very Active'),
    ];
    _showListPicker('Activity Level', opts, _activityLevel, (v) async {
      setState(() => _activityLevel = v);
      await _syncProfile();
      await _load();
    });
  }

  void _showListPicker(
    String title,
    List<(String, String)> opts,
    String current,
    ValueChanged<String> onSelect,
  ) {
    showListPickerSheet(
      context: context,
      title: title,
      options: opts,
      currentValue: current,
      onSelect: onSelect,
    );
  }

  // ═══════════════════════════════════════════════════════
  //  NUMBER PICKER – Cupertino wheel for integers
  // ═══════════════════════════════════════════════════════

  void _showNumberPicker(
    String title,
    int current,
    int minVal,
    int maxVal,
    int step,
    ValueChanged<int> onSave,
  ) {
    final items = List.generate(
      ((maxVal - minVal) ~/ step) + 1,
      (i) => minVal + i * step,
    );
    int idx = items.indexOf(current).clamp(0, items.length - 1);
    showIconPickerSheet(
      context: context,
      title: title,
      onConfirm: () => onSave(items[idx]),
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(initialItem: idx),
        itemExtent: 32,
        useMagnifier: true,
        magnification: 2.35 / 2.1,
        squeeze: 1.25,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: AppColors.dividerIOS,
        ),
        onSelectedItemChanged: (i) => idx = i,
        children: items
            .map(
              (v) => Center(
                child: Text(
                  '$v',
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════
  //  MACRO GOALS – sub-page
  // ═══════════════════════════════════════════════════════

  void _openMacroGoals() async {
    final result = await Navigator.push<Map<String, int>>(
      context,
      CupertinoPageRoute(
        builder: (_) => MacroGoalsPage(
          calories: _calories,
          protein: _protein,
          carbs: _carbs,
          fat: _fat,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _calories = result['calories']!;
        _protein = result['protein']!;
        _carbs = result['carbs']!;
        _fat = result['fat']!;
      });
      try {
        await ProfileService.updateGoals(
          dailyCalories: _calories,
          proteinG: _protein,
          carbsG: _carbs,
          fatsG: _fat,
        );
        if (mounted) {
          AdaptiveSnackBar.show(
            context,
            message: 'Goals updated',
            type: AdaptiveSnackBarType.success,
          );
        }
      } catch (_) {
        if (mounted) {
          AdaptiveSnackBar.show(
            context,
            message: 'Failed to save goals',
            type: AdaptiveSnackBarType.error,
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  //  ADDITIONAL NUTRIENT GOALS – sub-page
  // ═══════════════════════════════════════════════════════

  void _openNutrientGoals() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => const NutrientGoalsPage()),
    );
  }

  // ── Sync profile to backend ──

  Future<void> _syncProfile() async {
    try {
      String backendGoal = _weeklyGoal.startsWith('lose')
          ? 'lose'
          : _weeklyGoal.startsWith('gain')
          ? 'gain'
          : 'maintain';
      await ProfileService.updateProfile(
        weightKg: _lbsToKg(_currentWeight),
        targetWeightKg: _lbsToKg(_goalWeight),
        activityLevel: _activityLevel,
        goal: backendGoal,
      );
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Profile updated',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to save',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────
// Horizontal Ruler Weight Picker widget
// ─────────────────────────────────────────────────────────────
