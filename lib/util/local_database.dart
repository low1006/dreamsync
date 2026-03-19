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

  // ✅ FIX 1: Completer-based lock prevents concurrent _initDB calls.
  //
  // Without this, two callers that both see _database == null race to call
  // _initDB simultaneously. Both call _getEncryptionKey() before either
  // has written to secure storage, so each generates a *different* key.
  // The DB opens with key #1 but key #2 is stored — on the next open,
  // key #2 is read but the file was encrypted with key #1 → "hmac check
  // failed (code 26)".
  static Completer<Database>? _initCompleter;

  LocalDatabase._init();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _keyName = 'dreamsync_db_key';
  static const String _dbFileName = 'dreamsync_secure.db';

  static const List<String> allTables = [
    'sleep_record',
    'daily_activity',
    'schedule',
    'user_achievement',
    'achievement_definition',
    'friend_cache',
    'sleep_recommendation',
  ];

  Future<Database> get database async {
    // Fast path: already open
    if (_database != null) return _database!;

    // If an init is already in progress, wait for it instead of racing
    if (_initCompleter != null) return _initCompleter!.future;

    // First caller: own the init
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
      // Always clear so a future call can retry if this one failed
      _initCompleter = null;
    }
  }

  /// Call this on logout BEFORE navigating to the login screen.
  ///
  /// Closes the SQLCipher connection and clears the cached singleton so the
  /// next user's session gets a fresh open. Without this the stale connection
  /// from the previous session persists and causes "code 26" errors.
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
      _initCompleter = null; // clear any stale in-flight init too
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
      // ✅ FIX 2: Self-healing on key mismatch / corrupt file.
      //
      // Happens when:
      //   a) The race condition above wrote a different key than the one used
      //      to encrypt the file (now prevented by the Completer lock, but
      //      kept as a safety net for devices with existing bad state).
      //   b) The app was previously unencrypted and is now opened with
      //      SQLCipher.
      //   c) FlutterSecureStorage lost the key (OS wipe, reinstall, etc.)
      //
      // Recovery: delete the unreadable file, rotate to a fresh key, and
      // recreate the schema. Data re-syncs from Supabase on next network call.
      debugPrint('⚠️ DB open failed (key mismatch or corrupt): $e');
      debugPrint('🗑️  Deleting corrupt DB and recreating...');

      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$path$suffix');
        if (await f.exists()) {
          await f.delete();
          debugPrint('🗑️  Deleted: $path$suffix');
        }
      }

      // Rotate the key so we start completely clean
      await _secureStorage.delete(key: _keyName);
      debugPrint('🔐 Old key deleted. Generating a fresh key...');
      final freshPassword = await _getEncryptionKey();

      return await _openDB(path, freshPassword);
    }
  }

  Future<Database> _openDB(String path, String password) {
    return openDatabase(
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
        '🔄 Upgrading DB from v$oldVersion → v$newVersion. Recreating tables...',
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

    final beforeCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

    final rowId = await db.insert(
      table,
      _sanitizeRecord(mutableRecord),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final afterCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

    debugPrint(
      '📥 [$table] insert → rowId=$rowId | '
          'rows: $beforeCount → $afterCount '
          '(${afterCount > beforeCount ? '+1 inserted' : 'replaced existing'})',
    );
  }

  Future<void> insertRecords(
      String table,
      List<Map<String, dynamic>> records, {
        bool isSynced = false,
      }) async {
    if (records.isEmpty) return;

    final db = await instance.database;

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

    final afterCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $table'),
    ) ??
        0;

    debugPrint(
      '📦 [$table] batch insert ${records.length} records | '
          'rows: $beforeCount → $afterCount',
    );
  }

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