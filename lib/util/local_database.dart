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

  /// Only tables that hold sensitive / local-only data.
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

  // ===========================================================================
  // DATABASE LIFECYCLE
  // ===========================================================================

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

  // ===========================================================================
  // ENCRYPTION KEY
  // ===========================================================================

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

  // ===========================================================================
  // INIT / OPEN / UPGRADE
  // ===========================================================================

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    final String password = await _getEncryptionKey();

    try {
      return await _openDB(path, password);
    } catch (e) {
      debugPrint('⚠️ DB open failed (key mismatch or corrupt): $e');
      debugPrint('🗑️ Deleting corrupt DB and recreating...');

      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$path$suffix');
        if (await f.exists()) {
          await f.delete();
          debugPrint('🗑️ Deleted: $path$suffix');
        }
      }

      await _secureStorage.delete(key: _keyName);
      debugPrint('🔐 Old key deleted. Generating a fresh key...');
      final freshPassword = await _getEncryptionKey();

      return await _openDB(path, freshPassword);
    }
  }

  Future<Database> _openDB(String path, String password) {
    return openDatabase(
      path,
      version: 10,
      password: password,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      debugPrint(
        '🔄 Upgrading DB from v$oldVersion → v$newVersion. Recreating tables...',
      );
      for (final table in allTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }

      // Drop legacy tables that no longer exist in the schema
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

  // ===========================================================================
  // SANITIZE
  // ===========================================================================

  Map<String, dynamic> _sanitizeRecord(Map<String, dynamic> record) {
    return record.map((key, value) {
      if (value is bool) return MapEntry(key, value ? 1 : 0);
      if (value is List || value is Map) {
        return MapEntry(key, jsonEncode(value));
      }
      return MapEntry(key, value);
    });
  }

  // ===========================================================================
  // INSERT
  // ===========================================================================

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

  // ===========================================================================
  // SYNC HELPERS
  // ===========================================================================

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

  // ===========================================================================
  // QUERY HELPERS
  // ===========================================================================

  Future<void> debugPrintTable(String table, {int limit = 50}) async {
    final db = await instance.database;
    final rows = await db.query(table, limit: limit);
    debugPrint('🔍 [$table] — ${rows.length} row(s):');
    for (int i = 0; i < rows.length; i++) {
      debugPrint('  [$i] ${rows[i]}');
    }
  }

  Future<int> getRowCount(String table) async {
    final db = await instance.database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;
  }

  Future<void> debugPrintAllTableCounts() async {
    debugPrint('📊 DreamSync DB — table row counts:');
    for (final table in allTables) {
      final count = await getRowCount(table);
      debugPrint('   $table: $count row(s)');
    }
  }

  Future<List<Map<String, dynamic>>> getAllRows(
      String table, {
        int limit = 200,
      }) async {
    final db = await instance.database;
    return await db.query(table, limit: limit);
  }

  Future<void> updateField(
      String table,
      dynamic id,
      String field,
      dynamic value,
      ) async {
    final db = await instance.database;
    await db.update(
      table,
      {field: value},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateFields(
      String table,
      dynamic id,
      Map<String, dynamic> fields,
      ) async {
    final db = await instance.database;
    await db.update(
      table,
      _sanitizeRecord(fields),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteRecord(String table, dynamic id) async {
    final db = await instance.database;
    await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getAllByUser(
      String table,
      String userId,
      ) async {
    final db = await instance.database;
    return await db.query(table, where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<Map<String, dynamic>>> getRecordsByDateRange(
      String userId,
      String startDate,
      String endDate,
      ) async {
    final db = await instance.database;
    return await db.query(
      'sleep_record',
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }
}