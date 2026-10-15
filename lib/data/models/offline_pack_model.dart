class OfflinePackModel {
  final int id;
  final String name;
  final double sizeMb;
  final double downloadedMb;
  final String status; // 'downloaded', 'downloading', 'failed', 'paused', 'not_downloaded'
  final String badgeLabel;
  final String iconType; // 'terrain', 'forest', 'downloading', 'cloud_off'
  final String? speedText;
  final String? errorMessage;

  const OfflinePackModel({
    required this.id,
    required this.name,
    required this.sizeMb,
    required this.downloadedMb,
    required this.status,
    required this.badgeLabel,
    required this.iconType,
    this.speedText,
    this.errorMessage,
  });

  double get progress {
    if (sizeMb <= 0) return 0.0;
    return (downloadedMb / sizeMb).clamp(0.0, 1.0);
  }

  int get progressPercent => (progress * 100).round();

  OfflinePackModel copyWith({
    int? id,
    String? name,
    double? sizeMb,
    double? downloadedMb,
    String? status,
    String? badgeLabel,
    String? iconType,
    String? speedText,
    String? errorMessage,
  }) {
    return OfflinePackModel(
      id: id ?? this.id,
      name: name ?? this.name,
      sizeMb: sizeMb ?? this.sizeMb,
      downloadedMb: downloadedMb ?? this.downloadedMb,
      status: status ?? this.status,
      badgeLabel: badgeLabel ?? this.badgeLabel,
      iconType: iconType ?? this.iconType,
      speedText: speedText ?? this.speedText,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'size_mb': sizeMb,
      'downloaded_mb': downloadedMb,
      'status': status,
      'badge_label': badgeLabel,
      'icon_type': iconType,
      'speed_text': speedText,
      'error_message': errorMessage,
    };
  }

  factory OfflinePackModel.fromMap(Map<String, dynamic> map) {
    return OfflinePackModel(
      id: map['id'] as int,
      name: map['name'] as String,
      sizeMb: (map['size_mb'] as num).toDouble(),
      downloadedMb: (map['downloaded_mb'] as num).toDouble(),
      status: map['status'] as String,
      badgeLabel: map['badge_label'] as String,
      iconType: map['icon_type'] as String,
      speedText: map['speed_text'] as String?,
      errorMessage: map['error_message'] as String?,
    );
  }
}
