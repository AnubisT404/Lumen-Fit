import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../utils/modal_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/settings_service.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  Future<void> _saveSetting(Map<String, dynamic> data) async {
    try {
      await SettingsService.update(data);
      ref.invalidate(settingsProvider);
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Saved',
          type: AdaptiveSnackBarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Something went wrong. Please try again.',
          type: AdaptiveSnackBarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync brightness from actual theme context (not just provider)
    ref.watch(themeModeProvider); // also watch to trigger rebuild
    final settingsAsync = ref.watch(settingsProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: settingsAsync.when(
          loading: () => _buildShimmer(),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Could not load settings. Pull to retry.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                AppGlassButton(
                  onPressed: () => ref.invalidate(settingsProvider),
                  label: 'Retry',
                  style: AdaptiveButtonStyle.plain,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
          data: (settings) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              // ─── Profile Row ───────────────────────────────────
              _buildProfileRow(profileAsync),
              const SizedBox(height: 32),

              // ─── Navigation Group ──────────────────────────────
              _groupLabel('GENERAL'),
              const SizedBox(height: 8),
              _buildGroup([
                _SettingsRow(
                  icon: Icons.straighten_rounded,
                  iconColor: AppColors.success,
                  label: 'Measurements',
                  onTap: () => context.push('/measurements'),
                ),
                _SettingsRow(
                  icon: Icons.calendar_month_rounded,
                  iconColor: AppColors.primary,
                  label: 'Workout Plans',
                  onTap: () => context.push('/plans'),
                ),
                _SettingsRow(
                  icon: Icons.tune_rounded,
                  iconColor: AppColors.warning,
                  label: 'Nutrition Goals',
                  onTap: () => context.push('/nutrition/goals'),
                ),
              ]),
              const SizedBox(height: 28),

              // ─── Preferences Group ─────────────────────────────
              _groupLabel('PREFERENCES'),
              const SizedBox(height: 8),
              _buildGroup([
                _SettingsRow(
                  icon: Icons.scale_rounded,
                  iconColor: AppColors.primary,
                  label: 'Weight Unit',
                  trailing: _buildUnitToggle(settings),
                ),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  iconColor: AppColors.purple,
                  label: 'Appearance',
                  trailing: _buildThemeToggle(),
                ),
              ]),
              const SizedBox(height: 28),

              // ─── AI Group ──────────────────────────────────────
              _groupLabel('AI COACH'),
              const SizedBox(height: 8),
              _buildGroup([
                _SettingsRow(
                  icon: Icons.smart_toy_rounded,
                  iconColor: AppColors.purple,
                  label: 'AI Configuration',
                  subtitle: settings.aiProvider?.isNotEmpty == true
                      ? '${settings.aiProvider} · ${settings.aiModel ?? "default"}'
                      : 'Not configured',
                  onTap: () => _openAiConfig(settings),
                ),
                _SettingsRow(
                  icon: Icons.school_rounded,
                  iconColor: AppColors.success,
                  label: 'Scholar Search',
                  trailing: AdaptiveSwitch(
                    value: settings.scholarSearchEnabled,
                    onChanged: (v) =>
                        _saveSetting({'scholar_search_enabled': v}),
                  ),
                ),
              ]),
              const SizedBox(height: 28),

              const SizedBox(height: 24),

              // ─── Version footer ────────────────────────────────
              Center(
                child: Text(
                  'v1.0.0 · Made with ❤️ by Tejas',
                  style: AppTextStyles.small.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Profile Row ────────────────────────────────────────────────────────

  Widget _buildProfileRow(AsyncValue profileAsync) {
    return profileAsync.when(
      loading: () => _buildProfileShimmer(),
      error: (_, _) => const Text('Could not load profile'),
      data: (profile) {
        final hasProfile = profile.name?.isNotEmpty == true;
        if (!hasProfile) return _buildSetupCTA();

        return GestureDetector(
          onTap: () => context.push('/setup'),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment(-1, -1),
                    end: Alignment(1, 1),
                    colors: [AppColors.primary, AppColors.purple],
                  ),
                ),
                child: Center(
                  child: Text(
                    profile.name![0].toUpperCase(),
                    style: AppTextStyles.headline.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (profile.age != null) '${profile.age} yrs',
                        if (profile.activityLevel != null)
                          profile.activityLevel!
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map(
                                (w) => w.isNotEmpty
                                    ? '${w[0].toUpperCase()}${w.substring(1)}'
                                    : '',
                              )
                              .join(' '),
                      ].join(' · '),
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.iconMuted,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSetupCTA() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(18),
            AppColors.purple.withAlpha(12),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.purple],
              ),
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: AppColors.textOnPrimary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete Your Profile',
                  style: AppTextStyles.title.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Get personalized recommendations',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Set Up',
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textOnPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Settings Group Container ────────────────────────────────────────────

  Widget _buildGroup(List<_SettingsRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Column(
            children: [
              _buildRow(row, isFirst: i == 0, isLast: i == rows.length - 1),
              if (i < rows.length - 1)
                Divider(
                  height: 0.5,
                  indent: 58,
                  endIndent: 16,
                  color: AppColors.border.withAlpha(50),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRow(
    _SettingsRow row, {
    required bool isFirst,
    required bool isLast,
  }) {
    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(14) : Radius.zero,
      bottom: isLast ? const Radius.circular(14) : Radius.zero,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: row.onTap != null
            ? () {
                HapticFeedback.selectionClick();
                row.onTap!();
              }
            : null,
        borderRadius: borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Icon box
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: row.iconColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(row.icon, color: row.iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              // Label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.label,
                      style: AppTextStyles.subheading.copyWith(
                        fontWeight: FontWeight.w500,
                        color: row.labelColor ?? AppColors.textPrimary,
                      ),
                    ),
                    if (row.subtitle != null)
                      Text(
                        row.subtitle!,
                        style: AppTextStyles.small.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              // Trailing
              if (row.trailing != null)
                row.trailing!
              else if (row.onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.iconMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Unit Toggle ────────────────────────────────────────────────────────

  Widget _buildThemeToggle() {
    final mode = ref.watch(themeModeProvider);
    final modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    return SizedBox(
      width: 160,
      height: 40,
      child: AppSegmentedControl(
        labels: const ['Auto', 'Light', 'Dark'],
        selectedIndex: modes.indexOf(mode),
        onValueChanged: (i) {
          HapticFeedback.selectionClick();
          ref.read(themeModeProvider.notifier).setMode(modes[i]);
        },
      ),
    );
  }

  Widget _buildUnitToggle(dynamic settings) {
    final units = ['kg', 'lb'];
    return SizedBox(
      width: 100,
      height: 40,
      child: AppSegmentedControl(
        labels: const ['kg', 'lb'],
        selectedIndex: settings.weightUnit == 'kg' ? 0 : 1,
        onValueChanged: (i) {
          HapticFeedback.selectionClick();
          _saveSetting({'weight_unit': units[i]});
        },
      ),
    );
  }

  // ─── AI Configuration Sheet ─────────────────────────────────────────────

  void _openAiConfig(dynamic settings) {
    final providerCtrl = TextEditingController(text: settings.aiProvider ?? '');
    final modelCtrl = TextEditingController(text: settings.aiModel ?? '');
    final keyCtrl = TextEditingController();
    final endpointCtrl = TextEditingController(text: settings.aiEndpoint ?? '');
    bool keyVisible = false;

    showAppSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(44)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Configuration', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  'Configure your AI provider for the Coach feature',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),
                _sheetField(
                  providerCtrl,
                  'Provider',
                  Icons.cloud_outlined,
                  onSubmit: (v) => _saveSetting({'ai_provider': v.trim()}),
                ),
                const SizedBox(height: 12),
                _sheetField(
                  modelCtrl,
                  'Model',
                  Icons.memory_rounded,
                  onSubmit: (v) => _saveSetting({'ai_model': v.trim()}),
                ),
                const SizedBox(height: 12),
                AdaptiveTextField(
                  controller: keyCtrl,
                  obscureText: !keyVisible,
                  style: AppTextStyles.body,
                  placeholder: settings.aiApiKeySet
                      ? '••••••••  (key is set)'
                      : 'Enter API key',
                  prefixIcon: Icon(
                    Icons.key_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  cupertinoDecoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      keyVisible ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () =>
                        setSheetState(() => keyVisible = !keyVisible),
                  ),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty)
                      _saveSetting({'ai_api_key': v.trim()});
                  },
                ),
                const SizedBox(height: 12),
                _sheetField(
                  endpointCtrl,
                  'Endpoint (optional)',
                  Icons.link_rounded,
                  onSubmit: (v) => _saveSetting({'ai_endpoint': v.trim()}),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: AppGlassButton(
                    onPressed: () {
                      if (providerCtrl.text.trim().isNotEmpty) {
                        _saveSetting({'ai_provider': providerCtrl.text.trim()});
                      }
                      if (modelCtrl.text.trim().isNotEmpty) {
                        _saveSetting({'ai_model': modelCtrl.text.trim()});
                      }
                      if (keyCtrl.text.trim().isNotEmpty) {
                        _saveSetting({'ai_api_key': keyCtrl.text.trim()});
                      }
                      if (endpointCtrl.text.trim().isNotEmpty) {
                        _saveSetting({'ai_endpoint': endpointCtrl.text.trim()});
                      }
                      Navigator.of(ctx).pop();
                    },
                    label: 'Save',
                    color: AppColors.primary,
                    size: AdaptiveButtonSize.large,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sheetField(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    void Function(String)? onSubmit,
  }) {
    return AdaptiveTextField(
      controller: ctrl,
      style: AppTextStyles.body,
      placeholder: label,
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      onSubmitted: onSubmit,
      cupertinoDecoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  // ─── Group Label ────────────────────────────────────────────────────────

  Widget _groupLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        title,
        style: AppTextStyles.small.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ─── Shimmer Skeletons ────────────────────────────────────────────────

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          children: [
            // Profile placeholder
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(height: 28),
            // Settings rows placeholder
            ...List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.surface,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ─── Helper class ────────────────────────────────────────────────────────

class _SettingsRow {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color? labelColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.labelColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}
