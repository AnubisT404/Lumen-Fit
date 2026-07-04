import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Unified card widget with consistent styling across all screens.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool elevated;
  final Color? color;
  final Color? borderColor;
  final bool showBorder;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.elevated = false,
    this.color,
    this.borderColor,
    this.showBorder = true,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clipBehavior,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: showBorder ? Border.all(color: borderColor ?? AppColors.borderSubtle, width: 1) : null,
        boxShadow: elevated ? AppColors.cardShadowElevated : AppColors.cardShadow,
      ),
      child: child,
    );
  }
}
