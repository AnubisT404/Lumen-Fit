import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../config/theme.dart';
import '../utils/modal_utils.dart';
import '../utils/weight_utils.dart';

/// Standard picker sheet radius (smaller than full modals).
const _kPickerSheetRadius = 20.0;

/// Default picker item extent.
const _kPickerItemExtent = 42.0;

/// Default total sheet height.
const _kSheetHeight = 320.0;

// ─── Reusable Picker Bottom Sheet ─────────────────────────────────────

/// Shows a standardized picker bottom sheet with glass-styled Cancel/Done
/// buttons and a centered title.
///
/// [title] — center toolbar label (e.g. "Set 1", "Calories", "Jump to Date").
/// [titleColor] — optional accent color for the title badge.
/// [confirmColor] — accent color for the Done button.
/// [onConfirm] — called when Done is tapped (sheet auto-pops before calling).
/// [height] — total sheet height (default 320).
/// [child] — the picker content below the toolbar.
Future<void> showPickerSheet({
  required BuildContext context,
  required String title,
  Color? titleColor,
  Color? confirmColor,
  required VoidCallback onConfirm,
  double height = _kSheetHeight,
  required Widget child,
  bool useRootNavigator = true,
}) {
  return showAppSheet(
    context: context,
    useRootNavigator: useRootNavigator,
    builder: (ctx) => Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(_kPickerSheetRadius)),
      ),
      child: Column(
        children: [
          PickerToolbar(
            title: title,
            titleColor: titleColor,
            confirmColor: confirmColor,
            onCancel: () => Navigator.pop(ctx),
            onConfirm: () {
              Navigator.pop(ctx);
              onConfirm();
            },
          ),
          Container(height: 0.5, color: AppColors.surfaceAlt),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

// ─── Picker Toolbar ───────────────────────────────────────────────────

/// Standard toolbar with Cancel (left) / Title (center) / Done (right).
/// Uses AdaptiveButton with glass style and explicit width for iOS 26
/// native UIKit view compatibility.
class PickerToolbar extends StatelessWidget {
  const PickerToolbar({
    super.key,
    required this.title,
    this.titleColor,
    this.confirmColor,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel = 'Done',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final Color? titleColor;
  final Color? confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 80, height: 36,
            child: AppGlassButton(
              onPressed: onCancel,
              label: cancelLabel,
              style: AdaptiveButtonStyle.glass,
              size: AdaptiveButtonSize.small,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ),
          SizedBox(
            width: 72, height: 36,
            child: AppGlassButton(
              onPressed: onConfirm,
              label: confirmLabel,
              style: AdaptiveButtonStyle.glass,
              color: confirmColor ?? AppColors.primary,
              size: AdaptiveButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weight × Reps Picker ─────────────────────────────────────────────

/// A dual-column CupertinoPicker for weight and reps, used across the
/// new workout screen and history edit.
///
/// Call [showWeightRepsPicker] as a convenience.
Future<void> showWeightRepsPicker({
  required BuildContext context,
  required int setNumber,
  required String unit,
  required double? currentWeight,
  required int? currentReps,
  required Color accentColor,
  bool showWeight = true,
  required void Function(double? weight, int? reps) onConfirm,
}) {
  HapticFeedback.mediumImpact();

  final wStep = weightIncrement(unit);
  final wMax = unit == 'lb' ? 600.0 : 300.0;
  final weights = <double>[for (double v = 0; v <= wMax; v += wStep) v];
  final reps = <int>[for (int v = 0; v <= 100; v++) v];

  int wIdx = 0;
  if (currentWeight != null && currentWeight > 0) {
    wIdx = weights.indexWhere((v) => (v - currentWeight).abs() < wStep / 2);
    if (wIdx < 0) wIdx = 0;
  }
  int rIdx = currentReps ?? 0;

  double selWeight = currentWeight ?? 0;
  int selReps = currentReps ?? 0;

  final wCtrl = FixedExtentScrollController(initialItem: wIdx);
  final rCtrl = FixedExtentScrollController(initialItem: rIdx);

  return showPickerSheet(
    context: context,
    title: 'Set $setNumber',
    titleColor: accentColor,
    confirmColor: accentColor,
    onConfirm: () {
      onConfirm(
        selWeight > 0 ? selWeight : null,
        selReps > 0 ? selReps : null,
      );
    },
    child: Column(
      children: [
        if (showWeight)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'WEIGHT ($unit)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted.withAlpha(150),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
                if (showWeight) const SizedBox(width: 24),
                Expanded(
                  child: Center(
                    child: Text(
                      'REPS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted.withAlpha(150),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              if (showWeight)
                Expanded(
                  child: CupertinoPicker(
                    scrollController: wCtrl,
                    itemExtent: _kPickerItemExtent,
                    magnification: 1.1,
                    squeeze: 1.05,
                    useMagnifier: true,
                    onSelectedItemChanged: (i) {
                      HapticFeedback.selectionClick();
                      selWeight = weights[i];
                    },
                    children: weights.map((v) {
                      final txt = v == v.roundToDouble()
                          ? v.toInt().toString()
                          : v.toStringAsFixed(1);
                      return Center(
                        child: Text(txt, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
                ),
              if (showWeight)
                Container(
                  width: 24,
                  alignment: Alignment.center,
                  child: Text(
                    '\u00D7',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      color: AppColors.textMuted.withAlpha(100),
                    ),
                  ),
                ),
              Expanded(
                child: CupertinoPicker(
                  scrollController: rCtrl,
                  itemExtent: _kPickerItemExtent,
                  magnification: 1.1,
                  squeeze: 1.05,
                  useMagnifier: true,
                  onSelectedItemChanged: (i) {
                    HapticFeedback.selectionClick();
                    selReps = reps[i];
                  },
                  children: reps.map((v) => Center(
                    child: Text('$v', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Single-Column Number Picker ──────────────────────────────────────

/// Shows a single-column number picker (used for calories, macros, etc).
Future<void> showNumberPicker({
  required BuildContext context,
  required String title,
  required List<int> items,
  required int initialIndex,
  Color? accentColor,
  String suffix = '',
  required void Function(int selectedValue) onConfirm,
}) {
  HapticFeedback.mediumImpact();

  int idx = initialIndex;
  final ctrl = FixedExtentScrollController(initialItem: idx);

  return showPickerSheet(
    context: context,
    title: title,
    titleColor: accentColor,
    confirmColor: accentColor,
    height: 280,
    onConfirm: () => onConfirm(items[idx]),
    child: CupertinoPicker(
      scrollController: ctrl,
      itemExtent: 32,
      useMagnifier: true,
      magnification: 2.35 / 2.1,
      squeeze: 1.25,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: AppColors.dividerIOS,
      ),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        idx = i;
      },
      children: items.map((v) => Center(
        child: Text(
          suffix.isNotEmpty ? '$v $suffix' : '$v',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
      )).toList(),
    ),
  );
}

// ─── Icon-Toolbar Picker Sheet (nutrition/goals style) ────────────────

/// Shows a picker sheet with SF Symbol icon buttons (xmark / checkmark).
/// Used in nutrition goals screens for a cleaner, minimal toolbar.
Future<void> showIconPickerSheet({
  required BuildContext context,
  required String title,
  Color? confirmColor,
  required VoidCallback onConfirm,
  double height = 280,
  bool isScrollControlled = false,
  required Widget child,
}) {
  return showAppSheet(
    context: context,
    isScrollControlled: isScrollControlled,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PickerIconToolbar(
              title: title,
              confirmColor: confirmColor,
              onCancel: () => Navigator.pop(ctx),
              onConfirm: () {
                Navigator.pop(ctx);
                onConfirm();
              },
            ),
            const Divider(height: 1),
            SizedBox(height: height - 60, child: child),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Toolbar with icon buttons (xmark / checkmark) for goals/nutrition pickers.
class PickerIconToolbar extends StatelessWidget {
  const PickerIconToolbar({
    super.key,
    required this.title,
    this.confirmColor,
    required this.onCancel,
    required this.onConfirm,
    this.titleWidget,
  });

  final String title;
  final Color? confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  /// Optional custom center widget (overrides title text).
  final Widget? titleWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: AppSize.minTouchTarget, height: AppSize.minTouchTarget,
            child: Center(
              child: SizedBox(
                width: 32, height: 32,
                child: AppGlassButton(
                  sfSymbol: SFSymbol('xmark', size: 14),
                  style: AdaptiveButtonStyle.glass,
                  size: AdaptiveButtonSize.small,
                  onPressed: onCancel,
                ),
              ),
            ),
          ),
          titleWidget ?? Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(
            width: AppSize.minTouchTarget, height: AppSize.minTouchTarget,
            child: Center(
              child: SizedBox(
                width: 32, height: 32,
                child: AppGlassButton(
                  sfSymbol: SFSymbol('checkmark', size: 14),
                  style: AdaptiveButtonStyle.glass,
                  color: confirmColor ?? AppColors.primary,
                  size: AdaptiveButtonSize.small,
                  onPressed: onConfirm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── List Picker Sheet ────────────────────────────────────────────────

/// Shows a list-selection picker (used for weekly goal, activity level, etc).
Future<void> showListPickerSheet({
  required BuildContext context,
  required String title,
  required List<(String, String)> options,
  required String currentValue,
  required ValueChanged<String> onSelect,
}) {
  return showAppSheet(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.6,
    ),
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 32, height: 32,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('xmark', size: 14),
                      style: AdaptiveButtonStyle.glass,
                      size: AdaptiveButtonSize.small,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: options.map((o) => Material(
                  color: AppColors.surface,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      onSelect(o.$1);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              o.$2,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: currentValue == o.$1 ? FontWeight.w600 : FontWeight.w400,
                                color: currentValue == o.$1 ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (currentValue == o.$1)
                            const Icon(Icons.check, size: 20, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

// ─── Helpers ──────────────────────────────────────────────────────────

// weightIncrement is re-exported from ../utils/weight_utils.dart
