import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/services/nutrition_api_service.dart';
import 'package:dreamsync/widget/custom/custom_bottom_sheet.dart'; // ← your reusable widget
import 'package:dreamsync/util/network_helper.dart';

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
// EXERCISE SHEET
// =============================================================================
class _ExerciseSheetContent extends StatefulWidget {
  final BuildContext parentContext;
  const _ExerciseSheetContent({required this.parentContext});

  @override
  State<_ExerciseSheetContent> createState() => _ExerciseSheetContentState();
}

class _ExerciseSheetContentState extends State<_ExerciseSheetContent> {
  final _typeController = TextEditingController();
  final _durationController = TextEditingController();
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _durationController.addListener(() {
      final valid = (int.tryParse(_durationController.text) ?? 0) > 0;
      if (valid != _canSave) setState(() => _canSave = valid);
    });
  }

  @override
  void dispose() {
    _typeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durationController.text) ?? 0;
    if (duration <= 0) return;

    final ok = await NetworkHelper.ensureInternet(
      widget.parentContext,
      message: 'You cannot save exercise while offline.',
    );
    if (!ok) return;

    final user = widget.parentContext.read<ProfileViewModel>().userProfile;
    if (user != null) {
      await widget.parentContext.read<DailyActivityViewModel>().addActivity(
        userId: user.userId,
        addExercise: duration,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(
            content: Text('Exercise stored successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // CustomBottomSheet handles: drag handle, header icon+title, save button, keyboard padding
    return CustomBottomSheet(
      title: 'Add Exercise',
      icon: Icons.directions_run,
      isButtonEnabled: _canSave,
      onSave: _save,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _typeController,
            decoration: const InputDecoration(
              labelText: 'Activity Type (e.g., Running)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_run, color: Colors.indigoAccent),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _durationController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duration (minutes)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.timer, color: Colors.indigoAccent),
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
    final user = widget.parentContext.read<ProfileViewModel>().userProfile;

    if (user != null) {
      await widget.parentContext.read<DailyActivityViewModel>().addActivity(
        userId: user.userId,
        addFood: total,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Added $total kcal successfully!'),
            backgroundColor: Colors.green,
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
    return CustomBottomSheet(
      title: 'Add Food',
      icon: Icons.restaurant_menu,
      isButtonEnabled: _selectedFood != null,
      onSave: _save,
      // ── All the unique food UI goes here as `content` ────────────────────
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            autofocus: true,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search food (e.g., Nasi Lemak)...',
              filled: true,
              fillColor: Colors.grey.shade100,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              prefixIcon:
              const Icon(Icons.search, color: Colors.indigoAccent),
              suffixIcon: _isLoading
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.indigoAccent),
              )
                  : _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: _clearSelection,
              )
                  : null,
            ),
          ),
          const SizedBox(height: 8),

          // Results list — capped at 3.5 rows to hint scrollability
          if (_results.isNotEmpty && _selectedFood == null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 56.0 * 3.5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
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
                        Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          item['name'] ?? 'Unknown',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '${item['calories']} kcal per 100g',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: const Icon(Icons.add_circle_outline,
                            color: Colors.indigoAccent, size: 20),
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
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.indigoAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.indigoAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFood!['name'],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo),
                        ),
                        Text(
                          '${_selectedFood!['calories']} kcal per 100g',
                          style: TextStyle(
                              fontSize: 12, color: Colors.indigo.shade300),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearSelection,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 14, color: Colors.indigo),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Quantity + live kcal total
          const Text(
            'Servings',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
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
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(icon, color: Colors.indigoAccent, size: 20),
      ),
    );
  }
}