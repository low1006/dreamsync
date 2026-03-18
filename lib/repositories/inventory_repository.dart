import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/inventory_model.dart';
import 'package:dreamsync/util/network_helper.dart';

class InventoryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<InventoryItem>> fetchMyInventory({String? userId}) async {
    final resolvedUserId = userId ?? _client.auth.currentUser?.id;
    if (resolvedUserId == null) return [];

    if (!await NetworkHelper.isOnline()) {
      print("📴 Offline: Skipping inventory fetch.");
      return [];
    }

    try {
      final response = await _client
          .from('user_inventory')
          .select('id, quantity, store_items!item_id(*)')
          .eq('user_id', resolvedUserId)
          .order('id', ascending: true);

      final data = response as List<dynamic>;

      return data
          .map((row) => InventoryItem.fromMap(
        Map<String, dynamic>.from(row as Map),
      ))
          .where((item) => item.details.id != 0)
          .toList();
    } catch (e) {
      print("Error fetching inventory: $e");
      return [];
    }
  }

  Future<List<StoreItem>> fetchStoreItems() async {
    if (!await NetworkHelper.isOnline()) {
      print("📴 Offline: Skipping store items fetch.");
      return [];
    }

    try {
      final response = await _client
          .from('store_items')
          .select()
          .order('id', ascending: true);

      final data = response as List<dynamic>;

      return data
          .map((row) => StoreItem.fromMap(
        Map<String, dynamic>.from(row as Map),
      ))
          .toList();
    } catch (e) {
      print("Error fetching store items: $e");
      return [];
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
    if (!await NetworkHelper.isOnline()) {
      throw Exception('No internet connection.');
    }

    try {
      final existing = await _client
          .from('user_inventory')
          .select('id')
          .eq('user_id', userId)
          .eq('item_id', storeItemId)
          .maybeSingle();

      return existing != null;
    } catch (e) {
      print("Error checking ownership: $e");
      rethrow;
    }
  }

  Future<void> purchaseItem({
    required int storeItemId,
    required String userId,
  }) async {
    if (!await NetworkHelper.isOnline()) {
      throw Exception('No internet connection.');
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
  }
}