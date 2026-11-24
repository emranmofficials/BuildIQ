import 'dart:convert';

import 'package:engine/engine.dart';
import 'package:test/test.dart';

Building sampleBuilding() {
  final opening = Opening(
    id: 'o1',
    wallId: 'w_shared',
    kind: OpeningKind.window,
    offsetM: 0.5,
    widthM: 1.2,
    heightM: 1.5,
    sillM: 0.9,
    status: VerificationStatus.userEdited,
  );
  final shared = Wall(
    id: 'w_shared',
    floorId: 'f1',
    name: 'Shared wall',
    start: const PlanPoint(4, 0),
    end: const PlanPoint(4, 4),
    thicknessM: 0.2,
    heightM: 3,
    type: WallType.interior,
    isShared: true,
    openings: [opening],
  );
  final left = Wall(
    id: 'w_left',
    floorId: 'f1',
    name: 'Left exterior',
    start: const PlanPoint(0, 0),
    end: const PlanPoint(0, 4),
    thicknessM: 0.25,
    heightM: 3,
    type: WallType.exterior,
  );
  return Building(
    id: 'b1',
    projectId: 'p1',
    name: 'Sample building',
    floors: [
      Floor(
        id: 'f1',
        buildingId: 'b1',
        name: 'Ground floor',
        level: 0,
        heightM: 3,
        walls: [shared, left],
        rooms: [
          Room(
            id: 'r1',
            floorId: 'f1',
            name: 'Room A',
            polygon: const [
              PlanPoint(0, 0),
              PlanPoint(4, 0),
              PlanPoint(4, 4),
              PlanPoint(0, 4),
            ],
            wallIds: const {'w_shared', 'w_left'},
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('floor plan JSON round-trip preserves walls, openings and rooms', () {
    final original = sampleBuilding();
    final decoded = jsonDecode(jsonEncode(original.toJson()));
    final restored = Building.fromJson(decoded as Map<String, dynamic>);

    expect(restored.id, original.id);
    expect(restored.floors, hasLength(1));
    final floor = restored.floors.single;
    expect(floor.walls, hasLength(2));
    expect(floor.rooms, hasLength(1));

    final shared = floor.walls.firstWhere((w) => w.id == 'w_shared');
    expect(shared.isShared, isTrue);
    expect(shared.thicknessM, 0.2);
    expect(shared.openings, hasLength(1));
    expect(shared.openings.single.kind, OpeningKind.window);
    expect(shared.openings.single.status, VerificationStatus.userEdited);
    expect(shared.openings.single.sillM, 0.9);

    expect(floor.rooms.single.wallIds, {'w_shared', 'w_left'});
    expect(floor.rooms.single.areaM2, closeTo(16, 1e-9));
  });

  test('shared-wall takeoff after round-trip still deduplicates', () {
    final restored = Building.fromJson(
      jsonDecode(jsonEncode(sampleBuilding().toJson())) as Map<String, dynamic>,
    );
    final takeoff = SharedWallRegistry(
      walls: restored.floors.first.walls,
      rooms: restored.floors.first.rooms,
    ).takeoff(restored);
    expect(takeoff.uniqueWallCount, 2);
    expect(takeoff.duplicateWallIds, isEmpty);
  });
}
