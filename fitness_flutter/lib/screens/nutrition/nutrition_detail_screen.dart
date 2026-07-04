import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../providers/nutrition_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/modal_utils.dart';

class NutrientConfig {
  final String key;
  final String label;
  final String unit;
  final String rdiKey;
  final Color color;
  const NutrientConfig({required this.key, required this.label, required this.unit, required this.rdiKey, required this.color});
}

final _nutrientRows = [
  NutrientConfig(key: 'protein',             label: 'Protein',              unit: 'g',    rdiKey: '__protein',             color: AppColors.macroProtein),
  NutrientConfig(key: 'carbs',               label: 'Carbohydrates',        unit: 'g',    rdiKey: '__carbs',               color: AppColors.water),
  NutrientConfig(key: 'fiber',               label: 'Fiber',                unit: 'g',    rdiKey: 'fiber_g',               color: AppColors.lime),
  NutrientConfig(key: 'sugar',               label: 'Sugar',                unit: 'g',    rdiKey: 'sugar_g',               color: Color(0xFFEC4899)),
  NutrientConfig(key: 'fat',                 label: 'Fat',                  unit: 'g',    rdiKey: '__fat',                 color: AppColors.warning),
  NutrientConfig(key: 'saturated_fat',       label: 'Saturated Fat',        unit: 'g',    rdiKey: 'saturated_fat_g',       color: AppColors.dangerLight),
  NutrientConfig(key: 'polyunsaturated_fat', label: 'Polyunsaturated Fat',  unit: 'g',    rdiKey: 'polyunsaturated_fat_g', color: AppColors.sky),
  NutrientConfig(key: 'monounsaturated_fat', label: 'Monounsaturated Fat',  unit: 'g',    rdiKey: 'monounsaturated_fat_g', color: AppColors.teal),
  NutrientConfig(key: 'trans_fat',           label: 'Trans Fat',            unit: 'g',    rdiKey: 'trans_fat_g',           color: AppColors.dangerLight),
  NutrientConfig(key: 'cholesterol',         label: 'Cholesterol',          unit: 'mg',   rdiKey: 'cholesterol_mg',        color: AppColors.orange),
  NutrientConfig(key: 'sodium',              label: 'Sodium',               unit: 'mg',   rdiKey: 'sodium_mg',             color: Color(0xFFA78BFA)),
  NutrientConfig(key: 'potassium',           label: 'Potassium',            unit: 'mg',   rdiKey: 'potassium_mg',          color: AppColors.blue),
  NutrientConfig(key: 'calcium',             label: 'Calcium',              unit: 'mg',   rdiKey: 'calcium_mg',            color: AppColors.textMuted),
  NutrientConfig(key: 'iron',                label: 'Iron',                 unit: 'mg',   rdiKey: 'iron_mg',               color: AppColors.textSecondary),
  NutrientConfig(key: 'vitamin_a',           label: 'Vitamin A',            unit: '% DV', rdiKey: 'vitamin_a_pct',         color: AppColors.yellow),
  NutrientConfig(key: 'vitamin_c',           label: 'Vitamin C',            unit: '% DV', rdiKey: 'vitamin_c_pct',         color: Color(0xFFFACC15)),
  NutrientConfig(key: 'vitamin_d',           label: 'Vitamin D',            unit: 'mcg',  rdiKey: 'vitamin_d_mcg',         color: AppColors.orange),
];

const _mealTypeColors = {
  'breakfast': (color: AppColors.mealBreakfast, label: 'Breakfast'),
  'lunch':     (color: AppColors.mealLunch, label: 'Lunch'),
  'dinner':    (color: AppColors.mealDinner, label: 'Dinner'),
  'snack':     (color: AppColors.mealSnack, label: 'Snacks'),
};

const _microFields = [
  'saturated_fat', 'polyunsaturated_fat', 'monounsaturated_fat', 'trans_fat',
  'cholesterol', 'sodium', 'potassium', 'fiber', 'sugar',
  'vitamin_a', 'vitamin_c', 'vitamin_d', 'calcium', 'iron',
];

// ─── Helpers ─────────────────────────────────────────────────────────

String _addDays(String dateStr, int days) {
  final next = DateTime.parse(dateStr).add(Duration(days: days));
  return formatDateString(next);
}

String _getMonday(String dateStr) {
  final d = DateTime.parse(dateStr);
  final monday = d.subtract(Duration(days: d.weekday - 1));
  return formatDateString(monday);
}

String _formatDate(String dateStr) {
  final d = DateTime.parse(dateStr);
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}

String _formatWeekRange(String startStr, String endStr) {
  final s = DateTime.parse(startStr);
  final e = DateTime.parse(endStr);
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[s.month - 1]} ${s.day} – ${months[e.month - 1]} ${e.day}';
}

// ─── DonutChart ──────────────────────────────────────────────────────

class DonutSegment {
  final double value;
  final Color color;
  final String label;
  const DonutSegment({required this.value, required this.color, required this.label});
}

class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;
  final double strokeWidth;
  final String centerText;
  final String? centerSubtext;
  const DonutChart({super.key, required this.segments, this.size = 180, this.strokeWidth = 32, required this.centerText, this.centerSubtext});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(segments: segments, strokeWidth: strokeWidth),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerText, style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w800)),
              if (centerSubtext != null)
                Text(centerSubtext!, style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  final double strokeWidth;
  _DonutPainter({required this.segments, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = segments.fold(0.0, (s, seg) => s + seg.value);

    if (total == 0) {
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = AppColors.border;
      canvas.drawCircle(center, radius, paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final sweep = (seg.value / total) * 2 * math.pi;
      final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..color = seg.color..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, startAngle, sweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}

// ─── Main Screen ─────────────────────────────────────────────────────

class NutritionDetailScreen extends ConsumerStatefulWidget {
  const NutritionDetailScreen({super.key});

  @override
  ConsumerState<NutritionDetailScreen> createState() => _NutritionDetailScreenState();
}

class _NutritionDetailScreenState extends ConsumerState<NutritionDetailScreen> {
  int _activeTab = 0;
  static const _tabs = ['Calories', 'Nutrients', 'Macros'];

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(nutritionModeProvider);
    final currentDate = ref.watch(nutritionDateProvider);
    final dataAsync = ref.watch(nutritionDataProvider);
    final mealsAsync = ref.watch(nutritionMealsProvider);
    final weekChartAsync = ref.watch(nutritionWeekChartProvider);

    final weekStart = _getMonday(currentDate);
    final weekEnd = _addDays(weekStart, 6);
    final today = todayDateString();
    final isToday = currentDate == today;
    final isCurrentWeek = weekStart == _getMonday(today);
    final canGoForward = mode == 'day' ? !isToday : !isCurrentWeek;

    void navigate(int dir) {
      final delta = mode == 'day' ? dir : dir * 7;
      ref.read(nutritionDateProvider.notifier).state = _addDays(currentDate, delta);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Controls row with back button integrated
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, top: 4),
              child: Column(
                children: [
                  // Row 1: Back, Day/Week toggle, settings gear
                  Row(
                    children: [
                      SizedBox(
                        width: 36, height: 36,
                        child: AppGlassButton(
                          sfSymbol: SFSymbol('chevron.left', size: 14),
                          size: AdaptiveButtonSize.small,
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 130, height: 32,
                        child: AppSegmentedControl(
                          labels: const ['Day', 'Week'],
                          selectedIndex: mode == 'day' ? 0 : 1,
                          onValueChanged: (i) => ref.read(nutritionModeProvider.notifier).state = i == 0 ? 'day' : 'week',
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 32, height: 32,
                        child: AppGlassButton(
                          sfSymbol: SFSymbol('slider.horizontal.3', size: 12),
                          onPressed: () => context.push('/nutrition/goals'),
                          size: AdaptiveButtonSize.small,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Row 2: Date navigation (centered, full width)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: AppGlassButton(
                          sfSymbol: SFSymbol('chevron.left', size: 12),
                          onPressed: () => navigate(-1),
                          size: AdaptiveButtonSize.small,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mode == 'day' ? _formatDate(currentDate) : _formatWeekRange(weekStart, weekEnd),
                        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: AppGlassButton(
                          sfSymbol: SFSymbol('chevron.right', size: 12),
                          onPressed: canGoForward ? () => navigate(1) : null,
                          size: AdaptiveButtonSize.small,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (mode == 'week')
              Padding(
                padding: EdgeInsets.only(top: 2, bottom: 4),
                child: Text('Weekly totals', style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w400)),
              ),
            const SizedBox(height: 2),
            // Tab bar
            Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final active = _activeTab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _activeTab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? AppColors.primary : Colors.transparent, width: 2))),
                        child: Text(
                          _tabs[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5, color: active ? AppColors.primary : AppColors.textMuted),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Content
            Expanded(
              child: dataAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (err, _) => Center(child: Text('Could not load data.', style: TextStyle(color: AppColors.textMuted))),
                data: (data) {
                  try {
                    final totals = _computeTotals(data, mode);
                    final goals = _extractGoals(data);
                    final rdi = (data['rdi'] as Map<String, dynamic>?) ?? {};
                    final goalMul = mode == 'week' ? 7 : 1;

                    double getGoal(String rdiKey) {
                      if (rdiKey == '__protein') return (goals['protein_g'] ?? 150) * goalMul;
                      if (rdiKey == '__carbs') return (goals['carbs_g'] ?? 200) * goalMul;
                      if (rdiKey == '__fat') return (goals['fats_g'] ?? 65) * goalMul;
                      return ((rdi[rdiKey] as num?)?.toDouble() ?? 0) * goalMul;
                    }

                    final mealCals = _computeMealCalories(mealsAsync);
                    final carbsCal = (totals['carbs'] ?? 0) * 4;
                    final fatCal = (totals['fat'] ?? 0) * 9;
                    final proteinCal = (totals['protein'] ?? 0) * 4;
                    final macroTotalCal = carbsCal + fatCal + proteinCal;
                    final weekDays = weekChartAsync.valueOrNull ?? [];

                    return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_activeTab == 0) ..._buildCalories(totals, goals, goalMul, mealCals, isToday, mode, mealsAsync, weekDays, currentDate),
                      if (_activeTab == 1) ..._buildNutrients(totals, getGoal),
                      if (_activeTab == 2) ..._buildMacros(totals, goals, carbsCal, fatCal, proteinCal, macroTotalCal, mealsAsync, weekDays, currentDate),
                      if ((totals['items_count'] ?? 0) == 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No food logged ${mode == 'day' ? 'on this day' : 'this week'}',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body.copyWith(color: AppColors.textHint),
                          ),
                        ),
                    ],
                  );
                  } catch (e) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('Could not load nutrition data', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Data helpers ────────────────────────────────────────────────────

  Map<String, double> _computeTotals(Map<String, dynamic> data, String mode) {
    final days = (data['days'] as List?) ?? [];
    final keys = ['calories', 'protein', 'carbs', 'fat', 'items_count', ..._microFields];
    final result = <String, double>{for (final k in keys) k: 0};
    if (days.isEmpty) return result;
    if (mode == 'day') {
      final d = days[0] as Map<String, dynamic>;
      for (final k in keys) {
        result[k] = (d[k] as num?)?.toDouble() ?? 0;
      }
      return result;
    }
    for (final d in days) {
      final dm = d as Map<String, dynamic>;
      for (final k in keys) {
        result[k] = (result[k] ?? 0) + ((dm[k] as num?)?.toDouble() ?? 0);
      }
    }
    return result;
  }

  Map<String, double> _extractGoals(Map<String, dynamic> data) {
    final g = (data['goals'] as Map<String, dynamic>?) ?? {};
    return {
      'calories': (g['calories'] as num?)?.toDouble() ?? 2000,
      'protein_g': (g['protein_g'] as num?)?.toDouble() ?? 150,
      'carbs_g': (g['carbs_g'] as num?)?.toDouble() ?? 200,
      'fats_g': (g['fats_g'] as num?)?.toDouble() ?? 65,
    };
  }

  Map<String, double> _computeMealCalories(AsyncValue<List<dynamic>> mealsAsync) {
    final map = <String, double>{'breakfast': 0, 'lunch': 0, 'dinner': 0, 'snack': 0};
    final meals = mealsAsync.valueOrNull ?? [];
    for (final m in meals) {
      final type = (m.mealType as String?) ?? 'snack';
      map[type] = (map[type] ?? 0) + ((m.calories as num?)?.toDouble() ?? 0);
    }
    return map;
  }


  // ─── Calories Tab (with bar charts) ─────────────────────────────────

  List<Widget> _buildCalories(Map<String, double> totals, Map<String, double> goals, int goalMul, Map<String, double> mealCals, bool isToday, String mode, AsyncValue<List<dynamic>> mealsAsync, List<Map<String, dynamic>> weekDays, String currentDate) {
    final totalCal = totals['calories'] ?? 0;
    final calGoal = (goals['calories'] ?? 2000) * goalMul;
    final remaining = (calGoal - totalCal).round();
    final isOver = remaining < 0;
    final meals = mealsAsync.valueOrNull ?? [];

    // Top 5 calorie foods
    final topCalFoods = <({String name, double cal})>[];
    for (final m in meals) {
      try {
        final name = (m.foodName as String?) ?? 'Unknown';
        final c = (m.calories as num?)?.toDouble() ?? 0;
        if (c > 0) topCalFoods.add((name: name, cal: c));
      } catch (_) {}
    }
    topCalFoods.sort((a, b) => b.cal.compareTo(a.cal));
    final top5Cal = topCalFoods.take(5).toList();

    return [
      // ── 7-Day stacked calorie bar chart by meal type ──
      if (weekDays.isNotEmpty)
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WEEKLY CALORIES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 16),
              _buildWeeklyMealCalChart(weekDays, (goals['calories'] ?? 2000).toDouble(), currentDate),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chartLegendDot(AppColors.warning, 'Breakfast'),
                  const SizedBox(width: 10),
                  _chartLegendDot(AppColors.success, 'Lunch'),
                  const SizedBox(width: 10),
                  _chartLegendDot(AppColors.primary, 'Dinner'),
                  const SizedBox(width: 10),
                  _chartLegendDot(AppColors.danger, 'Snacks'),
                ],
              ),
            ],
          ),
        ),
      if (weekDays.isNotEmpty) const SizedBox(height: 12),

      // ── Calories by Meal donut ──
      _card(
        child: Column(
          children: [
            Text('CALORIES BY MEAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 16),
            DonutChart(
              size: 160,
              strokeWidth: 28,
              centerText: '${totalCal.round()}',
              centerSubtext: 'cal',
              segments: [
                DonutSegment(value: mealCals['breakfast'] ?? 0, color: AppColors.warning, label: 'Breakfast'),
                DonutSegment(value: mealCals['lunch'] ?? 0, color: AppColors.success, label: 'Lunch'),
                DonutSegment(value: mealCals['dinner'] ?? 0, color: AppColors.primary, label: 'Dinner'),
                DonutSegment(value: mealCals['snack'] ?? 0, color: AppColors.danger, label: 'Snacks'),
              ],
            ),
            const SizedBox(height: 16),
            for (final type in ['breakfast', 'lunch', 'dinner', 'snack'])
              _legendRow(_mealTypeColors[type]!.color, _mealTypeColors[type]!.label, mealCals[type] ?? 0, totalCal),
            if (!isToday && mode == 'day')
              Padding(padding: EdgeInsets.only(top: 12), child: Text('Meal breakdown only available for today', style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w400))),
            if (mode == 'week')
              Padding(padding: EdgeInsets.only(top: 12), child: Text('Meal breakdown available in Day mode', style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w400))),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // ── Highest calorie foods ──
      if (top5Cal.isNotEmpty) ...[
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HIGHEST CALORIE FOODS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              for (int i = 0; i < top5Cal.length; i++) ...[
                Row(
                  children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(child: Text('${i + 1}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(top5Cal[i].name, style: AppTextStyles.label, overflow: TextOverflow.ellipsis)),
                    Text('${top5Cal[i].cal.round()} cal', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
                if (i < top5Cal.length - 1) const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],

      // ── Summary stats ──
      _card(
        child: Column(
          children: [
            for (final row in [
              ('Total Calories', totalCal.round(), false),
              ('Net Calories', totalCal.round(), false),
              ('Goal', calGoal.round(), false),
              ('Remaining', remaining, true),
            ]) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(row.$1, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                    Text(
                      row.$3 && isOver ? '+${remaining.abs()}' : '${row.$2}',
                      style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700, color: row.$3 && isOver ? AppColors.dangerLight : AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              if (row.$1 != 'Remaining') Container(height: 0.5, color: AppColors.borderLight),
            ],
          ],
        ),
      ),
    ];
  }

  // ── Weekly stacked calorie chart by meal type with Y-axis ──
  Widget _buildWeeklyMealCalChart(List<Map<String, dynamic>> weekDays, double dailyGoal, String currentDate) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    double maxCal = dailyGoal;
    for (final d in weekDays) {
      final mc = (d['meal_calories'] as Map<String, dynamic>?) ?? {};
      final b = (mc['breakfast'] as num?)?.toDouble() ?? 0;
      final l = (mc['lunch'] as num?)?.toDouble() ?? 0;
      final di = (mc['dinner'] as num?)?.toDouble() ?? 0;
      final s = (mc['snack'] as num?)?.toDouble() ?? 0;
      final total = b + l + di + s;
      final dayCal = (d['calories'] as num?)?.toDouble() ?? total;
      maxCal = math.max(maxCal, dayCal);
    }
    if (maxCal == 0) maxCal = 1;
    const barHeight = 120.0;

    // Y-axis tick values (4 ticks)
    final yTicks = <int>[];
    final step = _niceStep(maxCal, 4);
    for (int v = 0; v <= maxCal + step; v += step) {
      yTicks.add(v);
      if (yTicks.length >= 5) break;
    }
    final yMax = yTicks.last.toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Y-axis labels
        SizedBox(
          width: 32,
          height: barHeight + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final t in yTicks.reversed)
                Text(t >= 1000 ? '${(t / 1000).toStringAsFixed(1)}k' : '$t',
                    style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Bars
        Expanded(
          child: SizedBox(
            height: barHeight + 20,
            child: Stack(
              children: [
                // Goal dashed line
                Positioned(
                  bottom: 20 + (dailyGoal / yMax * barHeight),
                  left: 0, right: 0,
                  child: Container(height: 1, color: AppColors.primary.withAlpha(80)),
                ),
                // Bars row
                Positioned(
                  left: 0, right: 0, bottom: 0,
                  height: barHeight + 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (int i = 0; i < weekDays.length && i < 7; i++)
                        Expanded(child: _mealCalBarColumn(weekDays[i], dayLabels[i], yMax, barHeight, currentDate)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mealCalBarColumn(Map<String, dynamic> day, String label, double yMax, double barHeight, String currentDate) {
    final mc = (day['meal_calories'] as Map<String, dynamic>?) ?? {};
    final breakfast = (mc['breakfast'] as num?)?.toDouble() ?? 0;
    final lunch = (mc['lunch'] as num?)?.toDouble() ?? 0;
    final dinner = (mc['dinner'] as num?)?.toDouble() ?? 0;
    final snack = (mc['snack'] as num?)?.toDouble() ?? 0;
    final totalCal = breakfast + lunch + dinner + snack;
    final date = day['date'] as String? ?? '';
    final isSelected = date == currentDate;
    final opacity = isSelected ? 255 : 150;
    final totalH = yMax > 0 ? (totalCal / yMax * barHeight).clamp(0.0, barHeight) : 0.0;

    final segments = <(double cal, Color color)>[
      (snack, Color.fromARGB(opacity, 0xEF, 0x44, 0x44)),
      (dinner, Color.fromARGB(opacity, 0x63, 0x66, 0xF1)),
      (lunch, Color.fromARGB(opacity, 0x10, 0xB9, 0x81)),
      (breakfast, Color.fromARGB(opacity, 0xF5, 0x9E, 0x0B)),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (int si = 0; si < segments.length; si++)
                if (segments[si].$1 > 0)
                  Builder(builder: (_) {
                    final segH = totalCal > 0 ? (segments[si].$1 / totalCal * totalH).clamp(0.0, barHeight) : 0.0;
                    final isFirst = si == segments.indexWhere((s) => s.$1 > 0);
                    final isLast = si == segments.lastIndexWhere((s) => s.$1 > 0);
                    return Container(
                      width: 24, height: segH,
                      decoration: BoxDecoration(
                        color: segments[si].$2,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(isFirst ? 4 : 0),
                          topRight: Radius.circular(isFirst ? 4 : 0),
                          bottomLeft: Radius.circular(isLast ? 4 : 0),
                          bottomRight: Radius.circular(isLast ? 4 : 0),
                        ),
                      ),
                    );
                  }),
              if (totalCal == 0)
                Container(width: 24, height: 3, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.micro.copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textMuted)),
      ],
    );
  }

  // Nice round step for Y-axis
  static int _niceStep(double maxVal, int targetTicks) {
    if (maxVal <= 0) return 100;
    final rough = maxVal / targetTicks;
    if (rough <= 0) return 100;
    final mag = math.pow(10, (math.log(rough) / math.ln10).floor()).toInt();
    if (mag <= 0) return 100;
    final residual = (rough / mag).ceil();
    if (residual <= 1) return mag;
    if (residual <= 2) return 2 * mag;
    if (residual <= 5) return 5 * mag;
    return 10 * mag;
  }

  Widget _legendRow(Color color, String label, double cal, double total) {
    final pct = total > 0 ? (cal / total * 100).round() : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
          Text('$pct% (${cal.round()} cal)', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  // ─── Nutrients Tab ───────────────────────────────────────────────────

  List<Widget> _buildNutrients(Map<String, double> totals, double Function(String) getGoal) {
    return [
      _card(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text('NUTRIENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5))),
                  SizedBox(width: 55, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5))),
                  SizedBox(width: 55, child: Text('GOAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5))),
                  SizedBox(width: 55, child: Text('LEFT', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5))),
                ],
              ),
            ),
            for (final row in _nutrientRows) ...[
              _nutrientTableRow(row, totals[row.key] ?? 0, getGoal(row.rdiKey)),
            ],
          ],
        ),
      ),
    ];
  }

  Widget _nutrientTableRow(NutrientConfig cfg, double val, double goal) {
    final pct = goal > 0 ? (val / goal * 100).clamp(0.0, 100.0) : 0.0;
    final over = goal > 0 && val > goal;
    final left = goal - val;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(cfg.label, style: AppTextStyles.label)),
              SizedBox(
                width: 55,
                child: Text('${val.round()}${cfg.unit}', textAlign: TextAlign.right,
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: over ? AppColors.dangerLight : AppColors.textSecondary)),
              ),
              SizedBox(
                width: 55,
                child: Text(goal > 0 ? '${goal.round()}${cfg.unit}' : '—', textAlign: TextAlign.right,
                    style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400)),
              ),
              SizedBox(
                width: 55,
                child: Text(
                  over ? '+${(val - goal).round()}' : goal > 0 ? '${left.round()}' : '—',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.small.copyWith(fontWeight: over ? FontWeight.w700 : FontWeight.normal, color: over ? AppColors.dangerLight : AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: AppColors.surfaceAlt),
                  FractionallySizedBox(
                    widthFactor: pct / 100,
                    child: Container(decoration: BoxDecoration(color: over ? AppColors.dangerLight : cfg.color, borderRadius: BorderRadius.circular(2))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Macros Tab ──────────────────────────────────────────────────────

  List<Widget> _buildMacros(Map<String, double> totals, Map<String, double> goals, double carbsCal, double fatCal, double proteinCal, double macroTotalCal, AsyncValue<List<dynamic>> mealsAsync, List<Map<String, dynamic>> weekDays, String currentDate) {
    final goalCalories = goals['calories'] ?? 2000;
    final macros = [
      (label: 'Carbohydrates', grams: totals['carbs'] ?? 0, cal: carbsCal, color: AppColors.water, goalG: goals['carbs_g'] ?? 200, factor: 4),
      (label: 'Fat', grams: totals['fat'] ?? 0, cal: fatCal, color: AppColors.warning, goalG: goals['fats_g'] ?? 65, factor: 9),
      (label: 'Protein', grams: totals['protein'] ?? 0, cal: proteinCal, color: AppColors.macroProtein, goalG: goals['protein_g'] ?? 150, factor: 4),
    ];

    final meals = mealsAsync.valueOrNull ?? [];

    // Build top-3 lists for each macro from meal entries
    List<({String name, double value})> topForMacro(String field) {
      final items = <({String name, double value})>[];
      for (final m in meals) {
        try {
          final name = (m.foodName as String?) ?? 'Unknown';
          double v = 0;
          if (field == 'carbs') v = (m.carbs as num?)?.toDouble() ?? 0;
          if (field == 'fat') v = (m.fat as num?)?.toDouble() ?? 0;
          if (field == 'protein') v = (m.protein as num?)?.toDouble() ?? 0;
          if (v > 0) items.add((name: name, value: v));
        } catch (_) {}
      }
      items.sort((a, b) => b.value.compareTo(a.value));
      return items.take(3).toList();
    }

    final highestMap = {
      'Carbohydrates': topForMacro('carbs'),
      'Fat': topForMacro('fat'),
      'Protein': topForMacro('protein'),
    };

    return [
      _card(
        child: Column(
          children: [
            Text('MACRO SPLIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 16),
            DonutChart(
              size: 180,
              strokeWidth: 32,
              centerText: '${macroTotalCal.round()}',
              centerSubtext: 'cal',
              segments: [
                DonutSegment(value: carbsCal, color: AppColors.water, label: 'Carbs'),
                DonutSegment(value: fatCal, color: AppColors.warning, label: 'Fat'),
                DonutSegment(value: proteinCal, color: AppColors.macroProtein, label: 'Protein'),
              ],
            ),
            const SizedBox(height: 16),
            for (final m in macros) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: m.color, borderRadius: BorderRadius.circular(2)),
                      child: Center(
                        child: Text(
                          m.label[0],
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white, height: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${m.label} (${m.grams.round()}g)', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                          Text(
                            'Total ${macroTotalCal > 0 ? (m.cal / macroTotalCal * 100).round() : 0}% · Goal ${goalCalories > 0 ? (m.goalG * m.factor / goalCalories * 100).round() : 0}%',
                            style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      // ── 7-Day stacked macro bar chart ──
      if (weekDays.isNotEmpty)
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WEEKLY MACROS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 16),
              _buildWeeklyMacroChart(weekDays, currentDate),
              const SizedBox(height: 12),
              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chartLegendDot(AppColors.water, 'Carbs'),
                  const SizedBox(width: 16),
                  _chartLegendDot(AppColors.macroProtein, 'Protein'),
                  const SizedBox(width: 16),
                  _chartLegendDot(AppColors.warning, 'Fat'),
                ],
              ),
            ],
          ),
        ),
      if (weekDays.isNotEmpty) const SizedBox(height: 12),
      for (final macro in ['Carbohydrates', 'Fat', 'Protein']) ...[
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HIGHEST IN ${macro.toUpperCase()}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              if ((highestMap[macro] ?? []).isEmpty)
                Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text("No foods logged yet", style: AppTextStyles.body.copyWith(color: AppColors.textHint))))
              else
                for (final item in highestMap[macro]!)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.name, style: AppTextStyles.label, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text('${item.value.toStringAsFixed(1)}g', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  // ── Weekly macro stacked bar chart with Y-axis ──
  Widget _buildWeeklyMacroChart(List<Map<String, dynamic>> weekDays, String currentDate) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    double maxCal = 0;
    for (final d in weekDays) {
      final c = ((d['carbs'] as num?)?.toDouble() ?? 0) * 4;
      final p = ((d['protein'] as num?)?.toDouble() ?? 0) * 4;
      final f = ((d['fat'] as num?)?.toDouble() ?? 0) * 9;
      maxCal = math.max(maxCal, c + p + f);
    }
    if (maxCal == 0) maxCal = 1;
    const barHeight = 120.0;

    final yTicks = <int>[];
    final step = _niceStep(maxCal, 4);
    for (int v = 0; v <= maxCal + step; v += step) {
      yTicks.add(v);
      if (yTicks.length >= 5) break;
    }
    final yMax = yTicks.last.toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Y-axis
        SizedBox(
          width: 32,
          height: barHeight + 20,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final t in yTicks.reversed)
                Text(t >= 1000 ? '${(t / 1000).toStringAsFixed(1)}k' : '$t',
                    style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: SizedBox(
            height: barHeight + 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < weekDays.length && i < 7; i++)
                  Expanded(
                    child: _macroStackColumn(weekDays[i], dayLabels[i], yMax, barHeight, currentDate),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _macroStackColumn(Map<String, dynamic> day, String label, double maxCal, double barHeight, String currentDate) {
    final carbsG = (day['carbs'] as num?)?.toDouble() ?? 0;
    final proteinG = (day['protein'] as num?)?.toDouble() ?? 0;
    final fatG = (day['fat'] as num?)?.toDouble() ?? 0;
    final carbsCal = carbsG * 4;
    final proteinCal = proteinG * 4;
    final fatCal = fatG * 9;
    final totalCal = carbsCal + proteinCal + fatCal;
    final date = day['date'] as String? ?? '';
    final isSelected = date == currentDate;
    final totalH = maxCal > 0 ? (totalCal / maxCal * barHeight).clamp(0.0, barHeight) : 0.0;
    final carbsH = totalCal > 0 ? (carbsCal / totalCal * totalH) : 0.0;
    final proteinH = totalCal > 0 ? (proteinCal / totalCal * totalH) : 0.0;
    final fatH = totalCal > 0 ? (fatCal / totalCal * totalH) : 0.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (fatH > 0)
                Container(
                  width: 24, height: fatH,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.warning : AppColors.warning.withAlpha(120),
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(fatH == totalH ? 4 : 0), topRight: Radius.circular(fatH == totalH ? 4 : 0)),
                  ),
                ),
              if (proteinH > 0)
                Container(
                  width: 24, height: proteinH,
                  color: isSelected ? AppColors.macroProtein : AppColors.macroProtein.withAlpha(120),
                ),
              if (carbsH > 0)
                Container(
                  width: 24, height: carbsH,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.water : AppColors.water.withAlpha(120),
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
                  ),
                ),
              if (totalCal == 0)
                Container(width: 24, height: 3, decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(4))),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.micro.copyWith(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.primary : AppColors.textMuted)),
      ],
    );
  }

  Widget _chartLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.micro.copyWith(fontWeight: FontWeight.w400)),
      ],
    );
  }

  // ─── Card helper ─────────────────────────────────────────────────────

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: child,
    );
  }
}
