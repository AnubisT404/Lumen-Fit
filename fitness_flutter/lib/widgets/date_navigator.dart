import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import 'picker_sheet.dart';

/// Shared date navigation header with left/right chevrons and a date picker.
class DateNavigator extends StatelessWidget {
  final String date;
  final ValueChanged<int> onDateChange;
  final ValueChanged<DateTime> onPickDate;

  const DateNavigator({
    super.key,
    required this.date,
    required this.onDateChange,
    required this.onPickDate,
  });

  String get _displayLabel {
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (date == todayStr) return 'Today';

    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
    if (date == yesterdayStr) return 'Yesterday';

    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowStr =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    if (date == tomorrowStr) return 'Tomorrow';

    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    return DateFormat('EEE, MMM d').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(date) ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 26),
            color: AppColors.iconMuted,
            onPressed: () => onDateChange(-1),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                final minDate = DateTime(2024);
                final maxDate = DateTime.now().add(const Duration(days: 1));
                // Clamp initial date within [min, max] to prevent assertion crash
                var initial = parsed;
                if (initial.isAfter(maxDate)) initial = maxDate;
                if (initial.isBefore(minDate)) initial = minDate;
                var tempDate = initial;
                showPickerSheet(
                  context: context,
                  title: 'Jump to Date',
                  confirmColor: AppColors.primary,
                  height: 260,
                  onConfirm: () => onPickDate(tempDate),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: initial,
                    minimumDate: minDate,
                    maximumDate: maxDate,
                    onDateTimeChanged: (d) => tempDate = d,
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.calendar_today_rounded,
                      size: 14, color: AppColors.iconMuted),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 26),
            color: AppColors.iconMuted,
            onPressed: () => onDateChange(1),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
