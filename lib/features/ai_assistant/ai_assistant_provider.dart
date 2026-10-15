import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../core/services/gemini_service.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../trip/trip_provider.dart';
import 'ai_chat_model.dart';

class AiAssistantProvider extends ChangeNotifier {
  bool _isTyping = false;

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

  List<ChatMessage> _messages = [
    const ChatMessage(
      id: 'msg-welcome',
      isUser: false,
      text:
          'Halo! Saya Jagawana AI, asisten cerdas resmi MeraTrip. Saya siap merekomendasikan rute wisata lereng Merapi yang aman, info tiket terverifikasi, dan itinerary terbaik untukmu.',
      time: '08:00',
      recommendation: _defaultRecommendation,
      followUpText: 'Mau coba jelajahi rute rekomendasi di atas?',
    ),
  ];

  AiAssistantProvider() {
    GeminiService().init().then((_) {
      notifyListeners();
    });
  }

  /// Notifikasi perubahan kunci API
  void notifyKeyChanged() {
    notifyListeners();
  }

  String? _selectedQuickPrompt;

  // Getters
  bool get isTyping => _isTyping;
  List<String> get quickPrompts => _quickPrompts;
  List<ChatMessage> get messages => _messages;
  ItineraryRecommendation get defaultRecommendation => _defaultRecommendation;
  String? get selectedQuickPrompt => _selectedQuickPrompt;

  /// Memilih quick prompt rekomendasi
  Future<void> selectQuickPrompt(String prompt) async {
    _selectedQuickPrompt = prompt;
    await sendMessage(prompt);
  }

  /// Mengirim pesan dari pengguna ke AI Assistant
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      isUser: true,
      text: text,
      time: 'Sekarang',
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

          // Parsing rekomendasi jika ada
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

    // 3. Mesin Cerdas Jagawana jika Gemini API sibuk, kuota habis, atau tidak ada internet
    if (aiResponseText == null) {
      final offlineResult = _generateSmartMerapiResponse(text);
      aiResponseText = offlineResult.$1;
      rec = offlineResult.$2;
    }

    final aiMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch + 1}',
      isUser: false,
      text: aiResponseText,
      time: 'Sekarang',
      recommendation: rec,
      followUpText: 'Apakah ada destinasi lain yang ingin kamu tanyakan pada Jagawana AI?',
    );

    _messages.add(aiMsg);
    _isTyping = false;
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
      quotaNote = '\n\n💡 Info: Kuota AI cloud sedang padat. Jawaban disajikan langsung oleh Asisten Jagawana Terverifikasi.';
    }

    // 1. Wisata Keluarga / Anak / Santai
    if (lower.contains('keluarga') || lower.contains('anak') || lower.contains('santai') || lower.contains('ramah')) {
      final familyRec = ItineraryRecommendation(
        title: 'Wisata Edukasi & Rekreasi Ramah Keluarga',
        categoryBadge: 'Ramah Keluarga & Anak',
        totalDuration: '~3.5 Jam',
        estimatedTicket: 'Rp 65.000/org',
        accessibility: 'Jalan Aspal Landai, Aman Kereta Bayi',
        stops: [
          const ItineraryStopModel(
            timeRange: '08:30 - 10:30',
            name: 'Museum Ullen Sentalu',
            ticketBadge: 'Tiket Rp 50.000',
            description: 'Wisata budaya Jawa bernuansa sejuk, asri, dan aman untuk anak serta lansia.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAT5SWRj9svCiCBlgYQx-zjjhyIZQ5obyW29TwX8hzE5Kypnjt2XCT_aIxPg_VVv7WgrpGcCDqPyRVRXO4KbCMAz0DGV5uxOBVT1Xmb7iR5rzWOf_rSa3MzPiIhKT5twdqV6OFikGTSio858GCmZgcX2T__egyhyosgIhO3w5SnZZMjhWC2sbCeWnE8mHLxuV9z6LVj8ogmkLQSxHfEXY8KWYkJDjxiMoNk576yo3CyJTti8_Sacqg',
          ),
          const ItineraryStopModel(
            timeRange: '10:45 - 12:00',
            name: 'Taman Rekreasi Kaliurang',
            ticketBadge: 'Tiket Rp 10.000',
            description: 'Taman bermain teduh dengan arena playground dan udara segar khas Kaliurang.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDnewMUxraaoMgsDZ14E3ySpfnSJs9bnzZp8wc3RA9G4TaYAPVbF-yXiIze2KnRF2wueiIbn18uKgQ8S9drhcNBbCqUqQZeHd0NWHAHkp5uK372tlpHMyrhEX-myc5cT-_TXk_FxMNaOtVDhqATfeK6GbLPdxMUL0VBA8hRQphwhCUZG2ag3fIQTa0SEwlEtabIDrS3DnLItFzeyxZbRQREoQr8RWceeWsfClw-XeroHn2zTERL4Rw',
          ),
        ],
        proTip: 'Bawa jaket tipis untuk anak-anak dan nikmati kuliner jadah tempe hangat di sekitar Kaliurang.',
      );

      return (
        'Untuk liburan keluarga yang nyaman dan aman, kawasan Kaliurang bawah sangat ideal! Jalur perjalanan mudah diakses mobil dan stroller dengan suasana yang sejuk:$quotaNote',
        familyRec,
      );
    }

    // 2. Petualangan Trekking & Panorama Alam
    if (lower.contains('petualangan') || lower.contains('trekking') || lower.contains('jalur') || lower.contains('alam')) {
      final adventureRec = ItineraryRecommendation(
        title: 'Petualangan Alam Merapi',
        categoryBadge: 'Petualangan & Panorama',
        totalDuration: '~3 Jam',
        estimatedTicket: 'Rp 25.000 / orang',
        accessibility: 'Jalur Trekking & Aspal Pegunungan',
        stops: [
          const ItineraryStopModel(
            timeRange: '06:00 - 07:30',
            name: 'Bukit Klangon',
            ticketBadge: 'Rp 10.000',
            description: 'Menikmati golden sunrise dan panorama kawah aktif Merapi dari jarak 4 km.',
            imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAT5SWRj9svCiCBlgYQx-zjjhyIZQ5obyW29TwX8hzE5Kypnjt2XCT_aIxPg_VVv7WgrpGcCDqPyRVRXO4KbCMAz0DGV5uxOBVT1Xmb7iR5rzWOf_rSa3MzPiIhKT5twdqV6OFikGTSio858GCmZgcX2T__egyhyosgIhO3w5SnZZMjhWC2sbCeWnE8mHLxuV9z6LVj8ogmkLQSxHfEXY8KWYkJDjxiMoNk576yo3CyJTti8_Sacqg',
          ),
          const ItineraryStopModel(
            timeRange: '08:00 - 09:30',
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
        _defaultRecommendation,
      );
    }

    // 4. Plunyon Kalikuning spesifik
    if (lower.contains('plunyon') || lower.contains('kalikuning')) {
      return (
        'Plunyon Kalikuning adalah destinasi ikonik dengan jembatan gantung berlatar tebing hijau pinus dan Gunung Merapi yang megah (lokasi syuting film KKN di Desa Penari).\n\n'
        '• Tiket Masuk: Rp 12.000 / orang.\n'
        '• Jam Buka: 07.00 - 16.00 WIB.\n'
        '• Aktivitas: Foto di jembatan gantung, trekking sungai bebatuan, dan menikmati gemericik air kali sejuk.$quotaNote',
        _defaultRecommendation,
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
        _defaultRecommendation,
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
        _defaultRecommendation,
      );
    }

    // 8. Default Rute & Rekomendasi Umum
    return (
      'Halo! Saya Jagawana AI, pemandu resmi kawasan Merapi. Saya siap membantu kamu merencanakan rute liburan, info tiket terverifikasi, dan keselamatan perjalanan.\n\n'
      'Berikut adalah rute tur terfavorit yang direkomendasikan untuk eksplorasi Merapi hari ini:$quotaNote',
      _defaultRecommendation,
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

  /// Mengosongkan riwayat obrolan AI
  void clearChat() {
    _messages = [];
    GeminiService().resetChat();
    notifyListeners();
  }
}
