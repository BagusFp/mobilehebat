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
}
