import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../utils/modal_utils.dart';
import '../../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    String? err;
    if (_isLogin) {
      err = await AuthService.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    } else {
      err = await AuthService.register(
        _emailCtrl.text.trim(),
        _passwordCtrl.text,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
    } else {
      // Navigate to main app via GoRouter
      if (mounted) {
        context.go('/diary');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _isLogin ? 'Welcome Back' : 'Create Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (!_isLogin) ...[
                    _buildField(_nameCtrl, 'Name (optional)', Icons.person_outline),
                    const SizedBox(height: 14),
                  ],
                  _buildField(_emailCtrl, 'Email', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v != null && v.contains('@') ? null : 'Enter valid email'),
                  const SizedBox(height: 14),
                  _buildField(_passwordCtrl, 'Password', Icons.lock_outline,
                      obscure: true,
                      validator: (v) => v != null && v.length >= 6 ? null : 'Min 6 characters'),
                  const SizedBox(height: 24),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_error!, style: TextStyle(color: AppColors.danger, fontSize: 13)),
                    ),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: AppGlassButton(
                      onPressed: _loading ? null : _submit,
                      label: _isLogin ? 'Sign In' : 'Sign Up',
                      color: AppColors.primary,
                      size: AdaptiveButtonSize.large,
                      enabled: !_loading,
                    ),
                  ),
                  const SizedBox(height: 16),

                  AppGlassButton(
                    onPressed: () => setState(() { _isLogin = !_isLogin; _error = null; }),
                    label: _isLogin ? "Don't have an account? Sign Up" : 'Already have an account? Sign In',
                    style: AdaptiveButtonStyle.plain,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return AdaptiveTextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppColors.textPrimary),
      placeholder: hint,
      prefixIcon: Icon(icon, color: AppColors.iconMuted),
    );
  }
}
