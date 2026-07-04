import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../providers/coach_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/modal_utils.dart';
import '../../services/coach_service.dart';
import '../../widgets/app_card.dart';

class _PreviewMsg {
  final String role;
  final String content;
  _PreviewMsg({required this.role, required this.content});
}

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final List<_PreviewMsg> _previewMessages = [];
  bool _previewError = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final history = await CoachService.getHistory(perPage: 6);
      if (!mounted) return;
      setState(() {
        _previewMessages.clear();
        _previewMessages.addAll(
          history.reversed.map(
            (m) => _PreviewMsg(role: m.role, content: m.content),
          ),
        );
        _previewError = false;
      });
    } catch (_) {
      if (mounted) setState(() => _previewError = true);
    }
  }

  void _openChat([String? prompt]) async {
    final uri = prompt != null && prompt.isNotEmpty
        ? '/chat?prompt=${Uri.encodeComponent(prompt)}'
        : '/chat';
    await context.push(uri);
    // Refresh preview after returning from chat
    _loadPreview();
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final aiConfigured = settingsAsync.whenOrNull(
      data: (s) =>
          s.aiProvider != null &&
          s.aiProvider!.isNotEmpty &&
          (s.aiApiKeySet || s.aiProvider == 'ollama'),
    );
    final disabled = aiConfigured == false;

    return SafeArea(
      bottom: false,
      child: _buildDashboard(aiConfigured: aiConfigured, disabled: disabled),
    );
  }

  // ─── Dashboard ───────────────────────────────────────────────────────

  Widget _buildDashboard({bool? aiConfigured, required bool disabled}) {
    final bottomPad = MediaQuery.of(context).padding.bottom + 68;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Daily Insight card
          _buildDailyInsight(aiConfigured),
          const SizedBox(height: 14),
          // 2. Quick Suggestions row
          _buildSuggestionChips(),
          const SizedBox(height: 14),
          // 3. Chat Window card
          _buildChatCard(disabled: disabled),
          const SizedBox(height: 16),
          // AI disclaimer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'AI coach provides general fitness guidance only. Not a substitute for professional medical advice.',
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withAlpha(150),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Daily Insight Card ──────────────────────────────────────────────

  Widget _buildDailyInsight(bool? aiConfigured) {
    final insightAsync = ref.watch(dailyInsightProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: AppColors.textOnPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Today\'s Insight',
                style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (aiConfigured == false)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your AI coach can help you with:',
                  style: AppTextStyles.label.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                _coachFeatureRow(
                  Icons.restaurant_menu,
                  'Personalized meal suggestions',
                ),
                _coachFeatureRow(
                  Icons.fitness_center,
                  'Workout optimization tips',
                ),
                _coachFeatureRow(Icons.insights, 'Daily progress insights'),
                _coachFeatureRow(
                  Icons.question_answer,
                  'Answer nutrition questions',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: AppGlassButton(
                    onPressed: () => context.go('/menu'),
                    label: 'Set Up AI Provider →',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Go to Menu → AI Configuration',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else
            insightAsync.when(
              loading: () => _shimmerLines(),
              error: (_, _) => GestureDetector(
                onTap: () => ref.invalidate(dailyInsightProvider),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Could not load insight. ',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'Tap to retry',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              data: (data) => Text(
                (data['insight'] ?? data['message'] ?? 'No insight available')
                    .toString(),
                style: AppTextStyles.label.copyWith(
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _shimmerLines() {
    return Shimmer.fromColors(
      baseColor: AppColors.surfaceAlt,
      highlightColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 11,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 11,
            width: 200,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Quick Suggestion Chips ──────────────────────────────────────────

  Widget _buildSuggestionChips() {
    const chips = [
      {
        'label': 'Review day',
        'prompt':
            'Review today\'s nutrition, hydration, and workouts. What are the top 3 things I should improve?',
      },
      {
        'label': 'Meal ideas',
        'prompt':
            'Based on my remaining macros for today, suggest 2-3 meal options with approximate calories and protein.',
      },
      {
        'label': 'Workout tips',
        'prompt':
            'Based on my recent workout history, suggest what I should focus on in my next session.',
      },
    ];

    return Row(
      children: chips
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: SizedBox(
                  height: 40,
                  child: AppGlassButton(
                    onPressed: () => _openChat(c['prompt']!),
                    label: c['label']!,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  // ─── Chat Window Card ────────────────────────────────────────────────

  Widget _buildChatCard({required bool disabled}) {
    final previewMsgs = _previewMessages.length > 6
        ? _previewMessages.sublist(_previewMessages.length - 6)
        : _previewMessages;

    return GestureDetector(
      onTap: () => _openChat(),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 0),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.smart_toy_outlined,
                        size: 13,
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Chat',
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.open_in_full_rounded,
                      size: 14,
                      color: AppColors.iconMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Message preview
              if (_previewError)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: GestureDetector(
                    onTap: _loadPreview,
                    child: Text(
                      'Could not load chat history. Tap to retry.',
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                )
              else if (_previewMessages.isEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text(
                    'Start a conversation with your AI coach.',
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: AppColors.textHint,
                      height: 1.4,
                    ),
                  ),
                )
              else
                ...previewMsgs.map((msg) {
                  final isUser = msg.role == 'user';
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Row(
                      mainAxisAlignment: isUser
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: isUser
                                  ? AppColors.primaryGradient
                                  : null,
                              color: isUser ? null : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg.content.replaceAll('\n', ' ').trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.small.copyWith(
                                fontWeight: FontWeight.w400,
                                color: isUser
                                    ? AppColors.textOnPrimary
                                    : AppColors.textPrimary,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              // Input bar teaser → tapping opens /chat route
              Container(
                margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        disabled ? 'Configure AI first…' : 'Message',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.iconMuted.withAlpha(30),
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 15,
                        color: AppColors.iconMuted,
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
}
