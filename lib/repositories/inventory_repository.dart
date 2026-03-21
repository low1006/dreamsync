import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/util/network_helper.dart';

class InventoryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  String _inventoryKey(String userId) => 'cached_inventory_$userId';
  String get _storeItemsKey => 'cached_store_items';

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
      print("Error fetching inventory: $e");
      return _getCachedInventory(resolvedUserId);
    }
  }

  Future<List<StoreItem>> fetchStoreItems() async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      return _getCachedStoreItems();
    }

    try {
      final response = await _client
          .from('store_items')
          .select()
          .order('id', ascending: true);

      final rows = response as List<dynamic>;
      await _cacheStoreItems(rows);

      return rows
          .map((row) => StoreItem.fromMap(
        Map<String, dynamic>.from(row as Map),
      ))
          .toList();
    } catch (e) {
      print("Error fetching store items: $e");
      return _getCachedStoreItems();
    }
  }

  Future<List<StoreItem>> fetchAvailableStoreItems({String? userId}) async {
    final resolvedUserId = userId ?? _client.auth.currentUser?.id;
    if (resolvedUserId == null) return [];

    final results = await Future.wait([
      fetchStoreItems(),
      fetchMyInventory(userId: resolvedUserId),
    ]);

    final allStoreItems = results[0] as List<StoreItem>;
    final ownedItems = results[1] as List<InventoryItem>;
    final ownedIds = ownedItems.map((e) => e.details.id).toSet();

    return allStoreItems.where((item) => !ownedIds.contains(item.id)).toList();
  }

  Future<bool> isOwned({
    required String userId,
    required int storeItemId,
  }) async {
    final inventory = await fetchMyInventory(userId: userId);
    return inventory.any((item) => item.details.id == storeItemId);
  }

  Future<void> purchaseItem({
    required int storeItemId,
    required String userId,
  }) async {
    final online = await NetworkHelper.hasInternet();
    if (!online) {
      throw Exception('Purchasing items requires internet.');
    }

    final alreadyOwned = await isOwned(
      userId: userId,
      storeItemId: storeItemId,
    );

    if (alreadyOwned) {
      throw Exception('Item already owned.');
    }

    await _client.from('user_inventory').insert({
      'user_id': userId,
      'item_id': storeItemId,
      'quantity': 1,
    });

    await fetchMyInventory(userId: userId);
  }
}