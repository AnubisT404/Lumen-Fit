// Cardio form widgets: CardioForm, InputRow, IntensitySelector,
// CardioTypeSelector, PaceRow, FieldLabel.
import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../utils/modal_utils.dart';
import 'workout_form_models.dart';

const _green = AppColors.catLegs;

// ─── Field Label ─────────────────────────────────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─── Input Row ───────────────────────────────────────────────────────

class InputRow extends StatelessWidget {
  final TextEditingController controller;
  final String placeholder;
  final String suffix;
  final bool decimal;
  final VoidCallback onChanged;
  const InputRow({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.suffix,
    this.decimal = false,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AdaptiveTextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            onChanged: (_) => onChanged(),
            placeholder: placeholder,
            style: AppTextStyles.body,
            cupertinoDecoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(
            suffix,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Pace Row ────────────────────────────────────────────────────────

class PaceRow extends StatelessWidget {
  final double durationMin;
  final double distanceKm;
  const PaceRow(
      {super.key, required this.durationMin, required this.distanceKm});
  @override
  Widget build(BuildContext context) {
    final minPerKm = durationMin / distanceKm;
    final minPerMi = durationMin / (distanceKm * 0.621371);
    final kmh = distanceKm / (durationMin / 60);
    String fmt(double v) =>
        '${v.floor()}:${((v % 1) * 60).round().toString().padLeft(2, '0')}';
    return Row(
      children: [
        Text(
          '${fmt(minPerKm)} /km',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w400,
            color: _green.withAlpha(200),
          ),
        ),
        Text(
          '  •  ',
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400),
        ),
        Text(
          '${fmt(minPerMi)} /mi',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w400,
            color: _green.withAlpha(200),
          ),
        ),
        Text(
          '  •  ',
          style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400),
        ),
        Text(
          '${kmh.toStringAsFixed(1)} km/h',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w400,
            color: _green.withAlpha(200),
          ),
        ),
      ],
    );
  }
}

// ─── Intensity Selector ──────────────────────────────────────────────

class IntensitySelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const IntensitySelector(
      {super.key, required this.value, required this.onChanged});

  static const _levels = [
    ('easy', AppColors.catLegs),
    ('moderate', AppColors.yellow),
    ('hard', AppColors.danger),
    ('interval', AppColors.purple),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (level, color) in _levels) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(value == level ? '' : level),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      value == level ? color.withAlpha(40) : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: value == level
                      ? Border.all(color: color.withAlpha(80))
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  level[0].toUpperCase() + level.substring(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: value == level ? color : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (level != 'interval') const SizedBox(width: 8),
        ],
      ],
    );
  }
}

// ─── Cardio Type Selector ────────────────────────────────────────────

class CardioTypeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const CardioTypeSelector(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 38,
      child: AppPopupMenu<String>(
        label: value,
        buttonStyle: PopupButtonStyle.glass,
        shrinkWrap: true,
        items: cardioTypes
            .map((t) => AdaptivePopupMenuItem<String>(label: t, value: t))
            .toList(),
        onSelected: (index, entry) {
          if (entry.value != null) onChanged(entry.value as String);
        },
      ),
    );
  }
}

// ─── Cardio Form ─────────────────────────────────────────────────────

class CardioForm extends StatelessWidget {
  final String cardioType;
  final ValueChanged<String> onCardioTypeChanged;
  final TextEditingController durationCtrl;
  final TextEditingController distanceCtrl;
  final TextEditingController caloriesCtrl;
  final TextEditingController avgHrCtrl;
  final TextEditingController maxHrCtrl;
  final TextEditingController elevationCtrl;
  final TextEditingController notesCtrl;
  final String intensity;
  final ValueChanged<String> onIntensityChanged;
  final VoidCallback onChanged;

  const CardioForm({
    super.key,
    required this.cardioType,
    required this.onCardioTypeChanged,
    required this.durationCtrl,
    required this.distanceCtrl,
    required this.caloriesCtrl,
    required this.avgHrCtrl,
    required this.maxHrCtrl,
    required this.elevationCtrl,
    required this.notesCtrl,
    required this.intensity,
    required this.onIntensityChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dur = double.tryParse(durationCtrl.text);
    final dist = double.tryParse(distanceCtrl.text);
    final showElev = elevationActivities.contains(cardioType);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Activity card ─────────────────────────────────────
          _CardSection(
            children: [
              const FieldLabel('Activity'),
              CardioTypeSelector(
                value: cardioType,
                onChanged: onCardioTypeChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Core metrics card ─────────────────────────────────
          _CardSection(
            children: [
              const FieldLabel('Duration'),
              InputRow(
                controller: durationCtrl,
                placeholder: '30',
                suffix: 'min',
                onChanged: onChanged,
              ),
              const SizedBox(height: 14),
              const FieldLabel('Distance (optional)'),
              InputRow(
                controller: distanceCtrl,
                placeholder: '5.0',
                suffix: 'km',
                decimal: true,
                onChanged: onChanged,
              ),
              if (dur != null && dur > 0 && dist != null && dist > 0) ...[
                const SizedBox(height: 8),
                PaceRow(durationMin: dur, distanceKm: dist),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // ─── Intensity card ────────────────────────────────────
          _CardSection(
            children: [
              const FieldLabel('Intensity (optional)'),
              IntensitySelector(
                value: intensity,
                onChanged: onIntensityChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Biometrics card ───────────────────────────────────
          _CardSection(
            children: [
              const FieldLabel('Heart Rate (optional)'),
              Row(
                children: [
                  Expanded(
                    child: InputRow(
                      controller: avgHrCtrl,
                      placeholder: '145',
                      suffix: 'avg bpm',
                      onChanged: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InputRow(
                      controller: maxHrCtrl,
                      placeholder: '175',
                      suffix: 'max bpm',
                      onChanged: () {},
                    ),
                  ),
                ],
              ),
              if (showElev) ...[
                const SizedBox(height: 14),
                const FieldLabel('Elevation Gain (optional)'),
                InputRow(
                  controller: elevationCtrl,
                  placeholder: '120',
                  suffix: 'm',
                  onChanged: () {},
                ),
              ],
              const SizedBox(height: 14),
              const FieldLabel('Calories (optional)'),
              InputRow(
                controller: caloriesCtrl,
                placeholder: '300',
                suffix: 'cal',
                onChanged: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Notes card ────────────────────────────────────────
          _CardSection(
            children: [
              const FieldLabel('Notes (optional)'),
              AdaptiveTextField(
                controller: notesCtrl,
                maxLines: 3,
                placeholder: 'How did it go?',
                style: AppTextStyles.body,
                cupertinoDecoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card section wrapper matching AppCard styling
class _CardSection extends StatelessWidget {
  final List<Widget> children;
  const _CardSection({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle, width: 1),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
