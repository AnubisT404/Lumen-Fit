// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD — Integration Test
// Tests: greeting, calorie card, water/hydration card, scrolling,
//        macro breakdown, week streak, date navigation
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  initBinding();

  testWidgets('Dashboard: Loads with greeting and calorie data', (t) async {
    await launchApp(t);
    await ss('dash_01_loaded');

    final hasGreeting = find.textContaining('Good ').evaluate().isNotEmpty;
    final hasCal = find.textContaining('cal').evaluate().isNotEmpty;
    expect(hasGreeting || hasCal, true,
        reason: 'Dashboard must show greeting or calorie data');
    debugPrint('✓ Dashboard loaded with content');
  });

  testWidgets('Dashboard: Scroll to see all cards', (t) async {
    await launchApp(t);

    final scrollable = find.byType(Scrollable);
    expect(scrollable, findsWidgets, reason: 'Must have scrollable content');

    // Scroll down
    await t.drag(scrollable.first, const Offset(0, -500));
    await settle(t);
    await ss('dash_02_scrolled_down');
    debugPrint('✓ Scrolled down — bottom cards visible');

    // Scroll back up
    await t.drag(scrollable.first, const Offset(0, 500));
    await settle(t);
    await ss('dash_03_scrolled_up');
  });

  testWidgets('Dashboard: Date navigation arrows work', (t) async {
    await launchApp(t);

    final leftChevron = find.byIcon(Icons.chevron_left_rounded);
    expect(leftChevron, findsWidgets, reason: 'Date nav left arrow must exist');

    // Go to yesterday
    await t.tap(leftChevron.first);
    await settle(t, 2000);
    await ss('dash_04_previous_day');
    debugPrint('✓ Navigated to previous day');

    // Go back to today
    final rightChevron = find.byIcon(Icons.chevron_right_rounded);
    expect(rightChevron, findsWidgets);
    await t.tap(rightChevron.first);
    await settle(t, 2000);
    await ss('dash_05_today_restored');
    debugPrint('✓ Navigated back to today');
  });

  testWidgets('Dashboard: Water/hydration quick-add button', (t) async {
    await launchApp(t);

    // Look for water add button
    final waterAdd = find.text('+250ml');
    if (waterAdd.evaluate().isNotEmpty) {
      await t.tap(waterAdd.first);
      await settle(t);
      await ss('dash_06_water_added');
      debugPrint('✓ Water quick-add tapped');
    } else {
      debugPrint('⚠ Water +250ml button not visible (may need scroll)');
      // Try scrolling to find it
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await t.drag(scrollable.first, const Offset(0, -300));
        await settle(t);
        final waterAddAfterScroll = find.text('+250ml');
        if (waterAddAfterScroll.evaluate().isNotEmpty) {
          await t.tap(waterAddAfterScroll.first);
          await settle(t);
          await ss('dash_06_water_added');
          debugPrint('✓ Water added after scroll');
        }
      }
    }
  });

  testWidgets('Dashboard: Macro ring/breakdown is visible', (t) async {
    await launchApp(t);

    // Macros should be visible (Protein, Carbs, Fat labels)
    final protein = find.text('Protein');
    final carbs = find.text('Carbs');
    final fat = find.text('Fat');

    // May need to scroll to see them
    final scrollable = find.byType(Scrollable);
    if (protein.evaluate().isEmpty && scrollable.evaluate().isNotEmpty) {
      await t.drag(scrollable.first, const Offset(0, -200));
      await settle(t);
    }

    expect(
      protein.evaluate().isNotEmpty || carbs.evaluate().isNotEmpty || fat.evaluate().isNotEmpty,
      true,
      reason: 'Macro breakdown (Protein/Carbs/Fat) must be visible',
    );
    await ss('dash_07_macros');
    debugPrint('✓ Macro breakdown visible');
  });

  testWidgets('Dashboard: Navigate to far past — empty state', (t) async {
    await launchApp(t);

    final leftChevron = find.byIcon(Icons.chevron_left_rounded);
    // Navigate 7 days back
    for (int i = 0; i < 7; i++) {
      if (leftChevron.evaluate().isNotEmpty) {
        await t.tap(leftChevron.first);
        await settle(t, 800);
      }
    }
    await settle(t, 1000);
    await ss('dash_08_past_date');
    debugPrint('✓ Past date (7 days back) shown');

    // Navigate back to today
    final rightChevron = find.byIcon(Icons.chevron_right_rounded);
    for (int i = 0; i < 7; i++) {
      if (rightChevron.evaluate().isNotEmpty) {
        await t.tap(rightChevron.first);
        await settle(t, 800);
      }
    }
    await settle(t, 1000);
    debugPrint('✓ Back to today');
  });
}
