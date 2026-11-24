import 'package:engine/engine.dart';
import 'package:test/test.dart';

Wall wall(String id, double x, String name, {double thickness = 0.2}) => Wall(
  id: id,
  floorId: 'f1',
  name: name,
  start: PlanPoint(x, 0),
  end: PlanPoint(x, 3),
  thicknessM: thickness,
  heightM: 3,
  type: WallType.interior,
);

Room room(String id, double x1, double x2, Set<String> wallIds) => Room(
  id: id,
  floorId: 'f1',
  name: 'Room $id',
  polygon: [
    PlanPoint(x1, 0),
    PlanPoint(x2, 0),
    PlanPoint(x2, 3),
    PlanPoint(x1, 3),
  ],
  wallIds: wallIds,
);

void main() {
  group('room geometry', () {
    test('shoelace area and perimeter', () {
      final r = room('a', 0, 4, const {'w_shared'});
      expect(r.areaM2, closeTo(12, 1e-9));
      expect(r.perimeterM, closeTo(14, 1e-9));
    });
  });

  group('shared wall invariants', () {
    test('two rooms sharing one wall count it once', () {
      final registry = SharedWallRegistry(
        walls: [
          wall('w_shared', 4, 'Shared'),
          wall('w_left', 0, 'Left'),
          wall('w_right', 8, 'Right'),
        ],
        rooms: [
          room('a', 0, 4, const {'w_left', 'w_shared'}),
          room('b', 4, 8, const {'w_shared', 'w_right'}),
        ],
      );
      final building = Building(
        id: 'b1',
        projectId: 'p1',
        name: 'Test',
        floors: [
          Floor(
            id: 'f1',
            buildingId: 'b1',
            name: 'Ground',
            level: 0,
            heightM: 3,
            rooms: [
              room('a', 0, 4, const {'w_left', 'w_shared'}),
              room('b', 4, 8, const {'w_shared', 'w_right'}),
            ],
            walls: [
              wall('w_shared', 4, 'Shared'),
              wall('w_left', 0, 'Left'),
              wall('w_right', 8, 'Right'),
            ],
          ),
        ],
      );

      expect(registry.roomsForWall('w_shared'), unorderedEquals(['a', 'b']));
      final takeoff = registry.takeoff(building);
      expect(takeoff.uniqueWallCount, 3);
      // 3 walls × 9 m² × 0.2 m = 5.4 m³ (shared wall counted once).
      expect(takeoff.totalBrickworkVolumeM3, closeTo(5.4, 1e-9));
      expect(takeoff.duplicateWallIds, isEmpty);
    });

    test('editing a shared wall updates all connected rooms', () {
      final registry = SharedWallRegistry(
        walls: [wall('w_shared', 4, 'Shared')],
        rooms: [
          room('a', 0, 4, const {'w_shared'}),
          room('b', 4, 8, const {'w_shared'}),
        ],
      );
      final updated = wall('w_shared', 4, 'Shared', thickness: 0.3);
      expect(registry.updateWall(updated), isTrue);

      for (final roomId in ['a', 'b']) {
        final walls = registry.wallsForRoom(roomId);
        expect(walls, hasLength(1));
        expect(walls.single.thicknessM, 0.3);
      }

      final takeoff = registry.takeoff(
        Building(
          id: 'b1',
          projectId: 'p1',
          name: 'Test',
          floors: [
            Floor(
              id: 'f1',
              buildingId: 'b1',
              name: 'Ground',
              level: 0,
              heightM: 3,
              walls: [updated],
            ),
          ],
        ),
      );
      expect(takeoff.totalBrickworkVolumeM3, closeTo(2.7, 1e-9));
      expect(takeoff.rooms, isEmpty);
    });

    test('deleting one room keeps the shared wall for the other', () {
      final registry = SharedWallRegistry(
        walls: [wall('w_shared', 4, 'Shared')],
        rooms: [
          room('a', 0, 4, const {'w_shared'}),
          room('b', 4, 8, const {'w_shared'}),
        ],
      );
      registry.removeRoom('a');
      expect(registry.roomsForWall('w_shared'), ['b']);
      expect(registry.wall('w_shared'), isNotNull);
      expect(registry.wallsForRoom('a'), isEmpty);
      expect(registry.wallsForRoom('b'), hasLength(1));
    });

    test('duplicate wall ID is rejected and reported', () {
      final registry = SharedWallRegistry(walls: [wall('w1', 1, 'First')]);
      expect(registry.addWall(wall('w1', 2, 'Duplicate')), isFalse);
      expect(registry.duplicateWallIds(), contains('w1'));
      expect(
        registry.validate().map((issue) => issue.code),
        contains('duplicateWallId'),
      );
      expect(registry.walls, hasLength(1));
    });

    test('opening on shared wall is deducted once', () {
      final shared = wall('w_shared', 4, 'Shared').copyWith(
        openings: [
          Opening(
            id: 'd1',
            wallId: 'w_shared',
            kind: OpeningKind.door,
            subtype: 'room',
            offsetM: 1,
            widthM: 1,
            heightM: 2,
          ),
        ],
      );
      final registry = SharedWallRegistry(
        walls: [shared, wall('w_left', 0, 'Left'), wall('w_right', 8, 'Right')],
        rooms: [
          room('a', 0, 4, const {'w_shared'}),
          room('b', 4, 8, const {'w_shared'}),
        ],
      );
      final takeoff = registry.takeoff(
        Building(
          id: 'b1',
          projectId: 'p1',
          name: 'Test',
          floors: [
            Floor(
              id: 'f1',
              buildingId: 'b1',
              name: 'Ground',
              level: 0,
              heightM: 3,
              walls: [
                shared,
                wall('w_left', 0, 'Left'),
                wall('w_right', 8, 'Right'),
              ],
              rooms: [
                room('a', 0, 4, const {'w_shared'}),
                room('b', 4, 8, const {'w_shared'}),
              ],
            ),
          ],
        ),
      );
      expect(shared.netAreaM2, closeTo(7, 1e-9));
      // 7×0.2 + 9×0.2 + 9×0.2 = 5.0 m³
      expect(takeoff.totalBrickworkVolumeM3, closeTo(5.0, 1e-9));
      // Shared wall has 2 exposed faces, others 1 each: 14 + 9 + 9 = 32 m²
      expect(takeoff.totalPlasterAreaM2, closeTo(32, 1e-9));
    });

    test('three-room chain with two shared walls has no duplication', () {
      final w1 = wall('w1', 4, 'A-B');
      final w2 = wall('w2', 8, 'B-C');
      final registry = SharedWallRegistry(
        walls: [w1, w2],
        rooms: [
          room('a', 0, 4, const {'w1'}),
          room('b', 4, 8, const {'w1', 'w2'}),
          room('c', 8, 12, const {'w2'}),
        ],
      );
      final takeoff = registry.takeoff(
        Building(
          id: 'b1',
          projectId: 'p1',
          name: 'Test',
          floors: [
            Floor(
              id: 'f1',
              buildingId: 'b1',
              name: 'Ground',
              level: 0,
              heightM: 3,
              walls: [w1, w2],
            ),
          ],
        ),
      );
      expect(takeoff.uniqueWallCount, 2);
      expect(takeoff.totalBrickworkVolumeM3, closeTo(3.6, 1e-9));
      expect(registry.roomsForWall('w1'), unorderedEquals(['a', 'b']));
      expect(registry.roomsForWall('w2'), unorderedEquals(['b', 'c']));
    });
  });

  group('geometry validation', () {
    test('opening outside wall is flagged', () {
      final bad = wall('w1', 0, 'Wall').copyWith(
        openings: [
          Opening(
            id: 'o1',
            wallId: 'w1',
            kind: OpeningKind.window,
            offsetM: 2.8,
            widthM: 1,
            heightM: 1,
          ),
        ],
      );
      final registry = SharedWallRegistry(walls: [bad]);
      expect(
        registry.validate().map((issue) => issue.code),
        contains('openingOutsideWall'),
      );
    });

    test('orphan wall produces a warning', () {
      final registry = SharedWallRegistry(walls: [wall('w1', 0, 'Wall')]);
      final issues = registry.validate();
      expect(issues.any((issue) => issue.code == 'orphanWall'), isTrue);
    });
  });
}
