import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/modal_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../services/workouts_service.dart';
import '../../widgets/exercise_search_sheet.dart';

const _orange = AppColors.orange;
const _categories = [
  'chest', 'back', 'shoulders', 'legs', 'arms', 'core', 'cardio'
];

// ─── Local data model ────────────────────────────────────────────────

class _ExerciseOption {
  String name;
  bool isDefault;
  _ExerciseOption({required this.name, this.isDefault = false});
}

class _RoutineExercise {
  String? category;
  int targetSets;
  int? targetReps;
  List<_ExerciseOption> options;

  _RoutineExercise({
    this.category,
    this.targetSets = 3,
    this.targetReps = 10,
    List<_ExerciseOption>? options,
  }) : options = options ?? [];

  String get displayName =>
      options.isEmpty ? 'Select exercise' : options.firstWhere((o) => o.isDefault, orElse: () => options.first).name;
}

// ─── Screen ──────────────────────────────────────────────────────────

class RoutineBuilderScreen extends ConsumerStatefulWidget {
  final String? editId;
  const RoutineBuilderScreen({super.key, this.editId});

  @override
  ConsumerState<RoutineBuilderScreen> createState() =>
      _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends ConsumerState<RoutineBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<_RoutineExercise> _exercises = [];
  String? _error;
  bool _saving = false;
  bool _loadingEdit = false;

  static const _draftKey = 'routine_builder_draft';

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadRoutine();
    } else {
      _loadDraft();
    }
  }

  Future<void> _saveDraft() async {
    if (_isEditing) return; // Don't save drafts when editing existing
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'name': _nameCtrl.text,
      'description': _descCtrl.text,
      'exercises': _exercises.map((ex) => {
        'category': ex.category,
        'targetSets': ex.targetSets,
        'targetReps': ex.targetReps,
        'options': ex.options.map((o) => {'name': o.name, 'isDefault': o.isDefault}).toList(),
      }).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return;
    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final ts = DateTime.tryParse(draft['timestamp'] as String? ?? '');
      if (ts != null && DateTime.now().difference(ts).inHours > 48) {
        await prefs.remove(_draftKey);
        return;
      }
      _nameCtrl.text = draft['name'] as String? ?? '';
      _descCtrl.text = draft['description'] as String? ?? '';
      final exercises = (draft['exercises'] as List?) ?? [];
      for (final ex in exercises) {
        final opts = (ex['options'] as List?) ?? [];
        _exercises.add(_RoutineExercise(
          category: ex['category'] as String?,
          targetSets: ex['targetSets'] as int? ?? 3,
          targetReps: ex['targetReps'] as int?,
          options: opts.map((o) => _ExerciseOption(
            name: o['name'] as String? ?? '',
            isDefault: o['isDefault'] == true,
          )).toList(),
        ));
      }
      if (_exercises.isNotEmpty && mounted) setState(() {});
    } catch (_) {
      await prefs.remove(_draftKey);
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Future<void> _loadRoutine() async {
    setState(() => _loadingEdit = true);
    try {
      final routine =
          await WorkoutsService.getRoutine(int.parse(widget.editId!));
      _nameCtrl.text = routine['name'] as String? ?? '';
      _descCtrl.text = routine['description'] as String? ?? '';

      final exercises =
          (routine['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      exercises.sort(
          (a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));

      for (final ex in exercises) {
        final opts =
            (ex['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        opts.sort((a, b) =>
            (a['sort_order'] as int).compareTo(b['sort_order'] as int));

        _exercises.add(_RoutineExercise(
          category: ex['exercise_category'] as String?,
          targetSets: ex['target_sets'] as int? ?? 3,
          targetReps: ex['target_reps'] as int?,
          options: opts
              .map((o) => _ExerciseOption(
                    name: o['exercise_name'] as String? ?? '',
                    isDefault: o['is_default'] == true,
                  ))
              .toList(),
        ));
      }
    } catch (e) {
      _error = 'Failed to load routine.';
    } finally {
      if (mounted) setState(() => _loadingEdit = false);
    }
  }

  Map<String, dynamic> _buildPayload() {
    final exerciseList = <Map<String, dynamic>>[];
    for (int i = 0; i < _exercises.length; i++) {
      final ex = _exercises[i];
      // Ensure exactly one default
      bool hasDefault = ex.options.any((o) => o.isDefault);
      if (!hasDefault && ex.options.isNotEmpty) {
        ex.options.first.isDefault = true;
      }

      exerciseList.add({
        'sort_order': i,
        'target_sets': ex.targetSets,
        'target_reps': ex.targetReps,
        'exercise_category': ex.category,
        'options': List.generate(ex.options.length, (j) => {
              'exercise_name': ex.options[j].name,
              'is_default': ex.options[j].isDefault,
              'sort_order': j,
            }),
      });
    }

    return {
      'name': _nameCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty)
        'description': _descCtrl.text.trim(),
      'exercises': exerciseList,
    };
  }

  Future<void> _save() async {
    setState(() => _error = null);

    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Routine name is required.');
      return;
    }
    if (_exercises.isEmpty) {
      setState(() => _error = 'Add at least one exercise.');
      return;
    }
    // Validate each exercise has at least one option
    for (int i = 0; i < _exercises.length; i++) {
      if (_exercises[i].options.isEmpty) {
        setState(
            () => _error = 'Exercise ${i + 1} needs at least one exercise.');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final payload = _buildPayload();
      if (_isEditing) {
        await WorkoutsService.updateRoutine(
            int.parse(widget.editId!), payload);
      } else {
        await WorkoutsService.createRoutine(payload);
      }
      if (!mounted) return;
      _clearDraft(); // fire-and-forget, don't await before context use
      AdaptiveSnackBar.show(context,
          message: _isEditing ? 'Routine updated!' : 'Routine created!',
          type: AdaptiveSnackBarType.success);
      context.pop(true); // Return true to signal success
    } catch (e) {
      setState(() => _error = 'Failed to save routine. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addExercise() {
    _showExerciseSearchSheet(context).then((result) {
      if (result != null && mounted) {
        setState(() {
          _exercises.add(_RoutineExercise(
            category: result['category'] as String? ?? '',
            options: [
              _ExerciseOption(
                name: result['name'] as String,
                isDefault: true,
              )
            ],
          ));
        });
      }
    });
  }

  void _addAlternative(int exerciseIndex) {
    _showExerciseSearchSheet(context).then((result) {
      if (result != null && mounted) {
        setState(() {
          _exercises[exerciseIndex].options.add(
            _ExerciseOption(name: result['name'] as String, isDefault: false),
          );
        });
      }
    });
  }

  void _removeExercise(int index) {
    setState(() => _exercises.removeAt(index));
  }

  void _removeOption(int exIndex, int optIndex) {
    setState(() {
      final ex = _exercises[exIndex];
      final wasDefault = ex.options[optIndex].isDefault;
      ex.options.removeAt(optIndex);
      if (wasDefault && ex.options.isNotEmpty) {
        ex.options.first.isDefault = true;
      }
    });
  }

  void _setDefault(int exIndex, int optIndex) {
    setState(() {
      final ex = _exercises[exIndex];
      for (int i = 0; i < ex.options.length; i++) {
        ex.options[i].isDefault = i == optIndex;
      }
    });
  }

  @override
  void dispose() {
    // Auto-save draft when leaving without saving
    if (!_isEditing && (_nameCtrl.text.isNotEmpty || _exercises.isNotEmpty)) {
      _saveDraft();
    }
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _nameCtrl.text.isNotEmpty || _exercises.isNotEmpty;
  }

  Future<bool> _confirmExit() async {
    if (!_hasChanges) return true;
    bool confirmed = false;
    await showAppAlert(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Are you sure you want to leave?',
      actions: [
        AlertAction(title: 'Cancel', style: AlertActionStyle.cancel, onPressed: () {}),
        AlertAction(title: 'Discard', style: AlertActionStyle.destructive, onPressed: () { confirmed = true; }),
      ],
    );
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldExit = await _confirmExit();
        if (!mounted) return;
        if (shouldExit) context.pop();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 36, height: 36,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('chevron.left', size: 14),
                      size: AdaptiveButtonSize.small,
                      onPressed: () async {
                        final shouldExit = await _confirmExit();
                        if (!mounted) return;
                        if (shouldExit) context.pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isEditing ? 'Edit Routine' : 'Create Routine',
                    style: AppTextStyles.headline,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 90, height: 36,
                    child: AppGlassButton(
                      onPressed: (_saving || _loadingEdit) ? null : _save,
                      label: _saving ? 'Saving...' : 'Save',
                      color: _orange,
                      enabled: !_saving && !_loadingEdit,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Body ──
            Expanded(
              child: _loadingEdit
                  ? _buildSkeleton()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Error
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withAlpha(25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.danger.withAlpha(60)),
                            ),
                            child: Text(
                              _error!,
                              style: AppTextStyles.label.copyWith(
                                fontWeight: FontWeight.w400,
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Name & description
                        _buildInfoCard(),
                        const SizedBox(height: 20),

                        // Exercises header
                        Row(
                          children: [
                            Text(
                              'Exercises',
                              style: AppTextStyles.title.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_exercises.length} exercise${_exercises.length != 1 ? 's' : ''}',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Exercise list
                        if (_exercises.isEmpty)
                          _buildEmptyExercises()
                        else
                          ..._buildExerciseList(),

                        const SizedBox(height: 12),

                        // Add exercise button
                        _buildAddButton(),
                        const SizedBox(height: 40),
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Routine Name', style: AppTextStyles.label),
          const SizedBox(height: 6),
          AdaptiveTextField(
            controller: _nameCtrl,
            style: AppTextStyles.subheading.copyWith(
              fontWeight: FontWeight.w400,
            ),
            placeholder: 'e.g. Push Day, Upper Body',
          
            cupertinoDecoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),),
          const SizedBox(height: 14),
          Text('Description', style: AppTextStyles.label),
          const SizedBox(height: 6),
          AdaptiveTextField(
            controller: _descCtrl,
            style: AppTextStyles.body,
            maxLines: 2,
            placeholder: 'Optional description',
          
            cupertinoDecoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),),
        ],
      ),
    );
  }

  Widget _buildEmptyExercises() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.fitness_center,
              size: 36, color: AppColors.iconMuted),
          const SizedBox(height: 10),
          Text(
            'No exercises added',
            style: AppTextStyles.body.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the button below to add exercises',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExerciseList() {
    return List.generate(_exercises.length, (i) {
      final ex = _exercises[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _buildExerciseCard(ex, i),
      );
    });
  }

  Widget _buildExerciseCard(_RoutineExercise ex, int index) {
    final catColor =
        AppColors.categoryColors[ex.category ?? ''] ?? _orange;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: const EdgeInsets.only(top: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 0),
            child: Row(
              children: [
                // Drag handle + index
                Icon(Icons.drag_indicator,
                    size: 18, color: AppColors.iconMuted),
                const SizedBox(width: 6),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.micro.copyWith(color: catColor),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ex.displayName,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Category chip
                if (ex.category != null && ex.category!.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 80),
                    child: Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ex.category!,
                        style: AppTextStyles.micro.copyWith(
                          fontWeight: FontWeight.w500,
                          color: catColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                // Delete button
                SizedBox(
                  width: 28, height: 28,
                  child: AppGlassButton(
                    sfSymbol: SFSymbol('xmark', size: 11),
                    onPressed: () => _removeExercise(index),
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 16, indent: 12, endIndent: 12),

          // Sets & Reps row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Target sets
                Flexible(
                  child: _buildStepper(
                    label: 'Sets',
                    value: ex.targetSets,
                    min: 1,
                    max: 10,
                    onChanged: (v) => setState(() => ex.targetSets = v),
                  ),
                ),
                const SizedBox(width: 4),
                // Target reps
                Flexible(
                  child: _buildStepper(
                    label: 'Reps',
                    value: ex.targetReps ?? 10,
                    min: 1,
                    max: 50,
                    onChanged: (v) => setState(() => ex.targetReps = v),
                  ),
                ),
                const SizedBox(width: 4),
                // Category picker
                Semantics(
                  label: 'Choose category: ${ex.category?.isNotEmpty == true ? ex.category! : "None"}',
                  button: true,
                  child: GestureDetector(
                    onTap: () => _showCategoryPicker(index),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 90),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withAlpha(20), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.label_outline,
                              size: 14, color: catColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              ex.category?.isNotEmpty == true
                                  ? ex.category!
                                  : 'Category',
                              style: AppTextStyles.micro.copyWith(
                                fontWeight: FontWeight.w400,
                                color: ex.category?.isNotEmpty == true
                                    ? catColor
                                    : AppColors.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Options list (alternatives)
          if (ex.options.length > 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alternatives:',
                    style: AppTextStyles.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...List.generate(ex.options.length, (optIdx) {
                    final opt = ex.options[optIdx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _setDefault(index, optIdx),
                            child: Icon(
                              opt.isDefault
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 16,
                              color:
                                  opt.isDefault ? _orange : AppColors.iconMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              opt.name,
                              style: AppTextStyles.label.copyWith(
                                color: opt.isDefault
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: opt.isDefault
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (ex.options.length > 1)
                            SizedBox(
                              width: 28, height: 28,
                              child: AppGlassButton(
                                sfSymbol: SFSymbol('xmark', size: 11),
                                onPressed: () => _removeOption(index, optIdx),
                                size: AdaptiveButtonSize.small,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Add alternative button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SizedBox(
              width: 130, height: 30,
              child: AppGlassButton(
                onPressed: () => _addAlternative(index),
                label: 'Add alternative',
                size: AdaptiveButtonSize.small,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 3),
        Semantics(
          label: 'Decrease $label',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (value > min) {
                HapticFeedback.selectionClick();
                onChanged(value - 1);
              }
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.minus, size: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
        Semantics(
          label: '$label: $value',
          child: SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Semantics(
          label: 'Increase $label',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (value < max) {
                HapticFeedback.selectionClick();
                onChanged(value + 1);
              }
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.plus, size: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 40,
        child: AppGlassButton(
          onPressed: _addExercise,
          label: 'Add Exercise',
          color: _orange,
        ),
      ),
    );
  }

  void _showCategoryPicker(int exerciseIndex) {
    showAppSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Category', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final color = AppColors.categoryColors[cat] ?? AppColors.textMuted;
                final isSelected =
                    _exercises[exerciseIndex].category == cat;
                return GestureDetector(
                  onTap: () {
                    setState(
                        () => _exercises[exerciseIndex].category = cat);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? color.withAlpha(30) : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? color : AppColors.border,
                        width: isSelected ? 1.5 : 0.5,
                      ),
                    ),
                    child: Text(
                      cat[0].toUpperCase() + cat.substring(1),
                      style: AppTextStyles.body.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected ? color : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showExerciseSearchSheet(
      BuildContext context) async {
    final result = await ExerciseSearchSheet.show(context);
    if (result == null) return null;
    return <String, dynamic>{...result};
  }

  Widget _buildSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: List.generate(4, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }),
      ),
    );
  }
}

