import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../utils/modal_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../models/measurement.dart';
import '../../providers/measurements_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/measurements_service.dart';
import '../../utils/weight_utils.dart';

class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measAsync = ref.watch(measurementsProvider);
    final statsAsync = ref.watch(measurementStatsProvider);
    final weightUnit =
        ref.watch(settingsProvider).valueOrNull?.weightUnit ?? 'kg';

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref, weightUnit),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Custom header
            Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 16,
                top: 4,
                bottom: 8,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Semantics(
                      label: 'Navigate back',
                      button: true,
                      child: AppGlassButton(
                        sfSymbol: SFSymbol('chevron.left', size: 14),
                        size: AdaptiveButtonSize.small,
                        onPressed: () => context.pop(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Weight & Measurements', style: AppTextStyles.headline),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  ref.invalidate(measurementsProvider);
                  ref.invalidate(measurementStatsProvider);
                  await ref.read(measurementsProvider.future);
                },
                child: measAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator.adaptive()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load data. Pull to retry.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        AppGlassButton(
                          onPressed: () => ref.invalidate(measurementsProvider),
                          label: 'Retry',
                          style: AdaptiveButtonStyle.plain,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                  data: (measurements) => ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    children: [
                      if (measurements.length >= 2) ...[
                        _WeightChart(
                          measurements: measurements,
                          weightUnit: weightUnit,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _StatsRow(statsAsync: statsAsync, weightUnit: weightUnit),
                      const SizedBox(height: 16),
                      Text('History', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 8),
                      if (measurements.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              'No measurements yet.\nTap + to add your first entry.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ),
                        )
                      else
                        ...measurements.map(
                          (m) => _MeasurementTile(
                            measurement: m,
                            weightUnit: weightUnit,
                            onDelete: () async {
                              if (m.id == null) return;
                              try {
                                await MeasurementsService.delete(m.id!);
                                ref.invalidate(measurementsProvider);
                                ref.invalidate(measurementStatsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  AdaptiveSnackBar.show(
                                    context,
                                    message:
                                        'Something went wrong. Please try again.',
                                    type: AdaptiveSnackBarType.error,
                                  );
                                }
                              }
                            },
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
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref, String weightUnit) {
    final weightCtrl = TextEditingController();
    final bfCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showAppSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Measurement',
              style: AppTextStyles.title.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            AdaptiveTextField(
              controller: weightCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: AppColors.textPrimary),
              placeholder: 'Weight ($weightUnit)',
              prefixIcon: const Icon(Icons.monitor_weight_outlined),
              autofocus: true,

              cupertinoDecoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: bfCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(color: AppColors.textPrimary),
              placeholder: 'Body Fat % (optional)',
              prefixIcon: const Icon(Icons.percent),

              cupertinoDecoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            AdaptiveTextField(
              controller: notesCtrl,
              style: TextStyle(color: AppColors.textPrimary),
              placeholder: 'Notes (optional)',
              prefixIcon: const Icon(Icons.notes),

              cupertinoDecoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppGlassButton(
                onPressed: () async {
                  final w = double.tryParse(weightCtrl.text.trim());
                  if (w == null || w <= 0) {
                    AdaptiveSnackBar.show(
                      context,
                      message: 'Enter a valid weight',
                      type: AdaptiveSnackBarType.info,
                    );
                    return;
                  }

                  final weightKg = displayToKg(w, weightUnit);
                  final bf = double.tryParse(bfCtrl.text.trim());
                  final notes = notesCtrl.text.trim();

                  try {
                    await MeasurementsService.log(
                      Measurement(
                        weightKg: weightKg,
                        bodyFatPercentage: bf,
                        notes: notes.isEmpty ? null : notes,
                      ),
                    );
                    ref.invalidate(measurementsProvider);
                    ref.invalidate(measurementStatsProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      AdaptiveSnackBar.show(
                        context,
                        message: 'Measurement saved',
                        type: AdaptiveSnackBarType.success,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AdaptiveSnackBar.show(
                        context,
                        message: 'Something went wrong. Please try again.',
                        type: AdaptiveSnackBarType.error,
                      );
                    }
                  }
                },
                label: 'Save',
                color: AppColors.primary,
                size: AdaptiveButtonSize.large,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Weight Chart ────────────────────────────────────────────────────────

class _WeightChart extends StatelessWidget {
  final List<Measurement> measurements;
  final String weightUnit;

  const _WeightChart({required this.measurements, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    // Take last 30, reversed so oldest → newest
    final data = measurements.take(30).toList().reversed.toList();
    if (data.length < 2) return const SizedBox.shrink();

    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final w = kgToDisplay(data[i].weightKg, weightUnit) ?? 0;
      spots.add(FlSpot(i.toDouble(), w));
    }

    final weights = spots.map((s) => s.y);
    final minY = weights.reduce((a, b) => a < b ? a : b) - 2;
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 2;

    return AdaptiveCard(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: ((maxY - minY) / 4).clamp(1, 100),
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.border, strokeWidth: 0.5),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: (data.length / 5).ceilToDouble().clamp(1, 30),
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox.shrink();
                      }
                      final dt = DateTime.tryParse(data[idx].createdAt ?? '');
                      if (dt == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat('d/M').format(dt),
                          style: AppTextStyles.small.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: ((maxY - minY) / 4).clamp(1, 100),
                    getTitlesWidget: (value, _) => Text(
                      value.toStringAsFixed(0),
                      style: AppTextStyles.small.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map(
                        (s) => LineTooltipItem(
                          '${s.y.toStringAsFixed(1)} $weightUnit',
                          AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textOnPrimary,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: AppColors.primary,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.primary,
                      strokeWidth: 1.5,
                      strokeColor: AppColors.textOnPrimary,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                    ),
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

// ─── Stats Row ───────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AsyncValue<Map<String, dynamic>> statsAsync;
  final String weightUnit;

  const _StatsRow({required this.statsAsync, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    return statsAsync.when(
      loading: () => const SizedBox(
        height: 70,
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        final currentKg = (stats['current_weight'] as num?)?.toDouble();
        final lowestKg = (stats['lowest_weight'] as num?)?.toDouble();
        final changeKg = (stats['weight_change'] as num?)?.toDouble();

        final current =
            kgToDisplay(currentKg, weightUnit)?.toStringAsFixed(1) ?? '—';
        final lowest =
            kgToDisplay(lowestKg, weightUnit)?.toStringAsFixed(1) ?? '—';
        final change = kgToDisplay(changeKg, weightUnit);
        final changeStr = change != null
            ? '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}'
            : '—';
        final changeColor = change != null
            ? (change <= 0 ? AppColors.success : AppColors.danger)
            : AppColors.textSecondary;

        return Row(
          children: [
            _StatCard(label: 'Current', value: current, unit: weightUnit),
            const SizedBox(width: 8),
            _StatCard(label: 'Lowest', value: lowest, unit: weightUnit),
            const SizedBox(width: 8),
            _StatCard(
              label: 'Change',
              value: changeStr,
              unit: weightUnit,
              valueColor: changeColor,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AdaptiveCard(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: AppTextStyles.title.copyWith(
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$label ($unit)',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Measurement Tile ────────────────────────────────────────────────────

class _MeasurementTile extends StatelessWidget {
  final Measurement measurement;
  final String weightUnit;
  final VoidCallback onDelete;

  const _MeasurementTile({
    required this.measurement,
    required this.weightUnit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(measurement.createdAt ?? '');
    final dateStr = dt != null
        ? DateFormat('MMM d, y').format(dt)
        : 'Unknown date';
    final weight =
        kgToDisplay(measurement.weightKg, weightUnit)?.toStringAsFixed(1) ??
        '—';

    return Dismissible(
      key: ValueKey(measurement.id ?? measurement.createdAt),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.textOnPrimary),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: AdaptiveCard(
        color: AppColors.surface,
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: const Icon(
              Icons.monitor_weight_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          title: Text(
            '$weight $weightUnit',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            [
              dateStr,
              if (measurement.bodyFatPercentage != null)
                '${measurement.bodyFatPercentage!.toStringAsFixed(1)}% BF',
            ].join(' · '),
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w400),
          ),
          trailing: measurement.notes != null && measurement.notes!.isNotEmpty
              ? Tooltip(
                  message: measurement.notes!,
                  child: Icon(
                    Icons.notes,
                    size: 18,
                    color: AppColors.iconMuted,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
