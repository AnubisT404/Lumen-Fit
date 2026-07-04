import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

/// Standard section header used across the app.
/// Displays a title with optional trailing action.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Numeric stepper with minus/plus buttons and label.
/// Extracted from routine_builder for reuse.
class AppStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const AppStepper({
    super.key,
    required this.label,
    required this.value,
    this.min = 0,
    this.max = 99,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(width: 3),
        Semantics(
          label: 'Decrease $label',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (value > min) {
                HapticFeedback.selectionClick();
                onChanged(value - 1);
              }
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.minus,
                    size: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
        Semantics(
          label: '$label: $value',
          child: SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        Semantics(
          label: 'Increase $label',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (value < max) {
                HapticFeedback.selectionClick();
                onChanged(value + 1);
              }
            },
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemFill,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.plus,
                    size: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small rounded chip for categories, tags, filters.
class AppChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    this.color,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? chipColor.withAlpha(30) : Colors.white.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? chipColor.withAlpha(80) : Colors.white.withAlpha(20),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? chipColor : AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? chipColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A labeled field with consistent styling for forms.
class AppFieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  final Widget child;

  const AppFieldLabel({
    super.key,
    required this.label,
    this.required = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            if (required)
              Text(' *',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.danger)),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// Standard glass-morphism card used as container across the app.
/// Replaces repeated `Container(decoration: BoxDecoration(color: white.withAlpha(12), ...))` pattern.
class AppGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const AppGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 14,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withAlpha(20),
          width: 0.5,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}

/// Small circular close/dismiss button (X icon).
/// Replaces duplicated close button pattern across modals, sheets, cards.
class AppCloseButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;
  final Color? iconColor;

  const AppCloseButton({
    super.key,
    required this.onTap,
    this.size = 28,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: CupertinoColors.systemFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.xmark,
          size: size * 0.45,
          color: iconColor ?? AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Empty state placeholder with icon, title, and subtitle.
/// Standardizes the empty/no-data state across all screens.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: AppColors.textSecondary.withAlpha(80)),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.orange.withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.orange.withAlpha(60), width: 0.5),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.orange,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

