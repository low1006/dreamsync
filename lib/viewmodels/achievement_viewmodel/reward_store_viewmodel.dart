import 'package:flutter/foundation.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/repositories/user_repository.dart';

class RewardStoreViewModel extends ChangeNotifier {
  final InventoryRepository _inventoryRepository;
  final UserRepository _userRepository;

  RewardStoreViewModel({
    required InventoryRepository inventoryRepository,
    required UserRepository userRepository,
  })  : _inventoryRepository = inventoryRepository,
        _userRepository = userRepository;

  bool _isLoading = false;
  bool _isPurchasing = false;

  List<StoreItem> _storeItems = [];
  List<InventoryItem> _ownedItems = [];
  List<StoreItem> _availableItems = [];

  StoreItem? _selectedItem;
  UserModel? _user;

  String? _errorMessage;
  String? _successMessage;
  String? _validationMessage;
  String? _debugMessage;

  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;

  List<StoreItem> get storeItems => List.unmodifiable(_availableItems);
  List<InventoryItem> get ownedItems => List.unmodifiable(_ownedItems);
  List<StoreItem> get allStoreItems => List.unmodifiable(_storeItems);

  StoreItem? get selectedItem => _selectedItem;
  UserModel? get user => _user;

  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get validationMessage => _validationMessage;
  String? get debugMessage => _debugMessage;

  int get currentPoints => _user?.currentPoints ?? 0;
  bool get hasSelection => _selectedItem != null;

  Future<void> initialize(String userId) async {
    debugPrint('🟡 [RewardStoreVM] initialize() called with userId = $userId');

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    _validationMessage = null;
    _debugMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _inventoryRepository.fetchStoreItems(),
        _inventoryRepository.fetchMyInventory(userId: userId),
        _userRepository.getProfileSafe(userId),
      ]);

      _storeItems = results[0] as List<StoreItem>;
      _ownedItems = results[1] as List<InventoryItem>;
      _user = results[2] as UserModel?;

      debugPrint('🟢 [RewardStoreVM] all store items count = ${_storeItems.length}');
      debugPrint('🟢 [RewardStoreVM] owned items count = ${_ownedItems.length}');
      debugPrint('🟢 [RewardStoreVM] user loaded = ${_user != null}');
      debugPrint('🟢 [RewardStoreVM] currentPoints = ${_user?.currentPoints}');

      final ownedIds = _ownedItems.map((e) => e.details.id).toSet();
      debugPrint('🟡 [RewardStoreVM] ownedIds = $ownedIds');

      _availableItems = _storeItems
          .where((item) => !ownedIds.contains(item.id))
          .toList();

      debugPrint('🟢 [RewardStoreVM] available items count = ${_availableItems.length}');
      for (final item in _availableItems) {
        debugPrint('   ↳ available item: id=${item.id}, name=${item.name}, cost=${item.cost}');
      }

      if (_storeItems.isEmpty) {
        _debugMessage = 'DEBUG: store_items table returned 0 rows.';
      } else if (_availableItems.isEmpty && _ownedItems.isNotEmpty) {
        _debugMessage = 'DEBUG: all store items are already owned by this user.';
      } else if (_user == null) {
        _debugMessage = 'DEBUG: user profile failed to load.';
      } else {
        _debugMessage =
        'DEBUG: loaded ${_storeItems.length} store items, ${_ownedItems.length} owned items, ${_availableItems.length} available items.';
      }

      _validateSelection();
    } catch (e, st) {
      debugPrint('🔴 [RewardStoreVM] Failed to load reward store: $e');
      debugPrint('$st');
      _errorMessage = 'Failed to load reward store: $e';
      _debugMessage = 'DEBUG ERROR: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh(String userId) async {
    debugPrint('🟡 [RewardStoreVM] refresh() called');
    await initialize(userId);
  }

  void selectItem(StoreItem item) {
    debugPrint('🟡 [RewardStoreVM] selectItem() => ${item.name} (${item.id})');
    _selectedItem = item;
    _errorMessage = null;
    _successMessage = null;
    _validateSelection();
    notifyListeners();
  }

  void clearSelection() {
    _selectedItem = null;
    _validationMessage = null;
    notifyListeners();
  }

  bool isSelected(StoreItem item) => _selectedItem?.id == item.id;

  bool isOwned(StoreItem item) {
    return _ownedItems.any((owned) => owned.details.id == item.id);
  }

  bool canAfford(StoreItem item) {
    return currentPoints >= item.cost;
  }

  String? getItemValidationMessage(StoreItem item) {
    if (_user == null) {
      return 'User profile is not loaded.';
    }

    if (isOwned(item)) {
      return 'You already own this item.';
    }

    if (!canAfford(item)) {
      return 'Not enough points to unlock this item.';
    }

    return null;
  }

  void _validateSelection() {
    if (_selectedItem == null) {
      _validationMessage = null;
      return;
    }

    _validationMessage = getItemValidationMessage(_selectedItem!);
  }

  bool validateSelectedItem() {
    _errorMessage = null;
    _successMessage = null;
    _validateSelection();
    notifyListeners();
    return _validationMessage == null;
  }

  Future<bool> purchaseSelectedItem() async {
    if (_selectedItem == null) {
      _validationMessage = 'Please select an item first.';
      notifyListeners();
      return false;
    }

    if (_user == null) {
      _errorMessage = 'User profile is not available.';
      notifyListeners();
      return false;
    }

    if (!validateSelectedItem()) {
      return false;
    }

    _isPurchasing = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final item = _selectedItem!;
      final newPoints = currentPoints - item.cost;

      debugPrint('🟡 [RewardStoreVM] purchasing item = ${item.name}, cost = ${item.cost}');
      debugPrint('🟡 [RewardStoreVM] old points = ${_user!.currentPoints}, new points = $newPoints');

      await _inventoryRepository.purchaseItem(
        storeItemId: item.id,
        userId: _user!.userId,
      );

      await _userRepository.updatePoints(_user!.userId, newPoints);

      _user!.currentPoints = newPoints;

      _ownedItems = await _inventoryRepository.fetchMyInventory(userId: _user!.userId);
      final ownedIds = _ownedItems.map((e) => e.details.id).toSet();
      _availableItems =
          _storeItems.where((item) => !ownedIds.contains(item.id)).toList();

      _successMessage = '${item.name} unlocked successfully!';
      _validationMessage = null;
      _debugMessage =
      'DEBUG: purchase success. Remaining available items = ${_availableItems.length}';
      _selectedItem = null;

      debugPrint('🟢 [RewardStoreVM] purchase success');
      notifyListeners();
      return true;
    } catch (e, st) {
      debugPrint('🔴 [RewardStoreVM] Failed to purchase item: $e');
      debugPrint('$st');
      _errorMessage = 'Failed to purchase item: $e';
      _debugMessage = 'DEBUG PURCHASE ERROR: $e';
      notifyListeners();
      return false;
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<bool> purchaseItem(StoreItem item) async {
    selectItem(item);
    return purchaseSelectedItem();
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _validationMessage = null;
    _debugMessage = null;
    notifyListeners();
  }

  StoreItem? getItemById(int itemId) {
    try {
      return _storeItems.firstWhere((item) => item.id == itemId);
    } catch (_) {
      return null;
    }
  }
}