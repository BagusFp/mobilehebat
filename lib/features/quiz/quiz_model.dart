class QuizQuestionModel {
  final int id;
  final String category;
  final String question;
  final String imageUrl;
  final String locationTag;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestionModel({
    required this.id,
    required this.category,
    required this.question,
    required this.imageUrl,
    required this.locationTag,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

class QuizLeaderboardItem {
  final String name;
  final int points;
  final String rankTitle;
  final String avatarLetter;
  final bool isCurrentUser;

  const QuizLeaderboardItem({
    required this.name,
    required this.points,
    required this.rankTitle,
    required this.avatarLetter,
    this.isCurrentUser = false,
  });
}
