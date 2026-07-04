import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/theme.dart';
import 'config/router.dart';
import 'config/offline_queue.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Load saved theme mode before first frame to avoid light→dark flash
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  final initialThemeMode = savedTheme != null
      ? ThemeMode.values.firstWhere(
          (m) => m.name == savedTheme,
          orElse: () => ThemeMode.system,
        )
      : ThemeMode.system;

  // Resolve effective brightness for AppColors
  final platformBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final effectiveBrightness = switch (initialThemeMode) {
    ThemeMode.dark => Brightness.dark,
    ThemeMode.light => Brightness.light,
    ThemeMode.system => platformBrightness,
  };
  AppColors.updateBrightness(effectiveBrightness);

  await initOnboardingState();
  await AuthService.init();

  runApp(ProviderScope(
    overrides: [
      themeModeProvider.overrideWith((ref) => ThemeModeNotifier(initialThemeMode)),
    ],
    child: const FitnessApp(),
  ));
}

class FitnessApp extends ConsumerStatefulWidget {
  const FitnessApp({super.key});

  @override
  ConsumerState<FitnessApp> createState() => _FitnessAppState();
}

class _FitnessAppState extends ConsumerState<FitnessApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Process any queued requests from last session on startup
    OfflineQueue.instance.processQueue();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      OfflineQueue.instance.processQueue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Fitness Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        // Derive brightness directly from themeMode to avoid
        // AnimatedTheme interpolation returning stale brightness at t<0.5
        final brightness = switch (themeMode) {
          ThemeMode.dark => Brightness.dark,
          ThemeMode.light => Brightness.light,
          ThemeMode.system => Theme.of(context).brightness,
        };
        AppColors.updateBrightness(brightness);

        // Override platform brightness to match the app's forced theme
        // This fixes iOS 26 native dialogs & modals reading wrong brightness
        final mediaQuery = MediaQuery.of(context);

        // Cap text scale to prevent layout overflow while supporting accessibility
        final clampedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.8,
          maxScaleFactor: 1.4,
        );

        // System chrome adapts to theme
        final isDark = brightness == Brightness.dark;
        return MediaQuery(
          data: mediaQuery.copyWith(
            platformBrightness: brightness,
            textScaler: clampedTextScaler,
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
              systemNavigationBarColor: AppColors.surface,
              systemNavigationBarIconBrightness:
                  isDark ? Brightness.light : Brightness.dark,
            ),
            child: DefaultTextStyle(
              style: TextStyle(decoration: TextDecoration.none),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}
