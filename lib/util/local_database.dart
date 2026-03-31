import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  static Completer<Database>? _initCompleter;

  LocalDatabase._init();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _keyName = 'dreamsync_db_key';
  static const String _dbFileName = 'dreamsync_secure.db';
  static const int _dbVersion = 4;

  static const List<String> allTables = [
    'sleep_record',
    'daily_activities',
    'sleep_recommendation',
    'sleep_schedule',
    'user_achievement',
    'achievement',
    'friend_cache',
    'profile',
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;

    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      final db = await _initDB(_dbFileName);
      _database = db;
      _initCompleter!.complete(db);
      return db;
    } catch (e) {
      _initCompleter!.completeError(e);
      rethrow;
    } finally {
      _initCompleter = null;
    }
  }

  Future<void> closeDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        debugPrint('🔒 LocalDatabase: connection closed on logout.');
      }
    } catch (e) {
      debugPrint('⚠️ LocalDatabase.closeDatabase error: $e');
    } finally {
      _database = null;
      _initCompleter = null;
    }
  }

  Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _keyName);

    if (key == null) {
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = base64UrlEncode(keyBytes);
      await _secureStorage.write(key: _keyName, value: key);
      debugPrint('🔐 Generated and stored new database encryption key.');
    }
    return key;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    final String password = await _getEncryptionKey();

    try {
      return await _openDB(path, password);
    } catch (e) {
      debugPrint('⚠️ DB open failed (key mismatch or corrupt): $e');
      debugPrint('🗑️ Deleting corrupt DB and recreating.');

      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$path$suffix');
        if (await f.exists()) {
          await f.delete();
          debugPrint('🗑️ Deleted: $path$suffix');
        }
      }

      await _secureStorage.delete(key: _keyName);
      debugPrint('🔐 Old key deleted.');

      final newPassword = await _getEncryptionKey();
      return await _openDB(path, newPassword);
    }
  }

  Future<Database> _openDB(String path, String password) async {
    return await openDatabase(
      path,
      version: _dbVersion,
      password: password,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    debugPrint(
      '⚠️ LocalDatabase upgrade: v$oldVersion → v$newVersion.',
    );

    // v2 → v3: Add caffeine, sugar, alcohol columns to daily_activities
    if (oldVersion < 3) {
      try {
        await db.execute(
          'ALTER TABLE daily_activities ADD COLUMN caffeine_intake_mg REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE daily_activities ADD COLUMN sugar_intake_g REAL DEFAULT 0',
        );
        await db.execute(
          'ALTER TABLE daily_activities ADD COLUMN alcohol_intake_g REAL DEFAULT 0',
        );
        debugPrint('✅ Added caffeine/sugar/alcohol columns to daily_activities.');
      } catch (e) {
        // Columns may already exist if user reinstalled — ignore duplicate errors
        debugPrint('⚠️ Migration v3 ALTER TABLE: $e (may be harmless)');
      }
    }

    // v3 → v4: Add snooze_duration_minutes column to sleep_schedule
    if (oldVersion < 4) {
      try {
        await db.execute(
          'ALTER TABLE sleep_schedule ADD COLUMN snooze_duration_minutes INTEGER DEFAULT 5',
        );
        debugPrint('✅ Added snooze_duration_minutes column to sleep_schedule.');
      } catch (e) {
        debugPrint('⚠️ Migration v4 ALTER TABLE: $e (may be harmless)');
      }
    }

    // Fallback: if upgrading from v1 or unknown, drop and recreate everything
    if (oldVersion < 2) {
      for (final table in allTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
      for (final legacy in [
        'schedule',
        'user_achievement',
        'achievement_definition',
        'friend_cache',
      ]) {
        await db.execute('DROP TABLE IF EXISTS $legacy');
      }
      await _createDB(db, newVersion);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    final String schema = await rootBundle.loadString('assets/sql/schema.sql');
    final List<String> queries = schema.split(';');

    for (String query in queries) {
      if (query.trim().isNotEmpty) {
        await db.execute(query);
      }
    }

    debugPrint('✅ Database schema v$version initialized from assets.');
  }

  Map<String, dynamic> _sanitizeRecord(Map<String, dynamic> record) {
    return record.map((key, value) {
      if (value is bool) return MapEntry(key, value ? 1 : 0);
      if (value is List || value is Map) {
        return MapEntry(key, jsonEncode(value));
      }
      return MapEntry(key, value);
    });
  }

  Future<void> insertRecord(
      String table,
      Map<String, dynamic> record, {
        bool isSynced = false,
      }) async {
    final db = await instance.database;
    final mutableRecord = Map<String, dynamic>.from(record);
    mutableRecord['is_synced'] = isSynced ? 1 : 0;

    await db.insert(
      table,
      _sanitizeRecord(mutableRecord),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertRecords(
      String table,
      List<Map<String, dynamic>> records, {
        bool isSynced = false,
      }) async {
    if (records.isEmpty) return;

    final db = await instance.database;

    await db.transaction((txn) async {
      for (final record in records) {
        final mutableRecord = Map<String, dynamic>.from(record);
        mutableRecord['is_synced'] = isSynced ? 1 : 0;

        await txn.insert(
          table,
          _sanitizeRecord(mutableRecord),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    final db = await instance.database;
    return await db.query(table, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(String table, String userId, String date) async {
    final db = await instance.database;
    await db.update(
      table,
      {'is_synced': 1},
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
  }

  Future<void> markAsUnsynced(String table, String userId, String date) async {
    final db = await instance.database;
    await db.update(
      table,
      {'is_synced': 0},
      where: 'user_id = ? AND date = ?',
      whereArgs: [userId, date],
    );
  }

  Future<int> clearTable(String table) async {
    final db = await instance.database;
    return await db.delete(table);
  }

  Future<void> clearAllUserData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final table in allTables) {
        await txn.delete(table);
      }
    });
    debugPrint('🧹 All local encrypted user data cleared.');
  }
}