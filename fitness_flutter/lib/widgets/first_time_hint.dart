import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

/// A one-time hint banner that shows on first visit and can be dismissed.
/// Uses SharedPreferences to persist dismissal state.
class FirstTimeHint extends StatefulWidget {
  final String hintKey;
  final String message;
  final IconData icon;

  const FirstTimeHint({
    super.key,
    required this.hintKey,
    required this.message,
    this.icon = Icons.lightbulb_outline,
  });

  @override
  State<FirstTimeHint> createState() => _FirstTimeHintState();
}

class _FirstTimeHintState extends State<FirstTimeHint>
    with SingleTickerProviderStateMixin {
  bool _visible = false;
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('hint_${widget.hintKey}') ?? false;
    if (!dismissed && mounted) {
      setState(() => _visible = true);
      _controller.forward();
    }
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hint_${widget.hintKey}', true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _opacity,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withAlpha(40), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
            GestureDetector(
              onTap: _dismiss,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
