import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../models/food_item.dart';
import '../../models/profile.dart';
import '../../utils/modal_utils.dart';
import 'add_food_models.dart';

// ═══════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class SourceToggle extends StatelessWidget {
  final String source;
  final ValueChanged<String> onChanged;
  const SourceToggle({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppSegmentedControl(
        labels: const ['Local DB', 'OpenFoodFacts'],
        selectedIndex: source == 'all' ? 0 : 1,
        onValueChanged: (i) => onChanged(i == 0 ? 'all' : 'off'),
      ),
    );
  }
}

class ToggleChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const ToggleChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.textPrimary.withAlpha(13),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class TapRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const TapRow({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MealDropdownRow extends StatefulWidget {
  final String mealType;
  final ValueChanged<String> onChanged;
  const MealDropdownRow({required this.mealType, required this.onChanged});

  @override
  State<MealDropdownRow> createState() => _MealDropdownRowState();
}

class _MealDropdownRowState extends State<MealDropdownRow> {
  static const _labels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snacks',
  };
  static const _keys = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Text(
            'Meal',
            style: AppTextStyles.subheading.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 120,
            height: 34,
            child: AppPopupMenu<String>(
              label: _labels[widget.mealType] ?? 'Meal',
              buttonStyle: PopupButtonStyle.glass,
              shrinkWrap: true,
              items: _keys
                  .map(
                    (k) => AdaptivePopupMenuItem<String>(
                      label: _labels[k]!,
                      value: k,
                    ),
                  )
                  .toList(),
              onSelected: (index, entry) {
                if (entry.value != null)
                  widget.onChanged(entry.value as String);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Food Result Tile ─────────────────────────────────────────────────
class FoodResultTile extends StatelessWidget {
  final FoodItem food;
  final VoidCallback onTap;
  const FoodResultTile({required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cal = food.calories?.round() ?? 0;
    final src = food.source ?? '';
    final isVerified = food.sourceQuality == 'verified';

    Color? badgeColor;
    Color? badgeTextColor;
    String? badgeLabel;

    if (src.startsWith('USDA')) {
      badgeColor = AppColors.successBg;
      badgeTextColor = AppColors.successDark;
      badgeLabel = 'USDA';
    } else if (src == 'MFP' && isVerified) {
      badgeColor = AppColors.primaryUltraLight;
      badgeTextColor = AppColors.blue;
      badgeLabel = '✓ MFP';
    } else if (src == 'MFP') {
      badgeColor = AppColors.surfaceAlt;
      badgeTextColor = AppColors.textSecondary;
      badgeLabel = 'MFP';
    } else if (src == 'OFF' || src == 'OpenFoodFacts') {
      badgeColor = AppColors.warningBg;
      badgeTextColor = AppColors.warningDark;
      badgeLabel = 'OFF';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                          food.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badgeLabel,
                            style: AppTextStyles.micro.copyWith(
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (food.displayBrand.isNotEmpty)
                    Text(
                      food.displayBrand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.micro.copyWith(
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$cal cal',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'per serving',
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Macro Donut Chart ────────────────────────────────────────────────
class MacroDonut extends StatelessWidget {
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  const MacroDonut({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final proteinCal = protein * 4;
    final carbsCal = carbs * 4;
    final fatCal = fat * 9;
    final totalMacroCal = proteinCal + carbsCal + fatCal;

    final carbsPct = totalMacroCal > 0
        ? (carbsCal / totalMacroCal * 100).round()
        : 0;
    final fatPct = totalMacroCal > 0
        ? (fatCal / totalMacroCal * 100).round()
        : 0;
    final proteinPct = totalMacroCal > 0 ? 100 - carbsPct - fatPct : 0;

    return Row(
      children: [
        SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: DonutPainter(
              carbsPct: carbsPct / 100,
              fatPct: fatPct / 100,
              proteinPct: proteinPct / 100,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$calories', style: AppTextStyles.heading),
                  Text(
                    'cal',
                    style: AppTextStyles.micro.copyWith(
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              MacroColumn(
                label: 'Carbs',
                pct: carbsPct,
                grams: carbs,
                color: AppColors.water,
              ),
              MacroColumn(
                label: 'Fat',
                pct: fatPct,
                grams: fat,
                color: AppColors.warning,
              ),
              MacroColumn(
                label: 'Protein',
                pct: proteinPct,
                grams: protein,
                color: AppColors.danger,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MacroColumn extends StatelessWidget {
  final String label;
  final int pct;
  final int grams;
  final Color color;
  const MacroColumn({
    required this.label,
    required this.pct,
    required this.grams,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$pct%',
          style: AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text('$grams g', style: AppTextStyles.titleMedium),
        Text(
          label,
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

class DonutPainter extends CustomPainter {
  final double carbsPct;
  final double fatPct;
  final double proteinPct;
  DonutPainter({
    required this.carbsPct,
    required this.fatPct,
    required this.proteinPct,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 10.0;
    const gap = 0.04; // radians gap between segments

    final bgPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final total = carbsPct + fatPct + proteinPct;
    if (total <= 0) return;

    final segments = <MapEntry<double, Color>>[];
    if (carbsPct > 0) segments.add(MapEntry(carbsPct, AppColors.water));
    if (fatPct > 0) segments.add(MapEntry(fatPct, AppColors.warning));
    if (proteinPct > 0) segments.add(MapEntry(proteinPct, AppColors.danger));

    final totalGap = gap * segments.length;
    final usable = 2 * math.pi - totalGap;
    var startAngle = -math.pi / 2;

    for (final seg in segments) {
      final sweep = seg.key * usable;
      final paint = Paint()
        ..color = seg.value
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) =>
      oldDelegate.carbsPct != carbsPct ||
      oldDelegate.fatPct != fatPct ||
      oldDelegate.proteinPct != proteinPct;
}

// ── Unit Picker Bottom Sheet ─────────────────────────────────────────
class UnitPickerSheet extends StatelessWidget {
  final List<ServingOption> options;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  const UnitPickerSheet({
    required this.options,
    required this.selectedIndex,
    required this.onSelect,
  });

  static String _fmtLabel(String label) {
    return label.replaceAllMapped(RegExp(r'(\d+\.\d{2,})'), (m) {
      final v = double.tryParse(m.group(0)!);
      if (v == null) return m.group(0)!;
      return v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Serving Size',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
                SizedBox(
                  width: 72,
                  height: 36,
                  child: AppGlassButton(
                    onPressed: () => Navigator.pop(context),
                    label: 'Done',
                    style: AdaptiveButtonStyle.glass,
                    color: AppColors.primary,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: options.length,
              itemBuilder: (_, i) {
                final isSelected = i == selectedIndex;
                return InkWell(
                  onTap: () => onSelect(i),
                  child: Container(
                    color: isSelected ? AppColors.primary.withAlpha(20) : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _fmtLabel(options[i].label),
                            style: AppTextStyles.subheading.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check,
                            color: AppColors.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Servings Picker Bottom Sheet (CupertinoPicker) ───────────────────
class ServingsPickerSheet extends StatefulWidget {
  final double currentValue;
  final bool isGramMode;
  final ValueChanged<double> onDone;
  const ServingsPickerSheet({
    required this.currentValue,
    required this.isGramMode,
    required this.onDone,
  });

  @override
  State<ServingsPickerSheet> createState() => _ServingsPickerSheetState();
}

class _ServingsPickerSheetState extends State<ServingsPickerSheet> {
  late double _tempValue;
  bool _isFrac = true;

  static const _decOptions = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    2.5,
    3.0,
    3.5,
    4.0,
    4.5,
    5.0,
    6.0,
    7.0,
    8.0,
    9.0,
    10.0,
    12.0,
    15.0,
    20.0,
  ];
  static const _fracLabels = ['-', '⅛', '¼', '⅓', '½', '⅔', '¾'];
  static const _fracValues = [0.0, 0.125, 0.25, 1 / 3, 0.5, 2 / 3, 0.75];

  // Controllers stored as fields so CupertinoPicker's internal scroll
  // listener (which plays SystemSound.tick) stays attached.
  late final FixedExtentScrollController _gramCtrl;
  late final FixedExtentScrollController _decCtrl;
  late final FixedExtentScrollController _fracWholeCtrl;
  late final FixedExtentScrollController _fracPartCtrl;

  @override
  void initState() {
    super.initState();
    _tempValue = widget.currentValue;
    _isFrac = !widget.isGramMode;

    _gramCtrl = FixedExtentScrollController(
      initialItem: (_tempValue.round() - 1).clamp(0, 499),
    );

    final decIdx = _decOptions.indexWhere((v) => (v - _tempValue).abs() < 0.01);
    _decCtrl = FixedExtentScrollController(
      initialItem: decIdx >= 0 ? decIdx : 3,
    );

    final wholeValue = _tempValue.floor();
    _fracWholeCtrl = FixedExtentScrollController(
      initialItem: wholeValue.clamp(0, 20),
    );

    var fracIdx = 0;
    var minDist = double.infinity;
    final fracValue = _tempValue - wholeValue;
    for (int i = 0; i < _fracValues.length; i++) {
      final dist = (fracValue - _fracValues[i]).abs();
      if (dist < minDist) {
        minDist = dist;
        fracIdx = i;
      }
    }
    _fracPartCtrl = FixedExtentScrollController(initialItem: fracIdx);
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    _decCtrl.dispose();
    _fracWholeCtrl.dispose();
    _fracPartCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isGramMode ? 'Grams' : 'Servings',
                  style: AppTextStyles.subheading.copyWith(
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
                SizedBox(
                  width: 72,
                  height: 36,
                  child: AppGlassButton(
                    onPressed: () => widget.onDone(_tempValue),
                    label: 'Done',
                    style: AdaptiveButtonStyle.glass,
                    color: AppColors.primary,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ],
            ),
          ),
          // DEC/FRAC toggle (non-gram only)
          if (!widget.isGramMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ToggleChip(
                    label: 'DEC',
                    isActive: !_isFrac,
                    onTap: () => setState(() => _isFrac = false),
                  ),
                  const SizedBox(width: 4),
                  ToggleChip(
                    label: 'FRAC',
                    isActive: _isFrac,
                    onTap: () => setState(() => _isFrac = true),
                  ),
                ],
              ),
            ),
          // Picker
          SizedBox(
            height: 180,
            child: widget.isGramMode
                ? _buildGramPicker()
                : _isFrac
                ? _buildFracPicker()
                : _buildDecPicker(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGramPicker() {
    return CupertinoPicker(
      backgroundColor: Colors.transparent,
      scrollController: _gramCtrl,
      itemExtent: 32,
      useMagnifier: true,
      magnification: 2.35 / 2.1,
      squeeze: 1.25,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: AppColors.dividerIOS,
      ),
      onSelectedItemChanged: (i) => _tempValue = (i + 1).toDouble(),
      children: List.generate(
        500,
        (i) => Center(
          child: Text(
            '${i + 1}',
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w400),
          ),
        ),
      ),
    );
  }

  Widget _buildDecPicker() {
    return CupertinoPicker(
      backgroundColor: Colors.transparent,
      scrollController: _decCtrl,
      itemExtent: 32,
      useMagnifier: true,
      magnification: 2.35 / 2.1,
      squeeze: 1.25,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: AppColors.dividerIOS,
      ),
      onSelectedItemChanged: (i) => _tempValue = _decOptions[i],
      children: _decOptions.map((v) {
        String s;
        if (v == v.roundToDouble()) {
          s = '${v.round()}';
        } else if ((v * 10) == (v * 10).roundToDouble()) {
          s = v.toStringAsFixed(1);
        } else {
          s = v.toStringAsFixed(2);
        }
        return Center(
          child: Text(
            s,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w400),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFracPicker() {
    return Row(
      children: [
        Expanded(
          child: CupertinoPicker(
            backgroundColor: Colors.transparent,
            scrollController: _fracWholeCtrl,
            itemExtent: 32,
            useMagnifier: true,
            magnification: 2.35 / 2.1,
            squeeze: 1.25,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
              background: AppColors.dividerIOS,
            ),
            onSelectedItemChanged: (i) {
              _tempValue = i + (_tempValue - _tempValue.floor());
            },
            children: List.generate(
              21,
              (i) => Center(
                child: Text(
                  '$i',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: CupertinoPicker(
            backgroundColor: Colors.transparent,
            scrollController: _fracPartCtrl,
            itemExtent: 32,
            useMagnifier: true,
            magnification: 2.35 / 2.1,
            squeeze: 1.25,
            selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
              background: AppColors.dividerIOS,
            ),
            onSelectedItemChanged: (i) {
              _tempValue = _tempValue.floor() + _fracValues[i];
            },
            children: _fracLabels
                .map(
                  (l) => Center(
                    child: Text(
                      l,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ── Build Mode Card ──────────────────────────────────────────────────
class BuildModeCard extends StatefulWidget {
  final String name;
  final List<BuildingItem> items;
  final int? editId;
  final ValueChanged<String> onUpdateName;
  final ValueChanged<int> onRemoveItem;
  final ValueChanged<int> onEditItem;
  final VoidCallback onAddMore;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  const BuildModeCard({
    super.key,
    required this.name,
    required this.items,
    this.editId,
    required this.onUpdateName,
    required this.onRemoveItem,
    required this.onEditItem,
    required this.onAddMore,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<BuildModeCard> createState() => _BuildModeCardState();
}

class _BuildModeCardState extends State<BuildModeCard> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
  }

  @override
  void didUpdateWidget(BuildModeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name && _nameController.text != widget.name) {
      _nameController.text = widget.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final totalCal = items.fold(0, (s, i) => s + i.calories);
    final totalP = items.fold(0, (s, i) => s + i.proteinG);
    final totalC = items.fold(0, (s, i) => s + i.carbsG);
    final totalF = items.fold(0, (s, i) => s + i.fatsG);

    return AdaptiveCard(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(44),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.editId != null ? 'EDITING MEAL' : 'CREATING MEAL',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      height: 28,
                      child: AppGlassButton(
                        onPressed: widget.onCancel,
                        label: 'Cancel',
                        style: AdaptiveButtonStyle.plain,
                        size: AdaptiveButtonSize.small,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AdaptiveTextField(
                  placeholder: 'Meal name (e.g. Morning Oats)',
                  controller: _nameController,
                  onChanged: widget.onUpdateName,
                  style: AppTextStyles.body,
                  cupertinoDecoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
          ),
          // Items
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No items yet',
                  style: AppTextStyles.body.copyWith(color: AppColors.textHint),
                ),
              ),
            )
          else ...[
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
              InkWell(
                onTap: () => widget.onEditItem(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].food.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body,
                            ),
                            Text(
                              '${items[i].calories} cal',
                              style: AppTextStyles.micro.copyWith(
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 16,
                          color: AppColors.iconMuted,
                        ),
                        onPressed: () => widget.onRemoveItem(i),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceAlt,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${items.length} item${items.length != 1 ? 's' : ''}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    '$totalCal cal · P:${totalP}g C:${totalC}g F:${totalF}g',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: AppGlassButton(
                    onPressed: widget.onAddMore,
                    label: 'Add Food',
                    style: AdaptiveButtonStyle.bordered,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: AppGlassButton(
                    onPressed: widget.name.trim().isNotEmpty && items.isNotEmpty
                        ? widget.onSave
                        : null,
                    label: widget.editId != null ? 'Update Meal' : 'Save Meal',
                    style: AdaptiveButtonStyle.glass,
                    color: AppColors.primary,
                    enabled: widget.name.trim().isNotEmpty && items.isNotEmpty,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CreateMealButton extends StatelessWidget {
  final VoidCallback onTap;
  const CreateMealButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.primary.withAlpha(80),
            style: BorderStyle.solid,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Create a Meal',
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Template Card ────────────────────────────────────────────────────
class TemplateCard extends StatefulWidget {
  final MealTemplate template;
  final String mealType;
  final VoidCallback onLog;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const TemplateCard({
    required this.template,
    required this.mealType,
    required this.onLog,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<TemplateCard> {
  bool _expanded = false;
  bool _confirmDelete = false;

  static const _labels = {
    'breakfast': 'Breakfast',
    'lunch': 'Lunch',
    'dinner': 'Dinner',
    'snack': 'Snacks',
  };

  @override
  Widget build(BuildContext context) {
    final t = widget.template;
    return AdaptiveCard(
      color: AppColors.surface,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              _expanded = !_expanded;
              _confirmDelete = false;
            }),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(44)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w600,
                                color: DefaultTextStyle.of(context).style.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${t.itemCount} item${t.itemCount != 1 ? 's' : ''} · ${t.totalCalories.round()} cal',
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.chevron_right,
                        size: 18,
                        color: AppColors.iconMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'P: ${t.totalProteinG.round()}g  C: ${t.totalCarbsG.round()}g  F: ${t.totalFatsG.round()}g',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            for (final item in t.items)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.foodName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body,
                          ),
                          if (item.brand != null && item.brand!.isNotEmpty)
                            Text(
                              item.brand!,
                              style: AppTextStyles.micro.copyWith(
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.calories.round()} cal',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: AppGlassButton(
                      onPressed: widget.onLog,
                      label: 'Add to ${_labels[widget.mealType] ?? 'Meal'}',
                      style: AdaptiveButtonStyle.glass,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    color: AppColors.iconMuted,
                    onPressed: widget.onEdit,
                  ),
                  if (_confirmDelete)
                    Row(
                      children: [
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: widget.onDelete,
                          child: Text(
                            'Delete',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              setState(() => _confirmDelete = false),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.iconMuted,
                      onPressed: () => setState(() => _confirmDelete = true),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
