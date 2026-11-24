enum ProjectStatus { planning, active, completed, onHold }

enum ProjectType { sqftBased, contract, dailyRate, custom }

abstract class Identified {
  String get id;
}

class Project implements Identified {
  @override
  final String id;
  final String name;
  final String clientName;
  final String clientPhone;
  final String address;
  final ProjectType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int budgetMinor;
  final String currency;
  final String notes;
  final ProjectStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool dirty;

  const Project({
    required this.id,
    required this.name,
    this.clientName = '',
    this.clientPhone = '',
    this.address = '',
    this.type = ProjectType.custom,
    this.startDate,
    this.endDate,
    this.budgetMinor = 0,
    this.currency = 'BDT',
    this.notes = '',
    this.status = ProjectStatus.planning,
    required this.createdAt,
    required this.updatedAt,
    this.dirty = false,
  });

  Project copyWith({
    String? name,
    String? clientName,
    String? clientPhone,
    String? address,
    ProjectType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? budgetMinor,
    String? currency,
    String? notes,
    ProjectStatus? status,
    DateTime? updatedAt,
    bool? dirty,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      address: address ?? this.address,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budgetMinor: budgetMinor ?? this.budgetMinor,
      currency: currency ?? this.currency,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'clientName': clientName,
    'clientPhone': clientPhone,
    'address': address,
    'type': type.name,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'budgetMinor': budgetMinor,
    'currency': currency,
    'notes': notes,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'dirty': dirty,
  };
}

class MaterialRequirement implements Identified {
  @override
  final String id;
  final String projectId;
  final String name;
  final double quantity;
  final String unit;
  final int unitRateMinor;
  final String category;

  const MaterialRequirement({
    required this.id,
    required this.projectId,
    required this.name,
    required this.quantity,
    required this.unit,
    this.unitRateMinor = 0,
    this.category = 'general',
  });

  int get amountMinor => (quantity * unitRateMinor).round();

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'unitRateMinor': unitRateMinor,
    'category': category,
  };
}

class Expense implements Identified {
  @override
  final String id;
  final String projectId;
  final String title;
  final int amountMinor;
  final String category;
  final DateTime spentAt;
  final String notes;

  const Expense({
    required this.id,
    required this.projectId,
    required this.title,
    required this.amountMinor,
    required this.category,
    required this.spentAt,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'title': title,
    'amountMinor': amountMinor,
    'category': category,
    'spentAt': spentAt.toIso8601String(),
    'notes': notes,
  };
}

class BoqLine implements Identified {
  @override
  final String id;
  final String projectId;
  final String description;
  final double quantity;
  final String unit;
  final int rateMinor;
  final String category;
  final String sourceType;
  final String? sourceId;
  final String? notes;

  const BoqLine({
    required this.id,
    required this.projectId,
    required this.description,
    required this.quantity,
    required this.unit,
    this.rateMinor = 0,
    this.category = 'general',
    this.sourceType = 'manual',
    this.sourceId,
    this.notes,
  });

  int get amountMinor => (quantity * rateMinor).round();

  BoqLine copyWith({double? quantity, int? rateMinor, String? notes}) =>
      BoqLine(
        id: id,
        projectId: projectId,
        description: description,
        quantity: quantity ?? this.quantity,
        unit: unit,
        rateMinor: rateMinor ?? this.rateMinor,
        category: category,
        sourceType: sourceType,
        sourceId: sourceId,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'projectId': projectId,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'rateMinor': rateMinor,
    'category': category,
    'sourceType': sourceType,
    'sourceId': sourceId,
    'amountMinor': amountMinor,
    'notes': notes,
  };
}

class BoqSummary {
  final List<BoqLine> lines;
  final int totalMinor;
  final Map<String, int> byCategoryMinor;

  const BoqSummary({
    required this.lines,
    required this.totalMinor,
    required this.byCategoryMinor,
  });

  Map<String, dynamic> toJson() => {
    'lines': lines.map((line) => line.toJson()).toList(),
    'totalMinor': totalMinor,
    'byCategoryMinor': byCategoryMinor,
  };
}
