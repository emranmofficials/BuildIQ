import 'package:engine/engine.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 11, 23, 12);

  Project project(String id) => Project(
    id: id,
    name: 'House $id',
    clientName: 'Client',
    budgetMinor: 50000000,
    status: ProjectStatus.active,
    createdAt: now,
    updatedAt: now,
  );

  group('offline repository', () {
    test('CRUD works without any platform dependency', () async {
      final repo = InMemoryRepository<Project>();
      await repo.put(project('p1'));
      expect((await repo.get('p1'))!.name, 'House p1');
      expect(await repo.getAll(), hasLength(1));
      await repo.put(project('p1').copyWith(name: 'Renamed'));
      expect((await repo.get('p1'))!.name, 'Renamed');
      await repo.delete('p1');
      expect(await repo.get('p1'), isNull);
    });
  });

  group('sync queue safety', () {
    PendingSyncOp op(String id) => PendingSyncOp(
      id: id,
      entityType: 'project',
      entityId: 'p1',
      operation: SyncOperation.update,
      payload: {'name': 'House p1'},
      createdAt: now,
    );

    test('failure keeps the operation and records attempts', () {
      final queue = SyncQueue();
      queue.enqueue(op('op1'));
      queue.markInFlight('op1');
      queue.recordFailure(
        'op1',
        'server timeout',
        now.add(const Duration(minutes: 1)),
      );
      expect(queue.all, hasLength(1));
      expect(queue.all.single.attempts, 1);
      expect(queue.all.single.status, PendingSyncStatus.failed);
      expect(queue.all.single.lastError, 'server timeout');
    });

    test('retry respects backoff time', () {
      final queue = SyncQueue();
      queue.enqueue(op('op1'));
      expect(queue.due(now), hasLength(1));
      queue.recordFailure(
        'op1',
        'offline',
        now.add(const Duration(minutes: 5)),
      );
      expect(queue.due(now), isEmpty);
      queue.requeue('op1');
      expect(queue.pending, hasLength(1));
    });

    test('only acknowledgement removes pending data', () {
      final queue = SyncQueue();
      queue.enqueue(op('op1'));
      queue.markInFlight('op1');
      expect(queue.all, hasLength(1));
      queue.acknowledge('op1');
      expect(queue.all, isEmpty);
    });
  });

  group('BOQ generation', () {
    const generator = BoqGenerator();

    test('concrete output becomes traceable lines with totals', () {
      final concrete = const ConcreteCalculator().calculate(
        ConcreteInput.rectangular(
          element: ConcreteElement.slab,
          lengthM: 2,
          widthM: 2,
          thicknessM: 0.15,
          rates: const MaterialRates(
            cementPerBagMinor: 5000,
            sandPerM3Minor: 600,
            aggregatePerM3Minor: 800,
          ),
        ),
      );
      final lines = generator.fromConcrete(
        projectId: 'p1',
        sourceId: 'calc1',
        output: concrete.output!,
        idPrefix: 'slab',
        rates: const MaterialRates(
          cementPerBagMinor: 5000,
          sandPerM3Minor: 600,
          aggregatePerM3Minor: 800,
        ),
      );
      final summary = generator.summarize(lines);
      expect(summary.lines, hasLength(3));
      expect(summary.totalMinor, greaterThan(0));
      expect(summary.byCategoryMinor['concrete'], summary.totalMinor);
      expect(summary.lines.first.sourceType, 'calculation');
    });

    test('floor plan takeoff uses deduplicated walls', () {
      final shared = Wall(
        id: 'w1',
        floorId: 'f1',
        name: 'Shared',
        start: const PlanPoint(0, 0),
        end: const PlanPoint(4, 0),
        thicknessM: 0.2,
        heightM: 3,
      );
      final registry = SharedWallRegistry(walls: [shared]);
      final takeoff = registry.takeoff(
        Building(
          id: 'b1',
          projectId: 'p1',
          name: 'B',
          floors: [
            Floor(
              id: 'f1',
              buildingId: 'b1',
              name: 'F',
              level: 0,
              heightM: 3,
              walls: [shared],
            ),
          ],
        ),
      );
      final lines = generator.fromFloorPlan(
        projectId: 'p1',
        sourceId: 'fp1',
        takeoff: takeoff,
        brickworkRatePerM3Minor: 100000,
        plasterRatePerM2Minor: 5000,
      );
      expect(lines, hasLength(2));
      expect(lines.first.quantity, closeTo(2.4, 1e-9));
      expect(lines.first.amountMinor, 240000);
      // Orphan-wall is a warning, not an error, so BOQ is still generated.
    });
  });
}
