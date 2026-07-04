import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/router.dart';
import '../../config/theme.dart';

/// Dev-only screen that auto-navigates through all app routes,
/// pausing at each for screenshot capture.
/// Uses a static timer so navigation continues even after this widget unmounts.
class DevTourScreen extends StatefulWidget {
  const DevTourScreen({super.key});

  static int _step = 0;
  static bool _isRunning = false;

  static final List<String> routes = [
    '/diary',
    '/coach',
    '/workouts',
    '/menu',
    '/add-food?meal=breakfast',
    '/new-workout?type=strength',
    '/plans',
    '/measurements',
    '/nutrition',
    '/nutrition/goals',
    '/chat',
  ];

  static final List<String> names = [
    'Diary',
    'Coach',
    'Workouts',
    'Menu',
    'Add Food',
    'New Workout',
    'Plans',
    'Measurements',
    'Nutrition Detail',
    'Goals',
    'Chat',
  ];

  static void startTour(BuildContext context) {
    if (_isRunning) return;
    _isRunning = true;
    _step = 0;

    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_step >= routes.length) {
        timer.cancel();
        _isRunning = false;
        return;
      }
      appRouter.go(routes[_step]);
      _step++;
    });
  }

  @override
  State<DevTourScreen> createState() => _DevTourScreenState();
}

class _DevTourScreenState extends State<DevTourScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Dev Tour', style: TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Visual QA Tour', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('Auto-navigating in 2 seconds...\nRun: ./auto_screenshot.sh 40', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.builder(
                itemCount: DevTourScreen.routes.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: Text('${i + 1}', style: TextStyle(color: AppColors.textMuted)),
                  title: Text(DevTourScreen.names[i], style: TextStyle(color: AppColors.textPrimary)),
                  subtitle: Text(DevTourScreen.routes[i], style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
