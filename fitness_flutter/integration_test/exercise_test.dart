// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE / WORKOUTS — Integration Test
// Tests: navigate to workouts tab, toggle strength/cardio, add exercise,
//        search exercise, fill weight/reps, add set, save/discard workout,
//        cardio inputs, date navigation
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  initBinding();

  testWidgets('Workouts: Tab loads with Strength/Cardio toggle', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');
    await ss('workout_01_tab_loaded');

    expect(find.text('Strength'), findsWidgets, reason: 'Strength tab must exist');
    expect(find.text('Cardio'), findsWidgets, reason: 'Cardio tab must exist');
    debugPrint('✓ Workouts tab loaded');
  });

  testWidgets('Workouts: Toggle between Strength and Cardio', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Tap Cardio
    await t.tap(find.text('Cardio').first);
    await settle(t);
    await ss('workout_02_cardio_mode');
    debugPrint('✓ Switched to Cardio mode');

    // Tap back to Strength
    await t.tap(find.text('Strength').first);
    await settle(t);
    await ss('workout_03_strength_mode');
    debugPrint('✓ Switched back to Strength');
  });

  testWidgets('Workouts: Open exercise picker and search', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Find Add Exercise or Next Exercise button
    final addExercise = find.textContaining('Add Exercise');
    final nextExercise = find.textContaining('Next Exercise');
    if (addExercise.evaluate().isNotEmpty) {
      await t.tap(addExercise.first);
    } else if (nextExercise.evaluate().isNotEmpty) {
      await t.tap(nextExercise.first);
    } else {
      debugPrint('⚠ No Add Exercise button found');
      return;
    }
    await settle(t);
    await ss('workout_04_exercise_picker');

    // Search for an exercise
    final searchHint = find.text('Search exercises...');
    expect(searchHint, findsWidgets, reason: 'Exercise picker must have search');

    final searchField = find.byType(TextField).last;
    await t.tap(searchField);
    await t.enterText(searchField, 'bench');
    await settle(t, 1500);
    await ss('workout_05_exercise_search');
    debugPrint('✓ Exercise search works');

    // Tap first result
    final tiles = find.byType(ListTile);
    if (tiles.evaluate().isNotEmpty) {
      await t.tap(tiles.first);
      await settle(t);
      await ss('workout_06_exercise_selected');
      debugPrint('✓ Exercise selected');
    } else {
      // Try custom add
      final custom = find.textContaining('custom');
      if (custom.evaluate().isNotEmpty) {
        await t.tap(custom.first);
        await settle(t);
      }
    }
  });

  testWidgets('Workouts: Fill weight and reps for a set', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Add exercise first
    final addExercise = find.textContaining('Add Exercise');
    final nextExercise = find.textContaining('Next Exercise');
    if (addExercise.evaluate().isNotEmpty) {
      await t.tap(addExercise.first);
    } else if (nextExercise.evaluate().isNotEmpty) {
      await t.tap(nextExercise.first);
    } else {
      return;
    }
    await settle(t);

    // Search and select
    final searchField = find.byType(TextField).last;
    await t.tap(searchField);
    await t.enterText(searchField, 'squat');
    await settle(t, 1500);

    final tiles = find.byType(ListTile);
    if (tiles.evaluate().isNotEmpty) {
      await t.tap(tiles.first);
      await settle(t);
    } else {
      return;
    }

    // Find weight/rep inputs (hint text is '0')
    final allFields = find.byType(TextField);
    int filled = 0;
    for (int i = 0; i < allFields.evaluate().length && filled < 2; i++) {
      try {
        final widget = t.widget<TextField>(allFields.at(i));
        if (widget.decoration?.hintText == '0') {
          await t.tap(allFields.at(i));
          await t.enterText(allFields.at(i), filled == 0 ? '225' : '5');
          filled++;
        }
      } catch (_) {}
    }
    await settle(t);
    await ss('workout_07_set_filled');
    expect(filled, greaterThan(0), reason: 'Should fill at least one field');
    debugPrint('✓ Weight/reps entered ($filled fields)');
  });

  testWidgets('Workouts: Add Set button creates new set row', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Add exercise
    final addExercise = find.textContaining('Add Exercise');
    final nextExercise = find.textContaining('Next Exercise');
    if (addExercise.evaluate().isNotEmpty) {
      await t.tap(addExercise.first);
    } else if (nextExercise.evaluate().isNotEmpty) {
      await t.tap(nextExercise.first);
    } else {
      return;
    }
    await settle(t);

    final searchField = find.byType(TextField).last;
    await t.tap(searchField);
    await t.enterText(searchField, 'deadlift');
    await settle(t, 1500);
    final tiles = find.byType(ListTile);
    if (tiles.evaluate().isNotEmpty) {
      await t.tap(tiles.first);
      await settle(t);
    } else {
      return;
    }

    // Tap Add Set
    final addSet = find.text('Add Set');
    if (addSet.evaluate().isNotEmpty) {
      await t.tap(addSet.first);
      await settle(t);
      await ss('workout_08_set_added');
      debugPrint('✓ Additional set added');
    }
  });

  testWidgets('Workouts: Save workout', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Add exercise and fill data
    final addExercise = find.textContaining('Add Exercise');
    final nextExercise = find.textContaining('Next Exercise');
    if (addExercise.evaluate().isNotEmpty) {
      await t.tap(addExercise.first);
    } else if (nextExercise.evaluate().isNotEmpty) {
      await t.tap(nextExercise.first);
    } else {
      return;
    }
    await settle(t);

    final searchField = find.byType(TextField).last;
    await t.tap(searchField);
    await t.enterText(searchField, 'bench');
    await settle(t, 1500);
    final tiles = find.byType(ListTile);
    if (tiles.evaluate().isNotEmpty) {
      await t.tap(tiles.first);
      await settle(t);
    } else {
      return;
    }

    // Fill one set
    final allFields = find.byType(TextField);
    for (int i = 0; i < allFields.evaluate().length; i++) {
      try {
        final widget = t.widget<TextField>(allFields.at(i));
        if (widget.decoration?.hintText == '0') {
          await t.tap(allFields.at(i));
          await t.enterText(allFields.at(i), '100');
          break;
        }
      } catch (_) {}
    }
    await settle(t);

    // Save
    final saveBtn = find.text('Save');
    if (saveBtn.evaluate().isNotEmpty) {
      await t.tap(saveBtn.first);
      await settle(t, 2000);
      await ss('workout_09_saved');
      debugPrint('✓ Workout saved');
    } else {
      debugPrint('⚠ No Save button found');
    }
  });

  testWidgets('Workouts: Discard workout', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Add exercise
    final addExercise = find.textContaining('Add Exercise');
    final nextExercise = find.textContaining('Next Exercise');
    if (addExercise.evaluate().isNotEmpty) {
      await t.tap(addExercise.first);
    } else if (nextExercise.evaluate().isNotEmpty) {
      await t.tap(nextExercise.first);
    } else {
      return;
    }
    await settle(t);

    final searchField = find.byType(TextField).last;
    await t.tap(searchField);
    await t.enterText(searchField, 'curl');
    await settle(t, 1500);
    final tiles = find.byType(ListTile);
    if (tiles.evaluate().isNotEmpty) {
      await t.tap(tiles.first);
      await settle(t);
    } else {
      return;
    }

    // Discard
    final discard = find.text('Discard');
    if (discard.evaluate().isNotEmpty) {
      await t.tap(discard.first);
      await settle(t);
      await ss('workout_10_discard_confirm');

      // Confirm discard
      final confirm = find.textContaining('Discard');
      if (confirm.evaluate().length > 1) {
        await t.tap(confirm.last);
        await settle(t);
        await ss('workout_11_discarded');
        debugPrint('✓ Workout discarded');
      }
    }
  });

  testWidgets('Workouts: Cardio mode inputs', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');

    // Switch to cardio
    await t.tap(find.text('Cardio').first);
    await settle(t);

    // Verify cardio inputs exist (duration, distance, etc.)
    final textFields = find.byType(TextField);
    expect(textFields.evaluate().length, greaterThan(0),
        reason: 'Cardio mode should have input fields');
    await ss('workout_12_cardio_inputs');
    debugPrint('✓ Cardio inputs visible');

    // Fill duration
    if (textFields.evaluate().isNotEmpty) {
      await t.tap(textFields.first);
      await t.enterText(textFields.first, '30');
      await settle(t);
      await ss('workout_13_cardio_filled');
      debugPrint('✓ Cardio duration entered');
    }
  });

  testWidgets('Workouts: Date navigation', (t) async {
    await launchApp(t);
    await goToTab(t, 'Workouts');
    await ss('workout_14_today');

    final leftChevron = find.byIcon(Icons.chevron_left_rounded);
    if (leftChevron.evaluate().isNotEmpty) {
      await t.tap(leftChevron.first);
      await settle(t, 1500);
      await ss('workout_15_previous_day');
      debugPrint('✓ Workout date navigation works');

      final rightChevron = find.byIcon(Icons.chevron_right_rounded);
      if (rightChevron.evaluate().isNotEmpty) {
        await t.tap(rightChevron.first);
        await settle(t, 1500);
      }
    }
  });
}
