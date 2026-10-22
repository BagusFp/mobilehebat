import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/utils/blockchain_proof_helper.dart';

void main() {
  group('BlockchainProofHelper Tests', () {
    test('generateSecureSalt menghasilkan 64 hex characters (32 bytes)', () {
      final salt1 = BlockchainProofHelper.generateSecureSalt();
      final salt2 = BlockchainProofHelper.generateSecureSalt();

      expect(salt1.length, 64);
      expect(salt2.length, 64);
      expect(salt1, isNot(equals(salt2)));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(salt1), isTrue);
    });

    test('generateProofId menghasilkan bytes32 hex berawalan 0x', () {
      final proofId = BlockchainProofHelper.generateProofId();

      expect(proofId.startsWith('0x'), isTrue);
      expect(proofId.length, 66); // '0x' + 64 hex
      expect(RegExp(r'^0x[0-9a-f]{64}$').hasMatch(proofId), isTrue);
    });

    test('buildCanonicalPayload menghasilkan struktur bebas PII dengan sorting alfabetis', () {
      final proofId = BlockchainProofHelper.generateProofId();
      final salt = BlockchainProofHelper.generateSecureSalt();

      final destinations = [
        {'name': 'Museum Sisa Hartaku', 'elevation_mdpl': 850, 'is_completed': 1},
        {'name': 'Bunker Kaliadem', 'elevation_mdpl': 1100, 'is_completed': 1},
        {'name': 'Plunyon Kalikuning', 'elevation_mdpl': 950, 'is_completed': 0},
      ];

      final payload = BlockchainProofHelper.buildCanonicalPayload(
        proofId: proofId,
        tripId: 42,
        startDate: '2026-10-23',
        completedAt: '2026-10-23T15:30:00Z',
        destinations: destinations,
        salt: salt,
      );

      // Verifikasi TIDAK ADA PII
      expect(payload.containsKey('user_name'), isFalse);
      expect(payload.containsKey('email'), isFalse);
      expect(payload.containsKey('phone'), isFalse);
      expect(payload.containsKey('budget'), isFalse);
      expect(payload.containsKey('notes'), isFalse);

      // Verifikasi urutan destinasi diurutkan secara alfabetis
      final destList = payload['destinations'] as List<Map<String, dynamic>>;
      expect(destList[0]['destination_name'], 'Bunker Kaliadem');
      expect(destList[1]['destination_name'], 'Museum Sisa Hartaku');
      expect(destList[2]['destination_name'], 'Plunyon Kalikuning');

      final canonicalJson = BlockchainProofHelper.toCanonicalJson(payload);
      final proofHash = BlockchainProofHelper.computeSha256Hash(canonicalJson);

      expect(proofHash.startsWith('0x'), isTrue);
      expect(proofHash.length, 66);

      // Verifikasi validitas lokal
      final isValid = BlockchainProofHelper.verifyLocalSnapshot(
        snapshotJson: canonicalJson,
        expectedHash: proofHash,
      );
      expect(isValid, isTrue);
    });

    test('verifyLocalSnapshot mendeteksi manipulasi data (anti-tamper)', () {
      final proofId = BlockchainProofHelper.generateProofId();
      final salt = BlockchainProofHelper.generateSecureSalt();

      final payload = BlockchainProofHelper.buildCanonicalPayload(
        proofId: proofId,
        tripId: 10,
        startDate: '2026-10-23',
        completedAt: '2026-10-23T12:00:00Z',
        destinations: [
          {'name': 'Bunker Kaliadem', 'elevation_mdpl': 1100, 'is_completed': 1},
        ],
        salt: salt,
      );

      final canonicalJson = BlockchainProofHelper.toCanonicalJson(payload);
      final genuineHash = BlockchainProofHelper.computeSha256Hash(canonicalJson);

      // 1. Snapshot asli -> Valid
      expect(
        BlockchainProofHelper.verifyLocalSnapshot(
          snapshotJson: canonicalJson,
          expectedHash: genuineHash,
        ),
        isTrue,
      );

      // 2. Manipulasi destinasi di snapshot -> Gagal (Integritas terdeteksi rusak)
      final tamperedMap = jsonDecode(canonicalJson) as Map<String, dynamic>;
      tamperedMap['destinations'] = [
        {'destination_name': 'Destinasi Palsu', 'elevation_mdpl': 2930, 'is_visited': true}
      ];
      final tamperedJson = jsonEncode(tamperedMap);

      expect(
        BlockchainProofHelper.verifyLocalSnapshot(
          snapshotJson: tamperedJson,
          expectedHash: genuineHash,
        ),
        isFalse,
      );
    });

    test('formatShortHash memformat string panjang menjadi ringkas', () {
      const fullHash = '0xb8fa4b7600f5905b8e958b8e0a21378ffef80b9d';
      final formatted = BlockchainProofHelper.formatShortHash(fullHash);

      expect(formatted, '0xb8fa4b76...fef80b9d');
      expect(BlockchainProofHelper.formatShortHash(null), '-');
      expect(BlockchainProofHelper.formatShortHash(''), '-');
    });
  });
}
