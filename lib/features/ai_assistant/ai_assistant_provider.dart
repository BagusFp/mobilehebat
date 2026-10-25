import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gemini_service.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../trip/trip_provider.dart';
import 'ai_chat_model.dart';

class AiAssistantProvider extends ChangeNotifier {
  static const String _historyPrefsKey = 'ai_chat_history_sessions';

  bool _isTyping = false;
  String _currentSessionId = 'session_initial';
  List<AiChatSession> _historySessions = [];

  final List<String> _quickPrompts = const [
    '🗺️ Buat itinerary 1 hari',
    '👨‍👩‍👧‍👦 Wisata ramah keluarga',
    '💸 Budget di bawah Rp 100rb',
    '📸 Spot foto pagi terbaik',
  ];

  static const ItineraryRecommendation _defaultRecommendation = ItineraryRecommendation(
    title: 'Rute Pine & Heritage Merapi',
    categoryBadge: 'Ramah Anak & Lansia',
    totalDuration: '~4 Jam',
    estimatedTicket: 'Rp 22.000/org',
    accessibility: 'Jalan Landai',
    stops: [
      ItineraryStopModel(
        timeRange: '08:00 - 09:30',
        name: '1. Jembatan Gantung Plunyon Kalikuning',
        ticketBadge: 'Tiket Rp 12.000',
        description:
            'Udara sejuk dengan pemandangan pinus yang rindang. Jalur paving ramah untuk kereta dorong bayi dan jalan santai.',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAxs1ZRG_JYRdao6KZbp90pfUuYWEqGyJM8OkwB-Q8IkvSBkwdC4kBI3UifSPp-UqlaZthO9AwYXZJZK7BPO9Iq0rmgobdodQcqlWVKYAe0AV9KB3_9vSXsxtl0SXqNh0D9KlZycgTCSMvRq5NZfNwZlZhiZmgI-f50c8DVNrMh3xlYUOd5cGl9D4ytvL6Grc_sQNXINF1ETRO7VAgPTwTKgo_OZqiM5aVfuHmbXl063UP4YHwxURc',
      ),
      ItineraryStopModel(
        timeRange: '09:45 - 11:00',
        name: '2. Bunker Kaliadem',
        ticketBadge: 'Tiket Rp 10.000',
        description:
            'Melihat puncak Merapi dari jarak dekat. Anak-anak bisa belajar tentang sejarah erupsi dan struktur bunker penyelamat.',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuD__JTBQcN2VsrNHKnYZ3FxiZdpsu2-fckBgW-YFTPB2_IwRsWRTY0ZzPK3EY0nOTR9Jaut-9xVIAY7bJ0r5GeR5Bp6WKDYOBF8nqbDwSw2iRpvqT-lu6DRI-DJ3fgMNSdprlLU4CPEld1KWrAocN1GBaG6J3iyYnlEw9_cvpKjcZAeSyY_sWN4k8zIzEvVJH4PvHj12yNDoQ4qetdwZJVqvmwcvyYcl_Kf_2lp-GWVsts1KsPJGgk',
      ),
      ItineraryStopModel(
        timeRange: '11:15 - 12:00',
        name: '3. Museum Mini Sisa Hartaku',
        ticketBadge: 'Donasi Sukarela',
        description:
            'Edukasi menyentuh tentang kedahsyatan awan panas Merapi tahun 2010. Ada warung jajanan tradisional wedang ronde di dekat area.',
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDnewMUxraaoMgsDZ14E3ySpfnSJs9bnzZp8wc3RA9G4TaYAPVbF-yXiIze2KnRF2wueiIbn18uKgQ8S9drhcNBbCqUqQZeHd0NWHAHkp5uK372tlpHMyrhEX-myc5cT-_TXk_FxMNaOtVDhqATfeK6GbLPdxMUL0VBA8hRQphwhCUZG2ag3fIQTa0SEwlEtabIDrS3DnLItFzeyxZbRQREoQr8RWceeWsfClw-XeroHn2zTERL4Rw',
      ),
    ],
    proTip:
        'Bawa jaket tipis untuk si kecil karena angin Kaliadem cukup kencang sebelum pukul 11 siang. Jangan lupa siapkan uang pas untuk parkir (Rp 5.000/mobil).',
  );

  static ChatMessage _createDefaultWelcomeMessage() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return ChatMessage(
      id: 'msg-welcome-${now.millisecondsSinceEpoch}',
      isUser: false,
      text: 'Halo! Saya Jagawana AI. Ada yang bisa saya bantu untuk rencana wisatamu di lereng Merapi hari ini?',
      time: '$hour:$minute',
    );
  }

  late List<ChatMessage> _messages;
  String? _selectedQuickPrompt;

  AiAssistantProvider() {
    _messages = [_createDefaultWelcomeMessage()];
    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

    GeminiService().init().then((_) {
      notifyListeners();
    });

    _loadSessionsFromPrefs();
  }

  // Getters
  bool get isTyping => _isTyping;
  List<String> get quickPrompts => _quickPrompts;
  List<ChatMessage> get messages => _messages;
  ItineraryRecommendation get defaultRecommendation => _defaultRecommendation;
  String? get selectedQuickPrompt => _selectedQuickPrompt;
  String get currentSessionId => _currentSessionId;
  List<AiChatSession> get historySessions => List.unmodifiable(_historySessions);

  /// Notifikasi perubahan kunci API
  void notifyKeyChanged() {
    notifyListeners();
  }

  /// Memuat riwayat sesi obrolan dari SharedPreferences
  Future<void> _loadSessionsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_historyPrefsKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr) as List;
        _historySessions = decoded
            .map((item) => AiChatSession.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading AI history: $e');
    }
  }

  /// Menyimpan riwayat sesi ke SharedPreferences
  Future<void> _saveSessionsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _historySessions.map((s) => s.toJson()).toList();
      await prefs.setString(_historyPrefsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving AI history: $e');
    }
  }

  /// Memulai room chat yang baru (riwayat obrolan sebelumnya disimpan)
  void startNewSession({bool autoSavePrevious = true}) {
    if (autoSavePrevious) {
      _saveCurrentSessionToHistory();
    }

    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _messages = [_createDefaultWelcomeMessage()];
    _selectedQuickPrompt = null;
    _isTyping = false;
    GeminiService().resetChat();
    notifyListeners();
  }

  /// Menyimpan obrolan yang sedang aktif ke dalam daftar riwayat
  void _saveCurrentSessionToHistory() {
    final userMessages = _messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return; // Jangan simpan sesi kosong hanya sambutan

    final firstUserText = userMessages.first.text.trim();
    final sessionTitle = firstUserText.length > 35
        ? '${firstUserText.substring(0, 35)}...'
        : firstUserText;

    final existingIndex = _historySessions.indexWhere((s) => s.id == _currentSessionId);
    final session = AiChatSession(
      id: _currentSessionId,
      title: sessionTitle,
      createdAt: DateTime.now().toIso8601String(),
      messages: List.from(_messages),
    );

    if (existingIndex >= 0) {
      _historySessions[existingIndex] = session;
    } else {
      _historySessions.insert(0, session);
    }

    _saveSessionsToPrefs();
  }

  /// Membuka sesi obrolan lama dari riwayat
  void loadSession(String sessionId) {
    if (sessionId == _currentSessionId) return;

    // Simpan dulu sesi saat ini jika ada pesan pengguna
    _saveCurrentSessionToHistory();

    final found = _historySessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => AiChatSession(
        id: sessionId,
        title: 'Obrolan',
        createdAt: DateTime.now().toIso8601String(),
        messages: [_createDefaultWelcomeMessage()],
      ),
    );

    _currentSessionId = found.id;
    _messages = List.from(found.messages);
    _selectedQuickPrompt = null;
    _isTyping = false;
    notifyListeners();
  }

  /// Menghapus sesi tertentu dari riwayat
  void deleteSession(String sessionId) {
    _historySessions.removeWhere((s) => s.id == sessionId);
    _saveSessionsToPrefs();

    if (_currentSessionId == sessionId) {
      startNewSession(autoSavePrevious: false);
    } else {
      notifyListeners();
    }
  }

  /// Menghapus seluruh riwayat chat
  void clearAllHistory() {
    _historySessions.clear();
    _saveSessionsToPrefs();
    startNewSession(autoSavePrevious: false);
  }

  /// Memilih quick prompt rekomendasi
  Future<void> selectQuickPrompt(String prompt) async {
    _selectedQuickPrompt = prompt;
    await sendMessage(prompt);
  }

  /// Mengirim pesan dari pengguna ke AI Assistant
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    final userMsg = ChatMessage(
      id: 'msg-${now.millisecondsSinceEpoch}',
      isUser: true,
      text: text,
      time: '$hour:$minute',
    );
    _messages.add(userMsg);
    _isTyping = true;
    notifyListeners();

    // 1. Prioritas Utama: Hubungi Google Gemini AI langsung via REST API (tanpa server lokal)
    String? aiResponseText;
    ItineraryRecommendation? rec;

    try {
      final geminiRes = await GeminiService().sendMessage(text);
      if (geminiRes != null && geminiRes.text.isNotEmpty) {
        aiResponseText = geminiRes.text;
        rec = geminiRes.recommendation;
      }
    } catch (e) {
      debugPrint('GeminiService REST API langsung gagal: $e');
    }

    // 2. Backup Sekunder: Coba hubungi via Backend Laravel jika tersedia
    if (aiResponseText == null) {
      try {
        final backendRes = await ApiService.chatWithGemini(
          message: text,
        );

        if (backendRes != null && backendRes['text'] != null) {
          aiResponseText = backendRes['text'] as String;

          if (backendRes['recommendation'] is Map) {
            final r = backendRes['recommendation'] as Map<String, dynamic>;
            final stopsList = <ItineraryStopModel>[];
            if (r['stops'] is List) {
              for (final s in r['stops']) {
                stopsList.add(ItineraryStopModel(
                  timeRange: s['timeRange'] ?? 'Pagi/Siang',
                  name: s['name'] ?? 'Destinasi',
                  ticketBadge: s['ticketBadge'] ?? 'Tiket Masuk',
                  description: s['description'] ?? 'Eksplorasi lereng Merapi',
                  imageUrl: s['imageUrl'] ?? 'https://lh3.googleusercontent.com/aida-public/AB6AXuAT5SWRj9svCiCBlgYQx-zjjhyIZQ5obyW29TwX8hzE5Kypnjt2XCT_aIxPg_VVv7WgrpGcCDqPyRVRXO4KbCMAz0DGV5uxOBVT1Xmb7iR5rzWOf_rSa3MzPiIhKT5twdqV6OFikGTSio858GCmZgcX2T__egyhyosgIhO3w5SnZZMjhWC2sbCeWnE8mHLxuV9z6LVj8ogmkLQSxHfEXY8KWYkJDjxiMoNk576yo3CyJTti8_Sacqg',
                ));
              }
            }
            if (stopsList.isNotEmpty) {
              rec = ItineraryRecommendation(
                title: r['title'] ?? 'Rekomendasi Rute Wisata Merapi',
                categoryBadge: r['categoryBadge'] ?? 'Wisata Terverifikasi',
                totalDuration: r['totalDuration'] ?? '~4 Jam',
                estimatedTicket: r['estimatedTicket'] ?? 'Terjangkau',
                accessibility: r['accessibility'] ?? 'Jalur Aspal & Paving',
                stops: stopsList,
                proTip: r['proTip'] ?? 'Tetap utamakan keselamatan dan periksa status vulkanik terkini.',
              );
            }
          }
        }
      } catch (_) {}
    }

    // 3. Mesin Cerdas MeraTrip AI jika Gemini API sibuk, kuota habis, atau tidak ada internet
    if (aiResponseText == null) {
      final offlineResult = _generateSmartMerapiResponse(text);
      aiResponseText = offlineResult.$1;
      rec = offlineResult.$2;
    }

    final respNow = DateTime.now();
    final respHour = respNow.hour.toString().padLeft(2, '0');
    final respMin = respNow.minute.toString().padLeft(2, '0');

    final aiMsg = ChatMessage(
      id: 'msg-${respNow.millisecondsSinceEpoch + 1}',
      isUser: false,
      text: aiResponseText,
      time: '$respHour:$respMin',
      recommendation: rec,
      followUpText: 'Apakah ada destinasi lain yang ingin kamu tanyakan pada Jagawana AI?',
    );

    _messages.add(aiMsg);
    _isTyping = false;

    // Simpan otomatis update sesi ke riwayat
    _saveCurrentSessionToHistory();
    notifyListeners();
  }

  /// Mesin cerdas lokal berbasis data destinasi lereng Merapi terverifikasi
  (String, ItineraryRecommendation?) _generateSmartMerapiResponse(String text) {
    final lower = text.toLowerCase();
    final geminiService = GeminiService();
    final bool isQuotaExceeded = geminiService.lastError?.contains('429') == true ||
        geminiService.lastError?.contains('Quota exceeded') == true ||
        geminiService.lastError?.contains('RESOURCE_EXHAUSTED') == true;

    String quotaNote = '';
    if (isQuotaExceeded) {
      quotaNote = '\n\n💡 Info: Kuota AI cloud sedang padat. Jawaban disajikan langsung oleh Jagawana AI Terverifikasi.';
    }

    // 1. Wisata Keluarga / Anak / Santai
    if (lower.contains('keluarga') || lower.contains('anak') || lower.contains('santai') || lower.contains('ramah')) {
      final familyRec = ItineraryRecommendation(
        title: 'Wisata Edukasi & Rekreasi Keluarga',
        categoryBadge: 'Ramah Keluarga',
        totalDuration: '~3.5 Jam',
        estimatedTicket: 'Rp 30.000/org',
        accessibility: 'Aman untuk Stroller & Lansia',
        stops: const [
          ItineraryStopModel(
            timeRange: '08:30 - 10:00',
            name: 'Kaliurang Park Botanical Garden',
            ticketBadge: 'Rp 25.000',
            description: 'Taman bunga, flying fox aman untuk anak, dan playground rindang berhawa sejuk.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAT5SWRj9svCiCBlgYQx-zjjhyIZQ5obyW29TwX8hzE5Kypnjt2XCT_aIxPg_VVv7WgrpGcCDqPyRVRXO4KbCMAz0DGV5uxOBVT1Xmb7iR5rzWOf_rSa3MzPiIhKT5twdqV6OFikGTSio858GCmZgcX2T__egyhyosgIhO3w5SnZZMjhWC2sbCeWnE8mHLxuV9z6LVj8ogmkLQSxHfEXY8KWYkJDjxiMoNk576yo3CyJTti8_Sacqg',
          ),
          ItineraryStopModel(
            timeRange: '10:15 - 11:30',
            name: 'Museum Mini Sisa Hartaku',
            ticketBadge: 'Donasi Sukarela',
            description: 'Mengenalkan sejarah letusan Merapi dan nilai-nilai ketangguhan masyarakat.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDnewMUxraaoMgsDZ14E3ySpfnSJs9bnzZp8wc3RA9G4TaYAPVbF-yXiIze2KnRF2wueiIbn18uKgQ8S9drhcNBbCqUqQZeHd0NWHAHkp5uK372tlpHMyrhEX-myc5cT-_TXk_FxMNaOtVDhqATfeK6GbLPdxMUL0VBA8hRQphwhCUZG2ag3fIQTa0SEwlEtabIDrS3DnLItFzeyxZbRQREoQr8RWceeWsfClw-XeroHn2zTERL4Rw',
          ),
        ],
        proTip: 'Sangat cocok dikunjungi sebelum terik siang. Banyak penjual jadah tempe hangat legendaris di sekitar Kaliurang.',
      );

      return (
        'Berikut rekomendasi perjalanan wisata yang sangat ramah untuk liburan keluarga:$quotaNote',
        familyRec,
      );
    }

    // 2. Petualangan / Jeep / Alam
    if (lower.contains('jeep') || lower.contains('petualangan') || lower.contains('adventure') || lower.contains('lava')) {
      final adventureRec = ItineraryRecommendation(
        title: 'Ekspedisi Lava Tour & Alam Merapi',
        categoryBadge: 'Petualangan Alam',
        totalDuration: '~4.5 Jam',
        estimatedTicket: 'Rp 350.000 - Rp 450.000 / Jeep (4-5 orang)',
        accessibility: 'Off-road Sedang',
        stops: const [
          ItineraryStopModel(
            timeRange: '07:30 - 09:30',
            name: 'Merapi Lava Tour Jeep',
            ticketBadge: 'Paket Short/Medium',
            description: 'Menyusuri bekas aliran lahar dingin, manuver air Kali Kuning, dan batu alien.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD__JTBQcN2VsrNHKnYZ3FxiZdpsu2-fckBgW-YFTPB2_IwRsWRTY0ZzPK3EY0nOTR9Jaut-9xVIAY7bJ0r5GeR5Bp6WKDYOBF8nqbDwSw2iRpvqT-lu6DRI-DJ3fgMNSdprlLU4CPEld1KWrAocN1GBaG6J3iyYnlEw9_cvpKjcZAeSyY_sWN4k8zIzEvVJH4PvHj12yNDoQ4qetdwZJVqvmwcvyYcl_Kf_2lp-GWVsts1KsPJGgk',
          ),
          ItineraryStopModel(
            timeRange: '09:45 - 11:00',
            name: 'Plunyon Kalikuning',
            ticketBadge: 'Rp 12.000',
            description: 'Trekking ringan melintasi jembatan gantung berlatar hutan pinus asri.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDnewMUxraaoMgsDZ14E3ySpfnSJs9bnzZp8wc3RA9G4TaYAPVbF-yXiIze2KnRF2wueiIbn18uKgQ8S9drhcNBbCqUqQZeHd0NWHAHkp5uK372tlpHMyrhEX-myc5cT-_TXk_FxMNaOtVDhqATfeK6GbLPdxMUL0VBA8hRQphwhCUZG2ag3fIQTa0SEwlEtabIDrS3DnLItFzeyxZbRQREoQr8RWceeWsfClw-XeroHn2zTERL4Rw',
          ),
        ],
        proTip: 'Gunakan sepatu trekking atau sneakers yang nyaman dan bawa jaket hangat di pagi hari.',
      );

      return (
        'Petualangan alam Merapi menawarkan udara segar dan pemandangan kawah menakjubkan:$quotaNote',
        adventureRec,
      );
    }

    // 3. Bunker Kaliadem spesifik
    if (lower.contains('bunker') || lower.contains('kaliadem')) {
      return (
        'Bunker Kaliadem terletak di elevasi 1.165 mdpl di Dusun Kinahrejo, Cangkringan.\n\n'
        '• Tiket Masuk: Rp 10.000 / orang (parkir Rp 5.000).\n'
        '• Jam Buka: 06.00 - 17.00 WIB.\n'
        '• Waktu Terbaik: Pukul 05.30 - 08.00 WIB untuk melihat puncak kawah Merapi tanpa tertutup kabut.\n'
        '• Akses: Bisa dijangkau sepeda motor atau mobil pribadi melalui jalan aspal halus.$quotaNote',
        null,
      );
    }

    // 4. Plunyon Kalikuning spesifik
    if (lower.contains('plunyon') || lower.contains('kalikuning')) {
      return (
        'Plunyon Kalikuning adalah destinasi ikonik dengan jembatan gantung berlatar tebing hijau pinus dan Gunung Merapi yang megah (lokasi syuting film KKN di Desa Penari).\n\n'
        '• Tiket Masuk: Rp 12.000 / orang.\n'
        '• Jam Buka: 07.00 - 16.00 WIB.\n'
        '• Aktivitas: Foto di jembatan gantung, trekking sungai bebatuan, dan menikmati gemericik air kali sejuk.$quotaNote',
        null,
      );
    }

    // 5. Tiket / Harga / Budget
    if (lower.contains('tiket') || lower.contains('harga') || lower.contains('biaya') || lower.contains('budget') || lower.contains('hemat')) {
      return (
        'Daftar harga tiket masuk destinasi wisata terverifikasi Merapi:\n\n'
        '1. Bunker Kaliadem: Rp 10.000 / orang\n'
        '2. Plunyon Kalikuning: Rp 12.000 / orang\n'
        '3. Bukit Klangon Glamping: Rp 5.000 / orang\n'
        '4. Museum Sisa Hartaku: Donasi sukarela (Rp 5.000 - Rp 10.000)\n'
        '5. Museum Ullen Sentalu: Rp 50.000 / orang (termasuk guide)\n\n'
        'Untuk paket hemat 1 hari, kamu cukup menyiapkan budget tiket sekitar Rp 25.000 - Rp 30.000 saja per orang!$quotaNote',
        null,
      );
    }

    // 6. Keselamatan / Status Merapi / Aman
    if (lower.contains('aman') || lower.contains('status') || lower.contains('bahaya') || lower.contains('erupsi') || lower.contains('radius')) {
      return (
        'Informasi Keselamatan Gunung Merapi:\n\n'
        '• Status Aktivitas: Level III (Siaga).\n'
        '• Rekomendasi Zona Aman: Sektor selatan-barat daya aman di luar radius 5 km, dan sektor tenggara aman di luar radius 3 km.\n'
        '• Seluruh destinasi wisata umum seperti Kaliurang, Plunyon, Bunker Kaliadem, dan desa wisata berada di zona AMAN terverifikasi BPBD dan Jagawana.\n'
        '• Tips: Selalu perhatikan arahan petugas loket keselamatan.$quotaNote',
        null,
      );
    }

    // 7. Spot Foto / Sunrise
    if (lower.contains('foto') || lower.contains('spot') || lower.contains('sunrise') || lower.contains('instagram')) {
      return (
        'Spot foto terbaik berlatar Gunung Merapi:\n\n'
        '1. Jembatan Gantung Plunyon: Pukul 06.00 - 07.30 WIB (latar jembatan, pinus, dan puncak Merapi jernih).\n'
        '2. Pintu Masuk Bunker Kaliadem: Foto sudut rendah berlatar kerucut kawah Merapi.\n'
        '3. Bukit Klangon: Menara pandang gardu kayu hanya berjarak 4 km dari puncak kawah, sangat dramatis.\n'
        '4. Kopi Merapi: Bersantai minum kopi robusta lereng Merapi dengan pemandangan batuan sisa lava.$quotaNote',
        null,
      );
    }

    // 8. Respon Umum Destinasi / Pertanyaan
    return (
      'Halo! Saya Jagawana AI, asisten perjalanan wisatamu di kawasan lereng Merapi.\n\n'
      'Kawasan lereng Merapi menawarkan keindahan panorama alam, udara sejuk pegunungan, serta ragam edukasi mitigasi dan geowisata yang menakjubkan. '
      'Silakan tanyakan info tiket, rekomendasi rute perjalanan, spot foto, atau fasilitas destinasi yang ingin kamu kunjungi!$quotaNote',
      null,
    );
  }

  /// Mengadopsi paket itinerary rekomendasi AI langsung ke modul My Trip
  Future<bool> adoptItineraryToMyTrip(
    TripProvider tripProvider, {
    required int userId,
    ItineraryRecommendation? customRec,
  }) async {
    try {
      final activeRec = customRec ?? _defaultRecommendation;
      final items = <TripItemModel>[];

      for (var i = 0; i < activeRec.stops.length; i++) {
        final stop = activeRec.stops[i];
        items.add(TripItemModel(
          destinationId: i + 1,
          itemName: stop.name,
          itemSubtitle: stop.description,
          visitOrder: i + 1,
          plannedTime: stop.timeRange,
          durationHours: 1.25,
          estimatedCost: 15000.0,
          elevationMdpl: 900,
          connectingDistanceKm: i == 0 ? 0.0 : 3.5,
          connectingTimeMinutes: i == 0 ? 0 : 15,
        ));
      }

      final trip = TripModel(
        userId: userId,
        tripName: activeRec.title,
        startDate: '2026-10-20',
        participantCount: 2,
        targetBudget: 400000.0,
        totalEstimatedCost: 44000.0,
        status: 'draft',
        reminderEnabled: true,
        isSavedOffline: true,
        createdAt: DateTime.now().toIso8601String(),
        items: items.isNotEmpty ? items : [
          const TripItemModel(
            destinationId: 2,
            itemName: 'Plunyon Kalikuning',
            itemSubtitle: 'Spot pinus & jembatan gantung',
            visitOrder: 1,
            plannedTime: '08:00 - 09:30',
            durationHours: 1.5,
            estimatedCost: 12000.0,
            elevationMdpl: 900,
            connectingDistanceKm: 3.5,
            connectingTimeMinutes: 15,
          ),
        ],
      );

      await tripProvider.createTrip(trip);
      return true;
    } catch (e) {
      debugPrint('Error adopting trip: $e');
      return false;
    }
  }

  /// Mengosongkan riwayat obrolan AI sesi aktif
  void clearChat() {
    startNewSession(autoSavePrevious: false);
  }
}
