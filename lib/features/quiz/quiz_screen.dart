import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';

import 'quiz_model.dart';
import 'quiz_provider.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final quiz = context.watch<QuizProvider>();

    final currentQ = quiz.currentQuestion;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(230),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Kuis Jelajah Merapi',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined, color: AppColors.primary),
            tooltip: 'Papan Peringkat',
            onPressed: () => _showLeaderboardModal(context, quiz),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // 1. Status Vulkanik & Info Skor Mini Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.margin,
              AppDimensions.spaceSm,
              AppDimensions.margin,
              AppDimensions.spaceXs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mode Kuis Edukasi Wisata',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.monetization_on, color: Color(0xFFC58A32), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '+50 Poin Tiap Jawaban',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Header Info Skor & Gelar Jagawana
          _buildScoreBannerCard(quiz),

          // 3. Area Pertanyaan Kuis Aktif
          _buildQuestionCard(context, quiz, currentQ),

          // 4. Tombol Aksi Bawah
          if (quiz.isAnswered)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.margin,
                AppDimensions.spaceLg,
                AppDimensions.margin,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (quiz.isQuizFinished) {
                      _showQuizSummaryDialog(context, quiz);
                    } else {
                      quiz.nextQuestion();
                    }
                  },
                  icon: Icon(
                    quiz.isQuizFinished ? Icons.emoji_events : Icons.arrow_forward,
                    color: AppColors.onPrimary,
                  ),
                  label: Text(
                    quiz.isQuizFinished ? 'Selesaikan Kuis & Lihat Hasil' : 'Pertanyaan Berikutnya',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScoreBannerCard(QuizProvider quiz) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceXs,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: const Icon(Icons.hiking, color: AppColors.onPrimary, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'GELAR AKTIF',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC58A32).withAlpha(30),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                  ),
                                  child: const Text(
                                    'PRO',
                                    style: TextStyle(
                                      color: Color(0xFFC58A32),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              quiz.activeRankTitle,
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Akumulasi Skor',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Color(0xFFC58A32), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${quiz.userScore} Poin',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.quiz, color: AppColors.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Pertanyaan ${quiz.currentQuestionIndex + 1} dari ${quiz.totalQuestions}',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${quiz.progressPercent}% Selesai',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: LinearProgressIndicator(
                value: quiz.progressFraction,
                minHeight: 8,
                backgroundColor: AppColors.surfaceContainer,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, QuizProvider quiz, QuizQuestionModel question) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category & Mode Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.landscape, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            question.category,
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Santai & Edukatif',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Question Image with location tag
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              child: Stack(
                children: [
                  Image.network(
                    question.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: AppColors.surfaceContainer,
                      child: const Center(
                        child: Icon(Icons.landscape, size: 48, color: AppColors.outline),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(150),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            question.locationTag,
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Question text
            Text(
              'TANTANGAN VULKANIK',
              style: AppTypography.labelSm.copyWith(
                color: const Color(0xFFC58A32),
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              question.question,
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),

            // 4 Multiple Choice Options
            ...List.generate(question.options.length, (index) {
              return _buildOptionButton(quiz, question, index);
            }),

            // Educational explanation card when answered
            if (quiz.isAnswered) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lightbulb, color: AppColors.onPrimary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.isCurrentAnswerCorrect ? 'Tepat Sekali! (+50 Poin)' : 'Penjelasan Edukatif:',
                            style: AppTypography.titleMd.copyWith(
                              color: quiz.isCurrentAnswerCorrect ? AppColors.primary : AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            question.explanation,
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(QuizProvider quiz, QuizQuestionModel question, int optionIndex) {
    const letters = ['A', 'B', 'C', 'D'];
    final letter = letters[optionIndex];
    final optionText = question.options[optionIndex];

    final isSelected = quiz.selectedOptionIndex == optionIndex;
    final isCorrect = question.correctIndex == optionIndex;

    Color bgColor = AppColors.surfaceContainerLow;
    Color letterBgColor = AppColors.surfaceContainerHighest;
    Color letterTextColor = AppColors.onSurface;
    Widget? trailingWidget;

    if (quiz.isAnswered) {
      if (isCorrect) {
        bgColor = AppColors.secondaryContainer;
        letterBgColor = AppColors.primary;
        letterTextColor = AppColors.onPrimary;
        trailingWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 14, color: AppColors.onPrimary),
              const SizedBox(width: 4),
              Text(
                'Benar!',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      } else if (isSelected && !isCorrect) {
        bgColor = AppColors.errorContainer;
        letterBgColor = AppColors.error;
        letterTextColor = AppColors.onError;
        trailingWidget = const Icon(Icons.cancel, color: AppColors.error, size: 20);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => quiz.answerQuestion(optionIndex),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: isSelected
                ? Border.all(color: isCorrect ? AppColors.primary : AppColors.error, width: 1.5)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: letterBgColor,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  letter,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: letterTextColor,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  optionText,
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: isSelected || (quiz.isAnswered && isCorrect)
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              ?trailingWidget,
            ],
          ),
        ),
      ),
    );
  }

  void _showQuizSummaryDialog(BuildContext context, QuizProvider quiz) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        title: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Color(0xFFC58A32), size: 28),
            SizedBox(width: 8),
            Text('Kuis Selesai!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hebat! Kamu berhasil menjawab ${quiz.sessionCorrectCount} dari ${quiz.totalQuestions} pertanyaan dengan benar.',
              style: AppTypography.bodyMd,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bonus Poin Didapat', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      Text('+${quiz.sessionEarnedPoints} Poin', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Total Skor Akhir', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      Text('${quiz.userScore} Poin', style: AppTypography.headlineSm.copyWith(color: const Color(0xFFC58A32), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              quiz.resetQuiz();
            },
            child: const Text('Main Lagi'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.of(context).maybePop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showLeaderboardModal(BuildContext context, QuizProvider quiz) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppDimensions.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.leaderboard, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Papan Peringkat Jagawana',
                  style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Peringkat mingguan penjelajah peduli konservasi lereng Merapi',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...quiz.leaderboard.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: item.isCurrentUser ? AppColors.secondaryContainer : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: item.isCurrentUser ? AppColors.primary : AppColors.outline,
                      child: Text(
                        item.avatarLetter,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                          Text(item.rankTitle, style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Text(
                      '${item.points} Poin',
                      style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.onSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                ),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
