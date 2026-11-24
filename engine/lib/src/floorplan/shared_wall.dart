import 'dart:math' as math;

import '../core/result.dart';
import 'models.dart';

class WallTakeoff {
  final String wallId;
  final String name;
  final double lengthM;
  final double thicknessM;
  final double grossAreaM2;
  final double openingAreaM2;
  final double netAreaM2;
  final double brickworkVolumeM3;
  final int exposedFaces;

  const WallTakeoff({
    required this.wallId,
    required this.name,
    required this.lengthM,
    required this.thicknessM,
    required this.grossAreaM2,
    required this.openingAreaM2,
    required this.netAreaM2,
    required this.brickworkVolumeM3,
    required this.exposedFaces,
  });

  double get plasterAreaM2 => netAreaM2 * exposedFaces;

  Map<String, dynamic> toJson() => {
    'wallId': wallId,
    'name': name,
    'lengthM': lengthM,
    'thicknessM': thicknessM,
    'grossAreaM2': grossAreaM2,
    'openingAreaM2': openingAreaM2,
    'netAreaM2': netAreaM2,
    'brickworkVolumeM3': brickworkVolumeM3,
    'exposedFaces': exposedFaces,
  };
}

class RoomTakeoff {
  final String roomId;
  final String name;
  final double floorAreaM2;
  final double perimeterM;
  final double linkedWallLengthM;
  final double netWallAreaM2;

  const RoomTakeoff({
    required this.roomId,
    required this.name,
    required this.floorAreaM2,
    required this.perimeterM,
    required this.linkedWallLengthM,
    required this.netWallAreaM2,
  });

  Map<String, dynamic> toJson() => {
    'roomId': roomId,
    'name': name,
    'floorAreaM2': floorAreaM2,
    'perimeterM': perimeterM,
    'linkedWallLengthM': linkedWallLengthM,
    'netWallAreaM2': netWallAreaM2,
  };
}

class BuildingTakeoff {
  final int uniqueWallCount;
  final List<String> duplicateWallIds;
  final double totalWallLengthM;
  final double totalNetWallAreaM2;
  final double totalBrickworkVolumeM3;
  final double totalPlasterAreaM2;
  final List<WallTakeoff> walls;
  final List<RoomTakeoff> rooms;
  final List<ValidationIssue> issues;

  const BuildingTakeoff({
    required this.uniqueWallCount,
    required this.duplicateWallIds,
    required this.totalWallLengthM,
    required this.totalNetWallAreaM2,
    required this.totalBrickworkVolumeM3,
    required this.totalPlasterAreaM2,
    required this.walls,
    required this.rooms,
    required this.issues,
  });

  Map<String, dynamic> toJson() => {
    'uniqueWallCount': uniqueWallCount,
    'duplicateWallIds': duplicateWallIds,
    'totalWallLengthM': totalWallLengthM,
    'totalNetWallAreaM2': totalNetWallAreaM2,
    'totalBrickworkVolumeM3': totalBrickworkVolumeM3,
    'totalPlasterAreaM2': totalPlasterAreaM2,
    'walls': walls.map((wall) => wall.toJson()).toList(),
    'rooms': rooms.map((room) => room.toJson()).toList(),
    'issues': issues.map((issue) => issue.toJson()).toList(),
  };
}

/// Owns the single source of truth for physical walls and room links.
///
/// Invariant: a wall ID appears at most once in [_walls]. Room links are
/// many-to-one, which is how shared walls are represented without copies.
class SharedWallRegistry {
  final Map<String, Wall> _walls = <String, Wall>{};
  final Map<String, Set<String>> _roomToWalls = <String, Set<String>>{};
  final Map<String, Set<String>> _wallToRooms = <String, Set<String>>{};
  final Set<String> _duplicateWallIds = <String>{};

  SharedWallRegistry({
    Iterable<Wall> walls = const [],
    Iterable<Room> rooms = const [],
  }) {
    for (final wall in walls) {
      addWall(wall);
    }
    for (final room in rooms) {
      registerRoom(room);
    }
  }

  /// Returns false (and records the ID) if a duplicate wall ID is injected.
  bool addWall(Wall wall) {
    if (wall.id.isEmpty) {
      _duplicateWallIds.add('<empty>');
      return false;
    }
    if (_walls.containsKey(wall.id)) {
      _duplicateWallIds.add(wall.id);
      return false;
    }
    _walls[wall.id] = wall;
    _wallToRooms.putIfAbsent(wall.id, () => <String>{});
    return true;
  }

  void registerRoom(Room room) {
    _roomToWalls.putIfAbsent(room.id, () => <String>{});
    for (final wallId in room.wallIds) {
      link(room.id, wallId);
    }
  }

  /// Links a room to an existing wall. Shared walls accumulate multiple links.
  bool link(String roomId, String wallId) {
    if (!_walls.containsKey(wallId)) return false;
    _roomToWalls.putIfAbsent(roomId, () => <String>{}).add(wallId);
    _wallToRooms.putIfAbsent(wallId, () => <String>{}).add(roomId);
    return true;
  }

  void unlink(String roomId, String wallId) {
    _roomToWalls[roomId]?.remove(wallId);
    _wallToRooms[wallId]?.remove(roomId);
  }

  /// Removes a room's links only — never deletes the physical wall.
  void removeRoom(String roomId) {
    final wallIds = _roomToWalls.remove(roomId) ?? const <String>{};
    for (final wallId in wallIds) {
      _wallToRooms[wallId]?.remove(roomId);
    }
  }

  /// Updates the one physical wall record. All linked rooms see the change.
  bool updateWall(Wall wall) {
    if (!_walls.containsKey(wall.id)) return false;
    _walls[wall.id] = wall;
    return true;
  }

  bool addOpening(Opening opening) {
    final wall = _walls[opening.wallId];
    if (wall == null) return false;
    return updateWall(wall.copyWith(openings: [...wall.openings, opening]));
  }

  Wall? wall(String id) => _walls[id];

  List<Wall> get walls => List.unmodifiable(_walls.values);

  List<String> duplicateWallIds() => List.unmodifiable(_duplicateWallIds);

  List<Wall> wallsForRoom(String roomId) =>
      (_roomToWalls[roomId] ?? const <String>{})
          .map((id) => _walls[id])
          .whereType<Wall>()
          .toList(growable: false);

  List<String> roomsForWall(String wallId) =>
      List.unmodifiable(_wallToRooms[wallId] ?? const <String>{});

  /// Deduplicates by wall ID. This is the only path to building-level totals.
  List<Wall> deduplicatedWalls() {
    final unique = <String, Wall>{};
    for (final wall in _walls.values) {
      unique.putIfAbsent(wall.id, () => wall);
    }
    return List.unmodifiable(unique.values);
  }

  List<ValidationIssue> validate() {
    final issues = <ValidationIssue>[];
    for (final id in _duplicateWallIds) {
      issues.add(
        ValidationIssue(
          code: 'duplicateWallId',
          field: 'wall.id',
          message: 'Duplicate wall ID detected: $id.',
        ),
      );
    }
    for (final wall in _walls.values) {
      if (wall.lengthM <= 0) {
        issues.add(
          ValidationIssue(
            code: 'zeroLengthWall',
            field: 'wall.${wall.id}.length',
            message: 'Wall ${wall.name} has zero length.',
          ),
        );
      }
      if (wall.thicknessM <= 0 || wall.heightM <= 0) {
        issues.add(
          ValidationIssue(
            code: 'invalidWallDimensions',
            field: 'wall.${wall.id}.dimensions',
            message: 'Wall ${wall.name} needs positive thickness and height.',
          ),
        );
      }
      for (final opening in wall.openings) {
        if (opening.widthM > wall.lengthM) {
          issues.add(
            ValidationIssue(
              code: 'openingWiderThanWall',
              field: 'opening.${opening.id}',
              message: 'Opening is wider than wall ${wall.name}.',
            ),
          );
        }
        if (opening.offsetM < 0 ||
            opening.offsetM + opening.widthM > wall.lengthM + 1e-9) {
          issues.add(
            ValidationIssue(
              code: 'openingOutsideWall',
              field: 'opening.${opening.id}',
              message: 'Opening is outside wall ${wall.name}.',
            ),
          );
        }
      }
      if ((_wallToRooms[wall.id] ?? const <String>{}).isEmpty) {
        issues.add(
          ValidationIssue.warning(
            'orphanWall',
            'wall.${wall.id}',
            'Wall ${wall.name} is not linked to any room.',
          ),
        );
      }
    }
    return issues;
  }

  RoomTakeoff roomTakeoff(Room room) {
    final linked = wallsForRoom(room.id);
    return RoomTakeoff(
      roomId: room.id,
      name: room.name,
      floorAreaM2: room.areaM2,
      perimeterM: room.perimeterM,
      linkedWallLengthM: linked.fold(0.0, (sum, wall) => sum + wall.lengthM),
      netWallAreaM2: linked.fold(0.0, (sum, wall) => sum + wall.netAreaM2),
    );
  }

  /// Building-level takeoff. Shared walls are counted exactly once.
  BuildingTakeoff takeoff(Building building) {
    final unique = <String, Wall>{};
    final duplicateIds = <String>{..._duplicateWallIds};
    for (final candidate in building.allWalls) {
      if (unique.containsKey(candidate.id)) {
        duplicateIds.add(candidate.id);
        continue;
      }
      final canonical = _walls[candidate.id] ?? candidate;
      unique[candidate.id] = canonical;
    }

    final wallTakeoffs = <WallTakeoff>[];
    var totalLength = 0.0;
    var totalNetArea = 0.0;
    var totalBrick = 0.0;
    var totalPlaster = 0.0;
    for (final wall in unique.values) {
      final faces = math.max(
        1,
        (_wallToRooms[wall.id] ?? const <String>{}).length,
      );
      final item = WallTakeoff(
        wallId: wall.id,
        name: wall.name,
        lengthM: wall.lengthM,
        thicknessM: wall.thicknessM,
        grossAreaM2: wall.grossAreaM2,
        openingAreaM2: wall.openingAreaM2,
        netAreaM2: wall.netAreaM2,
        brickworkVolumeM3: wall.netAreaM2 * wall.thicknessM,
        exposedFaces: faces,
      );
      wallTakeoffs.add(item);
      totalLength += item.lengthM;
      totalNetArea += item.netAreaM2;
      totalBrick += item.brickworkVolumeM3;
      totalPlaster += item.plasterAreaM2;
    }

    return BuildingTakeoff(
      uniqueWallCount: unique.length,
      duplicateWallIds: List.unmodifiable(duplicateIds),
      totalWallLengthM: totalLength,
      totalNetWallAreaM2: totalNetArea,
      totalBrickworkVolumeM3: totalBrick,
      totalPlasterAreaM2: totalPlaster,
      walls: wallTakeoffs,
      rooms: building.allRooms.map(roomTakeoff).toList(growable: false),
      issues: validate(),
    );
  }
}
