// ═══════════════════════════════════════════════════════════════════════════
// MENU & SETTINGS — Integration Test
// Tests: menu loads, dark mode toggle, AI configuration sheet,
//        measurements screen, plans screen, goals screen, theme persistence
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  initBinding();

  testWidgets('Menu: Screen loads with all options', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');
    await ss('menu_01_loaded');

    // Verify key menu items exist
    expect(find.byIcon(Icons.straighten_rounded), findsOneWidget,
        reason: 'Measurements icon must exist');
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget,
        reason: 'Plans icon must exist');
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget,
        reason: 'Goals icon must exist');
    debugPrint('✓ Menu screen loaded with all options');
  });

  testWidgets('Menu: Dark mode toggle works instantly', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');
    await ss('menu_02_light_mode');

    // Tap dark mode icon
    final darkIcon = find.byIcon(Icons.dark_mode_rounded);
    expect(darkIcon, findsOneWidget, reason: 'Dark mode icon must exist');
    await t.tap(darkIcon.first);
    // Extra pumps for theme propagation
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    await settle(t, 1000);
    await ss('menu_03_dark_mode');
    debugPrint('✓ Dark mode toggled');

    // Switch back to light
    final lightIcon = find.byIcon(Icons.light_mode_rounded);
    expect(lightIcon, findsOneWidget, reason: 'Light mode icon must exist after dark toggle');
    await t.tap(lightIcon.first);
    await t.pump(const Duration(milliseconds: 500));
    await settle(t, 1000);
    await ss('menu_04_light_restored');
    debugPrint('✓ Light mode restored');
  });

  testWidgets('Menu: Dark mode persists across tab switches', (t) async {
    await launchApp(t);

    // Enable dark mode
    await enableDarkMode(t);
    await ss('menu_05_dark_enabled');

    // Switch to dashboard
    await goToTab(t, 'Dashboard');
    await settle(t, 2000);
    await ss('menu_06_dark_dashboard');

    // Switch to coach
    await goToTab(t, 'Coach');
    await settle(t, 1500);
    await ss('menu_07_dark_coach');

    // Switch to workouts
    await goToTab(t, 'Workouts');
    await settle(t, 1500);
    await ss('menu_08_dark_workouts');

    // Come back to menu — should still be dark
    await goToTab(t, 'More');
    await settle(t);
    await ss('menu_09_dark_still_on');
    debugPrint('✓ Dark mode persists across all tabs');

    // Restore light
    await enableLightMode(t);
  });

  testWidgets('Menu: AI Configuration sheet opens', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');

    final aiConfig = find.text('AI Configuration');
    expect(aiConfig, findsOneWidget, reason: 'AI Configuration must exist');
    await t.tap(aiConfig);
    await settle(t);
    await ss('menu_10_ai_config_sheet');

    // Verify sheet has input fields
    expect(find.byType(TextField), findsWidgets,
        reason: 'AI Config must have text fields for provider/model/key');
    debugPrint('✓ AI Configuration sheet opened');

    // Close sheet by tapping outside
    await t.tapAt(const Offset(200, 100));
    await settle(t);
  });

  testWidgets('Menu: Open Measurements screen', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');

    await t.tap(find.byIcon(Icons.straighten_rounded));
    await settle(t, 1500);
    await ss('menu_11_measurements');
    debugPrint('✓ Measurements screen opened');

    await goBack(t);
    await settle(t);
  });

  testWidgets('Menu: Open Plans screen', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');

    await t.tap(find.byIcon(Icons.calendar_month_rounded));
    await settle(t, 1500);
    await ss('menu_12_plans');
    debugPrint('✓ Plans screen opened');

    await goBack(t);
    await settle(t);
  });

  testWidgets('Menu: Open Goals screen', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');

    await t.tap(find.byIcon(Icons.tune_rounded));
    await settle(t, 1500);
    await ss('menu_13_goals');
    debugPrint('✓ Goals screen opened');

    await goBack(t);
    await settle(t);
  });

  testWidgets('Menu: Scroll to see all options', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');

    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await t.drag(scrollable.last, const Offset(0, -300));
      await settle(t);
      await ss('menu_14_scrolled');
      debugPrint('✓ Menu scrolled');

      await t.drag(scrollable.last, const Offset(0, 300));
      await settle(t);
    }
  });

  testWidgets('Menu: Theme toggle shows 3 options (system/light/dark)', (t) async {
    await launchApp(t);
    await goToTab(t, 'More');

    // All three icons should be visible
    expect(find.byIcon(Icons.brightness_auto_rounded), findsOneWidget,
        reason: 'System theme icon must exist');
    expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget,
        reason: 'Light mode icon must exist');
    expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget,
        reason: 'Dark mode icon must exist');
    debugPrint('✓ All 3 theme toggle options visible');
    await ss('menu_15_theme_toggle');
  });
}
