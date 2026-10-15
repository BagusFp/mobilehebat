class TripExpenseModel {
  final int? id;
  final int tripId;
  final int userId;
  final int? destinationId;
  final String? destinationName;
  final String category;
  final double amount;
  final String? notes;
  final String spentAt;
  final String createdAt;

  const TripExpenseModel({
    this.id,
    required this.tripId,
    required this.userId,
    this.destinationId,
    this.destinationName,
    required this.category,
    required this.amount,
    this.notes,
    required this.spentAt,
    required this.createdAt,
  });

  TripExpenseModel copyWith({
    int? id,
    int? tripId,
    int? userId,
    int? destinationId,
    String? destinationName,
    String? category,
    double? amount,
    String? notes,
    String? spentAt,
    String? createdAt,
  }) {
    return TripExpenseModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      destinationId: destinationId ?? this.destinationId,
      destinationName: destinationName ?? this.destinationName,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      notes: notes ?? this.notes,
      spentAt: spentAt ?? this.spentAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TripExpenseModel.fromMap(Map<String, dynamic> map) {
    return TripExpenseModel(
      id: map['id'] as int?,
      tripId: map['trip_id'] as int,
      userId: map['user_id'] as int? ?? 1,
      destinationId: map['destination_id'] as int?,
      destinationName: map['destination_name'] as String?,
      category: map['category'] as String? ?? 'Lainnya',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'] as String?,
      spentAt: map['spent_at'] as String? ?? DateTime.now().toIso8601String(),
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'trip_id': tripId,
      'user_id': userId,
      'destination_id': destinationId,
      'destination_name': destinationName,
      'category': category,
      'amount': amount,
      'notes': notes,
      'spent_at': spentAt,
      'created_at': createdAt,
    };
  }
}
