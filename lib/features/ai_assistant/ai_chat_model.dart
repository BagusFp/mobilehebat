class ItineraryStopModel {
  final String timeRange;
  final String name;
  final String ticketBadge;
  final String description;
  final String imageUrl;

  const ItineraryStopModel({
    required this.timeRange,
    required this.name,
    required this.ticketBadge,
    required this.description,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'timeRange': timeRange,
    'name': name,
    'ticketBadge': ticketBadge,
    'description': description,
    'imageUrl': imageUrl,
  };

  factory ItineraryStopModel.fromJson(Map<String, dynamic> json) => ItineraryStopModel(
    timeRange: json['timeRange'] ?? '',
    name: json['name'] ?? '',
    ticketBadge: json['ticketBadge'] ?? '',
    description: json['description'] ?? '',
    imageUrl: json['imageUrl'] ?? '',
  );
}

class ItineraryRecommendation {
  final String title;
  final String categoryBadge;
  final String totalDuration;
  final String estimatedTicket;
  final String accessibility;
  final List<ItineraryStopModel> stops;
  final String proTip;

  const ItineraryRecommendation({
    required this.title,
    required this.categoryBadge,
    required this.totalDuration,
    required this.estimatedTicket,
    required this.accessibility,
    required this.stops,
    required this.proTip,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'categoryBadge': categoryBadge,
    'totalDuration': totalDuration,
    'estimatedTicket': estimatedTicket,
    'accessibility': accessibility,
    'stops': stops.map((s) => s.toJson()).toList(),
    'proTip': proTip,
  };

  factory ItineraryRecommendation.fromJson(Map<String, dynamic> json) => ItineraryRecommendation(
    title: json['title'] ?? '',
    categoryBadge: json['categoryBadge'] ?? '',
    totalDuration: json['totalDuration'] ?? '',
    estimatedTicket: json['estimatedTicket'] ?? '',
    accessibility: json['accessibility'] ?? '',
    stops: (json['stops'] as List? ?? [])
        .map((s) => ItineraryStopModel.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
    proTip: json['proTip'] ?? '',
  );
}

class ChatMessage {
  final String id;
  final bool isUser;
  final String text;
  final String time;
  final ItineraryRecommendation? recommendation;
  final String? followUpText;

  const ChatMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.time,
    this.recommendation,
    this.followUpText,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'isUser': isUser,
    'text': text,
    'time': time,
    'recommendation': recommendation?.toJson(),
    'followUpText': followUpText,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] ?? '',
    isUser: json['isUser'] ?? false,
    text: json['text'] ?? '',
    time: json['time'] ?? '',
    recommendation: json['recommendation'] != null
        ? ItineraryRecommendation.fromJson(Map<String, dynamic>.from(json['recommendation']))
        : null,
    followUpText: json['followUpText'],
  );
}

class AiChatSession {
  final String id;
  final String title;
  final String createdAt;
  final List<ChatMessage> messages;

  const AiChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory AiChatSession.fromJson(Map<String, dynamic> json) => AiChatSession(
    id: json['id'] ?? '',
    title: json['title'] ?? 'Obrolan Baru',
    createdAt: json['createdAt'] ?? '',
    messages: (json['messages'] as List? ?? [])
        .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );

  AiChatSession copyWith({
    String? id,
    String? title,
    String? createdAt,
    List<ChatMessage>? messages,
  }) {
    return AiChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      messages: messages ?? this.messages,
    );
  }
}
