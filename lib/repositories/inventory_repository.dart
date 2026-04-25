import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/util/network_helper.dart';

class InventoryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String _inventoryKey(String userId) => 'cached_inventory_$userId';
  String get _storeItemsKey => 'cached_store_items';
  String _streakShieldUsedKey(String userId, String dateKey) =>
      'streak_shield_used_${userId}_$dateKey';

  Future<void> _cacheInventory(String userId, List<dynamic> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_inventoryKey(userId), jsonEncode(rows));
  }

  Future<void> _cacheStoreItems(List<dynamic> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storeItemsKey, jsonEncode(rows));
  }

  Future<List<InventoryItem>> _getCachedInventory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_inventoryKey(userId));
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((row) => InventoryItem.fromMap(
      Map<String, dynamic>.from(row as Map),
    ))
        .where((item) => item.details.id != 0)
        .toList();
  }

  Future<List<StoreItem>> _getCachedStoreItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeItemsKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((row) => StoreItem.fromMap(
      Map<String, dynamic>.from(row as Map),
    ))
        .toList();
  }

  Future<List<InventoryItem>> fetchMyInventory({String? userId}) async {
    final resolvedUserId = userId ?? _client.auth.currentUser?.id;
    if (resolvedUserId == null) return [];

    final online = await NetworkHelper.hasInternet();
    if (!online) {
      return _getCachedInventory(resolvedUserId);
    }

    try {
      final response = await _client
          .from('user_inventory')
          .select('id, quantity, store_items!item_id(*)')
          .eq('user_id', resolvedUserId)
          .order('id', ascending: true);

      final rows = response as List<dynamic>;
      await _cacheInventory(resolvedUserId, rows);

      return rows
          .map((row) => InventoryItem.fromMap(
        Map<String, dynamic>.from(row as Map),
      ))
          .where((item) => item.details.id != 0)
          .toList();
    } catch (e) {
      print('Error fetching inventory: $e');
      return _getCachedInventory(resolvedUserId);
    }
  }

  Future<List<StoreItem>> fetchStoreItems() async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      return _getCachedStoreItems();
    }

    try {
      final response =
      await _client.from('store_items').select().order('id', ascending: true);

      final rows = response as List<dynamic>;
      await _cacheStoreItems(rows);

      return rows
          .map((row) => StoreItem.fromMap(
        Map<String, dynamic>.from(row as Map),
      ))
          .toList();
    } catch (e) {
      print('Error fetching store items: $e');
      return _getCachedStoreItems();
    }
  }

  Future<InventoryItem?> getInventoryItem({
    required String userId,
    required int storeItemId,
  }) async {
    final inventory = await fetchMyInventory(userId: userId);
    try {
      return inventory.firstWhere((item) => item.details.id == storeItemId);
    } catch (_) {
      return null;
    }
  }

  Future<int> getQuantity({
    required String userId,
    required int storeItemId,
  }) async {
    final item = await getInventoryItem(
      userId: userId,
      storeItemId: storeItemId,
    );
    return item?.quantity ?? 0;
  }

  Future<bool> isOwned({
    required String userId,
    required int storeItemId,
  }) async {
    final quantity = await getQuantity(
      userId: userId,
      storeItemId: storeItemId,
    );
    return quantity > 0;
  }

  bool canRepurchase(StoreItem item) => item.isConsumableShield;

  Future<void> purchaseItem({
    required int storeItemId,
    required String userId,
  }) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      throw Exception('Purchasing items requires internet.');
    }

    final storeItems = await fetchStoreItems();
    final item = storeItems.firstWhere((e) => e.id == storeItemId);

    final existing = await getInventoryItem(
      userId: userId,
      storeItemId: storeItemId,
    );

    if (existing != null) {
      if (!canRepurchase(item)) {
        throw Exception('Item already owned.');
      }

      await _client
          .from('user_inventory')
          .update({'quantity': existing.quantity + 1})
          .eq('id', existing.id);
    } else {
      await _client.from('user_inventory').insert({
        'user_id': userId,
        'item_id': storeItemId,
        'quantity': 1,
      });
    }

    await fetchMyInventory(userId: userId);
  }

  Future<List<StoreItem>> fetchOwnedAvatars(String userId) async {
    final inventory = await fetchMyInventory(userId: userId);
    return inventory
        .where((item) => item.quantity > 0 && item.details.isAvatar)
        .map((item) => item.details)
        .toList();
  }

  Future<void> equipAvatar({
    required String userId,
    required StoreItem avatarItem,
  }) async {
    if (!avatarItem.isAvatar) {
      throw Exception('Only avatar items can be equipped.');
    }

    final owned = await isOwned(userId: userId, storeItemId: avatarItem.id);
    if (!owned) {
      throw Exception('Avatar not owned yet.');
    }

    final online = await NetworkHelper.hasInternet();
    if (online) {
      await _client
          .from('profile')
          .update({'avatar_asset_path': avatarItem.assetPath})
          .eq('user_id', userId);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_equipped_avatar_$userId', avatarItem.assetPath);
  }

  Future<String?> getEquippedAvatarPath(String userId) async {
    final online = await NetworkHelper.hasInternet();

    if (online) {
      try {
        final response = await _client
            .from('profile')
            .select('avatar_asset_path')
            .eq('user_id', userId)
            .maybeSingle();

        final path = response?['avatar_asset_path'] as String?;
        if (path != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_equipped_avatar_$userId', path);
        }
        return path;
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('cached_equipped_avatar_$userId');
  }

  Future<bool> consumeShieldIfNeeded({
    required String userId,
    required int storeItemId,
  }) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) return false;

    final existing = await getInventoryItem(
      userId: userId,
      storeItemId: storeItemId,
    );

    if (existing == null || existing.quantity <= 0) return false;

    if (existing.quantity == 1) {
      await _client.from('user_inventory').delete().eq('id', existing.id);
    } else {
      await _client
          .from('user_inventory')
          .update({'quantity': existing.quantity - 1})
          .eq('id', existing.id);
    }

    await fetchMyInventory(userId: userId);
    return true;
  }

  Future<bool> tryConsumeStreakShield({
    required String userId,
    required String dateKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    debugPrint('==================================================');
    debugPrint('🛡️ [Shield] tryConsumeStreakShield() called');
    debugPrint('👤 [Shield] userId = $userId');
    debugPrint('📅 [Shield] dateKey = $dateKey');

    final alreadyUsed =
        prefs.getBool(_streakShieldUsedKey(userId, dateKey)) ?? false;

    debugPrint('📝 [Shield] alreadyUsedForThisDay = $alreadyUsed');

    if (alreadyUsed) {
      debugPrint('🛡️❌ [Shield] Shield already used for this date. Skip.');
      debugPrint('==================================================');
      return false;
    }

    final storeItems = await fetchStoreItems();
    debugPrint('🛒 [Shield] fetched store items count = ${storeItems.length}');

    StoreItem? shieldItem;
    try {
      shieldItem = storeItems.firstWhere((item) => item.isConsumableShield);
      debugPrint(
        '🛡️ [Shield] Found shield item: id=${shieldItem.id}, name=${shieldItem.name}',
      );
    } catch (_) {
      shieldItem = null;
      debugPrint('🛡️❌ [Shield] No streak shield item found in store_items');
    }

    if (shieldItem == null) {
      debugPrint('==================================================');
      return false;
    }

    final beforeQty = await getQuantity(
      userId: userId,
      storeItemId: shieldItem.id,
    );
    debugPrint('📦 [Shield] quantity before consume = $beforeQty');

    final consumed = await consumeShieldIfNeeded(
      userId: userId,
      storeItemId: shieldItem.id,
    );

    final afterQty = await getQuantity(
      userId: userId,
      storeItemId: shieldItem.id,
    );
    debugPrint('📦 [Shield] quantity after consume = $afterQty');
    debugPrint('🛡️ [Shield] consumed = $consumed');

    if (consumed) {
      await prefs.setBool(_streakShieldUsedKey(userId, dateKey), true);
      debugPrint('💾 [Shield] Marked shield as used for date=$dateKey');
    }

    debugPrint('==================================================');
    return consumed;
  }
}