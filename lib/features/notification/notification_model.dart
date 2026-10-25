class NotificationModel {
  final int id;
  final String title;
  final String body;
  final String category; // 'volcano', 'trip', 'system'
  final String timeAgo;
  final String tag;
  final bool isRead;
  final String? actionText;
  final String? actionRoute;
  final DateTime? timestamp;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.timeAgo,
    required this.tag,
    this.isRead = false,
    this.actionText,
    this.actionRoute,
    this.timestamp,
  });

  String get calculatedTimeAgo {
    if (timestamp == null) return timeAgo;
    final diff = DateTime.now().difference(timestamp!);
    if (diff.isNegative || diff.inSeconds < 60) {
      return 'Baru saja';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} jam lalu';
    }
    if (diff.inDays == 1) {
      return 'Kemarin';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} hari lalu';
    }
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final m = timestamp!.month >= 1 && timestamp!.month <= 12 ? months[timestamp!.month] : '${timestamp!.month}';
    return '${timestamp!.day} $m';
  }

  NotificationModel copyWith({
    int? id,
    String? title,
    String? body,
    String? category,
    String? timeAgo,
    String? tag,
    bool? isRead,
    String? actionText,
    String? actionRoute,
    DateTime? timestamp,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      timeAgo: timeAgo ?? this.timeAgo,
      tag: tag ?? this.tag,
      isRead: isRead ?? this.isRead,
      actionText: actionText ?? this.actionText,
      actionRoute: actionRoute ?? this.actionRoute,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'category': category,
      'time_ago': timeAgo,
      'tag': tag,
      'is_read': isRead ? 1 : 0,
      'action_text': actionText,
      'action_route': actionRoute,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as int,
      title: map['title'] as String,
      body: map['body'] as String,
      category: map['category'] as String,
      timeAgo: map['time_ago'] as String,
      tag: map['tag'] as String,
      isRead: (map['is_read'] as int? ?? 0) == 1,
      actionText: map['action_text'] as String?,
      actionRoute: map['action_route'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String)
          : null,
    );
  }
}
