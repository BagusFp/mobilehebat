import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../auth/auth_provider.dart';
import '../trip/create_trip_screen.dart';
import '../trip/my_trip_screen.dart';
import '../trip/trip_provider.dart';
import '../../core/services/gemini_service.dart';
import 'ai_assistant_provider.dart';
import 'ai_chat_model.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    GeminiService().init().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiProvider = context.watch<AiAssistantProvider>();
    final authProvider = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();
    final user = authProvider.currentUser;

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
          'Ai Assistant',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.onSurfaceVariant),
            tooltip: 'Bersihkan Obrolan',
            onPressed: () {
              aiProvider.clearChat();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Obrolan AI berhasil dibersihkan.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // 1. Volcanic Activity & AI Companion Status Bar
              _buildCompanionStatusBar(context, aiProvider),

              // 2. Quick Prompts Horizontal Scroll
              _buildQuickPrompts(aiProvider),

              // 3. Conversation Flow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (aiProvider.messages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.forum_outlined, size: 28, color: AppColors.primary),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Tanya Jagawana AI',
                                style: AppTypography.titleMd.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pilih inspirasi kilat di atas atau ketik pertanyaanmu\nuntuk rekomendasi rute, tiket, dan keselamatan Merapi.',
                                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...aiProvider.messages.map((msg) {
                        if (msg.isUser) {
                          return _buildUserMessageBubble(msg);
                        } else {
                          return _buildAiMessageBubble(context, msg, tripProvider, user?.id ?? 1);
                        }
                      }),
                  ],
                ),
              ),

              if (aiProvider.isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.auto_awesome, size: 16, color: AppColors.onPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MeraTrip AI sedang merancang rute...',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // 4. Pinned Ergonomic Floating Input Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingInputBar(context, aiProvider),
          ),
        ],
      ),
    );
  }

  // 1. Companion Status Bar
  Widget _buildCompanionStatusBar(BuildContext context, AiAssistantProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.margin,
        AppDimensions.spaceSm,
        AppDimensions.margin,
        AppDimensions.spaceXs,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy, size: 20, color: AppColors.primary),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'MeraTrip AI',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Text(
                        'Gemini AI',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSecondaryContainer,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  'Direct Cloud AI • Mandiri',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Online',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Quick Prompts Horizontal Scroll
  Widget _buildQuickPrompts(AiAssistantProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.bolt, size: 16, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(
                'Inspirasi Kilat',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Row(
            children: provider.quickPrompts.map((prompt) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    provider.sendMessage(prompt);
                    _scrollToBottom();
                  },
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(6),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Text(
                      prompt,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 3. User Message Bubble (Align Right)
  Widget _buildUserMessageBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Text(
                msg.text,
                style: AppTypography.bodyMd.copyWith(color: AppColors.onPrimary),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  msg.time,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.done_all, size: 14, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 4. AI Message Bubble (Align Left, with Rich Itinerary Card)
  Widget _buildAiMessageBubble(
    BuildContext context,
    ChatMessage msg,
    TripProvider tripProvider,
    int userId,
  ) {
    final rec = msg.recommendation;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome, size: 14, color: AppColors.onPrimary),
                ),
                const SizedBox(width: 6),
                Text(
                  'MeraTrip AI',
                  style: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  msg.time,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFormattedAiText(msg.text),

                if (rec != null) ...[
                  const SizedBox(height: 12),
                  // Journey Recommendation Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                              ),
                              child: Text(
                                rec.categoryBadge,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Total Durasi',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                                Text(
                                  rec.totalDuration,
                                  style: AppTypography.labelLg.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rec.title,
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Metrics Bar
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Estimasi Tiket', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
                                    Text(rec.estimatedTicket, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Aksesibilitas', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
                                    Text(rec.accessibility, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.secondary)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stops
                        Column(
                          children: rec.stops.map((stop) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          stop.timeRange,
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceContainer,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          stop.ticketBadge,
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                            fontSize: 10,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    stop.name,
                                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      stop.imageUrl,
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        height: 60,
                                        color: AppColors.surfaceContainer,
                                        child: const Center(
                                          child: Icon(Icons.landscape, color: AppColors.outline),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    stop.description,
                                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),

                        // Pro Tip Box
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh.withAlpha(150),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.tips_and_updates, color: AppColors.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tips Pintar MeraTrip', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                                    Text(rec.proTip, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                            ),
                            onPressed: () async {
                              final success = await context.read<AiAssistantProvider>().adoptItineraryToMyTrip(
                                tripProvider,
                                userId: userId,
                                customRec: rec,
                              );
                              if (context.mounted && success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Rute rekomendasi AI berhasil disimpan ke My Trip!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const MyTripScreen()),
                                );
                              }
                            },
                            icon: const Icon(Icons.bookmark_add, size: 18),
                            label: Text(
                              'Simpan ke My Trip',
                              style: AppTypography.labelLg.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerLowest,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                              );
                            },
                            icon: const Icon(Icons.tune, size: 16, color: AppColors.primary),
                            label: Text(
                              'Kustomisasi Rute',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (msg.followUpText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    msg.followUpText!,
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  /// Parser teks AI untuk merender format markdown (bold, bullet point, heading)
  /// dan membersihkan tanda bintang asteris (** atau *) agar tampilan rapi
  Widget _buildFormattedAiText(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      final trimmedLine = lines[i].trim();

      if (trimmedLine.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // 1. Heading markdown (contoh: ### Subjudul)
      final headingMatch = RegExp(r'^(#{1,4})\s+(.+)$').firstMatch(trimmedLine);
      if (headingMatch != null) {
        final content = headingMatch.group(2) ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              _cleanStrayAsterisks(content),
              style: AppTypography.bodyMd.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        );
        continue;
      }

      // 2. Bullet point (* atau - atau •)
      final bulletMatch = RegExp(r'^(\*|-|•)\s+(.+)$').firstMatch(trimmedLine);
      if (bulletMatch != null) {
        final content = bulletMatch.group(2) ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Expanded(
                  child: _buildRichInlineText(content, AppTypography.bodyMd),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 3. Numbered list (contoh: 1. atau 2.)
      final numberMatch = RegExp(r'^(\d+[\.\)])\s+(.+)$').firstMatch(trimmedLine);
      if (numberMatch != null) {
        final numPrefix = numberMatch.group(1) ?? '1.';
        final content = numberMatch.group(2) ?? '';
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$numPrefix ',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                Expanded(
                  child: _buildRichInlineText(content, AppTypography.bodyMd),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 4. Paragraf biasa (dengan parsing inline **bold** / *italic*)
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichInlineText(trimmedLine, AppTypography.bodyMd),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichInlineText(String text, TextStyle baseStyle) {
    // Regex mencocokkan **teks tebal** atau *teks miring*
    final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*)');
    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: _cleanStrayAsterisks(text.substring(lastIndex, match.start)),
        ));
      }

      final boldText = match.group(2);
      final italicText = match.group(3);

      if (boldText != null && boldText.isNotEmpty) {
        spans.add(TextSpan(
          text: _cleanStrayAsterisks(boldText),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ));
      } else if (italicText != null && italicText.isNotEmpty) {
        spans.add(TextSpan(
          text: _cleanStrayAsterisks(italicText),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: _cleanStrayAsterisks(text.substring(lastIndex)),
      ));
    }

    if (spans.isEmpty) {
      return Text(
        _cleanStrayAsterisks(text),
        style: baseStyle,
      );
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }

  String _cleanStrayAsterisks(String str) {
    return str.replaceAll('**', '').replaceAll('*', '');
  }

  // 5. Floating Bottom Input Bar
  Widget _buildFloatingInputBar(BuildContext context, AiAssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppDimensions.margin, 8, AppDimensions.margin, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(240),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_location_alt, size: 20, color: AppColors.onSurfaceVariant),
              onPressed: () {
                provider.sendMessage('Rekomendasikan spot terdekat dari Pos Retribusi Kaliurang');
                _scrollToBottom();
              },
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: 'Tanyakan rute, waktu terbaik, atau budget...',
                  hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    provider.sendMessage(val);
                    _textController.clear();
                    _scrollToBottom();
                  }
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.mic, size: 20, color: AppColors.onSurfaceVariant),
              onPressed: () {
                provider.sendMessage('Cari spot foto sunrise Merapi');
                _scrollToBottom();
              },
            ),
            InkWell(
              onTap: () {
                if (_textController.text.trim().isNotEmpty) {
                  provider.sendMessage(_textController.text);
                  _textController.clear();
                  _scrollToBottom();
                }
              },
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, size: 18, color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

