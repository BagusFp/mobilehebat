import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/mock/mock_destinations.dart';
import '../../data/models/destination_model.dart';
import '../../features/ai_assistant/ai_chat_model.dart';

class GeminiChatResult {
  final String text;
  final ItineraryRecommendation? recommendation;
  final String model;

  const GeminiChatResult({
    required this.text,
    this.recommendation,
    required this.model,
  });
}

/// Fungsi helper mandiri untuk tembak langsung REST API Gemini via package `http`.
/// Endpoint resmi: https://generativelanguage.googleapis.com/v1beta/models/...:generateContent?key=...
Future<String> chatWithGemini(
  String prompt, {
  String? apiKey,
  String model = 'gemini-3.7-flash',
}) async {
  final activeKey = apiKey ?? GeminiService().activeApiKey;
  final sanitizedKey = GeminiService.sanitizeApiKey(
    activeKey.isNotEmpty ? activeKey : GeminiService.defaultApiKey,
  );

  final url = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$sanitizedKey',
  );

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ]
    }),
  ).timeout(const Duration(seconds: 20));

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    final candidates = data['candidates'] as List?;
    if (candidates != null && candidates.isNotEmpty) {
      final parts = candidates[0]['content']?['parts'] as List?;
      if (parts != null && parts.isNotEmpty) {
        return (parts[0]['text'] ?? '').toString();
      }
    }
    return '';
  } else {
    throw Exception('Gagal memanggil Gemini (${response.statusCode}): ${response.body}');
  }
}

/// Service komunikasi langsung REST API ke Google Gemini.
/// Berjalan mandiri langsung dari HP pengguna (hanya butuh kuota internet),
/// tanpa memerlukan PC / laptop atau local web server (php artisan serve).
class GeminiService {
  // Kunci API resmi bawaan aplikasi (built-in) - User tinggal pakai tanpa perlu input API
  static final String defaultApiKey = utf8.decode(
    base64.decode('QVEuQWI4Uk42SXk3ZGx2RWVOMlltbjNXUnJMRVVKTG50SjA1QlpnWVJDclVLQTZjb25DcUE='),
  );
  static const String defaultModel = 'gemini-3.7-flash';
  static const String _prefApiKey = 'custom_gemini_api_key';

  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal() {
    init();
  }

  String _activeApiKey = defaultApiKey;
  String _activeModelName = defaultModel;
  final List<Map<String, dynamic>> _history = [];

  String? _lastError;
  String? get lastError => _lastError;
  String get activeApiKey => _activeApiKey;
  String get activeModelName => _activeModelName;

  /// Membersihkan API key dari karakter tersembunyi
  static String sanitizeApiKey(String key) {
    return key.replaceAll(RegExp(r'[\s\r\n\t"\x27]'), '');
  }

  /// Daftar model kandidat resmi berkecepatan tinggi yang kompatibel dengan API key
  List<String> get candidateModels => [
        'gemini-3.7-flash',
        'gemini-3.8-flash',
        'gemini-flash-latest',
        'gemini-3.5-flash-lite',
      ];

  /// Menginisialisasi service dan membaca API key bawaan
  Future<String> init({String? customApiKey, String? modelName}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefApiKey);

      if (customApiKey != null && customApiKey.trim().isNotEmpty) {
        _activeApiKey = sanitizeApiKey(customApiKey);
      } else if (savedKey != null && savedKey.trim().isNotEmpty && savedKey.startsWith('AQ.')) {
        _activeApiKey = sanitizeApiKey(savedKey);
      } else {
        _activeApiKey = sanitizeApiKey(defaultApiKey);
      }

      if (modelName != null && modelName.isNotEmpty) {
        _activeModelName = modelName;
      } else {
        _activeModelName = defaultModel;
      }

      debugPrint('GeminiService REST API siap dengan model $_activeModelName');
    } catch (e) {
      debugPrint('GeminiService.init error: $e');
    }
    return _activeApiKey;
  }

  /// Menyimpan custom API key jika diperlukan secara programmatic
  Future<void> setCustomApiKey(String apiKey) async {
    final sanitized = sanitizeApiKey(apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, sanitized);
    _activeApiKey = sanitized;
    resetChat();
  }

  /// Reset riwayat percakapan sesi chat
  void resetChat() {
    _history.clear();
  }

  /// Menguji koneksi langsung ke Google Gemini API
  Future<(bool, String)> testConnection([String? testKey]) async {
    final keyToTest = sanitizeApiKey(
      (testKey != null && testKey.isNotEmpty) ? testKey : _activeApiKey,
    );

    for (final model in candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$keyToTest',
        );
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': 'Halo, jawab satu kata: SIAP'}
                ]
              }
            ]
          }),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return (true, 'Berhasil terhubung ke Google Gemini ($model)!');
        }
      } catch (_) {}
    }
    return (false, 'Koneksi ke Gemini sedang sibuk. Silakan coba lagi.');
  }

  /// Mengirim pesan langsung ke endpoint REST API Google Generative Language
  Future<GeminiChatResult?> sendMessage(String message) async {
    _lastError = null;

    if (_activeApiKey.isEmpty) {
      await init();
    }

    final key = sanitizeApiKey(
      _activeApiKey.isNotEmpty ? _activeApiKey : defaultApiKey,
    );

    final systemPrompt = _buildSystemPrompt();

    // Tambahkan input user ke riwayat percakapan
    _history.add({
      'role': 'user',
      'parts': [
        {'text': message}
      ]
    });

    // Batasi riwayat percakapan maksimal 10 pasang (20 pesan) agar payload tetap ringan
    if (_history.length > 20) {
      _history.removeRange(0, _history.length - 20);
    }

    for (final model in candidateModels) {
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
        );

        // Siapkan request payload
        Map<String, dynamic> requestPayload = {
          'system_instruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'contents': _history,
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1500,
          }
        };

        var response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestPayload),
        ).timeout(const Duration(seconds: 15));

        // Jika model menolak system_instruction terpisah, gabungkan di user content
        if (response.statusCode != 200 && response.body.contains('system_instruction')) {
          final fallbackHistory = List<Map<String, dynamic>>.from(_history);
          if (fallbackHistory.isNotEmpty) {
            fallbackHistory[fallbackHistory.length - 1] = {
              'role': 'user',
              'parts': [
                {'text': '$systemPrompt\n\n---\nPertanyaan Pengguna: $message'}
              ]
            };
          }

          requestPayload = {
            'contents': fallbackHistory,
            'generationConfig': {
              'temperature': 0.7,
              'maxOutputTokens': 1500,
            }
          };

          response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          ).timeout(const Duration(seconds: 15));
        }

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'];
            final parts = content?['parts'] as List?;
            final rawText = (parts != null && parts.isNotEmpty)
                ? (parts[0]['text'] ?? '').toString()
                : '';

            if (rawText.isNotEmpty) {
              // Simpan respons bot ke riwayat percakapan
              _history.add({
                'role': 'model',
                'parts': [
                  {'text': rawText}
                ]
              });

              final parsed = _parseResponse(rawText);
              _activeModelName = model;
              return GeminiChatResult(
                text: parsed.$1,
                recommendation: parsed.$2,
                model: model,
              );
            }
          }
        } else {
          _lastError = 'Status ${response.statusCode}: ${response.body}';
          debugPrint('GeminiService REST API ($model) status: ${response.statusCode}');

          // Jika 503 (model sibuk sementara), lanjut ke kandidat model berikutnya
          if (response.statusCode == 503) {
            continue;
          }
          // Jika kuota habis (429)
          if (response.statusCode == 429 || response.body.contains('RESOURCE_EXHAUSTED')) {
            _lastError = '429 Quota exceeded (RESOURCE_EXHAUSTED)';
            break;
          }
        }
      } catch (e) {
        _lastError = e.toString();
        debugPrint('GeminiService error dengan model $model: $e');
      }
    }

    // Jika semua model gagal, hapus prompt user terakhir agar sesi tidak desinkronisasi
    if (_history.isNotEmpty && _history.last['role'] == 'user') {
      _history.removeLast();
    }

    return null;
  }

  /// Membangun system instruction berbasis destinasi nyata di lereng Merapi
  String _buildSystemPrompt() {
    final dests = MockDestinations.destinations;
    final destSummary = dests.map((d) {
      return '- [ID ${d.id}] ${d.name} (${d.categoryName}) | Tiket: ${d.ticketPriceLabel} | Elevasi: ${d.elevationMdpl} mdpl | Durasi: ${d.estimatedDuration} | Lokasi: ${d.address}';
    }).join('\n');

    return '''
Kamu adalah "Jagawana AI", asisten cerdas resmi aplikasi MeraTrip untuk perencanaan wisata kawasan Gunung Merapi, Yogyakarta.

PANDUAN UTAMA:
1. Bersikap ramah, sopan, informatif, dan utamakan keselamatan wisata Merapi (zona aman > 3 km dari puncak kawah aktif Merapi, status Siaga Level II).
2. Jangan pernah mengarang harga tiket atau destinasi fiktif. Selalu gunakan referensi destinasi terverifikasi di bawah ini:
$destSummary

3. PANDUAN FORMAT TEKS:
- PENTING: JANGAN gunakan simbol bintang atau asteris (** atau *) untuk menebalkan teks atau membuat poin. Tuliskan jawaban dalam format kalimat yang bersih, mengalir, dan rapi tanpa tanda formatting seperti **kata**.
- Jika membuat daftar, gunakan penomoran angka biasa (1., 2., 3.) atau tanda strip (-), bukan tanda bintang (*).

4. Jika pengguna meminta rekomendasi wisata, rute perjalanan, tur 1 hari/setengah hari, atau itinerary, berikan penjelasan bersahabat dan sertakan rekomendasi terstruktur di akhir jawaban dalam format blok JSON terpisah persis seperti ini:
```json
{
  "title": "Nama Paket Rute",
  "categoryBadge": "Misal: Ramah Keluarga / Petualangan Sejuk",
  "totalDuration": "~4 Jam",
  "estimatedTicket": "Rp 25.000/org",
  "accessibility": "Jalan Landai / Aspal & Paving",
  "stops": [
    {
      "name": "1. Nama Destinasi",
      "timeRange": "08:00 - 09:30",
      "ticketBadge": "Tiket Rp 10.000",
      "description": "Aktivitas menarik dan tips singkat di lokasi."
    }
  ],
  "proTip": "Tips penting cuaca, waktu terbaik, atau perlengkapan."
}
```

Pastikan blok ```json ... ``` valid dan terpisah dari narasi utama agar aplikasi dapat merendernya menjadi kartu interaktif.
''';
  }

  /// Memisahkan teks jawaban dengan kartu JSON rekomendasi jika ada
  (String, ItineraryRecommendation?) _parseResponse(String rawText) {
    ItineraryRecommendation? recommendation;
    String cleanText = rawText;

    final regExp = RegExp(r'```json\s*(\{[\s\S]*?\})\s*```');
    final match = regExp.firstMatch(rawText);

    if (match != null) {
      try {
        final jsonStr = match.group(1);
        if (jsonStr != null) {
          final data = jsonDecode(jsonStr) as Map<String, dynamic>;
          final stopsList = <ItineraryStopModel>[];

          if (data['stops'] is List) {
            for (final s in data['stops']) {
              final stopName = (s['name'] ?? 'Destinasi').toString();
              final matchedDest = _findMatchingDestination(stopName);
              final imgUrl = s['imageUrl'] ??
                  matchedDest?.imageUrl ??
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAT5SWRj9svCiCBlgYQx-zjjhyIZQ5obyW29TwX8hzE5Kypnjt2XCT_aIxPg_VVv7WgrpGcCDqPyRVRXO4KbCMAz0DGV5uxOBVT1Xmb7iR5rzWOf_rSa3MzPiIhKT5twdqV6OFikGTSio858GCmZgcX2T__egyhyosgIhO3w5SnZZMjhWC2sbCeWnE8mHLxuV9z6LVj8ogmkLQSxHfEXY8KWYkJDjxiMoNk576yo3CyJTti8_Sacqg';

              stopsList.add(ItineraryStopModel(
                timeRange: s['timeRange'] ?? 'Pagi/Siang',
                name: stopName,
                ticketBadge: s['ticketBadge'] ?? 'Tiket Masuk',
                description: s['description'] ?? 'Eksplorasi lereng Merapi',
                imageUrl: imgUrl,
              ));
            }
          }

          if (stopsList.isNotEmpty) {
            recommendation = ItineraryRecommendation(
              title: data['title'] ?? 'Rekomendasi Rute Wisata Merapi',
              categoryBadge: data['categoryBadge'] ?? 'Wisata Terverifikasi',
              totalDuration: data['totalDuration'] ?? '~4 Jam',
              estimatedTicket: data['estimatedTicket'] ?? 'Terjangkau',
              accessibility: data['accessibility'] ?? 'Jalur Aspal & Paving',
              stops: stopsList,
              proTip: data['proTip'] ?? 'Patuhi protokol keselamatan dan pantau status vulkanik.',
            );
          }

          // Bersihkan blok json dari teks agar tidak muncul tampilan mentah di gelembung chat
          cleanText = rawText.replaceAll(match.group(0)!, '').trim();
        }
      } catch (e) {
        debugPrint('Gagal parse JSON rekomendasi dari Gemini: $e');
      }
    }

    return (cleanText, recommendation);
  }

  /// Mencocokkan nama stop dengan destinasi lokal untuk mengambil foto asli
  DestinationModel? _findMatchingDestination(String name) {
    final lower = name.toLowerCase();
    for (final d in MockDestinations.destinations) {
      if (lower.contains(d.name.toLowerCase()) || d.name.toLowerCase().contains(lower)) {
        return d;
      }
    }
    return null;
  }
}
