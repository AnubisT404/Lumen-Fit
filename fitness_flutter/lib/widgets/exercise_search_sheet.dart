import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/workouts_service.dart';
import '../utils/modal_utils.dart';

const _categories = ['all', 'chest', 'back', 'shoulders', 'legs', 'arms', 'core', 'cardio'];

/// Full-screen exercise search page.
/// Returns {'name': String, 'category': String} on selection.
class ExerciseSearchSheet extends StatefulWidget {
  const ExerciseSearchSheet({super.key});

  @override
  State<ExerciseSearchSheet> createState() => _ExerciseSearchSheetState();

  /// Show as a full-screen page. Returns the selected exercise or null.
  static Future<Map<String, String>?> show(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<Map<String, String>>(
      CupertinoPageRoute(
        builder: (_) => const ExerciseSearchSheet(),
      ),
    );
  }
}


class _ExerciseSearchSheetState extends State<ExerciseSearchSheet> {
  String _query = '';
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;
  final _controller = TextEditingController();
  int _selectedTab = 0;
  final _pageController = PageController();
  Set<String> _favorites = {};

  static const _favKey = 'exercise_favorites';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _search('');
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favKey) ?? [];
    setState(() => _favorites = raw.toSet());
  }

  Future<void> _toggleFavorite(String name, String category) async {
    final key = '$name|$category';
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_favorites.contains(key)) {
        _favorites.remove(key);
      } else {
        _favorites.add(key);
      }
    });
    await prefs.setStringList(_favKey, _favorites.toList());
  }

  bool _isFavorite(String name, String category) => _favorites.contains('$name|$category');

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
    setState(() {});
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final res = await WorkoutsService.searchExercises(q);
      if (mounted) setState(() => _results = res);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> _filteredFor(String category) {
    if (category == 'all') return _results;
    return _results.where((e) => e['category'] == category).toList();
  }

  String _categoryLabel(String cat) {
    switch (cat) {
      case 'all':
        return 'All';
      default:
        return cat.isNotEmpty ? cat[0].toUpperCase() + cat.substring(1) : cat;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _query.length >= 2;
    final muted = AppColors.textMuted;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),

            // Close button + Search field row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: AppGlassButton(
                      sfSymbol: SFSymbol('chevron.left', size: 14),
                      style: AdaptiveButtonStyle.glass,
                      size: AdaptiveButtonSize.small,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: AdaptiveTextField(
                        controller: _controller,
                        autofocus: true,
                        autocorrect: false,
                        onChanged: _onQueryChanged,
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        placeholder: 'Search exercises...',
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.orange.withAlpha(140)),
                        suffixIcon: _query.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  _onQueryChanged('');
                                },
                                child: Icon(Icons.clear_rounded, size: 14, color: muted.withAlpha(120)),
                              )
                            : null,
                        cupertinoDecoration: BoxDecoration(
                          color: CupertinoColors.systemFill,
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Scrollable category chips (glass-styled)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final isActive = _selectedTab == i;
                  final label = _categoryLabel(_categories[i]);
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTab = i);
                      _pageController.animateToPage(
                        i,
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.orange
                            : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive
                              ? AppColors.orange.withAlpha(180)
                              : Colors.white.withAlpha(25),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Custom entry (when searching)
            if (hasQuery)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: AppGlassButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(context, {'name': _query, 'category': ''});
                    },
                    label: 'Add "$_query" as custom',
                    style: AdaptiveButtonStyle.glass,
                    size: AdaptiveButtonSize.small,
                  ),
                ),
              ),

            // Favorites section (when not searching and on All tab)
            if (!hasQuery && _favorites.isNotEmpty && _selectedTab == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 14, color: AppColors.orange.withAlpha(180)),
                        const SizedBox(width: 5),
                        Text('Favorites', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _favorites.map((key) {
                        final parts = key.split('|');
                        final name = parts[0];
                        final cat = parts.length > 1 ? parts[1] : '';
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, {'name': name, 'category': cat});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.orange.withAlpha(18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.orange.withAlpha(50), width: 0.5),
                            ),
                            child: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.orange)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            // Filtered exercise list — swipeable pages per category
            Expanded(
              child: _loading && _results.isEmpty
                  ? Center(child: CircularProgressIndicator(color: muted.withAlpha(100), strokeWidth: 2))
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _categories.length,
                      onPageChanged: (page) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedTab = page);
                      },
                      itemBuilder: (_, i) => _buildExerciseList(
                        _filteredFor(_categories[i]),
                        hasQuery,
                        muted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseList(
      List<Map<String, dynamic>> items, bool hasQuery, Color muted) {
    if (items.isEmpty) {
      final cat = _categories[_selectedTab];
      final isAll = cat == 'all';
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 40, color: AppColors.textSecondary.withAlpha(80)),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? (isAll ? 'No exercises found' : 'No ${_categoryLabel(cat)} exercises found')
                  : 'Search for exercises',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              hasQuery ? 'Try a different name or add as custom' : 'Type at least 2 characters to search',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildExerciseRow(items[i], i, items.length, muted),
    );
  }

  Widget _buildExerciseRow(Map<String, dynamic> ex, int index, int total, Color muted) {
    final cat = ex['category'] as String? ?? '';
    final name = ex['name'] as String? ?? '';
    final source = ex['source'] as String? ?? '';
    final count = ex['usage_count'] as int? ?? 0;
    final isRecent = source == 'history';
    final color = AppColors.categoryColors[cat] ?? AppColors.textMuted;

    return Padding(
      padding: EdgeInsets.only(bottom: index < total - 1 ? 6 : 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.pop(context, {'name': name, 'category': cat});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withAlpha(20), width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withAlpha(22),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  cat.isNotEmpty ? cat[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color.withAlpha(200)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (cat.isNotEmpty)
                          Text(_categoryLabel(cat), style: TextStyle(fontSize: 11, color: color.withAlpha(150))),
                        if (isRecent && count > 0) ...[
                          if (cat.isNotEmpty)
                            Text('  ·  ', style: TextStyle(fontSize: 11, color: muted.withAlpha(80))),
                          Text('$count×', style: TextStyle(fontSize: 11, color: muted.withAlpha(130))),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isRecent)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.history_rounded, size: 14, color: muted.withAlpha(80)),
                ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _toggleFavorite(name, cat);
                },
                child: Icon(
                  _isFavorite(name, cat) ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                  color: _isFavorite(name, cat) ? AppColors.orange : muted.withAlpha(60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
