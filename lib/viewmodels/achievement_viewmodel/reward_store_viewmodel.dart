import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/models/user_model.dart';
import 'package:dreamsync/repositories/inventory_repository.dart';
import 'package:dreamsync/repositories/user_repository.dart';
import 'package:dreamsync/services/notification_service.dart';

class RewardStoreViewModel extends ChangeNotifier {
  final InventoryRepository _inventoryRepository;
  final UserRepository _userRepository;
  final AudioPlayer _audioPlayer = AudioPlayer();

  static const Set<String> _hiddenDefaultAudioFiles = {
    'classic.mp3',
    'buzzer.mp3',
  };

  StreamSubscription<void>? _playerCompleteSubscription;
  bool _disposed = false;

  RewardStoreViewModel({
    required InventoryRepository inventoryRepository,
    required UserRepository userRepository,
  })  : _inventoryRepository = inventoryRepository,
        _userRepository = userRepository {
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      _isPreviewingAudio = false;
      _currentlyPreviewingAudioFile = null;
      _safeNotify();
    });
  }

  bool _isLoading = false;
  bool _isPurchasing = false;
  bool _isEquippingAvatar = false;
  bool _isPreviewingAudio = false;

  List<StoreItem> _storeItems = [];
  List<InventoryItem> _ownedItems = [];

  StoreItem? _selectedItem;
  UserModel? _user;
  String? _equippedAvatarPath;
  String? _currentlyPreviewingAudioFile;

  String? _errorMessage;
  String? _successMessage;
  String? _validationMessage;
  String? _debugMessage;

  bool get isLoading => _isLoading;
  bool get isPurchasing => _isPurchasing;
  bool get isEquippingAvatar => _isEquippingAvatar;
  bool get isPreviewingAudio => _isPreviewingAudio;

  List<StoreItem> get storeItems => List.unmodifiable(_storeItems);
  List<StoreItem> get allStoreItems => List.unmodifiable(_storeItems);

  /// Only items that should actually be shown in the reward store.
  List<StoreItem> get visibleStoreItems => List.unmodifiable(
    _storeItems.where(_shouldShowInRewardStore).toList(),
  );

  List<InventoryItem> get ownedItems => List.unmodifiable(_ownedItems);

  StoreItem? get selectedItem => _selectedItem;
  UserModel? get user => _user;
  String? get equippedAvatarPath => _equippedAvatarPath;
  String? get currentlyPreviewingAudioFile => _currentlyPreviewingAudioFile;

  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get validationMessage => _validationMessage;
  String? get debugMessage => _debugMessage;

  int get currentPoints => _user?.currentPoints ?? 0;
  bool get hasSelection => _selectedItem != null;

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  bool _isDefaultSystemAudio(StoreItem item) {
    if (!isAudioItem(item)) return false;
    final normalized = NotificationService.normalizeSoundFile(item.audioFile);
    return _hiddenDefaultAudioFiles.contains(normalized);
  }

  bool _shouldShowInRewardStore(StoreItem item) {
    return !_isDefaultSystemAudio(item);
  }

  Future<void> initialize(String userId) async {
    await stopAudioPreview(notify: false);

    _isLoading = true;
    clearMessages();
    _safeNotify();

    try {
      final results = await Future.wait([
        _inventoryRepository.fetchStoreItems(),
        _inventoryRepository.fetchMyInventory(userId: userId),
        _userRepository.getProfileSafe(userId),
        _inventoryRepository.getEquippedAvatarPath(userId),
      ]);

      _storeItems = results[0] as List<StoreItem>;
      _ownedItems = results[1] as List<InventoryItem>;
      _user = results[2] as UserModel?;
      _equippedAvatarPath = results[3] as String?;

      _debugMessage =
      'Loaded ${_storeItems.length} store items and ${_ownedItems.length} inventory items.';
      _validateSelection();
    } catch (e, st) {
      debugPrint('Failed to load reward store: $e');
      debugPrint('$st');
      _errorMessage = 'Failed to load reward store: $e';
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refresh(String userId) async => initialize(userId);

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    _validationMessage = null;
  }

  bool isOwned(StoreItem item) {
    return _ownedItems.any(
          (owned) => owned.details.id == item.id && owned.quantity > 0,
    );
  }

  int getItemQuantity(StoreItem item) {
    try {
      return _ownedItems
          .firstWhere((owned) => owned.details.id == item.id)
          .quantity;
    } catch (_) {
      return 0;
    }
  }

  bool isSelected(StoreItem item) => _selectedItem?.id == item.id;

  bool canAfford(StoreItem item) => currentPoints >= item.cost;

  bool isClaimed(StoreItem item) {
    if (item.isConsumableShield) return false;
    return isOwned(item);
  }

  bool isEquippedAvatar(StoreItem item) {
    if (!item.isAvatar) return false;
    return _equippedAvatarPath == item.assetPath;
  }

  bool isAudioItem(StoreItem item) => item.type == StoreItemType.audio;

  bool isPreviewing(StoreItem item) {
    return isAudioItem(item) &&
        _isPreviewingAudio &&
        _currentlyPreviewingAudioFile == item.audioFile.trim();
  }

  void selectItem(StoreItem item) {
    if (!_shouldShowInRewardStore(item)) {
      _validationMessage = 'This is a built-in system alarm tone, not a store reward.';
      _safeNotify();
      return;
    }

    _selectedItem = item;
    clearMessages();
    _validateSelection();
    _safeNotify();
  }

  void clearSelection() {
    _selectedItem = null;
    _validationMessage = null;
    _safeNotify();
  }

  String? getItemValidationMessage(StoreItem item) {
    if (_user == null) {
      return 'User profile is not loaded.';
    }

    if (_isDefaultSystemAudio(item)) {
      return 'This is a built-in system alarm tone.';
    }

    if (isClaimed(item)) {
      return 'Reward already claimed.';
    }

    if (!canAfford(item)) {
      return 'Insufficient Points Balance';
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

  Future<bool> purchaseSelectedItem() async {
    if (_selectedItem == null) {
      _validationMessage = 'Please select an item first.';
      _safeNotify();
      return false;
    }

    if (_user == null) {
      _errorMessage = 'User profile is not available.';
      _safeNotify();
      return false;
    }

    final item = _selectedItem!;

    if (_isDefaultSystemAudio(item)) {
      _validationMessage = 'This is a built-in system alarm tone and cannot be redeemed.';
      _safeNotify();
      return false;
    }

    if (isClaimed(item)) {
      _validationMessage = 'Reward already claimed.';
      _safeNotify();
      return false;
    }

    if (!canAfford(item)) {
      _validationMessage = 'Insufficient Points Balance';
      _safeNotify();
      return false;
    }

    _isPurchasing = true;
    clearMessages();
    _safeNotify();

    try {
      final newPoints = currentPoints - item.cost;

      await _inventoryRepository.purchaseItem(
        storeItemId: item.id,
        userId: _user!.userId,
      );

      await _userRepository.updatePoints(_user!.userId, newPoints);
      _user!.currentPoints = newPoints;

      _ownedItems =
      await _inventoryRepository.fetchMyInventory(userId: _user!.userId);
      _selectedItem = null;
      _validationMessage = null;
      _successMessage = 'Reward Claimed Successfully';

      _safeNotify();
      return true;
    } catch (e, st) {
      debugPrint('Failed to redeem item: $e');
      debugPrint('$st');
      _errorMessage = 'Failed to redeem item: $e';
      _safeNotify();
      return false;
    } finally {
      _isPurchasing = false;
      _safeNotify();
    }
  }

  Future<bool> equipAvatar(StoreItem item) async {
    if (_user == null) {
      _errorMessage = 'User profile is not available.';
      _safeNotify();
      return false;
    }
    if (!item.isAvatar) return false;
    if (!isOwned(item)) {
      _validationMessage = 'Redeem this avatar first before using it.';
      _safeNotify();
      return false;
    }

    _isEquippingAvatar = true;
    clearMessages();
    _safeNotify();

    try {
      await _inventoryRepository.equipAvatar(
        userId: _user!.userId,
        avatarItem: item,
      );
      _equippedAvatarPath = item.assetPath;
      _successMessage = '${item.name} is now your current avatar.';
      _safeNotify();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to equip avatar: $e';
      _safeNotify();
      return false;
    } finally {
      _isEquippingAvatar = false;
      _safeNotify();
    }
  }

  String _resolveAudioAssetPath(String rawFile) {
    final value = rawFile.trim();

    if (value.isEmpty) return '';

    if (value.startsWith('assets/')) {
      return value.substring('assets/'.length);
    }

    if (value.startsWith('audios/')) {
      return value;
    }

    return NotificationService.audioAssetPath(value);
  }

  Future<void> toggleAudioPreview(StoreItem item) async {
    if (!isAudioItem(item)) return;
    if (_isDefaultSystemAudio(item)) return;

    final rawFile = item.audioFile.trim();
    if (rawFile.isEmpty) return;

    try {
      if (_currentlyPreviewingAudioFile == rawFile && _isPreviewingAudio) {
        await stopAudioPreview();
        return;
      }

      await _audioPlayer.stop();

      final assetPath = _resolveAudioAssetPath(rawFile);
      if (assetPath.isEmpty) return;

      _currentlyPreviewingAudioFile = rawFile;
      _isPreviewingAudio = true;
      _safeNotify();

      await _audioPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Reward store audios preview failed: $e');
      _isPreviewingAudio = false;
      _currentlyPreviewingAudioFile = null;
      _errorMessage = 'Failed to play audios preview.';
      _safeNotify();
    }
  }

  Future<void> stopAudioPreview({bool notify = true}) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.release();
    } catch (_) {}

    _isPreviewingAudio = false;
    _currentlyPreviewingAudioFile = null;

    if (notify) {
      _safeNotify();
    }
  }

  Future<void> closeStoreSession() async {
    await stopAudioPreview(notify: false);
    clearMessages();
    _selectedItem = null;
  }

  Future<bool> purchaseItem(StoreItem item) async {
    selectItem(item);
    return purchaseSelectedItem();
  }

  @override
  void dispose() {
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    _disposed = true;
    super.dispose();
  }
}