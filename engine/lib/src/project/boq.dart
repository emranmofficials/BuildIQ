import '../calculators/concrete.dart';
import '../core/result.dart';
import '../floorplan/shared_wall.dart';
import 'models.dart';

/// Turns verified calculation outputs into traceable BOQ lines.
class BoqGenerator {
  const BoqGenerator();

  BoqSummary summarize(Iterable<BoqLine> lines) {
    final list = lines.toList(growable: false);
    final byCategory = <String, int>{};
    var total = 0;
    for (final line in list) {
      total += line.amountMinor;
      byCategory[line.category] =
          (byCategory[line.category] ?? 0) + line.amountMinor;
    }
    return BoqSummary(
      lines: list,
      totalMinor: total,
      byCategoryMinor: Map.unmodifiable(byCategory),
    );
  }

  List<BoqLine> fromConcrete({
    required String projectId,
    required String sourceId,
    required ConcreteOutput output,
    required String idPrefix,
    MaterialRates rates = const MaterialRates(),
  }) {
    return [
      BoqLine(
        id: '${idPrefix}_cement',
        projectId: projectId,
        description: 'Cement (${output.cementBags} bags)',
        quantity: output.cementBags.toDouble(),
        unit: 'bags',
        rateMinor: rates.cementPerBagMinor,
        category: 'concrete',
        sourceType: 'calculation',
        sourceId: sourceId,
      ),
      BoqLine(
        id: '${idPrefix}_sand',
        projectId: projectId,
        description: 'Sand',
        quantity: output.sandM3,
        unit: 'm³',
        rateMinor: rates.sandPerM3Minor,
        category: 'concrete',
        sourceType: 'calculation',
        sourceId: sourceId,
      ),
      BoqLine(
        id: '${idPrefix}_aggregate',
        projectId: projectId,
        description: 'Aggregate',
        quantity: output.aggregateM3,
        unit: 'm³',
        rateMinor: rates.aggregatePerM3Minor,
        category: 'concrete',
        sourceType: 'calculation',
        sourceId: sourceId,
      ),
    ];
  }

  List<BoqLine> fromFloorPlan({
    required String projectId,
    required String sourceId,
    required BuildingTakeoff takeoff,
    int brickworkRatePerM3Minor = 0,
    int plasterRatePerM2Minor = 0,
  }) {
    if (takeoff.issues.any((issue) => issue.severity == IssueSeverity.error)) {
      return [];
    }
    return [
      BoqLine(
        id: '${sourceId}_brickwork',
        projectId: projectId,
        description: 'Brickwork (shared walls counted once)',
        quantity: takeoff.totalBrickworkVolumeM3,
        unit: 'm³',
        rateMinor: brickworkRatePerM3Minor,
        category: 'masonry',
        sourceType: 'floorplan',
        sourceId: sourceId,
        notes: '${takeoff.uniqueWallCount} unique walls',
      ),
      BoqLine(
        id: '${sourceId}_plaster',
        projectId: projectId,
        description: 'Wall plaster (exposed faces)',
        quantity: takeoff.totalPlasterAreaM2,
        unit: 'm²',
        rateMinor: plasterRatePerM2Minor,
        category: 'finishing',
        sourceType: 'floorplan',
        sourceId: sourceId,
      ),
    ];
  }
}
