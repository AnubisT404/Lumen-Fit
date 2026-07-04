import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/dashboard_data.dart';
import '../utils/date_utils.dart';

class WeekStreak extends StatelessWidget {
  final List<WeekDay> days;

  const WeekStreak({super.key, required this.days});

  bool _isToday(WeekDay d) => !d.future && d.date == todayDateString();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: days.map((d) {
        final isToday = _isToday(d);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _DayDot(day: d, isToday: isToday),
        );
      }).toList(),
    );
  }
}

class _DayDot extends StatelessWidget {
  final WeekDay day;
  final bool isToday;

  const _DayDot({required this.day, required this.isToday});

  String get _label {
    if (day.day.isNotEmpty) return day.day.substring(0, 1).toUpperCase();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final status = day.logged ? 'logged' : (isToday ? 'today, not logged' : 'not logged');
    return Semantics(
      label: '${day.day}, $status',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDot(),
          const SizedBox(height: 4),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot() {
    const dotSize = 12.0;

    // Logged day: green filled with checkmark + subtle glow
    if (day.logged) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.success,
          border: isToday
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isToday
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.success.withValues(alpha: 0.4),
              blurRadius: isToday ? 6 : 4,
              spreadRadius: isToday ? 1.5 : 0.5,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, size: 8, color: Colors.white),
      );
    }

    // Today (not logged): slate fill with indigo ring + glow
    if (isToday) {
      return Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.textMuted,
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 6,
              spreadRadius: 1.5,
            ),
          ],
        ),
      );
    }

    // Not logged (past or future): gray outlined circle
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
    );
  }
}
