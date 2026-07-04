import 'package:flutter/material.dart';
import '../../utils/modal_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../services/workouts_service.dart';

const _orange = AppColors.orange;
const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

// ─── Provider for routines list ──────────────────────────────────────────────

final _routinesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return WorkoutsService.listRoutines();
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class PlanBuilderScreen extends ConsumerStatefulWidget {
  final String? editId;
  const PlanBuilderScreen({super.key, this.editId});

  @override
  ConsumerState<PlanBuilderScreen> createState() => _PlanBuilderScreenState();
}

class _PlanBuilderScreenState extends ConsumerState<PlanBuilderScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _durationType = 'repeating';
  int _durationWeeks = 4;
  List<int?> _dayRoutines = List.filled(7, null);
  Set<int> _planRoutineIds = {}; // Routines that belong to this plan
  String? _error;
  bool _saving = false;
  bool _loadingEdit = false;

  bool get _isEditing => widget.editId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadPlan();
  }

  Future<void> _loadPlan() async {
    setState(() => _loadingEdit = true);
    try {
      final editId = int.tryParse(widget.editId ?? '');
      if (editId == null) {
        if (mounted) setState(() => _loadingEdit = false);
        return;
      }
      final plan = await WorkoutsService.getPlan(editId);
      _nameCtrl.text = plan['name'] as String? ?? '';
      _descCtrl.text = plan['description'] as String? ?? '';
      _durationType = plan['duration_type'] as String? ?? 'repeating';
      _durationWeeks = plan['duration_weeks'] as int? ?? 4;

      final days = (plan['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final mapped = List<int?>.filled(7, null);
      for (final d in days) {
        final dow = d['day_of_week'] as int?;
        if (dow != null && dow >= 0 && dow <= 6) {
          mapped[dow] = d['routine_id'] as int?;
        }
      }
      _dayRoutines = mapped;
      _planRoutineIds = mapped.whereType<int>().toSet();
    } catch (e) {
      _error = 'Failed to load plan.';
    } finally {
      if (mounted) setState(() => _loadingEdit = false);
    }
  }

  void _showAddRoutineSheet(
    AsyncValue<List<Map<String, dynamic>>> routinesAsync,
  ) {
    final allRoutines = routinesAsync.valueOrNull ?? [];
    final available = allRoutines
        .where((r) => !_planRoutineIds.contains(r['id'] as int))
        .toList();

    showAppSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add Routine to Plan',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              // Create new
              GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await context.push<bool>('/routines/new');
                  if (result == true) ref.invalidate(_routinesListProvider);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withAlpha(20),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add, color: _orange, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Create New Routine',
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Build from scratch',
                            style: AppTextStyles.micro.copyWith(
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (available.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Existing Routines',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: available.length,
                    itemBuilder: (_, i) {
                      final r = available[i];
                      final name = r['name'] as String? ?? '';
                      final exercises = (r['exercises'] as List?)?.length ?? 0;
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _planRoutineIds.add(r['id'] as int));
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withAlpha(20),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.fitness_center,
                                size: 18,
                                color: AppColors.iconMuted,
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name, style: AppTextStyles.body),
                                  Text(
                                    '$exercises exercises',
                                    style: AppTextStyles.micro.copyWith(
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _error = null);

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Plan name is required.');
      return;
    }
    if (!_dayRoutines.any((r) => r != null)) {
      setState(() => _error = 'Add at least one workout day.');
      return;
    }

    final days = List.generate(7, (i) {
      final m = <String, dynamic>{'day_of_week': i};
      if (_dayRoutines[i] != null) m['routine_id'] = _dayRoutines[i];
      return m;
    });

    final payload = <String, dynamic>{
      'name': name,
      'duration_type': _durationType,
      'days': days,
    };
    final desc = _descCtrl.text.trim();
    if (desc.isNotEmpty) payload['description'] = desc;
    if (_durationType == 'fixed') payload['duration_weeks'] = _durationWeeks;

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await WorkoutsService.updatePlan(int.parse(widget.editId!), payload);
      } else {
        await WorkoutsService.createPlan(payload);
      }
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: _isEditing ? 'Plan updated!' : 'Plan created!',
          type: AdaptiveSnackBarType.success,
        );
        context.pop(true);
      }
    } catch (e) {
      setState(() => _error = 'Failed to save plan. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _nameCtrl.text.isNotEmpty || _planRoutineIds.isNotEmpty;
  }

  Future<bool> _confirmExit() async {
    if (!_hasChanges) return true;
    bool confirmed = false;
    await showAppAlert(
      context: context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Are you sure you want to leave?',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Discard',
          style: AlertActionStyle.destructive,
          onPressed: () {
            confirmed = true;
          },
        ),
      ],
    );
    return confirmed;
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(_routinesListProvider);

    final isLoading = _loadingEdit || routinesAsync is AsyncLoading;

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
                      width: 36,
                      height: 36,
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
                      _isEditing ? 'Edit Plan' : 'Create Plan',
                      style: AppTextStyles.headline,
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 90,
                      height: 36,
                      child: AppGlassButton(
                        onPressed: (_saving || isLoading) ? null : _save,
                        label: _saving ? 'Saving...' : 'Save',
                        color: _orange,
                        enabled: !_saving && !isLoading,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Body ──
              Expanded(
                child: isLoading
                    ? const _BuilderSkeleton()
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
                                  color: AppColors.danger.withAlpha(60),
                                ),
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

                          // Name & description card
                          _card([
                            _label('Plan Name', required: true),
                            const SizedBox(height: 6),
                            AdaptiveTextField(
                              controller: _nameCtrl,
                              style: TextStyle(color: AppColors.textPrimary),
                              placeholder: 'e.g. Push Pull Legs',

                              cupertinoDecoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _label('Description'),
                            const SizedBox(height: 6),
                            AdaptiveTextField(
                              controller: _descCtrl,
                              style: TextStyle(color: AppColors.textPrimary),
                              placeholder: 'Optional description',

                              cupertinoDecoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 16),

                          // Duration card
                          _card([
                            _label('Duration'),
                            const SizedBox(height: 12),
                            _durationToggle(),
                            const SizedBox(height: 8),
                            Text(
                              _durationType == 'repeating'
                                  ? 'Runs indefinitely on a weekly cycle.'
                                  : 'Runs for a set number of weeks, then stops.',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            if (_durationType == 'fixed') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: AdaptiveTextField(
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                      ),
                                      controller: TextEditingController(
                                        text: _durationWeeks.toString(),
                                      ),
                                      onChanged: (v) {
                                        final n = int.tryParse(v);
                                        if (n != null && n >= 1 && n <= 52) {
                                          _durationWeeks = n;
                                        }
                                      },

                                      cupertinoDecoration: BoxDecoration(
                                        color: AppColors.surfaceAlt,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'week${_durationWeeks != 1 ? 's' : ''}',
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ]),
                          const SizedBox(height: 16),

                          // ── Plan Routines Section ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Plan Routines',
                                style: AppTextStyles.title.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                width: 110,
                                height: 30,
                                child: AppGlassButton(
                                  onPressed: () =>
                                      _showAddRoutineSheet(routinesAsync),
                                  label: 'Add Routine',
                                  size: AdaptiveButtonSize.small,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add routines to this plan, then assign them to days below',
                            style: AppTextStyles.small.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildPlanRoutinesList(routinesAsync),

                          const SizedBox(height: 24),

                          // ── Weekly Schedule ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Weekly Schedule',
                                style: AppTextStyles.title.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_dayRoutines.where((r) => r != null).length} workout day${_dayRoutines.where((r) => r != null).length != 1 ? 's' : ''} / week',
                                style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Day rows
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.border,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              children: List.generate(7, (i) {
                                final isRest = _dayRoutines[i] == null;
                                return Column(
                                  children: [
                                    if (i > 0)
                                      const Divider(height: 0.5, indent: 12),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: isRest
                                                  ? AppColors.border
                                                  : _orange,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _dayLabels[i],
                                              style: AppTextStyles.caption
                                                  .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: isRest
                                                        ? AppColors
                                                              .textSecondary
                                                        : AppColors
                                                              .textOnPrimary,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            _dayNames[i],
                                            style: AppTextStyles.bodyMedium
                                                .copyWith(
                                                  color: isRest
                                                      ? AppColors.textMuted
                                                      : AppColors.textPrimary,
                                                ),
                                          ),
                                          const Spacer(),
                                          _routineDropdown(i, routinesAsync),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
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

  // ── Helpers ──

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppTextStyles.body.copyWith(color: AppColors.danger),
          ),
      ],
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _durationToggle() {
    return AppSegmentedControl(
      labels: const ['Repeating', 'Fixed'],
      selectedIndex: _durationType == 'repeating' ? 0 : 1,
      onValueChanged: (i) =>
          setState(() => _durationType = i == 0 ? 'repeating' : 'fixed'),
    );
  }

  Widget _buildPlanRoutinesList(
    AsyncValue<List<Map<String, dynamic>>> routinesAsync,
  ) {
    final allRoutines = routinesAsync.valueOrNull ?? [];
    final planRoutines = allRoutines
        .where((r) => _planRoutineIds.contains(r['id'] as int))
        .toList();

    if (planRoutines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Center(
          child: Text(
            'No routines added yet.\nTap "Add Routine" to assign routines to this plan.',
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < planRoutines.length; i++) ...[
            if (i > 0) const Divider(height: 0.5, indent: 12),
            _PlanRoutineTile(
              routine: planRoutines[i],
              onEdit: () async {
                final id = planRoutines[i]['id'] as int;
                final result = await context.push<bool>(
                  '/routines/new?edit=$id',
                );
                if (result == true) ref.invalidate(_routinesListProvider);
              },
              onRemove: () {
                final id = planRoutines[i]['id'] as int;
                final removedDayAssignments = <int, int?>{};
                for (int d = 0; d < 7; d++) {
                  if (_dayRoutines[d] == id) {
                    removedDayAssignments[d] = id;
                  }
                }
                setState(() {
                  _planRoutineIds.remove(id);
                  for (int d = 0; d < 7; d++) {
                    if (_dayRoutines[d] == id) _dayRoutines[d] = null;
                  }
                });
                AdaptiveSnackBar.show(
                  context,
                  message: 'Routine removed',
                  type: AdaptiveSnackBarType.info,
                  action: 'Undo',
                  onActionPressed: () {
                    setState(() {
                      _planRoutineIds.add(id);
                      for (final entry in removedDayAssignments.entries) {
                        _dayRoutines[entry.key] = entry.value;
                      }
                    });
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _routineDropdown(
    int dayIndex,
    AsyncValue<List<Map<String, dynamic>>> routinesAsync,
  ) {
    final allRoutines = routinesAsync.valueOrNull ?? [];

    // Only show routines that belong to this plan
    final planRoutines = allRoutines
        .where((r) => _planRoutineIds.contains(r['id'] as int))
        .toList();

    final currentValue = _dayRoutines[dayIndex];
    final currentName = currentValue == null
        ? 'Rest'
        : (planRoutines.firstWhere(
                    (r) => r['id'] == currentValue,
                    orElse: () => {'name': 'Unknown'},
                  )['name']
                  as String? ??
              'Unknown');

    final items = <AdaptivePopupMenuItem<int?>>[
      AdaptivePopupMenuItem<int?>(label: 'Rest Day', value: null),
      for (final r in planRoutines)
        AdaptivePopupMenuItem<int?>(
          label: r['name'] as String? ?? '',
          value: r['id'] as int,
        ),
    ];

    return SizedBox(
      width: 130,
      height: 34,
      child: AppPopupMenu<int?>(
        label: currentName,
        buttonStyle: PopupButtonStyle.glass,
        shrinkWrap: true,
        items: items,
        onSelected: (index, entry) {
          setState(() => _dayRoutines[dayIndex] = entry.value);
        },
      ),
    );
  }
}

// ─── Plan Routine Tile ───────────────────────────────────────────────────────

class _PlanRoutineTile extends StatelessWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onEdit;
  final VoidCallback? onRemove;
  const _PlanRoutineTile({
    required this.routine,
    required this.onEdit,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = routine['name'] as String? ?? '';
    final id = routine['id'] as int;
    final isPreset = routine['is_preset'] == true;
    final exercises =
        (routine['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final tile = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.fitness_center, size: 16, color: _orange),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isPreset) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Preset',
                            style: AppTextStyles.micro.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.warningDark,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${exercises.length} exercise${exercises.length != 1 ? 's' : ''}',
                    style: AppTextStyles.small.copyWith(
                      fontWeight: FontWeight.w400,
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
    );

    if (onRemove == null) return tile;

    return Dismissible(
      key: ValueKey('routine_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
      ),
      onDismissed: (_) => onRemove!(),
      child: tile,
    );
  }
}

// ─── Loading Skeleton ────────────────────────────────────────────────────────

class _BuilderSkeleton extends StatelessWidget {
  const _BuilderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(
            7,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
