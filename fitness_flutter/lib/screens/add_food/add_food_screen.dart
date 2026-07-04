// Add Food screen — search, select, configure servings, and log food.
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../../config/theme.dart';
import '../../models/food_item.dart';
import '../../providers/add_food_provider.dart';
import '../../providers/meals_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/meals_service.dart';
import '../../utils/modal_utils.dart';
import 'add_food_models.dart';
import 'add_food_widgets.dart';
import 'barcode_scanner_screen.dart';

class AddFoodScreen extends ConsumerStatefulWidget {
  final String mealType;
  final String date;
  final String? editItemId;

  const AddFoodScreen({
    super.key,
    required this.mealType,
    required this.date,
    this.editItemId,
  });

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _debouncedQuery = '';

  FoodItem? _selectedFood;
  double _servingAmount = 1;
  int _selectedServingIdx = 0;
  late String _mealType;
  String _browseTab = 'recent';
  bool _saving = false;

  // Template build mode
  List<BuildingItem>? _buildItems;
  int? _buildEditId;
  String _buildName = '';
  int? _editingBuildItemIdx;

  @override
  void initState() {
    super.initState();
    _mealType = widget.mealType;
    _searchController.addListener(_onSearchChanged);
    if (widget.editItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditItem());
    }
  }

  void _loadEditItem() {
    final meals = ref.read(mealsProvider).valueOrNull;
    if (meals == null) return;
    final editId = int.tryParse(widget.editItemId!);
    if (editId == null) return;
    final entry = meals.where((m) => m.id == editId).firstOrNull;
    if (entry == null) return;

    final food = FoodItem(
      name: entry.foodName,
      calories: entry.baseCalories ?? entry.calories,
      proteinG: entry.baseProtein ?? entry.protein,
      carbsG: entry.baseCarbs ?? entry.carbs,
      fatsG: entry.baseFat ?? entry.fat,
      servingSize: entry.servingSize,
      servingUnit: entry.servingUnit,
      source: 'local',
    );

    final options = getServingOptions(food);
    int servIdx = 0;
    for (int i = 0; i < options.length; i++) {
      if ((options[i].gramWeight - entry.servingSize).abs() < 0.5) {
        servIdx = i;
        break;
      }
    }

    setState(() {
      _selectedFood = food;
      _servingAmount = entry.servings;
      _selectedServingIdx = servIdx;
      _mealType = entry.mealType;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    ref.read(searchQueryProvider.notifier).state = query;
    _debounceTimer?.cancel();
    if (query.length < 2) {
      setState(() => _debouncedQuery = '');
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      setState(() => _debouncedQuery = query);
    });
  }

  Future<void> _openBarcodeScanner() async {
    final barcode = await BarcodeScannerScreen.show(context);
    if (barcode == null || !mounted) return;

    // Use fast barcode lookup (local DB → OFF product API)
    try {
      final results = await MealsService.lookupBarcode(barcode);
      if (!mounted) return;
      if (results.isNotEmpty) {
        // Show in search results via OFF tab with barcode in search field
        ref.read(searchSourceProvider.notifier).state = 'off';
        _searchController.text = barcode;
        ref.read(searchQueryProvider.notifier).state = barcode;
        setState(() {
          _debouncedQuery = barcode;
          // Auto-select if exactly one result
          if (results.length == 1) {
            _selectedFood = results.first;
            _selectedServingIdx = 0;
            _servingAmount = 1;
          }
        });
      } else {
        if (mounted) {
          AdaptiveSnackBar.show(context,
              message: 'Product not found for barcode $barcode',
              type: AdaptiveSnackBarType.warning);
        }
      }
    } catch (e) {
      if (mounted) {
        // Fallback to text search if barcode endpoint fails
        ref.read(searchSourceProvider.notifier).state = 'off';
        _searchController.text = barcode;
        ref.read(searchQueryProvider.notifier).state = barcode;
        setState(() => _debouncedQuery = barcode);
      }
    }
  }

  // ── Add Food Action ────────────────────────────────────────────────

  Future<void> _handleAddFood() async {
    if (_selectedFood == null || _saving) return;
    if (_servingAmount <= 0) {
      AdaptiveSnackBar.show(context,
          message: 'Serving size must be greater than zero.',
          type: AdaptiveSnackBarType.info);
      return;
    }
    setState(() => _saving = true);
    final food = _selectedFood!;
    final options = getServingOptions(food);
    final nutrition = calcNutrition(food, options, _selectedServingIdx, _servingAmount);
    final safeIdx = options.isNotEmpty
        ? _selectedServingIdx.clamp(0, options.length - 1)
        : 0;
    final selected = options.isNotEmpty ? options[safeIdx] : null;
    final totalGrams = nutrition['totalGrams']!;
    final base = (food.source == 'MFP' || food.source == 'local')
        ? (food.servingSize ?? 100)
        : 100.0;
    final multiplier = totalGrams / base;

    try {
      if (widget.editItemId != null) {
        await MealsService.updateItem(int.parse(widget.editItemId!), {
          'servings': _servingAmount,
          'serving_size': selected?.gramWeight ?? 100,
          'serving_unit': selected?.shortLabel ?? 'g',
          'calories': nutrition['calories']!,
          'protein_g': nutrition['protein']!,
          'carbs_g': nutrition['carbs']!,
          'fats_g': nutrition['fat']!,
          'meal_type': _mealType,
        });
      } else {
        await MealsService.quickAdd(
          mealType: _mealType,
          foodName: food.displayName,
          brand: food.displayBrand.isNotEmpty ? food.displayBrand : null,
          barcode: food.barcode,
          calories: nutrition['calories']!,
          proteinG: nutrition['protein']!,
          carbsG: nutrition['carbs']!,
          fatsG: nutrition['fat']!,
          fiberG: food.fiberG != null ? (food.fiberG! * multiplier).roundToDouble() : null,
          sugarG: food.sugarG != null ? (food.sugarG! * multiplier).roundToDouble() : null,
          sodiumMg: food.sodiumMg != null ? (food.sodiumMg! * multiplier).roundToDouble() : null,
          saturatedFatG: food.saturatedFatG != null
              ? double.parse((food.saturatedFatG! * multiplier).toStringAsFixed(1))
              : null,
          servingSize: totalGrams,
          servingUnit: selected?.shortLabel ?? 'g',
          servings: _servingAmount,
          source: food.source ?? 'manual',
        );
      }
      ref.invalidate(mealsProvider);
      if (mounted) {
        AdaptiveSnackBar.show(context,
            message: widget.editItemId != null ? 'Food updated!' : 'Food added!',
            type: AdaptiveSnackBarType.success);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AdaptiveSnackBar.show(context,
            message: 'Failed to save. Please try again.',
            type: AdaptiveSnackBarType.error);
      }
    }
  }

  void _addToBuild(
    FoodItem food,
    Map<String, double> nutrition,
    double servingAmount,
    String servingUnit,
    double servingGramWeight,
  ) {
    if (_buildItems == null) return;
    final base = (food.source == 'MFP' || food.source == 'local')
        ? (food.servingSize ?? 100)
        : 100.0;
    final multiplier = (servingGramWeight * servingAmount) / base;
    final newItem = BuildingItem(
      food: food,
      servings: multiplier,
      servingSize: servingGramWeight,
      servingUnit: '$servingAmount × $servingUnit',
      calories: nutrition['calories']!.round(),
      proteinG: nutrition['protein']!.round(),
      carbsG: nutrition['carbs']!.round(),
      fatsG: nutrition['fat']!.round(),
    );
    setState(() {
      if (_editingBuildItemIdx != null) {
        _buildItems![_editingBuildItemIdx!] = newItem;
        _editingBuildItemIdx = null;
      } else {
        _buildItems!.add(newItem);
      }
    });
  }

  Future<void> _handleSaveTemplate() async {
    if (_buildItems == null || _buildName.trim().isEmpty || _buildItems!.isEmpty) return;
    try {
      final payload = {
        'name': _buildName.trim(),
        'items': _buildItems!
            .map((item) => <String, dynamic>{
                  'food_id': int.tryParse(item.food.id ?? '0') ?? 0,
                  'servings': item.servings,
                  'serving_size': item.servingSize,
                  'serving_unit': item.servingUnit,
                  'food_name': item.food.displayName,
                  'brand': item.food.displayBrand,
                  'calories': item.food.calories ?? 0,
                  'protein_g': item.food.proteinG ?? 0,
                  'carbs_g': item.food.carbsG ?? 0,
                  'fats_g': item.food.fatsG ?? 0,
                })
            .toList(),
      };
      if (_buildEditId != null) {
        await MealsService.updateTemplate(_buildEditId!, payload);
      } else {
        await MealsService.createTemplate(
          name: _buildName.trim(),
          items: payload['items'] as List<Map<String, dynamic>>,
        );
      }
      ref.invalidate(mealTemplatesProvider);
      setState(() {
        _buildItems = null;
        _buildEditId = null;
        _buildName = '';
        _editingBuildItemIdx = null;
        _browseTab = 'mymeals';
      });
      if (mounted) {
        AdaptiveSnackBar.show(context,
            message: 'Meal template saved!', type: AdaptiveSnackBarType.success);
      }
    } catch (e) {
      if (mounted) {
        AdaptiveSnackBar.show(context,
            message: 'Failed to save template. Please try again.',
            type: AdaptiveSnackBarType.error);
      }
    }
  }

  void _showServingsSheet(bool isGramMode) {
    final currentValue = _servingAmount;
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ServingsPickerSheet(
          currentValue: currentValue,
          isGramMode: isGramMode,
          onDone: (v) {
            setState(() => _servingAmount = math.max(0.1, v));
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _showUnitSheet(List<ServingOption> options) {
    final safeIdx = _selectedServingIdx.clamp(0, options.length - 1);
    final currentTotalG = (options[safeIdx].gramWeight * _servingAmount).round();
    showAppSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: UnitPickerSheet(
          options: options,
          selectedIndex: safeIdx,
          onSelect: (i) {
            setState(() {
              final opt = options[i];
              _selectedServingIdx = i;
              if (opt.gramWeight == 1) {
                _servingAmount = currentTotalG > 0 ? currentTotalG.toDouble() : 100;
              } else if (opt.gramWeight == 28.35) {
                _servingAmount = math.max(1, (currentTotalG / 28.35 * 2).round() / 2);
              } else {
                _servingAmount = 1;
              }
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final searchSource = ref.watch(searchSourceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(searchSource),
            Expanded(
              child: _selectedFood != null
                  ? _buildFoodDetail()
                  : _buildSearchOrBrowse(searchQuery),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String searchSource) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 36, height: 36,
                child: AppGlassButton(
                  sfSymbol: SFSymbol('chevron.left', size: 14),
                  size: AdaptiveButtonSize.small,
                  onPressed: () {
                    if (_selectedFood != null && widget.editItemId == null) {
                      setState(() {
                        _selectedFood = null;
                        _servingAmount = 1;
                        _selectedServingIdx = 0;
                      });
                    } else {
                      context.pop();
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: AdaptiveTextField(
                    controller: _searchController,
                    autofocus: true,
                    autocorrect: false,
                    style: AppTextStyles.body,
                    placeholder: 'Search foods by name...',
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.primary.withAlpha(140)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchController.clear(); _onSearchChanged(); },
                            child: Icon(Icons.clear_rounded, size: 14, color: AppColors.textMuted.withAlpha(120)),
                          )
                        : null,
                    cupertinoDecoration: BoxDecoration(
                      color: CupertinoColors.systemFill,
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 36, height: 36,
                child: AppGlassButton(
                  sfSymbol: SFSymbol('barcode.viewfinder', size: 16),
                  size: AdaptiveButtonSize.small,
                  onPressed: _openBarcodeScanner,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 8),
              SourceToggle(
                source: searchSource,
                onChanged: (s) => ref.read(searchSourceProvider.notifier).state = s,
              ),
              if (searchSource == 'off')
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('Online — may be slower',
                      style: AppTextStyles.small.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.warning)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Food Detail View ───────────────────────────────────────────────

  Widget _buildFoodDetail() {
    final food = _selectedFood!;
    final options = getServingOptions(food);
    final safeIdx = options.isNotEmpty ? _selectedServingIdx.clamp(0, options.length - 1) : 0;
    final selected = options.isNotEmpty ? options[safeIdx] : null;
    final nutrition = calcNutrition(food, options, _selectedServingIdx, _servingAmount);
    final isGramMode = selected != null && selected.gramWeight == 1;
    final totalG = selected != null ? (selected.gramWeight * _servingAmount).round() : 0;

    final calories = nutrition['calories']!.round();
    final protein = nutrition['protein']!.round();
    final carbs = nutrition['carbs']!.round();
    final fat = nutrition['fat']!.round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdaptiveCard(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(food.displayName, style: AppTextStyles.heading)),
                  if (sourceBadge(food) != null) ...[const SizedBox(width: 8), sourceBadge(food)!],
                ]),
                if (food.displayBrand.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(food.displayBrand, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                  ),
                const Divider(height: 24),
                TapRow(
                  label: 'Serving Size',
                  value: fmtServingLabel(selected?.shortLabel ?? selected?.label ?? '-'),
                  onTap: () => _showUnitSheet(options),
                ),
                const Divider(height: 1),
                TapRow(
                  label: 'Number of Servings',
                  value: isGramMode
                      ? '${_servingAmount.round()}'
                      : (_servingAmount == _servingAmount.roundToDouble()
                          ? '${_servingAmount.round()}'
                          : _servingAmount.toStringAsFixed(1)),
                  onTap: () => _showServingsSheet(isGramMode),
                ),
                const Divider(height: 1),
                MealDropdownRow(mealType: _mealType, onChanged: (m) => setState(() => _mealType = m)),
                if (!isGramMode && totalG > 0) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('= ${totalG}g total', textAlign: TextAlign.center,
                        style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AdaptiveCard(
          color: AppColors.surface,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MacroDonut(calories: calories, protein: protein, carbs: carbs, fat: fat),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: AppGlassButton(
            onPressed: () {
              if (_buildItems != null) {
                final sel = options.isNotEmpty ? options[safeIdx] : null;
                if (sel != null) _addToBuild(food, nutrition, _servingAmount, sel.shortLabel, sel.gramWeight);
                setState(() { _selectedFood = null; _servingAmount = 1; _selectedServingIdx = 0; _searchController.clear(); _browseTab = 'mymeals'; });
              } else {
                _handleAddFood();
              }
            },
            label: widget.editItemId != null
                ? 'Save Changes'
                : _buildItems != null
                    ? (_editingBuildItemIdx != null ? 'Update Item' : 'Add to Meal')
                    : 'Add to ${mealLabels[_mealType] ?? 'Meal'}',
            color: AppColors.primary,
            size: AdaptiveButtonSize.large,
          ),
        ),
      ],
    );
  }

  // ── Search / Browse ────────────────────────────────────────────────

  Widget _buildSearchOrBrowse(String searchQuery) {
    if (searchQuery.length >= 2 && searchQuery != _debouncedQuery) return _buildSearchLoading();
    if (_debouncedQuery.length >= 2) return _buildSearchResults();

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            TabButton(label: 'Recent', isActive: _browseTab == 'recent', onTap: () => setState(() => _browseTab = 'recent')),
            const SizedBox(width: 16),
            TabButton(label: 'My Meals', isActive: _browseTab == 'mymeals', onTap: () => setState(() => _browseTab = 'mymeals')),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: _browseTab == 'recent' ? _buildRecentFoods() : _buildMyMeals()),
      ],
    );
  }

  Widget _buildSearchLoading() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 12),
          Text('Searching...', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildSearchResults() {
    final resultsAsync = ref.watch(foodSearchProvider(_debouncedQuery));
    return resultsAsync.when(
      loading: () => _buildSearchLoading(),
      error: (e, _) => const Center(child: Text('Could not load data.')),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text('No foods found for "$_debouncedQuery"', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Try shorter keywords, check spelling, or use "Quick Add" to log manually',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w400, color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('${results.length} results found', style: AppTextStyles.label),
            const SizedBox(height: 8),
            AdaptiveCard(
              color: AppColors.surface,
              child: Column(children: [
                for (int i = 0; i < results.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                  FoodResultTile(
                    food: results[i],
                    onTap: () => setState(() { _selectedFood = results[i]; _selectedServingIdx = 0; _servingAmount = 1; }),
                  ),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentFoods() {
    final recentAsync = ref.watch(recentFoodsProvider);
    return recentAsync.when(
      loading: () => Shimmer.fromColors(
        baseColor: AppColors.surfaceAlt,
        highlightColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: List.generate(5, (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(height: 60, decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12))),
          )),
        ),
      ),
      error: (e, _) => const Center(child: Text('Could not load recent foods.')),
      data: (data) {
        final recent = data['recent'] ?? [];
        final frequent = data['frequent'] ?? [];
        if (recent.isEmpty && frequent.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.search, size: 64, color: AppColors.iconMuted.withAlpha(100)),
                const SizedBox(height: 16),
                Text('Search for Foods', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Text('Start typing to search our database', style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
              ]),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (recent.isNotEmpty)
              AdaptiveCard(
                color: AppColors.surface,
                child: Column(children: [
                  for (int i = 0; i < recent.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    FoodResultTile(food: recent[i], onTap: () => setState(() { _selectedFood = recent[i]; _selectedServingIdx = 0; _servingAmount = 1; })),
                  ],
                ]),
              ),
            if (frequent.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Frequently Logged', style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              AdaptiveCard(
                color: AppColors.surface,
                child: Column(children: [
                  for (int i = 0; i < frequent.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    FoodResultTile(food: frequent[i], onTap: () => setState(() { _selectedFood = frequent[i]; _selectedServingIdx = 0; _servingAmount = 1; })),
                  ],
                ]),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildMyMeals() {
    final templatesAsync = ref.watch(mealTemplatesProvider);
    return templatesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => const Center(child: Text('Could not load data.')),
      data: (templates) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_buildItems != null)
              BuildModeCard(
                name: _buildName,
                items: _buildItems!,
                editId: _buildEditId,
                onUpdateName: (n) => setState(() => _buildName = n),
                onRemoveItem: (i) => setState(() => _buildItems!.removeAt(i)),
                onEditItem: (i) {
                  final item = _buildItems![i];
                  setState(() {
                    _editingBuildItemIdx = i;
                    _selectedFood = item.food;
                    final options = getServingOptions(item.food);
                    final gramIdx = options.indexWhere((o) => o.gramWeight == 1 && o.shortLabel == 'g');
                    _selectedServingIdx = gramIdx >= 0 ? gramIdx : 0;
                    _servingAmount = gramIdx >= 0 ? (item.servings * 100).roundToDouble() : item.servings;
                    _browseTab = 'recent';
                  });
                },
                onAddMore: () => setState(() { _editingBuildItemIdx = null; _selectedFood = null; _browseTab = 'recent'; }),
                onSave: _handleSaveTemplate,
                onCancel: () => setState(() { _buildItems = null; _buildEditId = null; _buildName = ''; _editingBuildItemIdx = null; }),
              )
            else
              CreateMealButton(onTap: () => setState(() { _buildItems = []; _buildEditId = null; _buildName = ''; _searchController.clear(); _selectedFood = null; })),
            if (_buildItems == null) ...[
              if (templates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(children: [
                    Text('No saved meals yet.', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text('Create one to quickly log combos you eat often.', style: AppTextStyles.small.copyWith(fontWeight: FontWeight.w400)),
                  ]),
                )
              else
                for (final t in templates) ...[
                  const SizedBox(height: 12),
                  TemplateCard(
                    template: t,
                    mealType: _mealType,
                    onLog: () async {
                      try {
                        await MealsService.logTemplate(t.id, mealType: _mealType, date: widget.date);
                        ref.invalidate(mealsProvider);
                        ref.invalidate(mealTemplatesProvider);
                        if (mounted) { AdaptiveSnackBar.show(context, message: 'Meal added!', type: AdaptiveSnackBarType.success); context.pop(); }
                      } catch (e) {
                        if (mounted) AdaptiveSnackBar.show(context, message: 'Failed to add meal. Please try again.', type: AdaptiveSnackBarType.error);
                      }
                    },
                    onEdit: () {
                      final items = t.items.map((item) => BuildingItem(
                        food: FoodItem(
                          id: item.foodId.toString(),
                          name: item.foodName,
                          brand: item.brand,
                          calories: item.calories / (item.servings > 0 ? item.servings : 1),
                          proteinG: item.proteinG / (item.servings > 0 ? item.servings : 1),
                          carbsG: item.carbsG / (item.servings > 0 ? item.servings : 1),
                          fatsG: item.fatsG / (item.servings > 0 ? item.servings : 1),
                        ),
                        servings: item.servings,
                        servingSize: item.servingSize ?? 100,
                        servingUnit: item.servingUnit ?? 'g',
                        calories: item.calories.round(),
                        proteinG: item.proteinG.round(),
                        carbsG: item.carbsG.round(),
                        fatsG: item.fatsG.round(),
                      )).toList();
                      setState(() { _buildItems = items; _buildEditId = t.id; _buildName = t.name; });
                    },
                    onDelete: () async {
                      try {
                        await MealsService.deleteTemplate(t.id);
                        ref.invalidate(mealTemplatesProvider);
                        if (mounted) AdaptiveSnackBar.show(context, message: 'Template deleted', type: AdaptiveSnackBarType.success);
                      } catch (e) {
                        if (mounted) AdaptiveSnackBar.show(context, message: 'Failed to delete. Please try again.', type: AdaptiveSnackBarType.error);
                      }
                    },
                  ),
                ],
            ],
          ],
        );
      },
    );
  }
}
