import 'package:supabase_flutter/supabase_flutter.dart';

abstract class BaseRepository<T> {
  final SupabaseClient client;
  final String tableName;
  final String idColumn;
  final T Function(Map<String, dynamic> json) fromJson;

  BaseRepository(
      this.client,
      this.tableName,
      this.idColumn,
      this.fromJson,
      );

  Future<void> create(Map<String, dynamic> data) async {
    try {
      await client.from(tableName).insert(data);
    } catch (e) {
      print("Error creating item in $tableName: $e");
      rethrow;
    }
  }

  Future<T?> getById(dynamic id) async {
    try {
      final data = await client
          .from(tableName)
          .select()
          .eq(idColumn, id)
          .single();

      return fromJson(data);
    } catch (e) {
      print("Error fetching item from $tableName by $idColumn=$id: $e");
      return null;
    }
  }

  Future<List<T>> getAll() async {
    try {
      final data = await client.from(tableName).select();
      return (data as List)
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print("Error fetching all items from $tableName: $e");
      return [];
    }
  }

  Future<void> update(dynamic id, Map<String, dynamic> data) async {
    try {
      await client
          .from(tableName)
          .update(data)
          .eq(idColumn, id);
    } catch (e) {
      print("Error updating item in $tableName with $idColumn=$id: $e");
      rethrow;
    }
  }

  Future<void> delete(dynamic id) async {
    try {
      await client
          .from(tableName)
          .delete()
          .eq(idColumn, id);
    } catch (e) {
      print("Error deleting item in $tableName with $idColumn=$id: $e");
      rethrow;
    }
  }
}
