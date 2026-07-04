import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../config/theme.dart';
import '../widgets/exercise_search_sheet.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static const _tabs = [
    _TabItem('/diary', 'Diary', 'fork.knife', 'fork.knife'),
    _TabItem('/coach', 'Coach', 'brain', 'brain.head.profile.fill'),
    _TabItem('/workouts', 'Workouts', 'dumbbell', 'dumbbell.fill'),
    _TabItem('/menu', 'More', 'ellipsis', 'ellipsis.circle.fill'),
  ];

  void _onTap(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    if (index == navigationShell.currentIndex) {
      _onReTap(context, index);
      return;
    }
    navigationShell.goBranch(index);
  }

  void _onReTap(BuildContext context, int index) {
    switch (index) {
      case 0: // Diary — open food search
        context.push('/add-food');
        break;
      case 1: // Coach — open chat
        context.push('/chat');
        break;
      case 2: // Workouts — open exercise search
        _openExerciseSearch(context);
        break;
    }
  }

  void _openExerciseSearch(BuildContext context) async {
    final result = await ExerciseSearchSheet.show(context);
    if (result != null && context.mounted) {
      context.push('/new-workout?type=strength&exercise=${Uri.encodeComponent(result['name'] ?? '')}&category=${Uri.encodeComponent(result['category'] ?? '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register as Theme dependent so shell rebuilds on system brightness changes
    Theme.of(context);
    final index = navigationShell.currentIndex;
    return Scaffold(
      extendBody: true,
      body: AppColors.gradientMesh(child: navigationShell),
      bottomNavigationBar: _buildNavBar(context, index),
    );
  }

  Widget _buildNavBar(BuildContext context, int index) {
    // Use native iOS 26 UITabBar on iOS, fallback to custom on other platforms
    if (!kIsWeb && Platform.isIOS) {
      return IOS26NativeTabBar(
        destinations: _tabs
            .map((t) => AdaptiveNavigationDestination(
                  icon: t.icon,
                  label: t.label,
                  selectedIcon: t.activeIcon,
                ))
            .toList(),
        selectedIndex: index,
        onTap: (i) => _onTap(context, i),
        tint: AppColors.primary,
      );
    }
    // Fallback for non-iOS (custom glass bar)
    return _FallbackGlassNavBar(
      currentIndex: index,
      onTap: (i) => _onTap(context, i),
      tabs: _tabs,
    );
  }
}

// ── Fallback for non-iOS platforms ───────────────────────────────────
class _FallbackGlassNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabItem> tabs;

  const _FallbackGlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  static const _iconMap = <String, IconData>{
    'fork.knife': Icons.restaurant_menu_rounded,
    'brain': Icons.smart_toy_outlined,
    'brain.head.profile.fill': Icons.smart_toy_rounded,
    'dumbbell': Icons.fitness_center_outlined,
    'dumbbell.fill': Icons.fitness_center_rounded,
    'ellipsis': Icons.more_horiz,
    'ellipsis.circle.fill': Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark
        ? Colors.black.withValues(alpha: 0.50)
        : Colors.white.withValues(alpha: 0.70);

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, bottom: bottomPadding + 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: barBg,
              borderRadius: BorderRadius.circular(35),
            ),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final isActive = i == currentIndex;
                final tab = tabs[i];
                final icon = isActive
                    ? (_iconMap[tab.activeIcon] ?? Icons.circle)
                    : (_iconMap[tab.icon] ?? Icons.circle);
                return Expanded(
                  child: Semantics(
                    label: tab.label,
                    button: true,
                    selected: isActive,
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 22,
                              color: isActive ? AppColors.primary : (isDark ? Colors.white : Colors.black)),
                          const SizedBox(height: 3),
                          Text(tab.label, style: TextStyle(
                            fontSize: 11,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive ? AppColors.primary : (isDark ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.8)),
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final String path, label;
  final String icon, activeIcon; // SF Symbol names
  const _TabItem(this.path, this.label, this.icon, this.activeIcon);
}
