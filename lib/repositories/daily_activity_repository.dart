import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dreamsync/models/daily_activity_model.dart';

class DailyActivityRepository {
  final _client = Supabase.instance.client;

  // Save or Update today's activity WITHOUT relying on .upsert()
  Future<void> saveActivity(DailyActivityModel activity) async {
    try {
      // 1. Manually check if a record already exists for this user today
      final existingRecord = await _client
          .from('daily_activities')
          .select('activity_id') // Only fetch the ID to save bandwidth
          .eq('user_id', activity.userId)
          .eq('date', activity.date)
          .maybeSingle();

      if (existingRecord != null) {
        // 2. If it EXISTS, perform an UPDATE
        await _client
            .from('daily_activities')
            .update({
          'exercise_minutes': activity.exerciseMinutes,
          'food_calories': activity.foodCalories,
          'screen_time_minutes': activity.screenTimeMinutes,
        })
            .eq('activity_id', existingRecord['activity_id']); // Update the specific row we found

        print("✅ Daily activity UPDATED successfully!");
      } else {
        // 3. If it DOES NOT EXIST, perform an INSERT
        await _client.from('daily_activities').insert(activity.toJson());

        print("✅ Daily activity INSERTED successfully!");
      }
    } catch (e) {
      print("❌ Error storing daily activity: $e");
    }
  }

  // Fetch today's activity to show on the UI when the app loads
  Future<DailyActivityModel?> getTodayActivity(String userId, String dateString) async {
    try {
      final response = await _client
          .from('daily_activities')
          .select()
          .eq('user_id', userId)
          .eq('date', dateString)
          .maybeSingle();

      if (response != null) {
        return DailyActivityModel.fromJson(response);
      }
      return null;
    } catch (e) {
      print("❌ Error fetching activity: $e");
      return null;
    }
  }

  // 🔥 NEW: Fetch activity records within a specific date range for the Weekly Charts
  Future<List<DailyActivityModel>> getActivityByDateRange(
      String userId, String startDate, String endDate) async {
    try {
      final response = await _client
          .from('daily_activities')
          .select()
          .eq('user_id', userId)
          .gte('date', startDate)
          .lte('date', endDate)
          .order('date', ascending: true);

      return response.map((json) => DailyActivityModel.fromJson(json)).toList();
    } catch (e) {
      print("❌ Error fetching activity date range: $e");
      return [];
    }
  }
}