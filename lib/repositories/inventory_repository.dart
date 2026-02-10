import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/inventory_model.dart'; // <--- Only this import needed

class InventoryRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<InventoryItem>> fetchMyInventory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // JOIN QUERY: Get inventory AND the related store item details
      final response = await _client
          .from('user_inventory')
          .select('id, quantity, store_items(*)') // <--- The magic join
          .eq('user_id', userId);

      final List<dynamic> data = response as List<dynamic>;

      // Convert database JSON to our clean Model
      return data.map((json) => InventoryItem.fromMap(json)).toList();

    } catch (e) {
      print("Error fetching inventory: $e");
      return [];
    }
  }
}