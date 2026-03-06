import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/sleep_record_model.dart';

class SleepRepository {
  final _client = Supabase.instance.client;

  Future<void> saveDailySummary(SleepRecordModel record) async {
    try {
      await _client.from('sleep_record').upsert(
        record.toJson(),
        onConflict: 'user_id, date',
      );
      print("✅ Sleep data stored successfully in Supabase!");
    } catch (e) {
      print("❌ Error storing sleep data: $e");
    }
  }

  // 🔥 NEW: Fetch sleep records within a specific date range for the charts
  Future<List<SleepRecordModel>> getSleepRecordsByDateRange(
      String userId, String startDate, String endDate) async {
    try {
      final response = await _client
          .from('sleep_record')
          .select()
          .eq('user_id', userId)
          .gte('date', startDate) // Greater than or equal to start date
          .lte('date', endDate)   // Less than or equal to end date
          .order('date', ascending: true); // Sort chronologically (Mon -> Sun)

      // Convert the raw JSON database response into a list of your Dart models
      return response.map((json) => SleepRecordModel.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching sleep data range: $e");
      return []; // Return an empty list on error so the UI doesn't crash
    }
  }
}