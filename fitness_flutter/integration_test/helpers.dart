// Shared test helpers for all integration tests
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/main.dart';

late IntegrationTestWidgetsFlutterBinding binding;

void initBinding() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

Future<void> ss(String name) => binding.takeScreenshot(name);

/// Pump frames and try settling with a short timeout
Future<void> settle(WidgetTester t, [int ms = 1000]) async {
  await t.pump(Duration(milliseconds: ms));
  for (int i = 0; i < 5; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

/// Launch app and wait for it to load
Future<void> launchApp(WidgetTester t) async {
  await t.pumpWidget(const ProviderScope(child: FitnessApp()));
  await settle(t, 3000);
}

/// Navigate to a tab using Semantics label or icon fallback
Future<void> goToTab(WidgetTester t, String label) async {
  final tab = find.bySemanticsLabel(label);
  if (tab.evaluate().isNotEmpty) {
    await t.tap(tab.first);
    await settle(t);
    return;
  }
  final icons = <String, IconData>{
    'Dashboard': Icons.dashboard_outlined,
    'Coach': Icons.smart_toy_outlined,
    'Workouts': Icons.fitness_center_outlined,
    'More': Icons.more_horiz,
  };
  final activeIcons = <String, IconData>{
    'Dashboard': Icons.dashboard_rounded,
    'Coach': Icons.smart_toy_rounded,
    'Workouts': Icons.fitness_center_rounded,
    'More': Icons.more_horiz_rounded,
  };
  final icon = find.byIcon(icons[label]!);
  if (icon.evaluate().isNotEmpty) {
    await t.tap(icon.first);
  } else {
    final active = find.byIcon(activeIcons[label]!);
    if (active.evaluate().isNotEmpty) await t.tap(active.first);
  }
  await settle(t);
}

/// Navigate back using common back/close icons
Future<void> goBack(WidgetTester t) async {
  for (final icon in [Icons.arrow_back, Icons.arrow_back_ios_new_rounded, Icons.close]) {
    final f = find.byIcon(icon);
    if (f.evaluate().isNotEmpty) {
      await t.tap(f.first);
      await settle(t);
      return;
    }
  }
}

/// Enable dark mode from any tab
Future<void> enableDarkMode(WidgetTester t) async {
  await goToTab(t, 'More');
  await settle(t);
  final darkIcon = find.byIcon(Icons.dark_mode_rounded);
  if (darkIcon.evaluate().isNotEmpty) {
    await t.tap(darkIcon.first);
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await settle(t, 1000);
  }
}

/// Disable dark mode (switch to light)
Future<void> enableLightMode(WidgetTester t) async {
  await goToTab(t, 'More');
  await settle(t);
  final lightIcon = find.byIcon(Icons.light_mode_rounded);
  if (lightIcon.evaluate().isNotEmpty) {
    await t.tap(lightIcon.first);
    await settle(t);
  }
}
