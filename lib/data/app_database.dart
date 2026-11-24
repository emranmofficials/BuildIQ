import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Offline SQLite store. Local data is the source of truth.
/// Migrations are additive only; no destructive migration without backup.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int version = 1;
  Database? _db;

  Future<Database> get database async {
    final existing = _db;
    if (existing != null && existing.isOpen) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'construction_calculator.db');
    _db = await openDatabase(
      path,
      version: version,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _db!;
  }

  Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    for (final statement in schema) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    // Additive migrations only. Always backup the DB file before a risky
    // migration at the file level (see docs/DATABASE_SCHEMA.md).
    if (oldVersion < 2) {
      // Example future migration:
      // await db.execute('ALTER TABLE projects ADD COLUMN new_column TEXT');
    }
  }

  static const List<String> schema = [
    '''CREATE TABLE IF NOT EXISTS meta (
      key TEXT PRIMARY KEY, value TEXT NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS projects (
      id TEXT PRIMARY KEY, name TEXT NOT NULL, client_name TEXT,
      client_phone TEXT, address TEXT, project_type TEXT,
      start_date INTEGER, end_date INTEGER, budget_minor INTEGER DEFAULT 0,
      notes TEXT, status TEXT, currency TEXT DEFAULT 'BDT',
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS buildings (
      id TEXT PRIMARY KEY, project_id TEXT, name TEXT NOT NULL,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS floors (
      id TEXT PRIMARY KEY, building_id TEXT, name TEXT,
      level INTEGER DEFAULT 0, floor_height_m REAL DEFAULT 3,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS rooms (
      id TEXT PRIMARY KEY, floor_id TEXT, name TEXT,
      polygon_json TEXT, finish_level_m REAL DEFAULT 0, notes TEXT,
      status TEXT DEFAULT 'userVerified',
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS walls (
      id TEXT PRIMARY KEY, floor_id TEXT, name TEXT,
      x1 REAL, y1 REAL, x2 REAL, y2 REAL,
      thickness_m REAL, height_m REAL, wall_type TEXT, material TEXT,
      brick_type TEXT, mortar_ratio TEXT, is_shared INTEGER DEFAULT 0,
      ai_status TEXT, confidence REAL,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS room_walls (
      room_id TEXT NOT NULL, wall_id TEXT NOT NULL, role TEXT,
      PRIMARY KEY (room_id, wall_id))''',
    '''CREATE TABLE IF NOT EXISTS openings (
      id TEXT PRIMARY KEY, wall_id TEXT NOT NULL, kind TEXT, subtype TEXT,
      offset_m REAL, width_m REAL, height_m REAL, sill_m REAL,
      ai_status TEXT, confidence REAL,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS materials (
      id TEXT PRIMARY KEY, project_id TEXT, name TEXT, unit TEXT,
      unit_cost_minor INTEGER DEFAULT 0, supplier TEXT, notes TEXT,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS saved_calculations (
      id TEXT PRIMARY KEY, project_id TEXT, kind TEXT, title TEXT,
      input_json TEXT, result_json TEXT,
      created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
      dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS calculation_history (
      id TEXT PRIMARY KEY, expression TEXT, result TEXT,
      created_at INTEGER NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS boq_lines (
      id TEXT PRIMARY KEY, project_id TEXT, source_type TEXT, source_id TEXT,
      description TEXT, quantity REAL, unit TEXT,
      rate_minor INTEGER, amount_minor INTEGER, category TEXT, notes TEXT,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY, project_id TEXT, title TEXT,
      amount_minor INTEGER, category TEXT, spent_at INTEGER, notes TEXT,
      created_at INTEGER, updated_at INTEGER, dirty INTEGER DEFAULT 0)''',
    '''CREATE TABLE IF NOT EXISTS settings (
      key TEXT PRIMARY KEY, value_json TEXT NOT NULL)''',
    '''CREATE TABLE IF NOT EXISTS sync_queue (
      id TEXT PRIMARY KEY, entity_type TEXT, entity_id TEXT, operation TEXT,
      payload_json TEXT, status TEXT, attempts INTEGER DEFAULT 0,
      last_error TEXT, created_at INTEGER, next_attempt_at INTEGER)''',
    '''CREATE TABLE IF NOT EXISTS sync_log (
      id TEXT PRIMARY KEY, started_at INTEGER, finished_at INTEGER,
      result TEXT, items_json TEXT, error TEXT)''',
    '''CREATE TABLE IF NOT EXISTS ai_analyses (
      id TEXT PRIMARY KEY, project_id TEXT, source_type TEXT, source_path TEXT,
      provider TEXT, model TEXT, raw_response_json TEXT,
      draft_floorplan_json TEXT, status TEXT, created_at INTEGER)''',
    'CREATE INDEX IF NOT EXISTS idx_projects_updated ON projects(updated_at)',
    'CREATE INDEX IF NOT EXISTS idx_walls_floor ON walls(floor_id)',
    'CREATE INDEX IF NOT EXISTS idx_room_walls_wall ON room_walls(wall_id)',
    'CREATE INDEX IF NOT EXISTS idx_history_created ON calculation_history(created_at)',
    'CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue(status, next_attempt_at)',
  ];

  Future<int> insert(String table, Map<String, Object?> values) async {
    final db = await database;
    return db.insert(
      table,
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final db = await database;
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> setSetting(String key, String value) async {
    await insert('settings', {'key': key, 'value_json': value});
  }

  Future<String?> getSetting(String key) async {
    final rows = await query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value_json'] as String?;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
