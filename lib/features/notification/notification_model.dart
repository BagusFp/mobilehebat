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
  });

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
    );
  }
}
