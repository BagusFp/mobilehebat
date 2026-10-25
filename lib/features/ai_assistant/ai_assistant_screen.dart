import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../auth/auth_provider.dart';
import '../explore/destination_provider.dart';
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
    // Setiap kali pengguna mengakses fitur AI, arahkan ke room chat yang baru
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AiAssistantProvider>().startNewSession(autoSavePrevious: true);
      }
    });

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

  /// Menampilkan bottom sheet pemilihan destinasi untuk ditanyakan ke AI
  void _showSelectDestinationBottomSheet(BuildContext context, AiAssistantProvider provider) {
    final destProvider = context.read<DestinationProvider>();
    if (destProvider.allDestinations.isEmpty) {
      destProvider.loadDestinations();
    }

    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final allDest = destProvider.allDestinations;
            final filtered = searchQuery.isEmpty
                ? allDest
                : allDest.where((d) => d.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return SafeArea(
              child: Container(
                height: MediaQuery.of(dialogCtx).size.height * 0.7,
                padding: const EdgeInsets.fromLTRB(AppDimensions.margin, 16, AppDimensions.margin, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Pilih Destinasi untuk Ditanyakan',
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search Field
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari nama destinasi Merapi...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (val) {
                        setSheetState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'Destinasi tidak ditemukan',
                                style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                              ),
                            )
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (ctx, index) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final dest = filtered[idx];
                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                    child: Container(
                                      width: 46,
                                      height: 46,
                                      color: AppColors.secondaryContainer,
                                      child: (dest.imageUrl != null && dest.imageUrl!.isNotEmpty)
                                          ? Image.network(
                                              dest.imageUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.landscape,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : const Icon(Icons.landscape, color: AppColors.primary),
                                    ),
                                  ),
                                  title: Text(
                                    dest.name,
                                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${dest.categoryName} • Tiket: ${dest.ticketPrice > 0 ? "Rp ${dest.ticketPrice.toInt()}" : "Gratis/Donasi"}',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.outline),
                                  onTap: () {
                                    Navigator.pop(sheetCtx);
                                    provider.sendMessage(
                                      'Bagaimana rute, harga tiket, fasilitas, dan waktu terbaik berkunjung ke ${dest.name}?',
                                    );
                                    _scrollToBottom();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Menampilkan modal riwayat percakapan pengguna dengan AI
  void _showChatHistoryModal(BuildContext context, AiAssistantProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            final sessions = provider.historySessions;

            return SafeArea(
              child: Container(
                height: MediaQuery.of(sheetCtx).size.height * 0.65,
                padding: const EdgeInsets.fromLTRB(AppDimensions.margin, 16, AppDimensions.margin, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Riwayat Obrolan AI',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Tombol Buat Room Chat Baru
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.add_comment_outlined, size: 18),
                        label: const Text(
                          '+ Room Chat Baru',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          provider.startNewSession(autoSavePrevious: true);
                          Navigator.pop(sheetCtx);
                          _scrollToBottom();
                        },
                      ),
                    ),

                    Expanded(
                      child: sessions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.outline),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada riwayat obrolan.',
                                    style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Setiap obrolan Anda dengan Jagawana AI akan otomatis tersimpan di sini.',
                                    style: AppTypography.bodySm.copyWith(color: AppColors.outlineVariant),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: sessions.length,
                              separatorBuilder: (ctx, index) => const Divider(height: 1),
                              itemBuilder: (_, idx) {
                                final session = sessions[idx];
                                final isCurrent = session.id == provider.currentSessionId;
                                final userMsgCount = session.messages.where((m) => m.isUser).length;

                                String formattedTime = '';
                                try {
                                  final dt = DateTime.parse(session.createdAt).toLocal();
                                  final months = [
                                    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                                    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
                                  ];
                                  final day = dt.day.toString().padLeft(2, '0');
                                  final month = months[dt.month - 1];
                                  final hour = dt.hour.toString().padLeft(2, '0');
                                  final min = dt.minute.toString().padLeft(2, '0');
                                  formattedTime = '$day $month, $hour:$min';
                                } catch (_) {
                                  formattedTime = session.createdAt;
                                }

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isCurrent ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCurrent ? Icons.chat_bubble : Icons.chat_bubble_outline,
                                      size: 20,
                                      color: isCurrent ? Colors.white : AppColors.primary,
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session.title,
                                          style: AppTypography.titleSmall.copyWith(
                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                            color: isCurrent ? AppColors.primary : AppColors.onSurface,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isCurrent)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            'Aktif',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    '$formattedTime • $userMsgCount pesan pengguna',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.outline),
                                    tooltip: 'Hapus Obrolan',
                                    onPressed: () {
                                      provider.deleteSession(session.id);
                                      setSheetState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    provider.loadSession(session.id);
                                    Navigator.pop(sheetCtx);
                                    _scrollToBottom();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
          'Jagawana MeraTrip AI Assistant',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: AppColors.onSurfaceVariant),
            tooltip: 'Riwayat Chat',
            onPressed: () => _showChatHistoryModal(context, aiProvider),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.onSurfaceVariant),
            tooltip: 'Room Chat Baru',
            onPressed: () {
              aiProvider.startNewSession(autoSavePrevious: true);
              _textController.clear();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Memulai room chat baru.'),
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
              const SizedBox(height: 8),

              // 1. Quick Prompts Horizontal Scroll
              _buildQuickPrompts(aiProvider),

              // 2. Conversation Flow
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
                        'Jagawana AI sedang merancang rute...',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // 3. Pinned Ergonomic Floating Input Bar
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

  // 1. Quick Prompts Horizontal Scroll
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

  // 2. User Message Bubble (Align Right)
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

  // 3. AI Message Bubble (Align Left, with Rich Itinerary Card)
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
                  'Jagawana AI',
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    rec.totalDuration,
                                    style: AppTypography.titleSmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Text(
                            rec.title,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Metadata Chips
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
                                      Text(
                                        'Estimasi Tiket',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        rec.estimatedTicket,
                                        style: AppTypography.bodySm.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                                      Text(
                                        'Aksesibilitas',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        rec.accessibility,
                                        style: AppTypography.bodySm.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Stops Timeline
                          ...rec.stops.map((stop) => _buildStopCard(stop)),

                          if (rec.proTip.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFFD97706)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      rec.proTip,
                                      style: AppTypography.bodySm.copyWith(
                                        color: const Color(0xFF92400E),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),

                          // Adopt CTA Buttons
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final success = await context.read<AiAssistantProvider>().adoptItineraryToMyTrip(
                                          tripProvider,
                                          userId: userId,
                                          customRec: rec,
                                        );

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Rute "${rec.title}" berhasil disimpan ke My Trip!'
                                                : 'Gagal mengadopsi rute.',
                                          ),
                                          backgroundColor: success ? AppColors.secondary : AppColors.error,
                                          action: success
                                              ? SnackBarAction(
                                                  label: 'Lihat Trip',
                                                  textColor: Colors.white,
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(builder: (_) => const MyTripScreen()),
                                                    );
                                                  },
                                                )
                                              : null,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.playlist_add_check, size: 18),
                                  label: const Text('Simpan ke My Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.onPrimary,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: OutlinedButton(
                                  onPressed: () {
                                    tripProvider.initBuilderTrip(empty: true);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                    ),
                                  ),
                                  child: const Text('Kustomisasi Rute', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (msg.followUpText != null && msg.followUpText!.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      msg.followUpText!,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildStopCard(ItineraryStopModel stop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stop.timeRange,
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    fontSize: 10,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stop.ticketBadge,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            stop.name,
            style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            child: SizedBox(
              width: double.infinity,
              height: 110,
              child: Image.network(
                stop.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(
                  color: AppColors.surfaceContainerLow,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: AppColors.outline),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stop.description,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedAiText(String text) {
    final cleanText = _cleanStrayAsterisks(text);
    final paragraphs = cleanText.split('\n\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.map((p) {
        if (p.trim().isEmpty) return const SizedBox.shrink();

        final lines = p.split('\n');
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: lines.map((line) {
              final trimmed = line.trim();
              if (trimmed.isEmpty) return const SizedBox.shrink();

              if (trimmed.startsWith('•') || trimmed.startsWith('-')) {
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          trimmed.substring(1).trim(),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Text(
                trimmed,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  String _cleanStrayAsterisks(String str) {
    return str.replaceAll('**', '').replaceAll('*', '');
  }

  // 4. Floating Bottom Input Bar (Icon Lokasi Berfungsi & Icon Suara Dihapus)
  Widget _buildFloatingInputBar(BuildContext context, AiAssistantProvider provider) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppDimensions.margin, 8, AppDimensions.margin, 12),
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
              // Icon Tambah Lokasi: Membuka Daftar Destinasi untuk Ditanyakan ke AI
              IconButton(
                icon: const Icon(Icons.add_location_alt, size: 20, color: AppColors.primary),
                tooltip: 'Pilih Destinasi',
                onPressed: () => _showSelectDestinationBottomSheet(context, provider),
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
              // Icon suara dihapus sesuai permintaan
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
      ),
    );
  }
}
