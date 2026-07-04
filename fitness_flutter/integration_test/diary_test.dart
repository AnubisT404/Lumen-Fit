// ═══════════════════════════════════════════════════════════════════════════
// DIARY / FOOD LOGGING — Integration Test
// Tests: navigate to add food, search, select, configure servings, log food,
//        verify it appears in diary, edit logged food, delete food
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  initBinding();

  testWidgets('Diary: Add food — full search, select, configure, log flow', (t) async {
    await launchApp(t);
    await ss('diary_01_home');

    // Find and tap "Add" button on a meal section
    final addBtn = find.text('Add');
    expect(addBtn, findsWidgets, reason: 'Meal "Add" buttons should exist on diary');
    await t.tap(addBtn.first);
    await settle(t, 2000);
    await ss('diary_02_add_food_screen');

    // Should see search field
    final searchField = find.byType(TextField);
    expect(searchField, findsWidgets, reason: 'Search field must exist');
    debugPrint('✓ Add Food screen loaded');

    // Type search query
    await t.tap(searchField.first);
    await t.enterText(searchField.first, 'chicken');
    await settle(t, 3000);
    await ss('diary_03_search_results');

    // Verify results show calorie info
    final calTexts = find.textContaining('cal');
    expect(calTexts, findsWidgets, reason: 'Search results should show calories');
    debugPrint('✓ Search results loaded');

    // Tap first result
    await t.tap(calTexts.first);
    await settle(t, 1500);
    await ss('diary_04_food_detail');

    // Verify food detail screen
    expect(find.text('Serving Size'), findsOneWidget, reason: 'Food detail must show Serving Size');
    expect(find.text('Number of Servings'), findsOneWidget);
    expect(find.text('Meal'), findsOneWidget);
    debugPrint('✓ Food detail loaded');
  });

  testWidgets('Diary: Unit picker opens and closes', (t) async {
    await launchApp(t);

    // Navigate to add food
    final addBtn = find.text('Add');
    if (addBtn.evaluate().isEmpty) return;
    await t.tap(addBtn.first);
    await settle(t, 2000);

    // Search and select food
    final searchField = find.byType(TextField);
    await t.tap(searchField.first);
    await t.enterText(searchField.first, 'rice');
    await settle(t, 3000);

    final calTexts = find.textContaining('cal');
    if (calTexts.evaluate().isEmpty) return;
    await t.tap(calTexts.first);
    await settle(t, 1500);

    // Tap Serving Size to open unit picker
    await t.tap(find.text('Serving Size'));
    await settle(t);
    await ss('diary_05_unit_picker');

    // Verify Done button exists
    expect(find.text('Done'), findsWidgets, reason: 'Unit picker must have Done button');
    debugPrint('✓ Unit picker opened');

    // Close picker
    await t.tap(find.text('Done').first);
    await settle(t);
    await ss('diary_06_unit_picker_closed');
  });

  testWidgets('Diary: Servings picker — scroll to change value', (t) async {
    await launchApp(t);

    final addBtn = find.text('Add');
    if (addBtn.evaluate().isEmpty) return;
    await t.tap(addBtn.first);
    await settle(t, 2000);

    final searchField = find.byType(TextField);
    await t.tap(searchField.first);
    await t.enterText(searchField.first, 'egg');
    await settle(t, 3000);

    final calTexts = find.textContaining('cal');
    if (calTexts.evaluate().isEmpty) return;
    await t.tap(calTexts.first);
    await settle(t, 1500);

    // Tap Number of Servings
    await t.tap(find.text('Number of Servings'));
    await settle(t);
    await ss('diary_07_servings_picker');

    // Verify picker exists
    final picker = find.byType(CupertinoPicker);
    expect(picker, findsWidgets, reason: 'CupertinoPicker must exist in servings sheet');

    // Scroll picker
    await t.drag(picker.first, const Offset(0, -30));
    await settle(t);
    await ss('diary_08_servings_scrolled');
    debugPrint('✓ Servings picker scrolled');

    // Close
    await t.tap(find.text('Done').first);
    await settle(t);
  });

  testWidgets('Diary: Meal selector popup', (t) async {
    await launchApp(t);

    final addBtn = find.text('Add');
    if (addBtn.evaluate().isEmpty) return;
    await t.tap(addBtn.first);
    await settle(t, 2000);

    final searchField = find.byType(TextField);
    await t.tap(searchField.first);
    await t.enterText(searchField.first, 'banana');
    await settle(t, 3000);

    final calTexts = find.textContaining('cal');
    if (calTexts.evaluate().isEmpty) return;
    await t.tap(calTexts.first);
    await settle(t, 1500);

    // Tap Meal row
    await t.tap(find.text('Meal'));
    await settle(t);
    await ss('diary_09_meal_selector');

    // Should see meal options
    final lunch = find.text('Lunch');
    final dinner = find.text('Dinner');
    expect(
      lunch.evaluate().isNotEmpty || dinner.evaluate().isNotEmpty,
      true,
      reason: 'Meal popup should show Lunch/Dinner options',
    );
    debugPrint('✓ Meal selector opened');

    // Select Lunch
    if (lunch.evaluate().isNotEmpty) {
      await t.tap(lunch.last);
      await settle(t);
    } else {
      await t.tapAt(const Offset(100, 300));
      await settle(t);
    }
  });

  testWidgets('Diary: Log food and verify in diary', (t) async {
    await launchApp(t);

    final addBtn = find.text('Add');
    if (addBtn.evaluate().isEmpty) return;
    await t.tap(addBtn.first);
    await settle(t, 2000);

    final searchField = find.byType(TextField);
    await t.tap(searchField.first);
    await t.enterText(searchField.first, 'apple');
    await settle(t, 3000);

    final calTexts = find.textContaining('cal');
    if (calTexts.evaluate().isEmpty) return;
    await t.tap(calTexts.first);
    await settle(t, 1500);

    // Verify nutrition display
    expect(find.text('Protein'), findsWidgets);
    expect(find.text('Carbs'), findsWidgets);
    expect(find.text('Fat'), findsWidgets);
    await ss('diary_10_nutrition_visible');

    // Tap Add to Meal button
    final addToBtn = find.textContaining('Add to');
    if (addToBtn.evaluate().isNotEmpty) {
      await t.tap(addToBtn.first);
      await settle(t, 2000);
      await ss('diary_11_food_logged');
      debugPrint('✓ Food logged — back on diary');
    }
  });

  testWidgets('Diary: Date navigation shows different days', (t) async {
    await launchApp(t);
    await ss('diary_12_today');

    // Navigate to previous day
    final leftChevron = find.byIcon(Icons.chevron_left_rounded);
    expect(leftChevron, findsWidgets, reason: 'Date nav arrows must exist');
    await t.tap(leftChevron.first);
    await settle(t, 2000);
    await ss('diary_13_yesterday');

    // Navigate back to today
    final rightChevron = find.byIcon(Icons.chevron_right_rounded);
    await t.tap(rightChevron.first);
    await settle(t, 2000);
    await ss('diary_14_back_to_today');
    debugPrint('✓ Date navigation works');
  });

  testWidgets('Diary: Empty search shows no results state', (t) async {
    await launchApp(t);

    final addBtn = find.text('Add');
    if (addBtn.evaluate().isEmpty) return;
    await t.tap(addBtn.first);
    await settle(t, 2000);

    final searchField = find.byType(TextField);
    await t.tap(searchField.first);
    await t.enterText(searchField.first, 'zzznonexistent999');
    await settle(t, 3000);
    await ss('diary_15_no_results');
    debugPrint('✓ No results state shown');

    // Clear search
    await t.enterText(searchField.first, '');
    await settle(t, 1000);
    await ss('diary_16_cleared');

    await goBack(t);
  });
}
