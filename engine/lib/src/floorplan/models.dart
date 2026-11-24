import 'dart:math' as math;

/// Floor-plan domain model. Pure Dart — no dart:ui, no Flutter.
class PlanPoint {
  final double x;
  final double y;

  const PlanPoint(this.x, this.y);

  PlanPoint operator +(PlanPoint other) => PlanPoint(x + other.x, y + other.y);
  PlanPoint operator -(PlanPoint other) => PlanPoint(x - other.x, y - other.y);

  @override
  bool operator ==(Object other) =>
      other is PlanPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  factory PlanPoint.fromJson(Map<String, dynamic> json) =>
      PlanPoint((json['x'] as num).toDouble(), (json['y'] as num).toDouble());

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

enum WallType {
  exterior,
  interior,
  partition,
  boundary,
  foundation,
  parapet,
  custom,
}

enum VerificationStatus {
  aiDetected,
  estimated,
  uncertain,
  userVerified,
  userEdited,
}

enum OpeningKind { door, window, ventilator, opening }

class Opening {
  final String id;
  final String wallId;
  final OpeningKind kind;
  final String subtype;
  final double offsetM;
  final double widthM;
  final double heightM;
  final double sillM;
  final VerificationStatus status;
  final double confidence;

  const Opening({
    required this.id,
    required this.wallId,
    required this.kind,
    this.subtype = 'custom',
    required this.offsetM,
    required this.widthM,
    required this.heightM,
    this.sillM = 0,
    this.status = VerificationStatus.userEdited,
    this.confidence = 1,
  });

  double get areaM2 => widthM * heightM;

  Opening copyWith({
    double? offsetM,
    double? widthM,
    double? heightM,
    double? sillM,
    VerificationStatus? status,
  }) {
    return Opening(
      id: id,
      wallId: wallId,
      kind: kind,
      subtype: subtype,
      offsetM: offsetM ?? this.offsetM,
      widthM: widthM ?? this.widthM,
      heightM: heightM ?? this.heightM,
      sillM: sillM ?? this.sillM,
      status: status ?? this.status,
      confidence: confidence,
    );
  }

  factory Opening.fromJson(Map<String, dynamic> json) => Opening(
    id: json['id'] as String,
    wallId: json['wallId'] as String,
    kind: OpeningKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => OpeningKind.opening,
    ),
    subtype: json['subtype'] as String? ?? 'custom',
    offsetM: (json['offsetM'] as num).toDouble(),
    widthM: (json['widthM'] as num).toDouble(),
    heightM: (json['heightM'] as num).toDouble(),
    sillM: (json['sillM'] as num?)?.toDouble() ?? 0,
    status: VerificationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => VerificationStatus.uncertain,
    ),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'wallId': wallId,
    'kind': kind.name,
    'subtype': subtype,
    'offsetM': offsetM,
    'widthM': widthM,
    'heightM': heightM,
    'sillM': sillM,
    'status': status.name,
    'confidence': confidence,
  };
}

/// One physical wall. Never duplicate this record for adjacent rooms.
class Wall {
  final String id;
  final String floorId;
  final String name;
  final PlanPoint start;
  final PlanPoint end;
  final double thicknessM;
  final double heightM;
  final WallType type;
  final String material;
  final bool isShared;
  final VerificationStatus status;
  final double confidence;
  final List<Opening> openings;

  const Wall({
    required this.id,
    required this.floorId,
    required this.name,
    required this.start,
    required this.end,
    required this.thicknessM,
    required this.heightM,
    this.type = WallType.interior,
    this.material = 'brick',
    this.isShared = false,
    this.status = VerificationStatus.userVerified,
    this.confidence = 1,
    this.openings = const [],
  });

  double get lengthM =>
      math.sqrt(math.pow(end.x - start.x, 2) + math.pow(end.y - start.y, 2));

  double get grossAreaM2 => lengthM * heightM;

  double get openingAreaM2 =>
      openings.fold(0.0, (sum, opening) => sum + opening.areaM2);

  double get netAreaM2 => math.max(0.0, grossAreaM2 - openingAreaM2);

  Wall copyWith({
    PlanPoint? start,
    PlanPoint? end,
    double? thicknessM,
    double? heightM,
    WallType? type,
    String? material,
    bool? isShared,
    VerificationStatus? status,
    List<Opening>? openings,
  }) {
    return Wall(
      id: id,
      floorId: floorId,
      name: name,
      start: start ?? this.start,
      end: end ?? this.end,
      thicknessM: thicknessM ?? this.thicknessM,
      heightM: heightM ?? this.heightM,
      type: type ?? this.type,
      material: material ?? this.material,
      isShared: isShared ?? this.isShared,
      status: status ?? this.status,
      confidence: confidence,
      openings: openings ?? this.openings,
    );
  }

  factory Wall.fromJson(Map<String, dynamic> json) => Wall(
    id: json['id'] as String,
    floorId: json['floorId'] as String,
    name: json['name'] as String? ?? '',
    start: PlanPoint.fromJson(json['start'] as Map<String, dynamic>),
    end: PlanPoint.fromJson(json['end'] as Map<String, dynamic>),
    thicknessM: (json['thicknessM'] as num).toDouble(),
    heightM: (json['heightM'] as num).toDouble(),
    type: WallType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => WallType.custom,
    ),
    material: json['material'] as String? ?? 'brick',
    isShared: json['isShared'] as bool? ?? false,
    status: VerificationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => VerificationStatus.uncertain,
    ),
    confidence: (json['confidence'] as num?)?.toDouble() ?? 1,
    openings: (json['openings'] as List<dynamic>? ?? [])
        .map((entry) => Opening.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'floorId': floorId,
    'name': name,
    'start': start.toJson(),
    'end': end.toJson(),
    'thicknessM': thicknessM,
    'heightM': heightM,
    'type': type.name,
    'material': material,
    'isShared': isShared,
    'status': status.name,
    'confidence': confidence,
    'openings': openings.map((opening) => opening.toJson()).toList(),
  };
}

class Room {
  final String id;
  final String floorId;
  final String name;
  final List<PlanPoint> polygon;
  final Set<String> wallIds;
  final VerificationStatus status;

  const Room({
    required this.id,
    required this.floorId,
    required this.name,
    required this.polygon,
    this.wallIds = const <String>{},
    this.status = VerificationStatus.userVerified,
  });

  /// Shoelace formula; returns absolute area in m².
  double get areaM2 {
    if (polygon.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return (sum / 2).abs();
  }

  double get perimeterM {
    var total = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      total += math.sqrt(math.pow(b.x - a.x, 2) + math.pow(b.y - a.y, 2));
    }
    return total;
  }

  Room copyWith({
    String? name,
    List<PlanPoint>? polygon,
    Set<String>? wallIds,
    VerificationStatus? status,
  }) {
    return Room(
      id: id,
      floorId: floorId,
      name: name ?? this.name,
      polygon: polygon ?? this.polygon,
      wallIds: wallIds ?? this.wallIds,
      status: status ?? this.status,
    );
  }

  factory Room.fromJson(Map<String, dynamic> json) => Room(
    id: json['id'] as String,
    floorId: json['floorId'] as String,
    name: json['name'] as String? ?? '',
    polygon: (json['polygon'] as List<dynamic>? ?? [])
        .map((entry) => PlanPoint.fromJson(entry as Map<String, dynamic>))
        .toList(),
    wallIds: (json['wallIds'] as List<dynamic>? ?? [])
        .map((entry) => entry as String)
        .toSet(),
    status: VerificationStatus.values.firstWhere(
      (value) => value.name == json['status'],
      orElse: () => VerificationStatus.uncertain,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'floorId': floorId,
    'name': name,
    'polygon': polygon.map((point) => point.toJson()).toList(),
    'wallIds': wallIds.toList(),
    'status': status.name,
  };
}

class Floor {
  final String id;
  final String buildingId;
  final String name;
  final int level;
  final double heightM;
  final List<Room> rooms;
  final List<Wall> walls;

  const Floor({
    required this.id,
    required this.buildingId,
    required this.name,
    required this.level,
    required this.heightM,
    this.rooms = const [],
    this.walls = const [],
  });

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
    id: json['id'] as String,
    buildingId: json['buildingId'] as String,
    name: json['name'] as String? ?? '',
    level: json['level'] as int? ?? 0,
    heightM: (json['heightM'] as num?)?.toDouble() ?? 3,
    rooms: (json['rooms'] as List<dynamic>? ?? [])
        .map((entry) => Room.fromJson(entry as Map<String, dynamic>))
        .toList(),
    walls: (json['walls'] as List<dynamic>? ?? [])
        .map((entry) => Wall.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'buildingId': buildingId,
    'name': name,
    'level': level,
    'heightM': heightM,
    'rooms': rooms.map((room) => room.toJson()).toList(),
    'walls': walls.map((wall) => wall.toJson()).toList(),
  };
}

class Building {
  final String id;
  final String projectId;
  final String name;
  final List<Floor> floors;

  const Building({
    required this.id,
    required this.projectId,
    required this.name,
    required this.floors,
  });

  factory Building.fromJson(Map<String, dynamic> json) => Building(
    id: json['id'] as String,
    projectId: json['projectId'] as String? ?? '',
    name: json['name'] as String? ?? '',
    floors: (json['floors'] as List<dynamic>? ?? [])
        .map((entry) => Floor.fromJson(entry as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'floors': floors.map((floor) => floor.toJson()).toList(),
  };

  Iterable<Wall> get allWalls => floors.expand((floor) => floor.walls);
  Iterable<Room> get allRooms => floors.expand((floor) => floor.rooms);
}
