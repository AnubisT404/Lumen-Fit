import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/router.dart';
import '../../config/theme.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/profile_service.dart';

// ─── Data ──────────────────────────────────────────────────────────────────

const _activityLevels = [
  ('sedentary', 'Sedentary', 'Little or no exercise'),
  ('lightly_active', 'Lightly Active', 'Light exercise 1-3 days/week'),
  ('moderately_active', 'Moderately Active', 'Moderate exercise 3-5 days/week'),
  ('very_active', 'Very Active', 'Hard exercise 6-7 days/week'),
  ('extra_active', 'Extra Active', 'Very hard exercise & physical job'),
];

const _goals = [
  ('lose', 'Lose Weight', '500 cal deficit', Icons.trending_down),
  ('maintain', 'Maintain', 'Stay at current weight', Icons.remove),
  ('gain', 'Gain Weight', '500 cal surplus', Icons.trending_up),
];

final _gradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [AppColors.primaryDark, const Color(0xFF7C3AED), AppColors.primaryDark],
);

final _indigo600 = AppColors.primaryDark;

// ─── Screen ────────────────────────────────────────────────────────────────

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 1;
  bool _loaded = false;
  bool _submitting = false;
  String? _error;

  // Form fields
  final _nameCtrl = TextEditingController();
  int _age = 25;
  String _sex = 'male';
  double _heightCm = 170;
  double _weightKg = 70;
  String _activityLevel = 'moderately_active';
  String _goal = 'maintain';
  double _targetWeightKg = 70;
  bool _useMetric = true;

  // Validation errors (null = valid)
  String? _ageError;
  String? _heightError;
  String? _weightError;
  String? _targetWeightError;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    // Schedule prefill after first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromProfile();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Pre-fill from existing profile
  void _prefillFromProfile() {
    final profileAsync = ref.read(profileProvider);
    profileAsync.whenData((p) {
      if (_loaded) return;
      _loaded = true;
      setState(() {
        _nameCtrl.text = p.name ?? '';
        _age = p.age ?? _age;
        _sex = p.sex ?? _sex;
        _heightCm = p.heightCm ?? _heightCm;
        _weightKg = p.weightKg ?? _weightKg;
        _activityLevel = p.activityLevel ?? _activityLevel;
        _goal = p.goal ?? _goal;
        _targetWeightKg = p.targetWeightKg ?? p.weightKg ?? _targetWeightKg;
      });
    });
  }

  // ─── Validation ─────────────────────────────────────────────────────
  bool get _step1Valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      _ageError == null &&
      _heightError == null &&
      _weightError == null &&
      _age >= 13 && _age <= 120 &&
      _heightCm >= 50 && _heightCm <= 300 &&
      _weightKg >= 20 && _weightKg <= 500;

  bool get _step3Valid =>
      _goal == 'maintain' ||
      (_targetWeightError == null && _targetWeightKg >= 20 && _targetWeightKg <= 500);

  void _validateAge(String v) {
    final parsed = int.tryParse(v);
    setState(() {
      if (parsed == null) {
        _ageError = 'Enter a valid number';
      } else if (parsed < 13) {
        _ageError = 'Must be at least 13';
      } else if (parsed > 120) {
        _ageError = 'Must be 120 or less';
      } else {
        _ageError = null;
        _age = parsed;
      }
    });
  }

  void _validateHeight(String v) {
    final parsed = double.tryParse(v);
    setState(() {
      if (parsed == null) {
        _heightError = 'Enter a valid number';
      } else if (_useMetric) {
        if (parsed < 50) { _heightError = 'Must be at least 50 cm'; }
        else if (parsed > 300) { _heightError = 'Must be 300 cm or less'; }
        else { _heightError = null; _heightCm = parsed; }
      } else {
        // Imperial: inches (20–120in ≈ 50–305cm)
        if (parsed < 20) { _heightError = 'Must be at least 20 in'; }
        else if (parsed > 120) { _heightError = 'Must be 120 in or less'; }
        else { _heightError = null; _heightCm = parsed * 2.54; }
      }
    });
  }

  void _validateWeight(String v) {
    final parsed = double.tryParse(v);
    setState(() {
      if (parsed == null) {
        _weightError = 'Enter a valid number';
      } else if (_useMetric) {
        if (parsed < 20) { _weightError = 'Must be at least 20 kg'; }
        else if (parsed > 500) { _weightError = 'Must be 500 kg or less'; }
        else { _weightError = null; _weightKg = parsed; if (_goal == 'maintain') _targetWeightKg = parsed; }
      } else {
        // Imperial: lbs (44–1100lb ≈ 20–500kg)
        if (parsed < 44) { _weightError = 'Must be at least 44 lb'; }
        else if (parsed > 1100) { _weightError = 'Must be 1100 lb or less'; }
        else { _weightError = null; _weightKg = parsed / 2.205; if (_goal == 'maintain') _targetWeightKg = _weightKg; }
      }
    });
  }

  void _validateTargetWeight(String v) {
    final parsed = double.tryParse(v);
    setState(() {
      if (parsed == null) {
        _targetWeightError = 'Enter a valid number';
      } else if (_useMetric) {
        if (parsed < 20) { _targetWeightError = 'Must be at least 20 kg'; }
        else if (parsed > 500) { _targetWeightError = 'Must be 500 kg or less'; }
        else { _targetWeightError = null; _targetWeightKg = parsed; }
      } else {
        if (parsed < 44) { _targetWeightError = 'Must be at least 44 lb'; }
        else if (parsed > 1100) { _targetWeightError = 'Must be 1100 lb or less'; }
        else { _targetWeightError = null; _targetWeightKg = parsed / 2.205; }
      }
    });
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ProfileService.setupProfile(
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        age: _age,
        sex: _sex,
        heightCm: _heightCm,
        weightKg: _weightKg,
        activityLevel: _activityLevel,
        goal: _goal,
        targetWeightKg: _goal != 'maintain' ? _targetWeightKg : null,
      );
      ref.invalidate(dashboardProvider);
      ref.invalidate(profileProvider);
      await markOnboardingComplete();
      if (mounted) {
        AdaptiveSnackBar.show(context,
            message: 'Profile saved!',
            type: AdaptiveSnackBarType.success);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/diary');
        }
      }
    } catch (e) {
      setState(() => _error = 'Failed to save profile. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch profile to trigger rebuild if data arrives later
    ref.watch(profileProvider).whenData((_) {
      if (!_loaded) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(gradient: _gradient),
          child: Stack(
            children: [
              // Decorative blurred circles
              Positioned(
                top: -60,
                left: -60,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: -80,
                right: -60,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.purple.withValues(alpha: 0.1),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    _buildProgressBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: _buildStep(),
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
  }

  // ─── Progress Bar ──────────────────────────────────────────────────────

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) {
              final s = i + 1;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: i > 0 ? 6 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: AppColors.surface.withValues(alpha: 0.2),
                  ),
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    alignment: Alignment.centerLeft,
                    widthFactor: _step >= s ? 1.0 : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [AppColors.textOnPrimary, AppColors.primaryUltraLight],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            'Step $_step of 3',
            style: AppTextStyles.label.copyWith(
              color: AppColors.primaryUltraLight.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Router ──────────────────────────────────────────────────────

  Widget _buildStep() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ─── Step 1: Personal Info ────────────────────────────────────────────

  Widget _buildStep1() {
    return Column(
      children: [
        _stepHeader(Icons.person, 'Personal Info', 'Tell us about yourself'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldLabel('Name'),
              _textField(
                controller: _nameCtrl,
                hint: 'Your name',
                keyboardType: TextInputType.name,
              ),
              const SizedBox(height: 16),
              _fieldLabel('Age'),
              _textField(
                initialValue: _age.toString(),
                keyboardType: TextInputType.number,
                onChanged: _validateAge,
              ),
              if (_ageError != null) _errorText(_ageError!),
              const SizedBox(height: 16),
              _fieldLabel('Sex'),
              const SizedBox(height: 6),
              Row(
                children: [
                  _sexButton('male', 'Male'),
                  const SizedBox(width: 12),
                  _sexButton('female', 'Female'),
                ],
              ),
              const SizedBox(height: 16),
              _fieldLabel('Units'),
              const SizedBox(height: 6),
              Row(
                children: [
                  _unitButton(true, 'Metric (cm/kg)'),
                  const SizedBox(width: 12),
                  _unitButton(false, 'Imperial (ft/lb)'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel(_useMetric ? 'Height (cm)' : 'Height (in)'),
                        _textField(
                          initialValue: _useMetric
                              ? _heightCm.toStringAsFixed(0)
                              : (_heightCm / 2.54).toStringAsFixed(0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: _validateHeight,
                        ),
                        if (_heightError != null) _errorText(_heightError!),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fieldLabel(_useMetric ? 'Weight (kg)' : 'Weight (lb)'),
                        _textField(
                          initialValue: _useMetric
                              ? _weightKg.toStringAsFixed(0)
                              : (_weightKg * 2.205).toStringAsFixed(0),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: _validateWeight,
                        ),
                        if (_weightError != null) _errorText(_weightError!),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _continueButton(
          onPressed: _step1Valid ? () => setState(() => _step = 2) : null,
        ),
      ],
    );
  }

  // ─── Step 2: Activity Level ───────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      children: [
        _stepHeader(Icons.local_fire_department, 'Activity Level', 'How active are you?'),
        ...List.generate(_activityLevels.length, (i) {
          final (value, label, desc) = _activityLevels[i];
          final selected = _activityLevel == value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < _activityLevels.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _activityLevel = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? AppColors.textOnPrimary : AppColors.textOnPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    // Radio dot
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? _indigo600 : AppColors.textOnPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.textPrimary : AppColors.textOnPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w400,
                              color: selected ? AppColors.textMuted : AppColors.primaryUltraLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Intensity bars
                    Row(
                      children: List.generate(5, (bar) {
                        final active = bar <= i;
                        return Container(
                          width: 3,
                          height: active ? 16 : 8,
                          margin: const EdgeInsets.only(left: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            color: active
                                ? (selected ? AppColors.primary : AppColors.textOnPrimary.withValues(alpha: 0.5))
                                : (selected ? AppColors.border : AppColors.textOnPrimary.withValues(alpha: 0.1)),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 20),
        _navButtons(
          onBack: () => setState(() => _step = 1),
          onNext: () => setState(() => _step = 3),
        ),
      ],
    );
  }

  // ─── Step 3: Goal ─────────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      children: [
        _stepHeader(Icons.monitor_weight_outlined, 'Your Goal', 'What do you want to achieve?'),
        ...List.generate(_goals.length, (i) {
          final (value, label, desc, icon) = _goals[i];
          final selected = _goal == value;
          return Padding(
            padding: EdgeInsets.only(bottom: i < _goals.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _goal = value;
                  if (value == 'maintain') _targetWeightKg = _weightKg;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected ? AppColors.textOnPrimary : AppColors.textOnPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: selected ? AppColors.primaryUltraLight : AppColors.textOnPrimary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        icon,
                        size: 20,
                        color: selected ? _indigo600 : AppColors.textOnPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.textPrimary : AppColors.textOnPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w400,
                              color: selected ? AppColors.textMuted : AppColors.primaryUltraLight,
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
        }),
        // Target weight field
        if (_goal != 'maintain') ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel(_useMetric ? 'Target Weight (kg)' : 'Target Weight (lb)'),
                _textField(
                  initialValue: _useMetric
                      ? _targetWeightKg.toStringAsFixed(0)
                      : (_targetWeightKg * 2.205).toStringAsFixed(0),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: _validateTargetWeight,
                ),
                if (_targetWeightError != null) _errorText(_targetWeightError!),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Error message
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.label.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        _navButtons(
          onBack: () => setState(() => _step = 2),
          nextChild: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: AppColors.textOnPrimary),
              const SizedBox(width: 6),
              Text(
                _submitting ? 'Saving...' : 'Start Tracking!',
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textOnPrimary,
                ),
              ),
            ],
          ),
          nextGradient: const LinearGradient(colors: [AppColors.successLight, AppColors.catLegs]),
          onNext: (_submitting || !_step3Valid) ? null : _submit,
        ),
      ],
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────────────

  Widget _stepHeader(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: AppRadius.cardRadius,
              color: AppColors.surface.withValues(alpha: 0.1),
            ),
            child: Icon(icon, size: 32, color: AppColors.textOnPrimary),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.headline.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.body.copyWith(
              color: AppColors.primaryUltraLight.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppTextStyles.micro.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.danger,
        ),
      ),
    );
  }

  Widget _textField({
    TextEditingController? controller,
    String? initialValue,
    String? hint,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return AdaptiveTextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: AppTextStyles.subheading.copyWith(
        fontWeight: FontWeight.w500,
      ),
      placeholder: hint,
    );
  }

  Widget _sexButton(String value, String label) {
    final selected = _sex == value;
    return Expanded(
      child: Semantics(
        label: '$label, ${selected ? "selected" : "not selected"}',
        button: true,
        selected: selected,
        child: GestureDetector(
        onTap: () => setState(() => _sex = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _indigo600 : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: _indigo600.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _unitButton(bool metric, String label) {
    final selected = _useMetric == metric;
    return Expanded(
      child: Semantics(
        label: '$label units, ${selected ? "selected" : "not selected"}',
        button: true,
        selected: selected,
        child: GestureDetector(
        onTap: () => setState(() {
          _useMetric = metric;
          _heightError = null;
          _weightError = null;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? _indigo600 : AppColors.background,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? [BoxShadow(color: _indigo600.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _continueButton({VoidCallback? onPressed}) {
    return Semantics(
      label: 'Continue',
      button: true,
      enabled: onPressed != null,
      child: SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: onPressed != null ? AppColors.textOnPrimary : AppColors.textOnPrimary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: onPressed != null
                ? [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Continue',
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onPressed != null ? _indigo600 : AppColors.textOnPrimary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward,
                size: 20,
                color: onPressed != null ? _indigo600 : AppColors.textOnPrimary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _navButtons({
    required VoidCallback onBack,
    VoidCallback? onNext,
    Widget? nextChild,
    Gradient? nextGradient,
  }) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: 'Back',
            button: true,
            child: GestureDetector(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.arrow_back, size: 16, color: AppColors.textOnPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Back',
                    style: AppTextStyles.subheading.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Semantics(
            label: 'Continue',
            button: true,
            enabled: onNext != null,
            child: GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: nextGradient,
                color: nextGradient == null ? AppColors.textOnPrimary : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: nextChild ??
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Continue',
                        style: AppTextStyles.subheading.copyWith(
                          fontWeight: FontWeight.w700,
                          color: nextGradient != null ? AppColors.textOnPrimary : _indigo600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward, size: 18, color: nextGradient != null ? AppColors.textOnPrimary : _indigo600),
                    ],
                  ),
            ),
          ),
          ),
        ),
      ],
    );
  }
}
