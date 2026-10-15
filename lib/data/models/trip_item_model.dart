class TripItemModel {
  final int? id;
  final int? tripId;
  final int? destinationId;
  final String itemName;
  final String itemSubtitle;
  final int visitOrder;
  final String plannedTime;
  final double durationHours;
  final double estimatedCost;
  final String? notes;
  final String? imageUrl;
  final int elevationMdpl;
  final double connectingDistanceKm;
  final int connectingTimeMinutes;
  final bool isCompleted;
  final String? completedAt;

  const TripItemModel({
    this.id,
    this.tripId,
    this.destinationId,
    required this.itemName,
    this.itemSubtitle = '',
    required this.visitOrder,
    this.plannedTime = '08:00 - 09:30',
    this.durationHours = 1.5,
    this.estimatedCost = 0.0,
    this.notes,
    this.imageUrl,
    this.elevationMdpl = 900,
    this.connectingDistanceKm = 3.5,
    this.connectingTimeMinutes = 15,
    this.isCompleted = false,
    this.completedAt,
  });

  TripItemModel copyWith({
    int? id,
    int? tripId,
    int? destinationId,
    String? itemName,
    String? itemSubtitle,
    int? visitOrder,
    String? plannedTime,
    double? durationHours,
    double? estimatedCost,
    String? notes,
    String? imageUrl,
    int? elevationMdpl,
    double? connectingDistanceKm,
    int? connectingTimeMinutes,
    bool? isCompleted,
    String? completedAt,
  }) {
    return TripItemModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      destinationId: destinationId ?? this.destinationId,
      itemName: itemName ?? this.itemName,
      itemSubtitle: itemSubtitle ?? this.itemSubtitle,
      visitOrder: visitOrder ?? this.visitOrder,
      plannedTime: plannedTime ?? this.plannedTime,
      durationHours: durationHours ?? this.durationHours,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      elevationMdpl: elevationMdpl ?? this.elevationMdpl,
      connectingDistanceKm: connectingDistanceKm ?? this.connectingDistanceKm,
      connectingTimeMinutes: connectingTimeMinutes ?? this.connectingTimeMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory TripItemModel.fromMap(Map<String, dynamic> map) {
    return TripItemModel(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int?,
      destinationId: map['destination_id'] as int?,
      itemName: map['item_name'] as String,
      itemSubtitle: map['item_subtitle'] as String? ?? '',
      visitOrder: map['visit_order'] as int? ?? 1,
      plannedTime: map['planned_time'] as String? ?? '08:00 - 09:30',
      durationHours: (map['duration_hours'] as num?)?.toDouble() ?? 1.5,
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      imageUrl: map['image_url'] as String?,
      elevationMdpl: map['elevation_mdpl'] as int? ?? 900,
      connectingDistanceKm: (map['connecting_distance_km'] as num?)?.toDouble() ?? 3.5,
      connectingTimeMinutes: map['connecting_time_minutes'] as int? ?? 15,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1 || (map['is_completed'] == true),
      completedAt: map['completed_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (tripId != null) 'trip_id': tripId,
      if (destinationId != null) 'destination_id': destinationId,
      'item_name': itemName,
      'item_subtitle': itemSubtitle,
      'visit_order': visitOrder,
      'planned_time': plannedTime,
      'duration_hours': durationHours,
      'estimated_cost': estimatedCost,
      'notes': notes,
      'image_url': imageUrl,
      'elevation_mdpl': elevationMdpl,
      'connecting_distance_km': connectingDistanceKm,
      'connecting_time_minutes': connectingTimeMinutes,
      'is_completed': isCompleted ? 1 : 0,
      if (completedAt != null) 'completed_at': completedAt,
    };
  }
}
