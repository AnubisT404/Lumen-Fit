import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/first_time_hint.dart';
import '../../models/meal_entry.dart';
import '../../models/food_item.dart';
import '../../models/dashboard_data.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/meals_service.dart';
import '../../services/water_service.dart';
import '../../utils/weight_utils.dart';
import '../../widgets/error_state.dart';
import '../../widgets/week_streak.dart';
import '../../widgets/date_navigator.dart';
import '../../widgets/app_card.dart';
import '../../utils/modal_utils.dart';

// ─── Design tokens ───────────────────────────────────────────────────

// Meal type config
class _MealConfig {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _MealConfig(this.key, this.label, this.icon, this.color);
}

const _mealTypes = [
  _MealConfig('breakfast', 'Breakfast', Icons.coffee, AppColors.mealBreakfast),
  _MealConfig('lunch', 'Lunch', Icons.lunch_dining, AppColors.mealLunch),
  _MealConfig('dinner', 'Dinner', Icons.restaurant, AppColors.mealDinner),
  _MealConfig('snack', 'Snacks', Icons.cookie, AppColors.mealSnack),
];

// ─── Screen ──────────────────────────────────────────────────────────

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    final date = ref.watch(selectedDateProvider);
    final mealsAsync = ref.watch(mealsProvider);
    final dashAsync = ref.watch(dashboardProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Glass-style header
            DateNavigator(
              date: date,
              onDateChange: (delta) {
                final current = DateTime.tryParse(date) ?? DateTime.now();
                final next = current.add(Duration(days: delta));
                ref.read(selectedDateProvider.notifier).state =
                    '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
              },
              onPickDate: (picked) {
                ref.read(selectedDateProvider.notifier).state =
                    '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
              },
            ),
            // Content
            Expanded(
              child: mealsAsync.when(
                loading: () => const _ShimmerLoading(),
                error: (err, _) => ErrorState(
                  message: 'Could not load meals.',
                  onRetry: () => ref.invalidate(mealsProvider),
                ),
                data: (meals) {
                  final goalCal =
                      dashAsync.valueOrNull?.nutrition.goals.calories ?? 2000;
                  final weightUnit =
                      settingsAsync.valueOrNull?.weightUnit ?? 'kg';
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(mealsProvider);
                      ref.invalidate(dashboardProvider);
                    },
                    color: AppColors.primary,
                    child: _DiaryContent(
                      meals: meals,
                      goalCalories: goalCal,
                      date: date,
                      dashData: dashAsync.valueOrNull,
                      weightUnit: weightUnit,
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

// ─── Content ─────────────────────────────────────────────────────────

class _DiaryContent extends ConsumerWidget {
  final List<MealEntry> meals;
  final double goalCalories;
  final String date;
  final DashboardData? dashData;
  final String weightUnit;

  const _DiaryContent({
    required this.meals,
    required this.goalCalories,
    required this.date,
    this.dashData,
    required this.weightUnit,
  });

  bool get _isToday {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return date == todayStr;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = <String, List<MealEntry>>{};
    for (final m in meals) {
      grouped.putIfAbsent(m.mealType, () => []).add(m);
    }

    final totalCal = meals.fold(0.0, (s, m) => s + m.calories);

    return ListView(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenPaddingH,
        right: AppSpacing.screenPaddingH,
        bottom: 80,
      ),
      children: [
        const FirstTimeHint(
          hintKey: 'diary_welcome',
          message:
              'Tap any card to see details. Swipe left on meals to delete. Use the + button to log food or workouts.',
        ),
        const SizedBox(height: AppSpacing.cardGap),

        // Dashboard section
        if (dashData != null) ...[
          // Week streak
          if (dashData!.weekStreak.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
              child: WeekStreak(days: dashData!.weekStreak),
            ),

          // Combined nutrition card — calories + macro rings
          Semantics(
            label: 'View nutrition details',
            button: true,
            child: GestureDetector(
              onTap: () => context.push('/nutrition'),
              child: _NutritionCard(
                consumed: totalCal,
                goalCal: goalCalories,
                meals: meals,
                protein: dashData!.nutrition.consumed.proteinG,
                proteinGoal: dashData!.nutrition.goals.proteinG,
                carbs: dashData!.nutrition.consumed.carbsG,
                carbsGoal: dashData!.nutrition.goals.carbsG,
                fat: dashData!.nutrition.consumed.fatsG,
                fatGoal: dashData!.nutrition.goals.fatsG,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.cardGap),

          // Hydration
          _CompactHydration(water: dashData!.water, isToday: _isToday),
          const SizedBox(height: AppSpacing.cardGap),

          // Weight + Exercise
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _WeightCard(
                    weight: dashData!.weight,
                    unit: weightUnit,
                  ),
                ),
                const SizedBox(width: AppSpacing.cardGap),
                Expanded(child: _ExerciseCard(exercise: dashData!.exercise)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
        ],

        // Meal sections
        // Quick-add recent foods
        if (_isToday) ...[
          _QuickAddChips(date: date),
          const SizedBox(height: AppSpacing.cardGap),
        ],

        for (int mti = 0; mti < _mealTypes.length; mti++) ...[
          _MealTypeCard(
            config: _mealTypes[mti],
            items: grouped[_mealTypes[mti].key] ?? [],
            date: date,
            onDelete: (item) => _deleteItem(context, ref, item),
          ),
          const SizedBox(height: AppSpacing.cardGap),
        ],
        const SizedBox(height: AppSpacing.sectionGap),
      ],
    );
  }

  Future<void> _deleteItem(
    BuildContext context,
    WidgetRef ref,
    MealEntry item,
  ) async {
    try {
      await MealsService.deleteItem(item.id);
      ref.invalidate(mealsProvider);
      ref.invalidate(dashboardProvider);
      if (context.mounted) {
        AdaptiveSnackBar.show(
          context,
          message: '${item.foodName} removed',
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

// ─── Combined Nutrition Card (calories + macro rings) ────────────────

class _NutritionCard extends StatelessWidget {
  final double consumed, goalCal;
  final List<MealEntry> meals;
  final double protein, proteinGoal, carbs, carbsGoal, fat, fatGoal;

  const _NutritionCard({
    required this.consumed,
    required this.goalCal,
    required this.meals,
    required this.protein,
    required this.proteinGoal,
    required this.carbs,
    required this.carbsGoal,
    required this.fat,
    required this.fatGoal,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = goalCal - consumed;
    final isOver = remaining < 0;
    final pct = goalCal > 0 ? consumed / goalCal : 0.0;
    final goalReached = pct >= 0.90 && pct <= 1.10 && consumed > 0;

    final segMap = <String, double>{};
    for (final m in meals) {
      segMap[m.mealType] = (segMap[m.mealType] ?? 0) + m.calories;
    }

    return Column(
      children: [
        if (goalReached)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.success.withValues(alpha: 0.15), AppColors.primary.withValues(alpha: 0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'Daily calorie goal reached!',
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Semantics(
      label:
          '${consumed.round()} of ${goalCal.round()} calories. ${isOver ? "${(-remaining).round()} over" : "${remaining.round()} remaining"}',
      child: AppCard(
        padding: const EdgeInsets.all(14),
        elevated: true,
        child: Column(
          children: [
            // Top row: calorie text left, macro rings right
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Calorie info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '${consumed.round()}',
                            style: AppTextStyles.display.copyWith(height: 1.1),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ ${goalCal.round()}',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'cal',
                            style: AppTextStyles.micro.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isOver
                              ? AppColors.macroProtein.withAlpha(20)
                              : AppColors.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isOver
                              ? '+${(-remaining).round()} over'
                              : '${remaining.round()} remaining',
                          style: AppTextStyles.small.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOver
                                ? AppColors.macroProtein
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Macro rings
                Row(
                  children: [
                    _MacroRing(
                      label: 'P',
                      current: protein,
                      goal: proteinGoal,
                      color: AppColors.macroProtein,
                    ),
                    const SizedBox(width: 8),
                    _MacroRing(
                      label: 'C',
                      current: carbs,
                      goal: carbsGoal,
                      color: AppColors.macroCarbs,
                    ),
                    const SizedBox(width: 8),
                    _MacroRing(
                      label: 'F',
                      current: fat,
                      goal: fatGoal,
                      color: AppColors.macroFats,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Meal-segmented calorie progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 10,
                color: AppColors.surfaceAlt,
                child: goalCal > 0
                    ? Row(
                        children: [
                          for (final mt in _mealTypes)
                            if ((segMap[mt.key] ?? 0) > 0)
                              Flexible(
                                flex:
                                    ((segMap[mt.key]! /
                                                (isOver ? consumed : goalCal)) *
                                            1000)
                                        .round(),
                                child: Container(
                                  color: isOver
                                      ? mt.color.withAlpha(179)
                                      : mt.color,
                                ),
                              ),
                          if (!isOver && consumed < goalCal)
                            Flexible(
                              flex: (((goalCal - consumed) / goalCal) * 1000)
                                  .round(),
                              child: const SizedBox(),
                            ),
                        ],
                      )
                    : const SizedBox(),
              ),
            ),

            const SizedBox(height: 8),

            // Meal legend dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _mealTypes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _mealTypes[i].color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _mealTypes[i].label,
                    style: AppTextStyles.micro.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
      ],
    );
  }
}

// ─── Macro Ring (mini circular progress) ─────────────────────────────

class _MacroRing extends StatelessWidget {
  final String label;
  final double current, goal;
  final Color color;
  const _MacroRing({
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final isOver = goal > 0 && current > goal;
    final overColor = HSLColor.fromColor(color)
        .withLightness(
          (HSLColor.fromColor(color).lightness - 0.12).clamp(0.0, 1.0),
        )
        .toColor();

    final macroName = label == 'P'
        ? 'Protein'
        : label == 'C'
        ? 'Carbs'
        : 'Fats';

    return Semantics(
      label: '$macroName: ${current.round()} of ${goal.round()} grams',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: _RingPainter(
                progress: pct,
                color: isOver ? overColor : color,
                trackColor: AppColors.surfaceAlt,
                strokeWidth: 4,
              ),
              child: Center(
                child: Text(
                  '${current.round()}',
                  style: AppTextStyles.small.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isOver ? overColor : AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${current.round()}/${goal.round()}g',
            style: AppTextStyles.small,
          ),
          Text(
            macroName,
            style: AppTextStyles.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color, trackColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -3.14159 / 2; // top
    final sweepAngle = 2 * 3.14159 * progress;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = trackColor
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ─── Meal Type Card ──────────────────────────────────────────────────

class _MealTypeCard extends StatelessWidget {
  final _MealConfig config;
  final List<MealEntry> items;
  final String date;
  final ValueChanged<MealEntry> onDelete;

  const _MealTypeCard({
    required this.config,
    required this.items,
    required this.date,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final totalCal = items.fold(0.0, (s, m) => s + m.calories);
    final hasItems = items.isNotEmpty;

    return AppCard(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Slim header — tappable to add food
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/add-food?meal=${config.key}&date=$date');
            },
            child: Semantics(
              label: 'Add food to ${config.label}',
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Colored dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: config.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      config.label,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasItems) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${totalCal.round()} cal',
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: config.color,
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.add_rounded, size: 18, color: config.color),
                  ],
                ),
              ),
            ),
          ),
          // Food items
          if (hasItems)
            for (int i = 0; i < items.length; i++)
              _FoodItemTile(
                item: items[i],
                mealColor: config.color,
                onDelete: () => onDelete(items[i]),
                onTap: () => context.push(
                  '/add-food?meal=${config.key}&date=$date&edit=${items[i].id}',
                ),
                showTopBorder: true,
              ),
        ],
      ),
    );
  }
}

// ─── Food Item Tile ──────────────────────────────────────────────────

class _FoodItemTile extends StatelessWidget {
  final MealEntry item;
  final Color mealColor;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final bool showTopBorder;

  const _FoodItemTile({
    required this.item,
    required this.mealColor,
    required this.onDelete,
    this.onTap,
    this.showTopBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    // Build serving text
    String? cleanUnit = item.servingUnit;
    if (cleanUnit != null) {
      cleanUnit = cleanUnit.replaceFirst(RegExp(r'^1\s+'), '');
    }
    String fmtServ(double v) =>
        v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    String servingText;
    if (cleanUnit != null && cleanUnit.toLowerCase() == 'serving') {
      final s = fmtServ(item.servings);
      servingText =
          '$s serving${item.servings == 1 ? '' : 's'} (${item.servingSize.round()}g)';
    } else if (cleanUnit != null) {
      servingText = item.servings == 1
          ? '$cleanUnit (${item.servingSize.round()}g)'
          : '${fmtServ(item.servings)}× $cleanUnit (${item.servingSize.round()}g)';
    } else {
      final s = fmtServ(item.servings);
      servingText = '$s serving${item.servings == 1 ? '' : 's'}';
    }

    final subtitleText =
        '$servingText · P${item.protein.round()} · C${item.carbs.round()} · F${item.fat.round()}';

    return AdaptiveContextMenu(
      actions: [
        if (onTap != null)
          AdaptiveContextMenuAction(
            title: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () => onTap!(),
          ),
        AdaptiveContextMenuAction(
          title: 'Delete',
          icon: Icons.delete_outline,
          isDestructive: true,
          onPressed: onDelete,
        ),
      ],
      child: Dismissible(
        key: ValueKey(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: AppColors.macroProtein,
          child: const Icon(
            Icons.delete_outline,
            color: AppColors.textOnPrimary,
            size: 18,
          ),
        ),
        confirmDismiss: (_) async {
          bool confirmed = false;
          await showAppAlert(
            context: context,
            title: 'Delete Item',
            message: 'Remove "${item.foodName}" from your diary?',
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
          if (confirmed) {
            onDelete();
          }
          return confirmed;
        },
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap?.call();
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: showTopBorder
                ? BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.surfaceAlt, width: 0.5),
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Name + macros
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.foodName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.micro.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Calories
                Text(
                  '${item.calories.round()}',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  'cal',
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shimmer Loading ─────────────────────────────────────────────────

class _ShimmerLoading extends StatelessWidget {
  const _ShimmerLoading();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < 4; i++) ...[
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

// ─── Dashboard card container ────────────────────────────────────────

Widget _dashCard({required Widget child, EdgeInsets? padding}) {
  return AppCard(
    elevated: true,
    padding: padding ?? const EdgeInsets.all(12),
    child: child,
  );
}

// ─── Compact hydration card ──────────────────────────────────────────

class _CompactHydration extends ConsumerStatefulWidget {
  final WaterData water;
  final bool isToday;
  const _CompactHydration({required this.water, required this.isToday});

  @override
  ConsumerState<_CompactHydration> createState() => _CompactHydrationState();
}

class _CompactHydrationState extends ConsumerState<_CompactHydration> {
  bool _busy = false;

  Future<void> _add() async {
    if (_busy || !widget.isToday) return;
    setState(() => _busy = true);
    try {
      await WaterService.log(250);
      ref.invalidate(dashboardProvider);
    } catch (_) {
      if (mounted) {
        AdaptiveSnackBar.show(context, message: 'Failed to log water', type: AdaptiveSnackBarType.error);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    if (_busy || !widget.isToday) return;
    bool confirmed = false;
    await showAppAlert(
      context: context,
      title: 'Reset Water',
      message: 'Clear all water logged today?',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Reset',
          style: AlertActionStyle.destructive,
          onPressed: () {
            confirmed = true;
          },
        ),
      ],
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await WaterService.resetToday();
      ref.invalidate(dashboardProvider);
    } catch (_) {
      if (mounted) {
        AdaptiveSnackBar.show(context, message: 'Failed to reset water', type: AdaptiveSnackBarType.error);
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.water;
    const int glassSize = 250;
    final int totalGlasses = w.goalMl > 0 ? (w.goalMl / glassSize).ceil() : 8;
    final int filledCount = w.consumedMl > 0
        ? (w.consumedMl / glassSize).floor().clamp(0, totalGlasses)
        : 0;
    final canEdit = widget.isToday;

    return _dashCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.water_drop, size: 18, color: AppColors.water),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${w.consumedMl} / ${w.goalMl} ml',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$filledCount of $totalGlasses',
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    totalGlasses,
                    (i) => Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(
                          right: i < totalGlasses - 1 ? 2 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: i < filledCount ? null : AppColors.surfaceAlt,
                          gradient: i < filledCount
                              ? const LinearGradient(
                                  colors: [AppColors.water, AppColors.sky],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (canEdit) ...[
            SizedBox(
              width: 44,
              height: 44,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                // ignore: deprecated_member_use
                minSize: 44,
                onPressed: _busy ? null : _add,
                child: Icon(
                  Icons.add_circle_outline,
                  size: 22,
                  color: AppColors.water,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                // ignore: deprecated_member_use
                minSize: 44,
                onPressed: _busy ? null : _reset,
                child: Icon(
                  Icons.refresh,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Weight card ─────────────────────────────────────────────────────

class _WeightCard extends StatelessWidget {
  final WeightData weight;
  final String unit;
  const _WeightCard({required this.weight, required this.unit});

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime(d.year, d.month, d.day);
      final diff = today.difference(date).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[d.month - 1]} ${d.day}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayWeight = weight.currentKg != null
        ? kgToDisplay(weight.currentKg!, unit)
        : null;
    final dateStr = _formatDate(weight.lastMeasured);

    return Semantics(
      label: 'View measurements',
      button: true,
      child: GestureDetector(
        onTap: () => context.push('/measurements'),
        child: _dashCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monitor_weight_outlined,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Weight',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (dateStr.isNotEmpty)
                    Text(
                      dateStr,
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (displayWeight != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      displayWeight.toStringAsFixed(1),
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      unit,
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'No weigh-in',
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Exercise card ───────────────────────────────────────────────────

class _ExerciseCard extends StatelessWidget {
  final ExerciseData exercise;
  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final hasData = exercise.totalMinutes > 0 || exercise.caloriesBurned > 0;

    return Semantics(
      label: 'View workouts',
      button: true,
      child: GestureDetector(
        onTap: () => context.go('/workouts'),
        child: _dashCard(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.fitness_center,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Exercise',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (hasData)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${exercise.totalMinutes}',
                      style: AppTextStyles.heading,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'min',
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${exercise.caloriesBurned} kcal',
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'No activity',
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Error State ─────────────────────────────────────────────────────

// ─── Quick-Add Recent Foods ──────────────────────────────────────────

class _QuickAddChips extends ConsumerStatefulWidget {
  final String date;
  const _QuickAddChips({required this.date});

  @override
  ConsumerState<_QuickAddChips> createState() => _QuickAddChipsState();
}

class _QuickAddChipsState extends ConsumerState<_QuickAddChips> {
  List<FoodItem> _recentFoods = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _fetchRecent();
  }

  Future<void> _fetchRecent() async {
    try {
      final data = await MealsService.getRecentFoods();
      final items = [...(data['frequent'] ?? []), ...(data['recent'] ?? [])];
      // Deduplicate by name
      final seen = <String>{};
      final unique = <FoodItem>[];
      for (final f in items) {
        final key = f.displayName.toLowerCase();
        if (seen.add(key) && unique.length < 6) unique.add(f);
      }
      if (mounted)
        setState(() {
          _recentFoods = unique;
          _loaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _quickAdd(FoodItem food) async {
    try {
      await MealsService.quickAdd(
        mealType: 'snack',
        foodName: food.displayName,
        brand: food.brand ?? food.brands,
        calories: food.calories ?? 0,
        proteinG: food.proteinG ?? 0,
        carbsG: food.carbsG ?? 0,
        fatsG: food.fatsG ?? 0,
        fiberG: food.fiberG,
        sugarG: food.sugarG,
        sodiumMg: food.sodiumMg,
        servingSize: food.servingSize,
        servingUnit: food.servingUnit,
        source: food.source,
      );
      ref.invalidate(mealsProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        HapticFeedback.lightImpact();
        AdaptiveSnackBar.show(
          context,
          message: '${food.displayName} added',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (_) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Could not add food',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _recentFoods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bolt, size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text(
              'Quick Add',
              style: AppTextStyles.small.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textHint,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recentFoods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final food = _recentFoods[i];
              return Semantics(
                label:
                    'Quick add ${food.displayName}, ${food.calories?.round() ?? 0} calories',
                button: true,
                child: GestureDetector(
                  onTap: () => _quickAdd(food),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          food.displayName.length > 18
                              ? '${food.displayName.substring(0, 16)}…'
                              : food.displayName,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${food.calories?.round() ?? 0}',
                          style: AppTextStyles.micro.copyWith(
                            fontWeight: FontWeight.w400,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
