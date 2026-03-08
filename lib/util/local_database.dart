import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _keyName = 'dreamsync_db_key';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dreamsync_secure.db');
    return _database!;
  }

  Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _keyName);

    if (key == null) {
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      key = base64UrlEncode(keyBytes);

      await _secureStorage.write(key: _keyName, value: key);
      debugPrint("🔐 Generated and stored new database encryption key.");
    }
    return key;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final String password = await _getEncryptionKey();

    return await openDatabase(
      path,
      version: 3,
      password: password,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS sleep_record');
      await db.execute('DROP TABLE IF EXISTS daily_activity');
      await db.execute('DROP TABLE IF EXISTS schedule');
      await db.execute('DROP TABLE IF EXISTS user_achievement');
      await db.execute('DROP TABLE IF EXISTS friend_cache');
      await _createDB(db, newVersion);
    }
  }

  Future _createDB(Database db, int version) async {
    // Read the SQL file from assets
    String schema = await rootBundle.loadString('assets/sql/schema.sql');

    // Split the file by semicolon to get individual commands
    List<String> queries = schema.split(';');

    for (String query in queries) {
      if (query.trim().isNotEmpty) {
        await db.execute(query);
      }
    }
    debugPrint("✅ Database schema initialized from assets.");
  }

  // ==========================================
  // Generic Helper Methods for All Modules
  // ==========================================

  Future<void> insertRecord(String table, Map<String, dynamic> record, {bool isSynced = false}) async {
    final db = await instance.database;
    final mutableRecord = Map<String, dynamic>.from(record);
    mutableRecord['is_synced'] = isSynced ? 1 : 0;

    final sanitizedRecord = mutableRecord.map((key, value) {
      if (value is bool) return MapEntry(key, value ? 1 : 0);
      if (value is List) return MapEntry(key, value.join(','));
      return MapEntry(key, value);
    });

    await db.insert(table, sanitizedRecord, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    final db = await instance.database;
    return await db.query(table, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(String table, dynamic id) async {
    final db = await instance.database;
    await db.update(table, {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllByUser(String table, String userId) async {
    final db = await instance.database;
    return await db.query(table, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<Map<String, dynamic>>> getRecordsByDateRange(String userId, String startDate, String endDate) async {
    final db = await instance.database;
    return await db.query(
      'sleep_record',
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }
}