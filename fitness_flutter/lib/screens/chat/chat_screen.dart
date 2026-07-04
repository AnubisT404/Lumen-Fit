import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../models/coach_message.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/modal_utils.dart';
import '../../services/coach_service.dart';

class _ChatMsg {
  final String role;
  String content;
  bool isStreaming;
  List<CoachSource> sources;
  _ChatMsg({
    required this.role,
    this.content = '',
    this.isStreaming = false,
    this.sources = const [],
  });
}

class ChatScreen extends ConsumerStatefulWidget {
  final String? initialPrompt;
  const ChatScreen({super.key, this.initialPrompt});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<_ChatMsg> _messages = [];
  bool _isLoading = false;
  String? _error;
  bool _historyLoaded = false;
  bool _initialPromptSent = false;
  bool? _aiConfigured;
  String? _currentSessionId;
  List<Map<String, dynamic>> _sessions = [];
  StreamSubscription<Map<String, dynamic>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadSessions();
    _checkAiConfig();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      // Load the most recent session's messages
      final sessions = await CoachService.getSessions();
      if (!mounted) return;
      if (sessions.isNotEmpty) {
        final latestSessionId = sessions.first['session_id'] as String?;
        if (latestSessionId != null) {
          final messages = await CoachService.getSessionMessages(
            latestSessionId,
          );
          if (!mounted) return;
          setState(() {
            _currentSessionId = latestSessionId;
            _messages.addAll(
              messages.map(
                (m) => _ChatMsg(
                  role: m.role,
                  content: m.content,
                  sources: m.sources ?? [],
                ),
              ),
            );
            _historyLoaded = true;
          });
          _scrollToBottom();
          _maybeSendInitialPrompt();
          return;
        }
      }
      setState(() => _historyLoaded = true);
      _maybeSendInitialPrompt();
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
      _maybeSendInitialPrompt();
    }
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await CoachService.getSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {}
  }

  Future<void> _switchToSession(String sessionId) async {
    try {
      final messages = await CoachService.getSessionMessages(sessionId);
      if (!mounted) return;
      setState(() {
        _currentSessionId = sessionId;
        _messages.clear();
        _messages.addAll(
          messages.map(
            (m) => _ChatMsg(
              role: m.role,
              content: m.content,
              sources: m.sources ?? [],
            ),
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _checkAiConfig() async {
    try {
      final settings = await ref.read(settingsProvider.future);
      if (!mounted) return;
      final ok =
          settings.aiProvider != null &&
          settings.aiProvider!.isNotEmpty &&
          (settings.aiApiKeySet || settings.aiProvider == 'ollama');
      setState(() => _aiConfigured = ok);
    } catch (_) {
      if (mounted) setState(() => _aiConfigured = false);
    }
  }

  void _maybeSendInitialPrompt() {
    if (_initialPromptSent) return;
    if (widget.initialPrompt != null &&
        widget.initialPrompt!.isNotEmpty &&
        _historyLoaded &&
        !_isLoading) {
      _initialPromptSent = true;
      _sendMessage(widget.initialPrompt!);
    }
  }

  // Throttle streaming UI updates to max 15fps
  DateTime _lastStreamUpdate = DateTime.now();
  static const _streamThrottle = Duration(milliseconds: 66);

  Future<void> _sendMessage(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _isLoading) return;
    _controller.clear();
    setState(() {
      _error = null;
      _messages.add(_ChatMsg(role: 'user', content: msg));
      _messages.add(_ChatMsg(role: 'assistant', isStreaming: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final stream = CoachService.chatStreamParsed(
        msg,
        sessionId: _currentSessionId,
      );
      String fullContent = '';
      final completer = Completer<void>();
      _streamSub = stream.listen(
        (json) {
          if (!mounted) return;
          final type = json['type'] as String? ?? json['_event'] as String?;
          if (type == 'error') {
            completer.completeError(Exception(json['content'] as String? ?? 'Stream error'));
            return;
          }
          if (type == 'chunk' && json['content'] != null) {
            fullContent += json['content'] as String;
            final now = DateTime.now();
            if (now.difference(_lastStreamUpdate) >= _streamThrottle) {
              _lastStreamUpdate = now;
              setState(() => _messages.last.content = fullContent);
              _scrollToBottom(animated: false);
            }
          } else if (type == 'done') {
            final dc = json['content'] as String?;
            if (dc != null && dc.length >= fullContent.length) fullContent = dc;
            final sources = (json['sources'] as List? ?? [])
                .map((s) => CoachSource.fromJson(s as Map<String, dynamic>))
                .toList();
            final sid = json['session_id'] as String?;
            if (sid != null && _currentSessionId == null) {
              _currentSessionId = sid;
              _loadSessions();
            }
            setState(() {
              _messages.last
                ..content = fullContent
                ..isStreaming = false
                ..sources = sources;
            });
          }
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
      );
      await completer.future;
      if (mounted) setState(() => _messages.last.isStreaming = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        if (_messages.isNotEmpty &&
            _messages.last.role == 'assistant' &&
            _messages.last.content.isEmpty) {
          _messages.removeLast();
        }
      });
    } finally {
      _streamSub = null;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _stopGenerating() {
    _streamSub?.cancel();
    _streamSub = null;
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_messages.isNotEmpty && _messages.last.isStreaming) {
          _messages.last.isStreaming = false;
        }
      });
    }
  }

  void _copyMessage(String content) {
    Clipboard.setData(ClipboardData(text: content));
    AdaptiveSnackBar.show(
      context,
      message: 'Copied to clipboard',
      type: AdaptiveSnackBarType.success,
    );
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animated) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      endDrawer: _buildSideDrawer(),
      endDrawerEnableOpenDragGesture: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildInputBar(bottomPad),
          ],
        ),
      ),
    );
  }

  // ─── Side Drawer (ChatGPT-style, slides from left) ──────────────────

  Widget _buildSideDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      width: MediaQuery.of(context).size.width * 0.78,
      child: SafeArea(
        child: Column(
          children: [
            // Top: Logo + Close(X) button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  _coachIcon(28),
                  const Spacer(),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('xmark', size: 14),
                      size: AdaptiveButtonSize.small,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
            // New chat
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: SizedBox(
                width: double.infinity,
                height: 40,
                child: AppGlassButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _startNewChat();
                  },
                  label: 'New chat',
                  size: AdaptiveButtonSize.small,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Section label
            if (_sessions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Conversations',
                    style: AppTextStyles.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // Sessions list
            Expanded(
              child: _sessions.isEmpty
                  ? const SizedBox()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _sessions.length,
                      itemBuilder: (context, i) {
                        final session = _sessions[i];
                        final title = session['title'] as String? ?? 'Chat';
                        final sessionId = session['session_id'] as String?;
                        final isActive = sessionId == _currentSessionId;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            if (sessionId != null &&
                                sessionId != _currentSessionId) {
                              _switchToSession(sessionId);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.surface
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                color: isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ─────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      color: AppColors.background,
      child: Row(
        children: [
          // Back button (left)
          SizedBox(
            width: 36,
            height: 36,
            child: AppGlassButton(
              sfSymbol: SFSymbol('chevron.left', size: 14),
              size: AdaptiveButtonSize.small,
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/coach');
                }
              },
            ),
          ),
          // Title (centered)
          Expanded(
            child: Center(
              child: Text('AI Coach', style: AppTextStyles.titleMedium),
            ),
          ),
          // Hamburger menu (right)
          SizedBox(
            width: 34,
            height: 34,
            child: AppGlassButton(
              sfSymbol: SFSymbol('line.3.horizontal', size: 14),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              size: AdaptiveButtonSize.small,
            ),
          ),
        ],
      ),
    );
  }

  void _startNewChat() {
    if (_messages.isEmpty) return;
    setState(() {
      _currentSessionId = null;
      _messages.clear();
      _error = null;
    });
  }

  // ─── Body ────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (_aiConfigured == false && _messages.isEmpty) {
      return _buildNotConfigured();
    }
    if (_aiConfigured != false && _messages.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _messages.length + (_error != null ? 1 : 0),
      itemBuilder: (context, i) =>
          i < _messages.length ? _buildMessage(_messages[i]) : _buildError(),
    );
  }

  Widget _buildNotConfigured() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _coachIcon(56),
          const SizedBox(height: 24),
          Text(
            'Set up AI Coach',
            style: AppTextStyles.headline.copyWith(letterSpacing: -0.4),
          ),
          const SizedBox(height: 10),
          Text(
            'Connect an AI provider in Settings to start getting personalized fitness coaching.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 160,
            height: 44,
            child: AppGlassButton(
              onPressed: () {
                context.pop();
                context.go('/menu');
              },
              label: 'Open Settings',
              color: AppColors.primary,
              size: AdaptiveButtonSize.large,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _coachIcon(48),
            const SizedBox(height: 20),
            Text(
              'What can I help with?',
              style: AppTextStyles.headline.copyWith(letterSpacing: -0.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about nutrition, workouts, recovery, or your fitness goals.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: 'Review my day',
                  icon: Icons.trending_up_rounded,
                  onTap: () => _sendMessage(
                    'Review my nutrition and activity for today',
                  ),
                ),
                _SuggestionChip(
                  label: 'Meal ideas',
                  icon: Icons.restaurant_rounded,
                  onTap: () => _sendMessage(
                    'Suggest some healthy meal ideas based on my goals',
                  ),
                ),
                _SuggestionChip(
                  label: 'Workout tips',
                  icon: Icons.fitness_center_rounded,
                  onTap: () =>
                      _sendMessage('Give me some workout tips for today'),
                ),
                _SuggestionChip(
                  label: 'Recovery advice',
                  icon: Icons.bedtime_rounded,
                  onTap: () =>
                      _sendMessage('What should I do for recovery today?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Message Row (ChatGPT-style: no bubbles for AI) ─────────────────

  Widget _buildMessage(_ChatMsg msg) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: isUser ? _buildUserMessage(msg) : _buildAssistantMessage(msg),
    );
  }

  Widget _buildUserMessage(_ChatMsg msg) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.isDarkMode
                  ? AppColors.surfaceAlt
                  : AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              msg.content,
              style: AppTextStyles.subheading.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantMessage(_ChatMsg msg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _coachIcon(28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AssistantContent(
                content: msg.content,
                isStreaming: msg.isStreaming,
              ),
            ),
          ],
        ),
        // Sources
        if (msg.sources.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: msg.sources.map((s) => _SourceChip(source: s)).toList(),
            ),
          ),
        ],
        // Action buttons (copy, etc.) — only show when not streaming
        if (!msg.isStreaming && msg.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: Row(
              children: [
                _ActionIconButton(
                  icon: Icons.content_copy_rounded,
                  onTap: () => _copyMessage(msg.content),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildError() => Container(
    margin: const EdgeInsets.only(left: 40, bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.danger.withAlpha(10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.danger.withAlpha(25)),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          size: 16,
          color: AppColors.danger.withAlpha(180),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _error ?? 'Something went wrong',
            style: AppTextStyles.label.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.danger,
            ),
          ),
        ),
      ],
    ),
  );

  // ─── Input Bar (pill container with morphing send/stop button) ─────

  Widget _buildInputBar(double bottomPad) {
    final disabled = _aiConfigured == false;
    final hasText = _controller.text.trim().isNotEmpty;
    final showActive = _isLoading || hasText;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, bottomPad + 12),
      color: AppColors.background,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border.withAlpha(80)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !disabled,
                maxLines: 5,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  _sendMessage(_controller.text);
                  _focusNode.requestFocus();
                },
                style: AppTextStyles.subheading.copyWith(
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: disabled ? 'Configure AI in Settings…' : 'Message',
                  hintStyle: AppTextStyles.subheading.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.textHint,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                ),
              ),
            ),
            // Send / Stop button (morphs between states)
            GestureDetector(
              onTap: disabled
                  ? null
                  : () {
                      if (_isLoading) {
                        _stopGenerating();
                      } else if (hasText) {
                        _sendMessage(_controller.text);
                        _focusNode.requestFocus();
                      }
                    },
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (disabled || !showActive)
                          ? (AppColors.isDarkMode
                                ? const Color(0xFF4A4A4A)
                                : const Color(0xFFE5E5E5))
                          : AppColors.primary,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _isLoading
                          ? Icon(
                              Icons.stop_rounded,
                              key: const ValueKey('stop'),
                              size: 16,
                              color: Colors.white,
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              key: const ValueKey('send'),
                              size: 18,
                              color: (disabled || !showActive)
                                  ? (AppColors.isDarkMode
                                        ? const Color(0xFF8E8E93)
                                        : const Color(0xFFBBBBBB))
                                  : Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Coach Icon ─────────────────────────────────────────────────────

  Widget _coachIcon(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.primary.withAlpha(15),
      border: Border.all(color: AppColors.primary.withAlpha(40), width: 1.5),
    ),
    child: Icon(Icons.auto_awesome, size: size * 0.5, color: AppColors.primary),
  );
}

// ─── Action Icon Button ──────────────────────────────────────────────────────

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ActionIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 15, color: AppColors.textHint),
      ),
    );
  }
}

// ─── Assistant Content (Markdown rendering) ──────────────────────────────────

class _AssistantContent extends StatelessWidget {
  final String content;
  final bool isStreaming;
  const _AssistantContent({required this.content, required this.isStreaming});

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty && isStreaming) return const _ThinkingIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MarkdownBody(
          data: content,
          shrinkWrap: true,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            p: AppTextStyles.subheading.copyWith(
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            strong: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            em: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textPrimary,
            ),
            h1: AppTextStyles.heading.copyWith(height: 1.4),
            h2: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
            h3: AppTextStyles.subheading.copyWith(fontWeight: FontWeight.w700),
            code: TextStyle(
              fontSize: 13,
              fontFamily: 'monospace',
              backgroundColor: AppColors.surfaceAlt,
              color: AppColors.textPrimary,
            ),
            codeblockDecoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            codeblockPadding: const EdgeInsets.all(12),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.primary.withAlpha(100),
                  width: 3,
                ),
              ),
            ),
            blockquotePadding: const EdgeInsets.only(
              left: 12,
              top: 4,
              bottom: 4,
            ),
            listBullet: AppTextStyles.subheading.copyWith(
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
            listIndent: 20,
            blockSpacing: 12,
          ),
        ),
        if (isStreaming) const _StreamingCursor(),
      ],
    );
  }
}

// ─── Thinking Indicator (ChatGPT-style shimmer dots) ─────────────────────────

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();
  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : 2 - t * 2));
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha((opacity * 255).toInt()),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Streaming Cursor ────────────────────────────────────────────────────────

class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();
  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _ctrl,
    child: Container(
      width: 2,
      height: 18,
      margin: const EdgeInsets.only(left: 1, top: 4),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
  );
}

// ─── Source Chip ──────────────────────────────────────────────────────────────

class _SourceChip extends StatelessWidget {
  final CoachSource source;
  const _SourceChip({required this.source});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 12, color: AppColors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              source.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (source.year != null) ...[
            const SizedBox(width: 4),
            Text(
              '${source.year}',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Suggestion Chip (empty state quick actions) ─────────────────────────────

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: AppGlassButton(
        onPressed: onTap,
        label: label,
        size: AdaptiveButtonSize.small,
      ),
    );
  }
}
