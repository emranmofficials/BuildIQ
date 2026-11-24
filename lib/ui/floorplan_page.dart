import 'dart:math' as math;

import 'package:engine/engine.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/app_state.dart';
import '../core/l10n.dart';
import '../core/logger.dart';
import 'widgets/common.dart';

class FloorPlanPage extends StatefulWidget {
  const FloorPlanPage({super.key});

  @override
  State<FloorPlanPage> createState() => _FloorPlanPageState();
}

class _FloorPlanPageState extends State<FloorPlanPage> {
  static const _uuid = Uuid();

  late SharedWallRegistry _registry;
  final List<Room> _rooms = [];
  final List<Wall> _walls = [];
  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];
  String? _selectedWallId;
  final double _scale = 40; // pixels per metre

  @override
  void initState() {
    super.initState();
    _registry = SharedWallRegistry();
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await context.read<AppState>().loadFloorPlan(
        'building_demo',
      );
      final floor = (saved == null || saved.floors.isEmpty)
          ? null
          : saved.floors.first;
      if (!mounted) return;
      setState(() {
        if (floor == null) {
          _seedDemo();
        } else {
          _rooms.addAll(floor.rooms);
          _walls.addAll(floor.walls);
          _registry = SharedWallRegistry(walls: _walls, rooms: _rooms);
        }
      });
    } catch (error) {
      AppLogger.warn('Could not load floor plan: $error');
      if (mounted) setState(_seedDemo);
    }
  }

  Future<void> _save() async {
    try {
      await context.read<AppState>().saveFloorPlan(_currentBuilding());
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.t('saved'))));
      }
    } catch (error) {
      AppLogger.error('Floor plan save failed', error);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $error')));
      }
    }
  }

  void _seedDemo() {
    const floorId = 'floor_demo';
    final left = _makeWall(
      'demo_left',
      0,
      0,
      0,
      4,
      'Left exterior',
      WallType.exterior,
    );
    final shared = _makeWall(
      'demo_shared',
      4,
      0,
      4,
      4,
      'Shared wall',
      WallType.interior,
    );
    final right = _makeWall(
      'demo_right',
      8,
      0,
      8,
      4,
      'Right exterior',
      WallType.exterior,
    );
    final bottom = _makeWall(
      'demo_bottom',
      0,
      4,
      8,
      4,
      'Bottom exterior',
      WallType.exterior,
    );
    final top = _makeWall(
      'demo_top',
      0,
      0,
      8,
      0,
      'Top exterior',
      WallType.exterior,
    );

    final roomA = Room(
      id: 'room_a',
      floorId: floorId,
      name: 'Room A',
      polygon: const [
        PlanPoint(0, 0),
        PlanPoint(4, 0),
        PlanPoint(4, 4),
        PlanPoint(0, 4),
      ],
      wallIds: {'demo_left', 'demo_shared', 'demo_bottom', 'demo_top'},
    );
    final roomB = Room(
      id: 'room_b',
      floorId: floorId,
      name: 'Room B',
      polygon: const [
        PlanPoint(4, 0),
        PlanPoint(8, 0),
        PlanPoint(8, 4),
        PlanPoint(4, 4),
      ],
      wallIds: {'demo_shared', 'demo_right', 'demo_bottom', 'demo_top'},
    );

    _walls.addAll([left, shared, right, bottom, top]);
    _rooms.addAll([roomA, roomB]);
    for (final wall in _walls) {
      _registry.addWall(wall);
    }
    for (final room in _rooms) {
      _registry.registerRoom(room);
    }
  }

  Wall _makeWall(
    String id,
    double x1,
    double y1,
    double x2,
    double y2,
    String name,
    WallType type,
  ) => Wall(
    id: id,
    floorId: 'floor_demo',
    name: name,
    start: PlanPoint(x1, y1),
    end: PlanPoint(x2, y2),
    thicknessM: 0.2,
    heightM: 3,
    type: type,
    isShared: id == 'demo_shared',
  );

  Building _currentBuilding() => Building(
    id: 'building_demo',
    projectId: 'project_demo',
    name: 'Demo Building',
    floors: [
      Floor(
        id: 'floor_demo',
        buildingId: 'building_demo',
        name: 'Ground floor',
        level: 0,
        heightM: 3,
        rooms: List.unmodifiable(_rooms),
        walls: List.unmodifiable(_walls),
      ),
    ],
  );

  void _pushUndo() {
    _undo.add(
      _Snapshot(walls: List<Wall>.from(_walls), rooms: List<Room>.from(_rooms)),
    );
    _redo.clear();
  }

  void _restore(_Snapshot snapshot) {
    setState(() {
      _walls
        ..clear()
        ..addAll(snapshot.walls);
      _rooms
        ..clear()
        ..addAll(snapshot.rooms);
      _registry = SharedWallRegistry(walls: _walls, rooms: _rooms);
      _selectedWallId = null;
    });
  }

  void _undoAction() {
    if (_undo.isEmpty) return;
    final snapshot = _undo.removeLast();
    _redo.add(
      _Snapshot(walls: List<Wall>.from(_walls), rooms: List<Room>.from(_rooms)),
    );
    _restore(snapshot);
  }

  void _redoAction() {
    if (_redo.isEmpty) return;
    final snapshot = _redo.removeLast();
    _undo.add(
      _Snapshot(walls: List<Wall>.from(_walls), rooms: List<Room>.from(_rooms)),
    );
    _restore(snapshot);
  }

  void _addRoom() {
    _pushUndo();
    final index = _rooms.length + 1;
    final room = Room(
      id: _uuid.v4(),
      floorId: 'floor_demo',
      name: 'Room $index',
      polygon: const [
        PlanPoint(0, 0),
        PlanPoint(3, 0),
        PlanPoint(3, 3),
        PlanPoint(0, 3),
      ],
      wallIds: const {},
    );
    setState(() {
      _rooms.add(room);
      _registry.registerRoom(room);
    });
  }

  void _addWall() {
    _pushUndo();
    final index = _walls.length + 1;
    final wall = Wall(
      id: _uuid.v4(),
      floorId: 'floor_demo',
      name: 'Wall $index',
      start: const PlanPoint(1, 1),
      end: const PlanPoint(4, 1),
      thicknessM: 0.2,
      heightM: 3,
      type: WallType.partition,
    );
    setState(() {
      _walls.add(wall);
      _registry.addWall(wall);
      _selectedWallId = wall.id;
    });
  }

  void _addOpening(OpeningKind kind) {
    final id = _selectedWallId;
    if (id == null) return;
    final wall = _registry.wall(id);
    if (wall == null) return;
    _pushUndo();
    final opening = Opening(
      id: _uuid.v4(),
      wallId: id,
      kind: kind,
      subtype: 'standard',
      offsetM: 0.5,
      widthM: kind == OpeningKind.door ? 0.9 : 1.2,
      heightM: kind == OpeningKind.door ? 2.1 : 1.2,
      sillM: kind == OpeningKind.door ? 0 : 0.9,
      status: VerificationStatus.userEdited,
    );
    setState(() {
      _registry.addOpening(opening);
      final updated = _registry.wall(id)!;
      final idx = _walls.indexWhere((w) => w.id == id);
      if (idx >= 0) _walls[idx] = updated;
    });
  }

  void _updateSelectedWall({double? thickness, double? height}) {
    final id = _selectedWallId;
    if (id == null) return;
    final wall = _registry.wall(id);
    if (wall == null) return;
    _pushUndo();
    final updated = wall.copyWith(
      thicknessM: thickness ?? wall.thicknessM,
      heightM: height ?? wall.heightM,
      status: VerificationStatus.userEdited,
    );
    setState(() {
      _registry.updateWall(updated);
      final idx = _walls.indexWhere((w) => w.id == id);
      if (idx >= 0) _walls[idx] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final takeoff = _registry.takeoff(_currentBuilding());
    final selected = _selectedWallId == null
        ? null
        : _registry.wall(_selectedWallId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('floorPlan')),
        actions: [
          IconButton(
            tooltip: context.t('save'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
          ),
          IconButton(
            tooltip: context.t('undo'),
            onPressed: _undo.isEmpty ? null : _undoAction,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: context.t('redo'),
            onPressed: _redo.isEmpty ? null : _redoAction,
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: _addRoom,
                  child: Text(context.t('addRoom')),
                ),
                FilledButton.tonal(
                  onPressed: _addWall,
                  child: Text(context.t('addWall')),
                ),
                OutlinedButton(
                  onPressed: selected == null
                      ? null
                      : () => _addOpening(OpeningKind.door),
                  child: Text(context.t('addDoor')),
                ),
                OutlinedButton(
                  onPressed: selected == null
                      ? null
                      : () => _addOpening(OpeningKind.window),
                  child: Text(context.t('addWindow')),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                '${context.t('uniqueWalls')}: ${takeoff.uniqueWallCount} · '
                '${takeoff.totalBrickworkVolumeM3.toStringAsFixed(2)} m³ · '
                '${context.t('sharedWallNote')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: _PlanCanvas(
              rooms: _rooms,
              walls: _walls,
              scale: _scale,
              selectedWallId: _selectedWallId,
              onWallTap: (id) => setState(() => _selectedWallId = id),
            ),
          ),
          if (selected != null)
            _WallEditor(
              wall: selected,
              roomsForWall: _registry.roomsForWall(selected.id),
              onThicknessChanged: (value) =>
                  _updateSelectedWall(thickness: value),
              onHeightChanged: (value) => _updateSelectedWall(height: value),
            ),
          _TakeoffSummary(takeoff: takeoff),
        ],
      ),
    );
  }
}

class _Snapshot {
  final List<Wall> walls;
  final List<Room> rooms;
  const _Snapshot({required this.walls, required this.rooms});
}

class _PlanCanvas extends StatelessWidget {
  final List<Room> rooms;
  final List<Wall> walls;
  final double scale;
  final String? selectedWallId;
  final ValueChanged<String> onWallTap;

  const _PlanCanvas({
    required this.rooms,
    required this.walls,
    required this.scale,
    required this.selectedWallId,
    required this.onWallTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapUp: (details) {
            final tap = details.localPosition;
            double bestDistance = 22;
            String? bestId;
            for (final wall in walls) {
              final a = Offset(
                wall.start.x * scale + 40,
                wall.start.y * scale + 40,
              );
              final b = Offset(
                wall.end.x * scale + 40,
                wall.end.y * scale + 40,
              );
              final distance = _distanceToSegment(tap, a, b);
              if (distance < bestDistance) {
                bestDistance = distance;
                bestId = wall.id;
              }
            }
            if (bestId != null) onWallTap(bestId);
          },
          child: CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _PlanPainter(
              rooms: rooms,
              walls: walls,
              scale: scale,
              selectedWallId: selectedWallId,
              colorScheme: Theme.of(context).colorScheme,
            ),
          ),
        );
      },
    );
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSq = dx * dx + dy * dy;
    if (lengthSq == 0) return (p - a).distance;
    var t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSq;
    t = t.clamp(0.0, 1.0);
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}

class _PlanPainter extends CustomPainter {
  final List<Room> rooms;
  final List<Wall> walls;
  final double scale;
  final String? selectedWallId;
  final ColorScheme colorScheme;

  _PlanPainter({
    required this.rooms,
    required this.walls,
    required this.scale,
    required this.selectedWallId,
    required this.colorScheme,
  });

  Offset _point(PlanPoint p) => Offset(p.x * scale + 40, p.y * scale + 40);

  @override
  void paint(Canvas canvas, Size size) {
    final roomPaint = Paint()
      ..color = colorScheme.primaryContainer.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    for (final room in rooms) {
      if (room.polygon.length < 3) continue;
      final path = Path()
        ..moveTo(_point(room.polygon.first).dx, _point(room.polygon.first).dy);
      for (final point in room.polygon.skip(1)) {
        path.lineTo(_point(point).dx, _point(point).dy);
      }
      path.close();
      canvas.drawPath(path, roomPaint);
      final center =
          room.polygon.fold<Offset>(Offset.zero, (sum, p) => sum + _point(p)) /
          room.polygon.length.toDouble();
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${room.name}\n${room.areaM2.toStringAsFixed(1)} m²',
          style: TextStyle(color: colorScheme.onPrimaryContainer, fontSize: 12),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      textPainter.paint(
        canvas,
        center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    for (final wall in walls) {
      final isSelected = wall.id == selectedWallId;
      final paint = Paint()
        ..color = isSelected
            ? colorScheme.error
            : wall.isShared
            ? colorScheme.tertiary
            : colorScheme.onSurface
        ..strokeWidth = isSelected ? 10 : math.max(4, wall.thicknessM * scale)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(_point(wall.start), _point(wall.end), paint);

      for (final opening in wall.openings) {
        final direction = (wall.end - wall.start);
        final length = math.sqrt(
          direction.x * direction.x + direction.y * direction.y,
        );
        if (length == 0) continue;
        final ux = direction.x / length;
        final uy = direction.y / length;
        final start = _point(
          PlanPoint(
            wall.start.x + ux * opening.offsetM,
            wall.start.y + uy * opening.offsetM,
          ),
        );
        final end = _point(
          PlanPoint(
            wall.start.x + ux * (opening.offsetM + opening.widthM),
            wall.start.y + uy * (opening.offsetM + opening.widthM),
          ),
        );
        final openingPaint = Paint()
          ..color = opening.kind == OpeningKind.door
              ? colorScheme.primary
              : colorScheme.secondary
          ..strokeWidth = 4;
        canvas.drawLine(start, end, openingPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlanPainter oldDelegate) =>
      oldDelegate.rooms != rooms ||
      oldDelegate.walls != walls ||
      oldDelegate.selectedWallId != selectedWallId;
}

class _WallEditor extends StatefulWidget {
  final Wall wall;
  final List<String> roomsForWall;
  final ValueChanged<double> onThicknessChanged;
  final ValueChanged<double> onHeightChanged;

  const _WallEditor({
    required this.wall,
    required this.roomsForWall,
    required this.onThicknessChanged,
    required this.onHeightChanged,
  });

  @override
  State<_WallEditor> createState() => _WallEditorState();
}

class _WallEditorState extends State<_WallEditor> {
  late final TextEditingController _thickness;
  late final TextEditingController _height;

  @override
  void initState() {
    super.initState();
    _thickness = TextEditingController(
      text: widget.wall.thicknessM.toStringAsFixed(2),
    );
    _height = TextEditingController(
      text: widget.wall.heightM.toStringAsFixed(2),
    );
  }

  @override
  void didUpdateWidget(covariant _WallEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the fields in sync when the selection or the wall changes
    // externally (undo/redo), but never clobber what the user is typing.
    if (widget.wall.id != oldWidget.wall.id ||
        widget.wall.thicknessM != oldWidget.wall.thicknessM) {
      _thickness.text = widget.wall.thicknessM.toStringAsFixed(2);
    }
    if (widget.wall.id != oldWidget.wall.id ||
        widget.wall.heightM != oldWidget.wall.heightM) {
      _height.text = widget.wall.heightM.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _thickness.dispose();
    _height.dispose();
    super.dispose();
  }

  void _commitThickness(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed > 0 && parsed != widget.wall.thicknessM) {
      widget.onThicknessChanged(parsed);
    }
  }

  void _commitHeight(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null && parsed > 0 && parsed != widget.wall.heightM) {
      widget.onHeightChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.wall.name, style: Theme.of(context).textTheme.titleSmall),
          Text(
            '${widget.wall.lengthM.toStringAsFixed(2)} m · '
            '${widget.wall.type.name} · '
            '${widget.roomsForWall.length} '
            '${widget.roomsForWall.length == 1 ? 'room' : 'rooms'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (widget.wall.isShared)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.t('sharedWallNote'),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: NumberField(
                  controller: _thickness,
                  label: context.t('thickness'),
                  suffix: 'm',
                  onFieldSubmitted: _commitThickness,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 120,
                child: NumberField(
                  controller: _height,
                  label: context.t('height'),
                  suffix: 'm',
                  onFieldSubmitted: _commitHeight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TakeoffSummary extends StatelessWidget {
  final BuildingTakeoff takeoff;
  const _TakeoffSummary({required this.takeoff});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        '${context.t('result')} — ${takeoff.uniqueWallCount} ${context.t('uniqueWalls')}',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row(
                context,
                'Wall length',
                '${takeoff.totalWallLengthM.toStringAsFixed(2)} m',
              ),
              _row(
                context,
                'Brickwork',
                '${takeoff.totalBrickworkVolumeM3.toStringAsFixed(2)} m³',
              ),
              _row(
                context,
                'Plaster',
                '${takeoff.totalPlasterAreaM2.toStringAsFixed(2)} m²',
              ),
              if (takeoff.duplicateWallIds.isNotEmpty)
                Text(
                  'Duplicate IDs: ${takeoff.duplicateWallIds.join(', ')}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text(value)],
    ),
  );
}
