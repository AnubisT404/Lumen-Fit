import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../config/theme.dart';

/// Global notifier: `true` when NO modal is open (native views safe).
/// `false` when a modal sheet/dialog is open (native views must hide).
final nativeViewSafe = ValueNotifier<bool>(true);
int _modalRefCount = 0;

void _pushModal() {
  _modalRefCount++;
  nativeViewSafe.value = false;
}

void _popModal() {
  _modalRefCount--;
  if (_modalRefCount <= 0) {
    _modalRefCount = 0;
    nativeViewSafe.value = true;
  }
}

/// InheritedWidget that overrides [nativeViewSafe] for its subtree.
/// Used inside sheets/popups so buttons WITHIN the modal still render natively
/// (they're above the barrier and don't bleed through).
class NativeViewSafeOverride extends InheritedWidget {
  final bool safe;
  const NativeViewSafeOverride({super.key, required this.safe, required super.child});

  static bool? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NativeViewSafeOverride>()?.safe;
  }

  @override
  bool updateShouldNotify(NativeViewSafeOverride old) => old.safe != safe;
}

/// Maps SF Symbol names to their Material Icons equivalent for Android.
const sfSymbolToMaterial = <String, IconData>{
  'chevron.left': Icons.arrow_back_ios_new,
  'chevron.right': Icons.arrow_forward_ios,
  'xmark': Icons.close,
  'checkmark': Icons.check,
  'minus': Icons.remove,
  'barcode.viewfinder': Icons.qr_code_scanner,
  'line.3.horizontal': Icons.menu,
  'slider.horizontal.3': Icons.tune,
  'play.fill': Icons.play_arrow,
  'pause.fill': Icons.pause,
  'trash': Icons.delete_outline,
};

/// Drop-in replacement for [showModalBottomSheet] that automatically
/// hides native platform views (UiKitView) while the sheet is open.
///
/// On iOS 26, AdaptiveButton with glass style renders as a native UIKit
/// platform view that punches through Flutter's compositor — including
/// modal barriers. This wrapper toggles [nativeViewSafe] so buttons
/// can listen and switch to Flutter-rendered mode while a sheet is open.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  Color? backgroundColor = Colors.transparent,
  bool showDragHandle = false,
  ShapeBorder? shape,
  BoxConstraints? constraints,
}) async {
  // Hide native platform views on background screens to prevent bleed-through
  _pushModal();
  try {
    final result = await showModalBottomSheet<T>(
      context: context,
      // Re-enable native views inside the sheet (above the barrier)
      builder: (ctx) => NativeViewSafeOverride(safe: true, child: builder(ctx)),
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      backgroundColor: backgroundColor,
      showDragHandle: showDragHandle,
      shape: shape,
      constraints: constraints,
    );
    return result;
  } finally {
    _popModal();
  }
}

/// Shows an iOS 26 liquid glass alert dialog via AdaptiveAlertDialog.
/// The glass tint is now system blue (not indigo) since we removed
/// primaryColor from cupertinoOverrideTheme.
Future<void> showAppAlert({
  required BuildContext context,
  required String title,
  String? message,
  required List<AlertAction> actions,
}) async {
  _pushModal();
  try {
    await AdaptiveAlertDialog.show(
      context: context,
      title: title,
      message: message,
      actions: actions,
    );
  } finally {
    _popModal();
  }
}

/// A modal-safe glass button that automatically switches to Flutter rendering
/// when a bottom sheet is open (to prevent native UiKitView bleed-through).
///
/// Drop-in replacement for AdaptiveButton — passes all parameters through.
class AppGlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String? label;
  final IconData? icon;
  final SFSymbol? sfSymbol;
  final AdaptiveButtonStyle style;
  final AdaptiveButtonSize size;
  final Color? color;
  final Color? textColor;
  final EdgeInsetsGeometry? padding;
  final bool? enabled;

  const AppGlassButton({
    super.key,
    this.onPressed,
    this.label,
    this.icon,
    this.sfSymbol,
    this.style = AdaptiveButtonStyle.glass,
    this.size = AdaptiveButtonSize.medium,
    this.color,
    this.textColor,
    this.padding,
    this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    // Local override (inside sheet/modal) takes precedence over global flag
    final localOverride = NativeViewSafeOverride.of(context);
    if (localOverride != null) {
      return _build(localOverride);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: nativeViewSafe,
      builder: (_, safe, __) => _build(safe),
    );
  }

  Widget _build(bool safe) {
    // In light mode, buttons without an explicit color are nearly invisible.
    // Provide a subtle default so the glass effect has definition.
    final effectiveColor = color ??
        (AppColors.isDarkMode ? null : const Color(0xFF64748B)); // slate-500

    // On iOS use SF Symbol natively ONLY when native views are safe
    if (sfSymbol != null && Platform.isIOS && safe) {
      return AdaptiveButton.sfSymbol(
        sfSymbol: sfSymbol!,
        onPressed: onPressed,
        style: style,
        size: size,
        color: effectiveColor,
        useNative: true,
      );
    }
    // Resolve Material icon: explicit icon param, or auto-map from sfSymbol
    final materialIcon =
        icon ?? sfSymbolToMaterial[sfSymbol?.name] ?? Icons.circle;
    if (icon != null || sfSymbol != null) {
      return AdaptiveButton.icon(
        icon: materialIcon,
        onPressed: onPressed,
        style: style,
        size: size,
        color: effectiveColor,
        iconColor: textColor,
        useNative: safe,
      );
    }
    return AdaptiveButton(
      onPressed: onPressed,
      label: label ?? '',
      style: style,
      size: size,
      color: effectiveColor,
      textColor: textColor,
      padding: padding,
      useNative: safe,
      enabled: enabled ?? true,
    );
  }
}

/// A modal-safe segmented control that automatically switches to Flutter
/// rendering when a bottom sheet is open (to prevent native UiKitView
/// bleed-through on iOS 26).
///
/// Drop-in replacement for AdaptiveSegmentedControl.
class AppSegmentedControl extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onValueChanged;
  final bool enabled;
  final Color? color;
  final double height;
  final bool shrinkWrap;

  const AppSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onValueChanged,
    this.enabled = true,
    this.color,
    this.height = 36.0,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    // Local override (inside sheet/modal) takes precedence over global flag
    final localOverride = NativeViewSafeOverride.of(context);
    if (localOverride != null) {
      return localOverride
          ? AdaptiveSegmentedControl(
              labels: labels,
              selectedIndex: selectedIndex,
              onValueChanged: onValueChanged,
              enabled: enabled,
              color: color,
              height: height,
              shrinkWrap: shrinkWrap,
            )
          : _buildCupertinoFallback(context);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: nativeViewSafe,
      builder: (_, safe, __) {
        if (safe) {
          return AdaptiveSegmentedControl(
            labels: labels,
            selectedIndex: selectedIndex,
            onValueChanged: onValueChanged,
            enabled: enabled,
            color: color,
            height: height,
            shrinkWrap: shrinkWrap,
          );
        }
        // Flutter-rendered fallback (no UiKitView)
        return _buildCupertinoFallback(context);
      },
    );
  }

  Widget _buildCupertinoFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? CupertinoColors.white : CupertinoColors.black;

    final Map<int, Widget> children = {};
    for (int i = 0; i < labels.length; i++) {
      children[i] = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Text(
          labels[i],
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      );
    }

    Widget control = CupertinoSlidingSegmentedControl<int>(
      children: children,
      groupValue: selectedIndex,
      thumbColor: color ?? (isDark ? const Color(0xFF636366) : CupertinoColors.white),
      onValueChanged: (int? value) {
        if (enabled && value != null) {
          onValueChanged(value);
        }
      },
    );

    // Clip to prevent internal UnconstrainedBox overflow warnings
    control = ClipRect(child: control);

    control = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: control,
    );

    if (shrinkWrap) {
      control = Center(child: IntrinsicWidth(child: control));
    }

    return control;
  }
}

/// A modal-safe popup menu button that automatically switches to Flutter
/// rendering when a bottom sheet is open (to prevent native UiKitView
/// bleed-through on iOS 26).
///
/// Drop-in replacement for AdaptivePopupMenuButton.text.
class AppPopupMenu<T> extends StatelessWidget {
  final String label;
  final List<AdaptivePopupMenuEntry> items;
  final void Function(int index, AdaptivePopupMenuItem<T> entry) onSelected;
  final Color? tint;
  final double height;
  final bool shrinkWrap;
  final PopupButtonStyle buttonStyle;

  const AppPopupMenu({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.tint,
    this.height = 32.0,
    this.shrinkWrap = false,
    this.buttonStyle = PopupButtonStyle.plain,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: nativeViewSafe,
      builder: (_, safe, __) {
        if (safe) {
          return AdaptivePopupMenuButton.text<T>(
            label: label,
            items: items,
            onSelected: onSelected,
            tint: tint,
            height: height,
            shrinkWrap: shrinkWrap,
            buttonStyle: buttonStyle,
          );
        }
        // Flutter-rendered fallback — plain CupertinoButton
        return SizedBox(
          height: height,
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            onPressed: () => _showFallbackMenu(context),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: tint ?? CupertinoTheme.of(context).primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFallbackMenu(BuildContext context) {
    final menuItems = items.whereType<AdaptivePopupMenuItem<T>>().toList();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          for (int i = 0; i < menuItems.length; i++)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                onSelected(i, menuItems[i]);
              },
              child: Text(menuItems[i].label),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
