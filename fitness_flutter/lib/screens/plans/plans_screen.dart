import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../services/workouts_service.dart';
import '../../utils/modal_utils.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';

// ─── Colors ──────────────────────────────────────────────────────────────────

const _orange = AppColors.orange;

// ─── Providers ───────────────────────────────────────────────────────────────

final _plansProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((
  ref,
) async {
  return WorkoutsService.listPlans();
});

final _routinesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      return WorkoutsService.listRoutines();
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(_plansProvider);
    final routinesAsync = ref.watch(_routinesProvider);

    return Scaffold(
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
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('Workout Plans', style: AppTextStyles.headline),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Unified Content ──
            Expanded(
              child: plansAsync.when(
                loading: () => const _LoadingSkeleton(),
                error: (err, _) => ErrorState(
                  message: 'Failed to load plans.',
                  onRetry: () {
                    ref.invalidate(_plansProvider);
                    ref.invalidate(_routinesProvider);
                  },
                ),
                data: (plans) {
                  if (routinesAsync.isLoading) {
                    return const Center(child: CupertinoActivityIndicator());
                  }
                  final routines = routinesAsync.valueOrNull ?? [];

                  // Sort plans: active first, then by date
                  final sorted = List<Map<String, dynamic>>.from(plans)
                    ..sort((a, b) {
                      final aActive = a['is_active'] == true ? 0 : 1;
                      final bActive = b['is_active'] == true ? 0 : 1;
                      if (aActive != bActive) return aActive.compareTo(bActive);
                      final aDate = a['created_at'] as String? ?? '';
                      final bDate = b['created_at'] as String? ?? '';
                      return bDate.compareTo(aDate);
                    });

                  // Find routines assigned to plans
                  final assignedIds = <int>{};
                  for (final plan in plans) {
                    final days =
                        (plan['days'] as List?)?.cast<Map<String, dynamic>>() ??
                        [];
                    for (final day in days) {
                      final rid = day['routine_id'] as int?;
                      if (rid != null) assignedIds.add(rid);
                    }
                  }

                  // Unassigned routines
                  final unassigned = routines
                      .where((r) => !assignedIds.contains(r['id'] as int))
                      .toList();

                  return RefreshIndicator(
                    color: _orange,
                    onRefresh: () async {
                      ref.invalidate(_plansProvider);
                      ref.invalidate(_routinesProvider);
                      await ref.read(_plansProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (sorted.isEmpty && unassigned.isEmpty) ...[
                          const SizedBox(height: 80),
                          const EmptyState(
                            icon: Icons.fitness_center,
                            title: 'No workout plans yet',
                            subtitle:
                                'Create a plan to schedule your weekly workouts',
                          ),
                        ] else ...[
                          // Each plan as a unified card
                          for (final plan in sorted) ...[
                            _UnifiedPlanCard(plan: plan, ref: ref),
                            const SizedBox(height: 16),
                          ],

                          // Unassigned routines section
                          if (unassigned.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _SectionHeader(
                              title: 'Routine Library',
                              icon: Icons.folder_outlined,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Routines not assigned to any plan',
                              style: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 10),
                            for (final routine in unassigned) ...[
                              _RoutineCompactCard(routine: routine, ref: ref),
                              const SizedBox(height: 6),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ],

                        // Create button
                        _CreateButton(
                          label: 'Create Custom Plan',
                          onTap: () => context.push('/plans/new'),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Unified Plan Card ───────────────────────────────────────────────────────
// Shows: plan header → plan routines → weekly schedule

class _UnifiedPlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final WidgetRef ref;
  const _UnifiedPlanCard({required this.plan, required this.ref});

  @override
  Widget build(BuildContext context) {
    final id = plan['id'] as int;
    final name = plan['name'] as String? ?? '';
    final isActive = plan['is_active'] == true;
    final isPreset = plan['is_preset'] == true;
    final durationType = plan['duration_type'] as String? ?? 'repeating';
    final durationWeeks = plan['duration_weeks'] as int?;
    final days = (plan['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final workoutDays = days.where((d) => d['routine_id'] != null).length;

    return GestureDetector(
      onTap: () => context.push('/plans/new?edit=$id'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.catLegs : AppColors.border,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Plan Header ──
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        _Badge(
                          label: 'Active',
                          icon: Icons.check_circle,
                          bgColor: AppColors.successBg,
                          textColor: AppColors.successDark,
                        ),
                      ],
                      if (isPreset) ...[
                        const SizedBox(width: 6),
                        _Badge(
                          label: 'Preset',
                          icon: Icons.star,
                          bgColor: AppColors.warningBg,
                          textColor: AppColors.warningDark,
                        ),
                      ],
                    ],
                  ),
                ),
                _ActionIcon(
                  icon: isActive ? Icons.pause : Icons.play_arrow,
                  color: isActive ? AppColors.iconMuted : _orange,
                  onTap: () => _toggleActivation(context, id, isActive),
                ),
                if (!isPreset)
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    color: AppColors.iconMuted,
                    hoverColor: AppColors.danger,
                    onTap: () => _deletePlan(context, id, name),
                  ),
              ],
            ),

            const SizedBox(height: 4),

            // ── Duration info ──
            Row(
              children: [
                Icon(
                  durationType == 'repeating'
                      ? Icons.repeat
                      : Icons.access_time,
                  size: 13,
                  color: AppColors.iconMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  durationType == 'repeating'
                      ? 'Repeating'
                      : '${durationWeeks ?? 0} week${(durationWeeks ?? 0) != 1 ? 's' : ''}',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '·',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$workoutDays day${workoutDays != 1 ? 's' : ''} / week',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Weekly Schedule ──
            DayCircles(days: days),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActivation(
    BuildContext context,
    int id,
    bool isActive,
  ) async {
    try {
      if (isActive) {
        await WorkoutsService.deactivatePlan(id);
      } else {
        await WorkoutsService.activatePlan(id);
      }
      ref.invalidate(_plansProvider);
    } catch (e) {
      if (context.mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Something went wrong. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  Future<void> _deletePlan(BuildContext context, int id, String name) async {
    bool confirmed = false;
    await showAppAlert(
      context: context,
      title: 'Delete Plan',
      message: 'Delete "$name"? This cannot be undone.',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Delete',
          style: AlertActionStyle.destructive,
          onPressed: () {
            confirmed = true;
          },
        ),
      ],
    );
    if (!confirmed) return;
    try {
      await WorkoutsService.deletePlan(id);
      ref.invalidate(_plansProvider);
      if (context.mounted) {
        AdaptiveSnackBar.show(
          context,
          message: '"$name" deleted',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Failed to delete. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }
}

// ─── Day Circles ─────────────────────────────────────────────────────────────

const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

class DayCircles extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const DayCircles({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final dayMap = <int, Map<String, dynamic>>{};
    for (final d in days) {
      final dow = d['day_of_week'] as int?;
      if (dow != null) dayMap[dow] = d;
    }

    return Row(
      children: List.generate(7, (i) {
        final day = dayMap[i];
        final hasRoutine = day != null && day['routine_id'] != null;
        final routineName =
            (day?['routine'] as Map<String, dynamic>?)?['name'] as String?;

        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: hasRoutine ? _orange : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _dayLabels[i],
                  style: AppTextStyles.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: hasRoutine
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 12,
                child: hasRoutine && routineName != null
                    ? Text(
                        routineName,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: _orange),
          const SizedBox(width: 6),
          Text(
            title,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Routine Compact Card (less overwhelming, used in grouped view) ──────────

class _RoutineCompactCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final WidgetRef ref;
  const _RoutineCompactCard({required this.routine, required this.ref});

  @override
  Widget build(BuildContext context) {
    final id = routine['id'] as int;
    final name = routine['name'] as String? ?? '';
    final isPreset = routine['is_preset'] == true;
    final exercises =
        (routine['exercises'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return GestureDetector(
      onTap: () async {
        final result = await context.push<bool>('/routines/new?edit=$id');
        if (result == true) ref.invalidate(_routinesProvider);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(20), width: 0.5),
        ),
        child: Row(
          children: [
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
                        _Badge(
                          label: 'Preset',
                          icon: Icons.star,
                          bgColor: AppColors.warningBg,
                          textColor: AppColors.warningDark,
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
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  const _Badge({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.small.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? hoverColor;
  final VoidCallback onTap;
  final double size;
  const _ActionIcon({
    required this.icon,
    required this.color,
    this.hoverColor,
    required this.onTap,
    this.size = 18,
  });

  String get _sfSymbolName {
    if (icon == Icons.delete_outline) return 'trash';
    if (icon == Icons.play_arrow) return 'play.fill';
    if (icon == Icons.pause) return 'pause.fill';
    return 'circle';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: AppGlassButton(
        sfSymbol: SFSymbol(_sfSymbolName, size: 12),
        icon: icon,
        onPressed: onTap,
        color: color,
        size: AdaptiveButtonSize.small,
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CreateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: AppGlassButton(
        onPressed: onTap,
        label: label,
        size: AdaptiveButtonSize.small,
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: List.generate(3, (_) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 110,
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
