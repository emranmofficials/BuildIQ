import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import 'connectivity.dart';
import 'logger.dart';

/// Global, offline-first application state.
class AppState extends ChangeNotifier {
  AppState({
    required this.database,
    required this.connectivity,
    required this.preferences,
    required this.secureStorage,
  });

  final AppDatabase database;
  final ConnectivityService connectivity;
  final SharedPreferences preferences;
  final FlutterSecureStorage secureStorage;

  static const _uuid = Uuid();

  /// Set by [SyncService] so every committed local change is queued for an
  /// honest sync attempt. Local writes never depend on this being set.
  void Function({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  })?
  onLocalChange;

  void _queueLocalChange({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
  }) {
    onLocalChange?.call(
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
    );
  }

  Locale locale = const Locale('bn');
  ThemeMode themeMode = ThemeMode.system;
  int precision = 3;
  String landPresetId = 'bd_standard';

  List<Map<String, dynamic>> history = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> savedCalculations = <Map<String, dynamic>>[];
  List<Project> projects = <Project>[];

  NetworkStatus _syncStatus = NetworkStatus.syncPending;
  NetworkStatus get syncStatus => _syncStatus;

  String? aiEndpoint;
  String? aiModel;
  String? aiKey;
  bool get aiConfigured =>
      aiEndpoint != null &&
      aiEndpoint!.isNotEmpty &&
      aiModel != null &&
      aiModel!.isNotEmpty &&
      aiKey != null &&
      aiKey!.isNotEmpty;

  Future<void> load() async {
    try {
      final languageCode = preferences.getString('locale') ?? 'bn';
      locale = Locale(languageCode);
      themeMode = switch (preferences.getString('themeMode')) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
      precision = preferences.getInt('precision') ?? 3;
      landPresetId = preferences.getString('landPreset') ?? 'bd_standard';
      aiEndpoint = preferences.getString('aiEndpoint');
      aiModel = preferences.getString('aiModel');
      aiKey = await secureStorage.read(key: 'ai_api_key');

      await refreshHistory();
      await refreshSavedCalculations();
      await refreshProjects();
      notifyListeners();
    } catch (error, stack) {
      AppLogger.error('Failed to load app state', '$error\n$stack');
    }
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    await preferences.setString('locale', value.languageCode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    await preferences.setString('themeMode', value.name);
    notifyListeners();
  }

  Future<void> setPrecision(int value) async {
    precision = value.clamp(0, 6);
    await preferences.setInt('precision', precision);
    notifyListeners();
  }

  Future<void> setLandPreset(String id) async {
    landPresetId = id;
    await preferences.setString('landPreset', id);
    notifyListeners();
  }

  Future<void> configureAi({
    required String endpoint,
    required String model,
    required String key,
  }) async {
    aiEndpoint = endpoint.trim();
    aiModel = model.trim();
    aiKey = key.trim();
    await preferences.setString('aiEndpoint', aiEndpoint ?? '');
    await preferences.setString('aiModel', aiModel ?? '');
    if (aiKey!.isNotEmpty) {
      await secureStorage.write(key: 'ai_api_key', value: aiKey);
    } else {
      await secureStorage.delete(key: 'ai_api_key');
    }
    notifyListeners();
  }

  Future<void> addHistory(String expression, double result) async {
    final entry = {
      'id': _uuid.v4(),
      'expression': expression,
      'result': result.toString(),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };
    await database.insert('calculation_history', entry);
    await refreshHistory();
  }

  Future<void> clearHistory() async {
    await database.delete('calculation_history', where: '1=1', whereArgs: []);
    await refreshHistory();
  }

  Future<void> refreshHistory() async {
    history = await database.query(
      'calculation_history',
      orderBy: 'created_at DESC',
      limit: 100,
    );
    notifyListeners();
  }

  Future<void> saveCalculation({
    required String kind,
    required String title,
    required Map<String, dynamic> input,
    required Map<String, dynamic> result,
    String? projectId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rowId = _uuid.v4();
    await database.insert('saved_calculations', {
      'id': rowId,
      'project_id': projectId,
      'kind': kind,
      'title': title,
      'input_json': jsonEncode(input),
      'result_json': jsonEncode(result),
      'created_at': now,
      'updated_at': now,
      'dirty': 1,
    });
    await refreshSavedCalculations();
    _queueLocalChange(
      entityType: 'saved_calculation',
      entityId: rowId,
      operation: SyncOperation.insert,
      payload: result,
    );
    setSyncStatus(NetworkStatus.syncPending);
  }

  Future<void> refreshSavedCalculations() async {
    savedCalculations = await database.query(
      'saved_calculations',
      orderBy: 'created_at DESC',
      limit: 200,
    );
    notifyListeners();
  }

  Future<void> refreshProjects() async {
    final rows = await database.query('projects', orderBy: 'updated_at DESC');
    projects = rows.map(_projectFromRow).toList(growable: false);
    notifyListeners();
  }

  Project _projectFromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      clientName: row['client_name'] as String? ?? '',
      clientPhone: row['client_phone'] as String? ?? '',
      address: row['address'] as String? ?? '',
      type: ProjectType.values.firstWhere(
        (value) => value.name == row['project_type'],
        orElse: () => ProjectType.custom,
      ),
      startDate: row['start_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['start_date'] as int),
      endDate: row['end_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['end_date'] as int),
      budgetMinor: row['budget_minor'] as int? ?? 0,
      currency: row['currency'] as String? ?? 'BDT',
      notes: row['notes'] as String? ?? '',
      status: ProjectStatus.values.firstWhere(
        (value) => value.name == row['status'],
        orElse: () => ProjectStatus.planning,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(row['updated_at'] as int),
      dirty: (row['dirty'] as int? ?? 0) == 1,
    );
  }

  Future<void> createProject({
    required String name,
    required String clientName,
    required String clientPhone,
    required String address,
    required int budgetMinor,
    required ProjectStatus status,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final newId = _uuid.v4();
    await database.insert('projects', {
      'id': newId,
      'name': name,
      'client_name': clientName,
      'client_phone': clientPhone,
      'address': address,
      'project_type': ProjectType.custom.name,
      'budget_minor': budgetMinor,
      'status': status.name,
      'currency': 'BDT',
      'created_at': now,
      'updated_at': now,
      'dirty': 1,
    });
    _queueLocalChange(
      entityType: 'project',
      entityId: newId,
      operation: SyncOperation.insert,
      payload: {
        'name': name,
        'clientName': clientName,
        'budgetMinor': budgetMinor,
      },
    );
    await refreshProjects();
    setSyncStatus(NetworkStatus.syncPending);
  }

  Future<void> deleteProject(String id) async {
    await database.delete('projects', where: 'id = ?', whereArgs: [id]);
    _queueLocalChange(
      entityType: 'project',
      entityId: id,
      operation: SyncOperation.delete,
      payload: const {},
    );
    await refreshProjects();
    setSyncStatus(NetworkStatus.syncPending);
  }

  void setSyncStatus(NetworkStatus value) {
    _syncStatus = value;
    notifyListeners();
  }

  UnitRegistry get unitRegistry => UnitRegistry(
    preset:
        LandUnitPreset.presets[landPresetId] ??
        LandUnitPreset.bangladeshStandard,
  );

  /// Persists a floor plan atomically enough for offline-first use: every
  /// physical wall is written once and only linked to rooms via `room_walls`.
  /// This is what guarantees a shared wall can never be double-counted after
  /// a restart.
  Future<void> saveFloorPlan(Building building) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await database.insert('buildings', {
      'id': building.id,
      'project_id': building.projectId,
      'name': building.name,
      'created_at': now,
      'updated_at': now,
      'dirty': 1,
    });

    for (final floor in building.floors) {
      await database.insert('floors', {
        'id': floor.id,
        'building_id': building.id,
        'name': floor.name,
        'level': floor.level,
        'floor_height_m': floor.heightM,
        'created_at': now,
        'updated_at': now,
        'dirty': 1,
      });

      for (final wall in floor.walls) {
        await database.insert('walls', {
          'id': wall.id,
          'floor_id': floor.id,
          'name': wall.name,
          'x1': wall.start.x,
          'y1': wall.start.y,
          'x2': wall.end.x,
          'y2': wall.end.y,
          'thickness_m': wall.thicknessM,
          'height_m': wall.heightM,
          'wall_type': wall.type.name,
          'material': wall.material,
          'is_shared': wall.isShared ? 1 : 0,
          'ai_status': wall.status.name,
          'confidence': wall.confidence,
          'created_at': now,
          'updated_at': now,
          'dirty': 1,
        });
        await database.delete(
          'openings',
          where: 'wall_id = ?',
          whereArgs: [wall.id],
        );
        for (final opening in wall.openings) {
          await database.insert('openings', {
            'id': opening.id,
            'wall_id': wall.id,
            'kind': opening.kind.name,
            'subtype': opening.subtype,
            'offset_m': opening.offsetM,
            'width_m': opening.widthM,
            'height_m': opening.heightM,
            'sill_m': opening.sillM,
            'ai_status': opening.status.name,
            'confidence': opening.confidence,
            'created_at': now,
            'updated_at': now,
            'dirty': 1,
          });
        }
      }

      final wallIds = floor.walls.map((wall) => wall.id).toSet();
      for (final room in floor.rooms) {
        await database.insert('rooms', {
          'id': room.id,
          'floor_id': floor.id,
          'name': room.name,
          'polygon_json': jsonEncode(
            room.polygon.map((point) => point.toJson()).toList(),
          ),
          'status': room.status.name,
          'created_at': now,
          'updated_at': now,
          'dirty': 1,
        });
        await database.delete(
          'room_walls',
          where: 'room_id = ?',
          whereArgs: [room.id],
        );
        // Only link walls that actually exist in this floor plan.
        for (final wallId in room.wallIds.where(wallIds.contains)) {
          await database.insert('room_walls', {
            'room_id': room.id,
            'wall_id': wallId,
            'role': 'boundary',
          });
        }
      }
    }
    _queueLocalChange(
      entityType: 'building',
      entityId: building.id,
      operation: SyncOperation.update,
      payload: building.toJson(),
    );
    setSyncStatus(NetworkStatus.syncPending);
  }

  /// Rebuilds a [Building] from the local store. Returns null when nothing
  /// has been saved yet so callers can seed a demo plan on first launch.
  Future<Building?> loadFloorPlan(String buildingId) async {
    final buildingRows = await database.query(
      'buildings',
      where: 'id = ?',
      whereArgs: [buildingId],
      limit: 1,
    );
    if (buildingRows.isEmpty) return null;
    final buildingRow = buildingRows.first;

    final floorRows = await database.query(
      'floors',
      where: 'building_id = ?',
      whereArgs: [buildingId],
      orderBy: 'level ASC',
    );
    final floors = <Floor>[];
    for (final floorRow in floorRows) {
      final floorId = floorRow['id'] as String;
      final openingRows = await database.query('openings');
      final openingsByWall = <String, List<Opening>>{};
      for (final row in openingRows) {
        final wallId = row['wall_id'] as String;
        openingsByWall
            .putIfAbsent(wallId, () => [])
            .add(
              Opening(
                id: row['id'] as String,
                wallId: wallId,
                kind: OpeningKind.values.firstWhere(
                  (value) => value.name == row['kind'],
                  orElse: () => OpeningKind.opening,
                ),
                subtype: row['subtype'] as String? ?? 'custom',
                offsetM: (row['offset_m'] as num?)?.toDouble() ?? 0,
                widthM: (row['width_m'] as num?)?.toDouble() ?? 0,
                heightM: (row['height_m'] as num?)?.toDouble() ?? 0,
                sillM: (row['sill_m'] as num?)?.toDouble() ?? 0,
                status: VerificationStatus.values.firstWhere(
                  (value) => value.name == row['ai_status'],
                  orElse: () => VerificationStatus.uncertain,
                ),
                confidence: (row['confidence'] as num?)?.toDouble() ?? 1,
              ),
            );
      }

      final wallRows = await database.query(
        'walls',
        where: 'floor_id = ?',
        whereArgs: [floorId],
      );
      final walls = wallRows.map((row) {
        final id = row['id'] as String;
        return Wall(
          id: id,
          floorId: floorId,
          name: row['name'] as String? ?? '',
          start: PlanPoint(
            (row['x1'] as num?)?.toDouble() ?? 0,
            (row['y1'] as num?)?.toDouble() ?? 0,
          ),
          end: PlanPoint(
            (row['x2'] as num?)?.toDouble() ?? 0,
            (row['y2'] as num?)?.toDouble() ?? 0,
          ),
          thicknessM: (row['thickness_m'] as num?)?.toDouble() ?? 0.2,
          heightM: (row['height_m'] as num?)?.toDouble() ?? 3,
          type: WallType.values.firstWhere(
            (value) => value.name == row['wall_type'],
            orElse: () => WallType.custom,
          ),
          material: row['material'] as String? ?? 'brick',
          isShared: (row['is_shared'] as int? ?? 0) == 1,
          status: VerificationStatus.values.firstWhere(
            (value) => value.name == row['ai_status'],
            orElse: () => VerificationStatus.uncertain,
          ),
          confidence: (row['confidence'] as num?)?.toDouble() ?? 1,
          openings: openingsByWall[id] ?? const [],
        );
      }).toList();

      final roomRows = await database.query(
        'rooms',
        where: 'floor_id = ?',
        whereArgs: [floorId],
      );
      final linkRows = await database.query('room_walls');
      final linksByRoom = <String, Set<String>>{};
      for (final row in linkRows) {
        linksByRoom
            .putIfAbsent(row['room_id'] as String, () => <String>{})
            .add(row['wall_id'] as String);
      }
      final rooms = roomRows.map((row) {
        final polygonJson = row['polygon_json'] as String? ?? '[]';
        final decoded = jsonDecode(polygonJson) as List<dynamic>;
        final id = row['id'] as String;
        return Room(
          id: id,
          floorId: floorId,
          name: row['name'] as String? ?? '',
          polygon: decoded
              .map((point) => PlanPoint.fromJson(point as Map<String, dynamic>))
              .toList(),
          wallIds: linksByRoom[id] ?? const <String>{},
          status: VerificationStatus.values.firstWhere(
            (value) => value.name == row['status'],
            orElse: () => VerificationStatus.uncertain,
          ),
        );
      }).toList();

      floors.add(
        Floor(
          id: floorId,
          buildingId: buildingId,
          name: floorRow['name'] as String? ?? '',
          level: floorRow['level'] as int? ?? 0,
          heightM: (floorRow['floor_height_m'] as num?)?.toDouble() ?? 3,
          rooms: rooms,
          walls: walls,
        ),
      );
    }

    return Building(
      id: buildingId,
      projectId: buildingRow['project_id'] as String? ?? '',
      name: buildingRow['name'] as String? ?? '',
      floors: floors,
    );
  }
}
