import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/sleep_record_model.dart'; // Import your model

class SleepRepository {
  final _client = Supabase.instance.client;

  // Notice how it now asks for "SleepRecordModel record" instead of separate variables
  Future<void> saveDailySummary(SleepRecordModel record) async {
    try {
      await _client.from('sleep_record').upsert(
        record.toJson(), // Instantly converts your Dart object to Supabase data
        onConflict: 'user_id, date',
      );
      print("✅ Sleep data stored successfully in Supabase!");
    } catch (e) {
      print("❌ Error storing sleep data: $e");
    }
  }
}