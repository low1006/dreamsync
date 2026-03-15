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

  // ─────────────────────────────────────────────────────────────
  // Known tables — used by the debug viewer
  // ─────────────────────────────────────────────────────────────
  static const List<String> allTables = [
    'sleep_record',
    'daily_activity',
    'schedule',
    'user_achievement',
    'achievement_definition',
    'friend_cache',
  ];

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dreamsync_secure.db');
    return _database!;
  }

  Future<String> _getEncryptionKey() async {
    String? key = await _secureStorage.read(key: _keyName);

    if (key == null) {
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (_) => random.nextInt(256));
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
      version: 9,
      password: password,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      debugPrint(
        "🔄 Upgrading DB from v$oldVersion → v$newVersion. Recreating tables...",
      );
      for (final table in allTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
      }
      await _createDB(db, newVersion);
    }
  }

  Future _createDB(Database db, int version) async {
    final String schema = await rootBundle.loadString('assets/sql/schema.sql');
    final List<String> queries = schema.split(';');

    for (String query in queries) {
      if (query.trim().isNotEmpty) {
        await db.execute(query);
      }
    }

    debugPrint("✅ Database schema v$version initialized from assets.");
  }

  // ─────────────────────────────────────────────────────────────
  // Generic Helper Methods
  // ─────────────────────────────────────────────────────────────

  Future<void> insertRecord(
      String table,
      Map<String, dynamic> record, {
        bool isSynced = false,
      }) async {
    final db = await instance.database;
    final mutableRecord = Map<String, dynamic>.from(record);
    mutableRecord['is_synced'] = isSynced ? 1 : 0;

    // ── VERIFICATION: row count before insert ──────────────────
    final beforeCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

    final rowId = await db.insert(
      table,
      _sanitizeRecord(mutableRecord),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // ── VERIFICATION: row count after insert ───────────────────
    final afterCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

    debugPrint(
      "📥 [$table] insert → rowId=$rowId | "
          "rows: $beforeCount → $afterCount "
          "(${afterCount > beforeCount ? '+1 inserted' : 'replaced existing'})",
    );
  }

  Future<void> insertRecords(
      String table,
      List<Map<String, dynamic>> records, {
        bool isSynced = false,
      }) async {
    if (records.isEmpty) return;

    final db = await instance.database;

    // ── VERIFICATION: row count before batch ──────────────────
    final beforeCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

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

    // ── VERIFICATION: row count after batch ───────────────────
    final afterCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

    debugPrint(
      "📦 [$table] batch insert ${records.length} records | "
          "rows: $beforeCount → $afterCount",
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Debug / Inspection Helpers
  // ─────────────────────────────────────────────────────────────

  /// Prints every row of [table] to the debug console.
  /// Call this right after an insert to confirm the data is there.
  ///
  /// Example:
  ///   await LocalDatabase.instance.debugPrintTable('sleep_record');
  Future<void> debugPrintTable(String table, {int limit = 50}) async {
    final db = await instance.database;
    final rows = await db.query(table, limit: limit);
    debugPrint("🔍 [$table] — ${rows.length} row(s):");
    for (int i = 0; i < rows.length; i++) {
      debugPrint("  [$i] ${rows[i]}");
    }
  }

  /// Returns the total row count for [table].
  Future<int> getRowCount(String table) async {
    final db = await instance.database;
    return Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;
  }

  /// Prints a one-line summary of every table's row count.
  Future<void> debugPrintAllTableCounts() async {
    debugPrint("📊 DreamSync DB — table row counts:");
    for (final table in allTables) {
      final count = await getRowCount(table);
      debugPrint("   $table: $count row(s)");
    }
  }

  /// Returns all rows from [table] — used by [DatabaseDebugScreen].
  Future<List<Map<String, dynamic>>> getAllRows(
      String table, {
        int limit = 200,
      }) async {
    final db = await instance.database;
    return await db.query(table, limit: limit);
  }

  // Converts bool → int and List/Map → JSON String so SQLite never
  // receives a type it cannot store.
  Map<String, dynamic> _sanitizeRecord(Map<String, dynamic> record) {
    return record.map((key, value) {
      if (value is bool) return MapEntry(key, value ? 1 : 0);
      if (value is List || value is Map) {
        return MapEntry(key, jsonEncode(value));
      }
      return MapEntry(key, value);
    });
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    final db = await instance.database;
    return await db.query(table, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(String table, dynamic id) async {
    final db = await instance.database;
    await db.update(
      table,
      {'is_synced': 1},
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