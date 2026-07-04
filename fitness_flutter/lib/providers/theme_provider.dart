import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier([ThemeMode initial = ThemeMode.system]) : super(initial);

  static const _key = 'theme_mode';

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    // Eagerly update AppColors so widgets see correct brightness immediately
    final brightness = switch (mode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };
    AppColors.updateBrightness(brightness);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }
}
