import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Helper kanonisasi data, pembuatan payload, dan hashing SHA-256 untuk
/// Proof of Visit MeraTrip pada jaringan blockchain Ethereum Sepolia.
///
/// PERLINDUNGAN PRIVASI PENGGUNA:
/// - Tidak menyimpan data mentah PII (Nama asli, Email, Nomor Telepon, Koordinat GPS mentah, Catatan pribadi, Pengeluaran).
/// - Menggunakan trip_identifier yang disamarkan dengan salt kriptografis.
/// - Serialisasi kanonis dengan urutan key alfabetis konsisten agar menghasilkan hash deterministik.
class BlockchainProofHelper {
  static const String currentPayloadVersion = '1.0.0';

  /// Menghasilkan random salt 32-byte berkekuatan kriptografis dalam bentuk hex
  static String generateSecureSalt() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Menghasilkan Proof ID 32-byte acak berawalan '0x' yang unik untuk smart contract
  static String generateProofId() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hex';
  }

  /// Menghasilkan identifier anonim trip dari kombinasi tripId dan salt
  static String generateTripIdentifier(int tripId, String salt) {
    final bytes = utf8.encode('meratrip_trip_${tripId}_$salt');
    final digest = sha256.convert(bytes);
    return '0x${digest.toString()}';
  }

  /// Membangun payload kanonis trip tanpa data PII
  static Map<String, dynamic> buildCanonicalPayload({
    required String proofId,
    required int tripId,
    required String startDate,
    required String? completedAt,
    required List<Map<String, dynamic>> destinations,
    required String salt,
    String version = currentPayloadVersion,
  }) {
    // Normalisasi dan ekstrak hanya data non-PII dari destinasi
    final normalizedDestinations = destinations.map((d) {
      return {
        'destination_name': (d['name'] ?? d['item_name'] ?? '').toString().trim(),
        'elevation_mdpl': (d['elevation_mdpl'] as num?)?.toInt() ?? 0,
        'is_visited': (d['is_completed'] == 1 || d['is_completed'] == true),
      };
    }).toList()
      ..sort((a, b) => (a['destination_name'] as String)
          .compareTo(b['destination_name'] as String));

    // Urutan key wajib konsisten (alfabetis)
    final canonicalMap = <String, dynamic>{
      'completed_at': completedAt ?? '',
      'destinations': normalizedDestinations,
      'payload_version': version,
      'proof_id': proofId.toLowerCase(),
      'salt': salt,
      'start_date': startDate.trim(),
      'total_destinations': normalizedDestinations.length,
      'trip_identifier': generateTripIdentifier(tripId, salt),
    };

    return canonicalMap;
  }

  /// Mengubah payload ke dalam string JSON kanonis (deterministik, sorted keys, tanpa whitespace ekstra)
  static String toCanonicalJson(Map<String, dynamic> payload) {
    // Sort keys secara alfabetis
    final sortedKeys = payload.keys.toList()..sort();
    final sortedMap = <String, dynamic>{};
    for (final key in sortedKeys) {
      sortedMap[key] = payload[key];
    }
    return jsonEncode(sortedMap);
  }

  /// Menghitung hash SHA-256 dari canonical JSON string
  /// Menghasilkan format '0x' + 64 karakter hex (32 bytes) sesuai bytes32 Solidity
  static String computeSha256Hash(String canonicalJson) {
    final bytes = utf8.encode(canonicalJson);
    final digest = sha256.convert(bytes);
    return '0x${digest.toString()}';
  }

  /// Memvalidasi integritas snapshot terhadap proof hash tersimpan
  static bool verifyLocalSnapshot({
    required String snapshotJson,
    required String expectedHash,
  }) {
    try {
      final decoded = jsonDecode(snapshotJson) as Map<String, dynamic>;
      final recomputedCanonical = toCanonicalJson(decoded);
      final recomputedHash = computeSha256Hash(recomputedCanonical);
      return recomputedHash.toLowerCase() == expectedHash.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Memformat teks hash agar mudah dibaca di UI (misal: 0x4E7A...9B0F)
  static String formatShortHash(String? hash) {
    if (hash == null || hash.isEmpty) return '-';
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 8)}';
  }
}
