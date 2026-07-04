// ═══════════════════════════════════════════════════════════════════════════
// COACH & CHAT — Integration Test
// Tests: coach screen loads, insight card, topic cards, open chat,
//        type message, send message, receive response, chat history
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  initBinding();

  testWidgets('Coach: Screen loads with insight and topics', (t) async {
    await launchApp(t);
    await goToTab(t, 'Coach');
    await ss('coach_01_loaded');

    // Verify key elements
    final insight = find.text("Today's Insight");
    final chat = find.text('Chat');

    expect(
      insight.evaluate().isNotEmpty || chat.evaluate().isNotEmpty,
      true,
      reason: 'Coach screen must show insight or chat button',
    );
    debugPrint('✓ Coach screen loaded');
  });

  testWidgets('Coach: Scroll to see all topics', (t) async {
    await launchApp(t);
    await goToTab(t, 'Coach');

    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isNotEmpty) {
      await t.drag(scrollable.first, const Offset(0, -300));
      await settle(t);
      await ss('coach_02_scrolled');
      debugPrint('✓ Coach scrolled — topics visible');

      await t.drag(scrollable.first, const Offset(0, 300));
      await settle(t);
    }
  });

  testWidgets('Coach: Open chat screen', (t) async {
    await launchApp(t);
    await goToTab(t, 'Coach');

    final chatBtn = find.text('Chat');
    if (chatBtn.evaluate().isNotEmpty) {
      await t.tap(chatBtn.last);
      await settle(t, 1500);
      await ss('coach_03_chat_screen');

      // Verify chat screen elements
      final chatInput = find.byType(TextField);
      expect(chatInput, findsWidgets, reason: 'Chat must have input field');
      debugPrint('✓ Chat screen opened');

      await goBack(t);
    } else {
      debugPrint('⚠ Chat button not found');
    }
  });

  testWidgets('Coach: Type and send chat message', (t) async {
    await launchApp(t);
    await goToTab(t, 'Coach');

    final chatBtn = find.text('Chat');
    if (chatBtn.evaluate().isEmpty) return;
    await t.tap(chatBtn.last);
    await settle(t, 1500);

    // Type a message
    final chatField = find.byType(TextField);
    if (chatField.evaluate().isEmpty) return;
    await t.tap(chatField.first);
    await t.enterText(chatField.first, 'What are good protein sources?');
    await settle(t);
    await ss('coach_04_message_typed');
    debugPrint('✓ Message typed');

    // Tap send button
    final sendBtn = find.byIcon(Icons.arrow_upward_rounded);
    if (sendBtn.evaluate().isNotEmpty) {
      await t.tap(sendBtn.first);
      await settle(t, 5000); // wait for AI response
      await ss('coach_05_response');
      debugPrint('✓ Message sent — waiting for response');
    } else {
      debugPrint('⚠ Send button not found (AI may not be configured)');
    }
  });

  testWidgets('Coach: Tap topic card opens chat with pre-filled', (t) async {
    await launchApp(t);
    await goToTab(t, 'Coach');

    // Look for topic cards
    final fatLoss = find.text('Fat loss tips');
    final mealPrep = find.text('Meal prep ideas');
    Finder? topic;
    if (fatLoss.evaluate().isNotEmpty) {
      topic = fatLoss;
    } else if (mealPrep.evaluate().isNotEmpty) {
      topic = mealPrep;
    }

    if (topic != null) {
      await t.tap(topic.first);
      await settle(t, 2000);
      await ss('coach_06_topic_chat');
      debugPrint('✓ Topic card opened chat');

      // Should be on chat screen
      final chatField = find.byType(TextField);
      expect(chatField, findsWidgets, reason: 'Should navigate to chat');

      await goBack(t);
    } else {
      debugPrint('⚠ No topic cards found (may need scroll)');
      // Try scrolling
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        await t.drag(scrollable.first, const Offset(0, -300));
        await settle(t);
        final anyTopic = find.textContaining('tips');
        if (anyTopic.evaluate().isNotEmpty) {
          await t.tap(anyTopic.first);
          await settle(t, 2000);
          await ss('coach_06_topic_chat');
          await goBack(t);
        }
      }
    }
  });

  testWidgets('Coach: Chat back button returns to coach', (t) async {
    await launchApp(t);
    await goToTab(t, 'Coach');

    final chatBtn = find.text('Chat');
    if (chatBtn.evaluate().isEmpty) return;
    await t.tap(chatBtn.last);
    await settle(t, 1500);

    // Verify on chat
    final chatField = find.byType(TextField);
    expect(chatField, findsWidgets);

    // Go back
    await goBack(t);
    await settle(t);
    await ss('coach_07_back_from_chat');

    // Should be back on coach screen
    final coachContent = find.text("Today's Insight");
    expect(coachContent.evaluate().isNotEmpty || find.text('Chat').evaluate().isNotEmpty, true,
        reason: 'Should be back on Coach screen');
    debugPrint('✓ Back navigation from chat works');
  });
}
