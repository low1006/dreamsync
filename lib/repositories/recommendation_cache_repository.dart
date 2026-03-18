import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:dreamsync/models/sleep_model/sleep_recommendation_cache_model.dart';
import 'package:dreamsync/util/local_database.dart';

class RecommendationCacheRepository {
  Future<void> save(SleepRecommendationCacheModel model) async {
    final db = await LocalDatabase.instance.database;
    await db.insert(
      'sleep_recommendation',
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<SleepRecommendationCacheModel?> getLatestRecommendation(String userId) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'sleep_recommendation',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date DESC', // Gets the most recent recommendation
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return SleepRecommendationCacheModel.fromMap(rows.first);
  }
  Future<SleepRecommendationCacheModel?> getToday({
    required String userId,
    required String date,
  }) async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'sleep_recommendation',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return SleepRecommendationCacheModel.fromMap(rows.first);
  }

  Future<void> deleteToday({
    required String userId,
    required String date,
  }) async {
    final db = await LocalDatabase.instance.database;
    await db.delete(
      'sleep_recommendation',
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
  }
}