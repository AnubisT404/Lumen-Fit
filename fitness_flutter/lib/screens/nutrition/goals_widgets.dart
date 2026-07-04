import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../utils/modal_utils.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../widgets/picker_sheet.dart';

Widget goalsScreenBuildHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, right: 16, top: 4, bottom: 4),
    child: Row(
      children: [
        SizedBox(
          width: 36,
          height: 36,
          child: AppGlassButton(
            sfSymbol: SFSymbol('chevron.left', size: 14),
            size: AdaptiveButtonSize.small,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.title,
          ),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );
}

class WeightRuler extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const WeightRuler({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  State<WeightRuler> createState() => _WeightRulerState();
}

class _WeightRulerState extends State<WeightRuler> {
  late ScrollController _scrollController;
  static const double _pxPerUnit = 12.0; // pixels per 1 lb
  bool _programmatic = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(
      initialScrollOffset: (widget.value - widget.min) * _pxPerUnit,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(WeightRuler old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final offset = (widget.value - widget.min) * _pxPerUnit;
      if ((_scrollController.offset - offset).abs() > _pxPerUnit / 2) {
        _programmatic = true;
        _scrollController.jumpTo(offset);
        _programmatic = false;
      }
    }
  }

  void _onScroll() {
    if (_programmatic) return;
    final v = (widget.min + _scrollController.offset / _pxPerUnit)
        .roundToDouble();
    final clamped = v.clamp(widget.min, widget.max);
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final totalUnits = (widget.max - widget.min).toInt();
    final contentWidth = totalUnits * _pxPerUnit;

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: Container(
            width: contentWidth + width,
            padding: EdgeInsets.only(left: width / 2, right: width / 2),
            child: CustomPaint(
              size: Size(contentWidth, 80),
              painter: RulerPainter(
                minVal: widget.min.toInt(),
                maxVal: widget.max.toInt(),
                pxPerUnit: _pxPerUnit,
              ),
            ),
          ),
        ),
        // Center indicator
        Positioned(
          left: width / 2 - 1,
          top: 0,
          bottom: 20,
          child: Container(
            width: 2.5,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
  }
}

class RulerPainter extends CustomPainter {
  final int minVal;
  final int maxVal;
  final double pxPerUnit;

  RulerPainter({
    required this.minVal,
    required this.maxVal,
    required this.pxPerUnit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..color = AppColors.textMuted
      ..strokeWidth = 1.2;
    final majorPaint = Paint()
      ..color = AppColors.textSecondary
      ..strokeWidth = 1.8;
    final textStyle = AppTextStyles.caption.copyWith(
      fontWeight: FontWeight.w400,
    );

    for (int i = 0; i <= (maxVal - minVal); i++) {
      final x = i * pxPerUnit;
      final val = minVal + i;
      final isMajor = val % 10 == 0;
      final isMid = val % 5 == 0 && !isMajor;

      double tickH;
      if (isMajor) {
        tickH = 36;
      } else if (isMid) {
        tickH = 24;
      } else {
        tickH = 14;
      }

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, tickH),
        isMajor ? majorPaint : tickPaint,
      );

      if (isMajor) {
        final tp = TextPainter(
          text: TextSpan(text: '$val', style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, tickH + 4));
      }
    }
  }

  @override
  bool shouldRepaint(RulerPainter old) => false;
}

// ─────────────────────────────────────────────────────────────
// Calorie & Macro Goals sub-page
// ─────────────────────────────────────────────────────────────

class MacroGoalsPage extends StatefulWidget {
  final int calories, protein, carbs, fat;
  const MacroGoalsPage({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });
  @override
  State<MacroGoalsPage> createState() => _MacroGoalsPageState();
}

class _MacroGoalsPageState extends State<MacroGoalsPage> {
  late int _cal, _pro, _carb, _fat;

  @override
  void initState() {
    super.initState();
    _cal = widget.calories;
    _pro = widget.protein;
    _carb = widget.carbs;
    _fat = widget.fat;
  }

  int _pct(int grams, int calPerG) =>
      _cal > 0 ? ((grams * calPerG) / _cal * 100).round() : 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(
                left: 4,
                right: 16,
                top: 4,
                bottom: 4,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('chevron.left', size: 14),
                      size: AdaptiveButtonSize.small,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Calorie & Macro Goals',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.title.copyWith(fontSize: 17),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('checkmark', size: 14),
                      color: AppColors.primary,
                      size: AdaptiveButtonSize.small,
                      onPressed: () => Navigator.pop(context, {
                        'calories': _cal,
                        'protein': _pro,
                        'carbs': _carb,
                        'fat': _fat,
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Section: Default Goal
                  _sectionLabel('Default Goal'),
                  _macroRow('Calories', '$_cal', null, () {
                    _showCaloriePicker();
                  }),
                  _d(),
                  _macroRow(
                    'Carbohydrates',
                    '$_carb g',
                    '${_pct(_carb, 4)}%',
                    () {
                      _showMacroWheels();
                    },
                  ),
                  _d(),
                  _macroRow('Protein', '$_pro g', '${_pct(_pro, 4)}%', () {
                    _showMacroWheels();
                  }),
                  _d(),
                  _macroRow('Fat', '$_fat g', '${_pct(_fat, 9)}%', () {
                    _showMacroWheels();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: AppColors.border,
    child: Text(
      text,
      style: AppTextStyles.label.copyWith(
        fontWeight: FontWeight.w400,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _macroRow(String label, String val, String? pct, VoidCallback onTap) =>
      Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Text(
                  label,
                  style: AppTextStyles.subheading.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (pct == null) ...[
                  const Spacer(),
                  Text(
                    val,
                    style: AppTextStyles.subheading.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 8),
                  Text(
                    val,
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    pct,
                    style: AppTextStyles.subheading.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );

  Widget _d() => Container(
    height: 0.5,
    color: AppColors.border,
    margin: const EdgeInsets.only(left: 16),
  );

  // ── Calorie picker – Cupertino wheel ──

  void _showCaloriePicker() {
    final items = List.generate(92, (i) => 800 + i * 100);
    int idx = items.indexOf((_cal ~/ 100) * 100).clamp(0, items.length - 1);
    showIconPickerSheet(
      context: context,
      title: 'Calories',
      onConfirm: () => setState(() => _cal = items[idx]),
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

  // ── Macro wheels – % / Grams toggle with three CupertinoPickers ──

  void _showMacroWheels() {
    // Initial % values from current grams
    int carbPct = _pct(_carb, 4);
    int proPct = _pct(_pro, 4);
    int fatPct = _pct(_fat, 9);
    carbPct = ((carbPct / 5).round() * 5).clamp(0, 100);
    proPct = ((proPct / 5).round() * 5).clamp(0, 100);
    fatPct = ((fatPct / 5).round() * 5).clamp(0, 100);
    final totalInit = carbPct + proPct + fatPct;
    if (totalInit != 100 && totalInit > 0) {
      carbPct = (100 - proPct - fatPct).clamp(0, 100);
    }

    // Initial gram values
    int carbGrams = _carb;
    int proGrams = _pro;
    int fatGrams = _fat;

    bool isPercent = true; // true = %, false = Grams
    final pctValues = List.generate(21, (i) => i * 5); // 0,5,...,100
    // Gram picker: 0–500 in steps of 5
    final gramValues = List.generate(101, (i) => i * 5);

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
            // Derived values
            final totalPct = carbPct + proPct + fatPct;
            final derivedCarbG = _cal > 0
                ? ((_cal * carbPct / 100) / 4).round()
                : 0;
            final derivedProG = _cal > 0
                ? ((_cal * proPct / 100) / 4).round()
                : 0;
            final derivedFatG = _cal > 0
                ? ((_cal * fatPct / 100) / 9).round()
                : 0;

            // Derive % from grams when in gram mode
            final derivedCarbPct = _cal > 0
                ? ((carbGrams * 4) / _cal * 100).round()
                : 0;
            final derivedProPct = _cal > 0
                ? ((proGrams * 4) / _cal * 100).round()
                : 0;
            final derivedFatPct = _cal > 0
                ? ((fatGrams * 9) / _cal * 100).round()
                : 0;

            // Display values
            final dispCarbG = isPercent ? derivedCarbG : carbGrams;
            final dispProG = isPercent ? derivedProG : proGrams;
            final dispFatG = isPercent ? derivedFatG : fatGrams;
            final dispCarbPct = isPercent ? carbPct : derivedCarbPct;
            final dispProPct = isPercent ? proPct : derivedProPct;
            final dispFatPct = isPercent ? fatPct : derivedFatPct;

            // Validation
            final pctOk = isPercent ? totalPct == 100 : true;

            void onSave() {
              if (isPercent && totalPct != 100) return;
              setState(() {
                _carb = dispCarbG;
                _pro = dispProG;
                _fat = dispFatG;
              });
              Navigator.pop(ctx);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    // Header: X — toggle — ✓
                    PickerIconToolbar(
                      title: 'Macros',
                      confirmColor: pctOk
                          ? AppColors.primary
                          : AppColors.textMuted,
                      onCancel: () => Navigator.pop(ctx),
                      onConfirm: onSave,
                      titleWidget: SizedBox(
                        width: 140,
                        height: 40,
                        child: AppSegmentedControl(
                          labels: const ['%', 'Grams'],
                          selectedIndex: isPercent ? 0 : 1,
                          onValueChanged: (i) =>
                              setBS(() => isPercent = i == 0),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Macro labels — show secondary unit
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _macroLabel(
                              'Carbs',
                              isPercent ? '$dispCarbG g' : '$dispCarbPct%',
                              AppColors.success,
                            ),
                          ),
                          Expanded(
                            child: _macroLabel(
                              'Protein',
                              isPercent ? '$dispProG g' : '$dispProPct%',
                              AppColors.orange,
                            ),
                          ),
                          Expanded(
                            child: _macroLabel(
                              'Fat',
                              isPercent ? '$dispFatG g' : '$dispFatPct%',
                              AppColors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Three CupertinoPickers
                    SizedBox(
                      height: 180,
                      child: isPercent
                          ? Row(
                              children: [
                                _pctWheel(
                                  carbPct,
                                  pctValues,
                                  (v) => setBS(() => carbPct = v),
                                ),
                                _pctWheel(
                                  proPct,
                                  pctValues,
                                  (v) => setBS(() => proPct = v),
                                ),
                                _pctWheel(
                                  fatPct,
                                  pctValues,
                                  (v) => setBS(() => fatPct = v),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                _gramWheel(
                                  carbGrams,
                                  gramValues,
                                  (v) => setBS(() => carbGrams = v),
                                ),
                                _gramWheel(
                                  proGrams,
                                  gramValues,
                                  (v) => setBS(() => proGrams = v),
                                ),
                                _gramWheel(
                                  fatGrams,
                                  gramValues,
                                  (v) => setBS(() => fatGrams = v),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Footer – % total (only in % mode)
                    if (isPercent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '% Total',
                                  style: AppTextStyles.subheading,
                                ),
                                Text(
                                  '$totalPct%',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: totalPct == 100
                                        ? AppColors.successDark
                                        : AppColors.danger,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totalPct == 100
                                  ? 'Macronutrients equal 100%'
                                  : 'Macronutrients must equal 100%',
                              style: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.w400,
                                color: totalPct == 100
                                    ? AppColors.textMuted
                                    : AppColors.danger,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Footer – total grams / cals in gram mode
                    if (!isPercent)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Calories',
                              style: AppTextStyles.subheading,
                            ),
                            Text(
                              '${carbGrams * 4 + proGrams * 4 + fatGrams * 9}',
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary.withAlpha(180),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pctWheel(int current, List<int> values, ValueChanged<int> onChanged) {
    return Expanded(
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
          initialItem: current ~/ 5,
        ),
        itemExtent: 36,
        useMagnifier: true,
        magnification: 1.1,
        squeeze: 1.3,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: AppColors.dividerIOS,
        ),
        onSelectedItemChanged: (i) {
          onChanged(values[i]);
        },
        children: values
            .map(
              (v) => Center(
                child: Text(
                  '$v %',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _gramWheel(
    int current,
    List<int> values,
    ValueChanged<int> onChanged,
  ) {
    final idx = values.indexOf(
      ((current / 5).round() * 5).clamp(0, values.last),
    );
    return Expanded(
      child: CupertinoPicker(
        scrollController: FixedExtentScrollController(
          initialItem: idx.clamp(0, values.length - 1),
        ),
        itemExtent: 36,
        useMagnifier: true,
        magnification: 1.1,
        squeeze: 1.3,
        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
          background: AppColors.dividerIOS,
        ),
        onSelectedItemChanged: (i) {
          onChanged(values[i]);
        },
        children: values
            .map(
              (v) => Center(
                child: Text(
                  '$v g',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _macroLabel(String name, String secondary, Color color) => Column(
    children: [
      Text(name, style: AppTextStyles.subheading.copyWith(color: color)),
      const SizedBox(height: 2),
      Text(
        secondary,
        style: AppTextStyles.label.copyWith(
          fontWeight: FontWeight.w400,
          color: AppColors.textMuted,
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────────────────────
// Additional Nutrient Goals sub-page (editable)
// ─────────────────────────────────────────────────────────────

class NutrientGoalsPage extends StatefulWidget {
  const NutrientGoalsPage();
  @override
  State<NutrientGoalsPage> createState() => _NutrientGoalsPageState();
}

class _NutrientGoalsPageState extends State<NutrientGoalsPage> {
  // (name, default value, unit, step, max)
  static const _defs = [
    ('Saturated Fat', 31, 'g', 1, 200),
    ('Polyunsaturated Fat', 0, 'g', 1, 200),
    ('Monounsaturated Fat', 0, 'g', 1, 200),
    ('Trans Fat', 0, 'g', 1, 50),
    ('Cholesterol', 300, 'mg', 10, 1000),
    ('Sodium', 2300, 'mg', 50, 10000),
    ('Potassium', 3500, 'mg', 50, 10000),
    ('Fiber', 38, 'g', 1, 200),
    ('Sugar', 106, 'g', 1, 500),
    ('Vitamin A', 100, '%', 5, 500),
    ('Vitamin C', 100, '%', 5, 500),
    ('Calcium', 100, '%', 5, 500),
    ('Iron', 100, '%', 5, 500),
  ];

  late List<int> _values;

  @override
  void initState() {
    super.initState();
    _values = _defs.map((d) => d.$2).toList();
  }

  String _fmt(int val, String unit) {
    if (val >= 1000) {
      final s = val.toString();
      final buf = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
        buf.write(s[i]);
      }
      return '$buf $unit';
    }
    return '$val $unit';
  }

  void _editNutrient(int index) {
    final d = _defs[index];
    final step = d.$4;
    final maxVal = d.$5;
    final items = List.generate((maxVal ~/ step) + 1, (i) => i * step);
    int idx = items.indexOf(
      ((_values[index] / step).round() * step).clamp(0, maxVal),
    );
    if (idx < 0) idx = 0;

    showIconPickerSheet(
      context: context,
      title: d.$1,
      onConfirm: () => setState(() => _values[index] = items[idx]),
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
                  '$v ${d.$3}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            goalsScreenBuildHeader(context, 'Nutrient Goals'),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _defs.length + 1,
                separatorBuilder: (_, _) => Container(
                  height: 0.5,
                  color: AppColors.border,
                  margin: const EdgeInsets.only(left: 16),
                ),
                itemBuilder: (_, i) {
                  if (i == _defs.length) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.iconMuted,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'How we make recommendations',
                            style: AppTextStyles.label.copyWith(
                              fontWeight: FontWeight.w400,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final d = _defs[i];
                  return Material(
                    color: AppColors.surface,
                    child: InkWell(
                      onTap: () => _editNutrient(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.$1,
                                style: AppTextStyles.subheading.copyWith(
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            Text(
                              _fmt(_values[i], d.$3),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
