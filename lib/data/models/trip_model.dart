import 'trip_item_model.dart';

class TripModel {
  final int? id;
  final int userId;
  final String tripName;
  final String startDate;
  final int participantCount;
  final double targetBudget;
  final double totalEstimatedCost;
  final String status; // 'upcoming', 'draft', 'completed'
  final bool reminderEnabled;
  final bool isSavedOffline;
  final String? bannerImageUrl;
  final String createdAt;
  final List<TripItemModel> items;

  const TripModel({
    this.id,
    required this.userId,
    required this.tripName,
    required this.startDate,
    this.participantCount = 2,
    this.targetBudget = 400000.0,
    this.totalEstimatedCost = 64000.0,
    this.status = 'upcoming',
    this.reminderEnabled = true,
    this.isSavedOffline = true,
    this.bannerImageUrl,
    required this.createdAt,
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
    String? status,
    bool? reminderEnabled,
    bool? isSavedOffline,
    String? bannerImageUrl,
    String? createdAt,
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
      status: status ?? this.status,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      isSavedOffline: isSavedOffline ?? this.isSavedOffline,
      bannerImageUrl: bannerImageUrl ?? this.bannerImageUrl,
      createdAt: createdAt ?? this.createdAt,
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
      status: map['status'] as String? ?? 'upcoming',
      reminderEnabled: (map['reminder_enabled'] as int? ?? 1) == 1,
      isSavedOffline: (map['is_saved_offline'] as int? ?? 1) == 1,
      bannerImageUrl: map['banner_image_url'] as String?,
      createdAt: map['created_at'] as String,
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
      'status': status,
      'reminder_enabled': reminderEnabled ? 1 : 0,
      'is_saved_offline': isSavedOffline ? 1 : 0,
      'banner_image_url': bannerImageUrl,
      'created_at': createdAt,
    };
  }
}
