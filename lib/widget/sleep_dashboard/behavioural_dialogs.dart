import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/services/nutrition_api_service.dart';
import 'package:dreamsync/services/exercise_api_service.dart';
import 'package:dreamsync/widget/custom/custom_bottom_sheet.dart';
import 'package:dreamsync/util/network_helper.dart';
import 'package:dreamsync/util/app_theme.dart';

class BehaviouralDialogs {
  // ── A1: Add Exercise ──────────────────────────────────────────────────────
  static Future<void> showAddExerciseDialog(BuildContext context) async {
    final ok = await NetworkHelper.ensureInternet(
      context,
      message: 'You cannot add exercise while offline.',
    );
    if (!ok) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExerciseSheetContent(parentContext: context),
    );
  }

  // ── A2: Add Food ──────────────────────────────────────────────────────────
  static Future<void> showAddFoodDialog(BuildContext context) async {
    final ok = await NetworkHelper.ensureInternet(
      context,
      message: 'You cannot add food while offline.',
    );
    if (!ok) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodSheetContent(parentContext: context),
    );
  }
}

// =============================================================================
// EXERCISE SHEET (with API search + calorie burn calculation)
// =============================================================================
class _ExerciseSheetContent extends StatefulWidget {
  final BuildContext parentContext;
  const _ExerciseSheetContent({required this.parentContext});

  @override
  State<_ExerciseSheetContent> createState() => _ExerciseSheetContentState();
}

class _ExerciseSheetContentState extends State<_ExerciseSheetContent> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _durationController = TextEditingController(text: '30');
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedExercise;
  bool _isLoading = false;
  int _durationMinutes = 30;

  @override
  void initState() {
    super.initState();
    _durationController.addListener(_onDurationChanged);
  }

  void _onDurationChanged() {
    final parsed = int.tryParse(_durationController.text) ?? 0;
    if (parsed != _durationMinutes) {
      setState(() => _durationMinutes = parsed);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _selectedExercise = null;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final hasInternet = await NetworkHelper.hasInternet();
      NetworkHelper.isOffline.value = !hasInternet;

      if (!hasInternet) {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
          });
          NetworkHelper.showOfflineSnackBar(
            widget.parentContext,
            message: 'Exercise search is unavailable while offline.',
          );
        }
        return;
      }

      final user =
          widget.parentContext.read<ProfileViewModel>().userProfile;
      final weightKg = user?.weight ?? 70.0;

      final results = await ExerciseApiService.searchExercises(
        query,
        weightKg: weightKg,
      );

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    });
  }

  void _selectExercise(Map<String, dynamic> exercise) {
    setState(() {
      _selectedExercise = exercise;
      _results = [];
      _searchController.text = exercise['name'];
    });
    _searchFocus.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selectedExercise = null;
      _searchController.clear();
      _results = [];
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  int get _calculatedCalories {
    if (_selectedExercise == null || _durationMinutes <= 0) return 0;
    final caloriesPerHour =
    (_selectedExercise!['calories_per_hour'] ?? 0).toDouble();
    return ExerciseApiService.calculateCaloriesBurned(
      caloriesPerHour: caloriesPerHour,
      durationMinutes: _durationMinutes,
    );
  }

  bool get _canSave =>
      _selectedExercise != null && _durationMinutes > 0;

  Future<void> _save() async {
    if (!_canSave) return;

    final ok = await NetworkHelper.ensureInternet(
      widget.parentContext,
      message: 'You cannot save exercise while offline.',
    );
    if (!ok) return;

    final user = widget.parentContext.read<ProfileViewModel>().userProfile;
    if (user != null) {
      final calories = _calculatedCalories;

      await widget.parentContext.read<DailyActivityViewModel>().addActivity(
        userId: user.userId,
        addExercise: _durationMinutes,
        addBurnedCalories: calories,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Added $_durationMinutes mins exercise ($calories kcal burned)',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSurface = AppTheme.surface(context);
    final themeText = AppTheme.text(context);
    final themeSubText = AppTheme.subText(context);
    final themeBorder = AppTheme.border(context);

    return CustomBottomSheet(
      title: 'Add Exercise',
      icon: Icons.directions_run,
      isButtonEnabled: _canSave,
      onSave: _save,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search field ──
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: true,
            style: TextStyle(color: themeText),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search exercise (e.g., Running)...',
              hintStyle: TextStyle(color: themeSubText),
              filled: true,
              fillColor: themeText.withOpacity(0.05),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: AppTheme.accent),
              suffixIcon: _isLoading
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              )
                  : _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close, color: themeSubText),
                onPressed: _clearSelection,
              )
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // ── Results list ──
          if (_results.isNotEmpty && _selectedExercise == null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 56.0 * 3.5),
              child: Container(
                decoration: BoxDecoration(
                  color: themeSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: themeBorder),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item['name'] ?? 'Unknown',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: themeText),
                        ),
                        subtitle: Text(
                          '${(item['calories_per_hour'] ?? 0).round()} kcal/hour',
                          style: TextStyle(fontSize: 12, color: themeSubText),
                        ),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: AppTheme.accent, size: 20),
                        onTap: () => _selectExercise(item),
                      );
                    },
                  ),
                ),
              ),
            ),

          // ── Selected exercise chip ──
          if (_selectedExercise != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedExercise!['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                        Text(
                          '${(_selectedExercise!['calories_per_hour'] ?? 0).round()} kcal/hour',
                          style: TextStyle(
                              fontSize: 12, color: themeText.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Duration input ──
          Text(
            'Duration (minutes)',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, color: themeText),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove,
                onTap: () {
                  if (_durationMinutes > 5) {
                    setState(() {
                      _durationMinutes -= 5;
                      _durationController.text = _durationMinutes.toString();
                    });
                  }
                },
              ),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 60,
                    child: TextField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: themeText),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                onTap: () {
                  setState(() {
                    _durationMinutes += 5;
                    _durationController.text = _durationMinutes.toString();
                  });
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Calorie burn estimate ──
          if (_selectedExercise != null && _durationMinutes > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department,
                      color: Colors.redAccent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated burn: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: themeText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_calculatedCalories kcal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// FOOD SHEET
// =============================================================================
class _FoodSheetContent extends StatefulWidget {
  final BuildContext parentContext;
  const _FoodSheetContent({required this.parentContext});

  @override
  State<_FoodSheetContent> createState() => _FoodSheetContentState();
}

class _FoodSheetContentState extends State<_FoodSheetContent> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];
  Map<String, dynamic>? _selectedFood;
  bool _isLoading = false;
  int _quantity = 1;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _selectedFood = null;
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final hasInternet = await NetworkHelper.hasInternet();
      NetworkHelper.isOffline.value = !hasInternet;

      if (!hasInternet) {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
          });
          NetworkHelper.showOfflineSnackBar(
            widget.parentContext,
            message: 'Food search is unavailable while offline.',
          );
        }
        return;
      }

      final results = await NutritionApiService.searchFoods(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    });
  }

  void _selectFood(Map<String, dynamic> food) {
    setState(() {
      _selectedFood = food;
      _results = [];
      _searchController.text = food['name'];
    });
    _searchFocus.unfocus();
  }

  void _clearSelection() {
    setState(() {
      _selectedFood = null;
      _searchController.clear();
      _results = [];
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  Future<void> _save() async {
    if (_selectedFood == null) return;

    final ok = await NetworkHelper.ensureInternet(
      widget.parentContext,
      message: 'You cannot save food intake while offline.',
    );
    if (!ok) return;

    final total =
    ((_selectedFood!['calories'] ?? 0).toDouble() * _quantity).round();
    final caffeine =
    ((_selectedFood!['caffeine_mg'] ?? 0).toDouble() * _quantity);
    final sugar = ((_selectedFood!['sugar_g'] ?? 0).toDouble() * _quantity);
    final alcohol = ((_selectedFood!['alcohol_g'] ?? 0).toDouble() * _quantity);

    final user = widget.parentContext.read<ProfileViewModel>().userProfile;

    if (user != null) {
      await widget.parentContext.read<DailyActivityViewModel>().addActivity(
        userId: user.userId,
        addFood: total,
        addCaffeine: caffeine,
        addSugar: sugar,
        addAlcohol: alcohol,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Added $total kcal successfully!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSurface = AppTheme.surface(context);
    final themeText = AppTheme.text(context);
    final themeSubText = AppTheme.subText(context);
    final themeBorder = AppTheme.border(context);

    return CustomBottomSheet(
      title: 'Add Food',
      icon: Icons.restaurant_menu,
      isButtonEnabled: _selectedFood != null,
      onSave: _save,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: true,
            style: TextStyle(color: themeText),
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search food (e.g., Nasi Lemak)...',
              hintStyle: TextStyle(color: themeSubText),
              filled: true,
              fillColor: themeText.withOpacity(0.05),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: AppTheme.accent),
              suffixIcon: _isLoading
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent),
              )
                  : _searchController.text.isNotEmpty
                  ? IconButton(
                icon: Icon(Icons.close, color: themeSubText),
                onPressed: _clearSelection,
              )
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Results list
          if (_results.isNotEmpty && _selectedFood == null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 56.0 * 3.5),
              child: Container(
                decoration: BoxDecoration(
                  color: themeSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: themeBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: themeBorder),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      final hasCaffeine = (item['caffeine_mg'] ?? 0) > 0;
                      final hasAlcohol = (item['alcohol_g'] ?? 0) > 0;
                      return ListTile(
                        dense: true,
                        title: Text(
                          item['name'] ?? 'Unknown',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: themeText),
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              '${item['calories']} kcal/100g',
                              style: TextStyle(fontSize: 12, color: themeSubText),
                            ),
                            if (hasCaffeine) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.brown.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '☕ ${(item['caffeine_mg'] as num).round()}mg',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: themeText,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            if (hasAlcohol) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '🍷 ${(item['alcohol_g'] as num).toStringAsFixed(1)}g',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: themeText,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: AppTheme.accent, size: 20),
                        onTap: () => _selectFood(item),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Selected food chip
          if (_selectedFood != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFood!['name'],
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: themeText),
                        ),
                        Text(
                          '${_selectedFood!['calories']} kcal per 100g',
                          style: TextStyle(
                              fontSize: 12,
                              color: themeText.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: AppTheme.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Quantity + live kcal total
          Text(
            'Servings',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 15, color: themeText),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove,
                onTap: () {
                  if (_quantity > 1) setState(() => _quantity--);
                },
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_quantity',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: themeText),
                  ),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                onTap: () => setState(() => _quantity++),
              ),
              if (_selectedFood != null) ...[
                const SizedBox(width: 16),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${((_selectedFood!['calories'] ?? 0).toDouble() * _quantity).round()} kcal',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
              ],
            ],
          ),

          // ── Sleep-impact warnings ──
          if (_selectedFood != null) ...[
            if ((_selectedFood!['caffeine_mg'] ?? 0).toDouble() * _quantity > 0) ...[
              const SizedBox(height: 12),
              _SleepWarningBanner(
                icon: '☕',
                baseColor: Colors.brown,
                label: 'Caffeine',
                value: '${((_selectedFood!['caffeine_mg'] ?? 0).toDouble() * _quantity).round()} mg',
                warning: 'Caffeine can disrupt sleep for up to 6 hours',
              ),
            ],
            if ((_selectedFood!['sugar_g'] ?? 0).toDouble() * _quantity > 0) ...[
              const SizedBox(height: 8),
              _SleepWarningBanner(
                icon: '🍬',
                baseColor: Colors.amber,
                label: 'Sugar',
                value: '${((_selectedFood!['sugar_g'] ?? 0).toDouble() * _quantity).toStringAsFixed(1)} g',
                warning: 'High sugar intake can reduce sleep quality',
              ),
            ],
            if ((_selectedFood!['alcohol_g'] ?? 0).toDouble() * _quantity > 0) ...[
              const SizedBox(height: 8),
              _SleepWarningBanner(
                icon: '🍷',
                baseColor: Colors.purple,
                label: 'Alcohol',
                value: '${((_selectedFood!['alcohol_g'] ?? 0).toDouble() * _quantity).toStringAsFixed(1)} g',
                warning: 'Alcohol reduces REM sleep and sleep quality',
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Sleep-impact warning banner ───────────────────────────────────────────────
class _SleepWarningBanner extends StatelessWidget {
  final String icon;
  final MaterialColor baseColor;
  final String label;
  final String value;
  final String warning;

  const _SleepWarningBanner({
    required this.icon,
    required this.baseColor,
    required this.label,
    required this.value,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    final themeText = AppTheme.text(context);
    final themeSubText = AppTheme.subText(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$label: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: baseColor,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: themeText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  warning,
                  style: TextStyle(
                    fontSize: 11,
                    color: themeSubText,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.bedtime, size: 16, color: baseColor.withOpacity(0.5)),
        ],
      ),
    );
  }
}

// ── Reusable +/- button ───────────────────────────────────────────────────────
class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final themeText = AppTheme.text(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: themeText.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: themeText.withOpacity(0.1)),
        ),
        child: Icon(icon, color: AppTheme.accent, size: 20),
      ),
    );
  }
}