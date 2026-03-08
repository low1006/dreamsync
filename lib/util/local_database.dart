import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dreamsync_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // ---------------------------------------------------------------------------
  // Schema v2 — matches SleepRecordModel exactly
  // ---------------------------------------------------------------------------
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sleep_record (
        id            TEXT PRIMARY KEY,
        user_id       TEXT NOT NULL,
        date          TEXT NOT NULL,
        total_minutes INTEGER DEFAULT 0,
        sleep_score   INTEGER DEFAULT 0,
        is_synced     INTEGER DEFAULT 0
      )
    ''');
  }

  // Migrates v1 (sleep_duration) → v2 (total_minutes + sleep_score)
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE sleep_record_new (
          id            TEXT PRIMARY KEY,
          user_id       TEXT NOT NULL,
          date          TEXT NOT NULL,
          total_minutes INTEGER DEFAULT 0,
          sleep_score   INTEGER DEFAULT 0,
          is_synced     INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        INSERT INTO sleep_record_new (id, user_id, date, total_minutes, sleep_score, is_synced)
        SELECT id, user_id, date, sleep_duration, 0, is_synced
        FROM sleep_record
      ''');

      await db.execute('DROP TABLE sleep_record');
      await db.execute('ALTER TABLE sleep_record_new RENAME TO sleep_record');
    }
  }

  // ---------------------------------------------------------------------------
  // INSERT — only persists columns that exist in the local schema
  // ---------------------------------------------------------------------------
  Future<void> insertSleepRecord(
      Map<String, dynamic> record, {bool isSynced = false}) async {
    final db = await instance.database;

    final localRecord = {
      'id':            record['id'],
      'user_id':       record['user_id'],
      'date':          record['date'],
      'total_minutes': record['total_minutes'] ?? 0,
      'sleep_score':   record['sleep_score'] ?? 0,
      'is_synced':     isSynced ? 1 : 0,
    };

    await db.insert(
      'sleep_record',
      localRecord,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------------------------------------------------------------------------
  // GET BY DATE RANGE — offline fallback for weekly chart
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getRecordsByDateRange(
      String userId, String startDate, String endDate) async {
    final db = await instance.database;
    return await db.query(
      'sleep_record',
      where: 'user_id = ? AND date >= ? AND date <= ?',
      whereArgs: [userId, startDate, endDate],
      orderBy: 'date ASC',
    );
  }

  // ---------------------------------------------------------------------------
  // GET ALL — offline fallback for achievement checks
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAllRecords(String userId) async {
    final db = await instance.database;
    return await db.query(
      'sleep_record',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'date ASC',
    );
  }

  // ---------------------------------------------------------------------------
  // GET UNSYNCED — records not yet pushed to Supabase
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await instance.database;
    return await db.query(
      'sleep_record',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
  }

  // ---------------------------------------------------------------------------
  // MARK SYNCED — after successful Supabase upload
  // ---------------------------------------------------------------------------
  Future<void> markAsSynced(String id) async {
    final db = await instance.database;
    await db.update(
      'sleep_record',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}