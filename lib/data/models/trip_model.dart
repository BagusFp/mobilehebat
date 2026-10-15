import 'trip_item_model.dart';

class TripModel {
  final int? id;
  final int userId;
  final String tripName;
  final String startDate;
  final int participantCount;
  final double targetBudget;
  final double totalEstimatedCost;
  final double totalActualCost;
  final String status; // 'draft', 'upcoming'/'planned', 'active', 'completed'
  final bool reminderEnabled;
  final bool isSavedOffline;
  final String? bannerImageUrl;
  final String? startedAt;
  final String? completedAt;
  final String createdAt;
  final String? originCity;
  final String? originTimezone;
  final String? destinationCity;
  final String? destinationTimezone;
  final String? currencySource;
  final String? currencyTarget;
  final List<TripItemModel> items;

  const TripModel({
    this.id,
    required this.userId,
    required this.tripName,
    required this.startDate,
    this.participantCount = 2,
    this.targetBudget = 400000.0,
    this.totalEstimatedCost = 64000.0,
    this.totalActualCost = 0.0,
    this.status = 'upcoming',
    this.reminderEnabled = true,
    this.isSavedOffline = true,
    this.bannerImageUrl,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    this.originCity,
    this.originTimezone,
    this.destinationCity,
    this.destinationTimezone,
    this.currencySource = 'IDR',
    this.currencyTarget = 'USD',
    this.items = const [],
  });

  TripModel copyWith({
    int? id,
    int? userId,
    String? tripName,
    String? startDate,
    int? participantCount,
    double? targetBudget,
    double? totalEstimatedCost,
    double? totalActualCost,
    String? status,
    bool? reminderEnabled,
    bool? isSavedOffline,
    String? bannerImageUrl,
    String? startedAt,
    String? completedAt,
    String? createdAt,
    String? originCity,
    String? originTimezone,
    String? destinationCity,
    String? destinationTimezone,
    String? currencySource,
    String? currencyTarget,
    List<TripItemModel>? items,
  }) {
    return TripModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripName: tripName ?? this.tripName,
      startDate: startDate ?? this.startDate,
      participantCount: participantCount ?? this.participantCount,
      targetBudget: targetBudget ?? this.targetBudget,
      totalEstimatedCost: totalEstimatedCost ?? this.totalEstimatedCost,
      totalActualCost: totalActualCost ?? this.totalActualCost,
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isSavedOffline: isSavedOffline ?? this.isSavedOffline,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      originCity: originCity ?? this.originCity,
      originTimezone: originTimezone ?? this.originTimezone,
      destinationCity: destinationCity ?? this.destinationCity,
      destinationTimezone: destinationTimezone ?? this.destinationTimezone,
      currencySource: currencySource ?? this.currencySource,
      currencyTarget: currencyTarget ?? this.currencyTarget,
      items: items ?? this.items,
    );
  }

  factory TripModel.fromMap(Map<String, dynamic> map, {List<TripItemModel> items = const []}) {
    return TripModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      tripName: map['trip_name'] as String,
      startDate: map['start_date'] as String,
      participantCount: map['participant_count'] as int? ?? 1,
      targetBudget: (map['target_budget'] as num?)?.toDouble() ?? 400000.0,
      totalEstimatedCost: (map['total_estimated_cost'] as num?)?.toDouble() ?? 0.0,
      totalActualCost: (map['total_actual_cost'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] as String? ?? 'upcoming',
      reminderEnabled: (map['reminder_enabled'] as int? ?? 1) == 1 || (map['reminder_enabled'] == true),
      isSavedOffline: (map['is_saved_offline'] as int? ?? 1) == 1 || (map['is_saved_offline'] == true),
      bannerImageUrl: map['banner_image_url'] as String?,
      startedAt: map['started_at'] as String?,
      completedAt: map['completed_at'] as String?,
      createdAt: map['created_at'] as String? ?? DateTime.now().toIso8601String(),
      originCity: map['origin_city'] as String?,
      originTimezone: map['origin_timezone'] as String?,
      destinationCity: map['destination_city'] as String?,
      destinationTimezone: map['destination_timezone'] as String?,
      currencySource: map['currency_source'] as String? ?? 'IDR',
      currencyTarget: map['currency_target'] as String? ?? 'USD',
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'trip_name': tripName,
      'start_date': startDate,
      'participant_count': participantCount,
      'target_budget': targetBudget,
      'total_estimated_cost': totalEstimatedCost,
      'total_actual_cost': totalActualCost,
      'status': status,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'is_saved_offline': isSavedOffline ? 1 : 0,
      'banner_image_url': bannerImageUrl,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      'created_at': createdAt,
      'origin_city': originCity,
      'origin_timezone': originTimezone,
      'destination_city': destinationCity,
      'destination_timezone': destinationTimezone,
      'currency_source': currencySource,
      'currency_target': currencyTarget,
    };
  }
}
