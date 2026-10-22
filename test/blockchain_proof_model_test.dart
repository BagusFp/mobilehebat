import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/models/trip_proof_model.dart';

void main() {
  group('TripProofModel Tests', () {
    test('Status getter dan Indonesian display labels', () {
      const proofConfirmed = TripProofModel(
        userId: 1,
        tripId: 10,
        proofId: '0x1111',
        proofHash: '0x2222',
        snapshotJson: '{}',
        salt: 'abcdef',
        contractAddress: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
        status: 'confirmed',
        txHash: '0x3333',
        createdAt: '2026-10-23T10:00:00Z',
      );

      expect(proofConfirmed.isConfirmed, isTrue);
      expect(proofConfirmed.isPending, isFalse);
      expect(proofConfirmed.statusDisplayLabel, 'Bukti tercatat di blockchain');
      expect(
        proofConfirmed.blockExplorerUrl,
        'https://sepolia.etherscan.io/tx/0x3333',
      );

      const proofPending = TripProofModel(
        userId: 1,
        tripId: 10,
        proofId: '0x1111',
        proofHash: '0x2222',
        snapshotJson: '{}',
        salt: 'abcdef',
        contractAddress: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
        status: 'pending',
        createdAt: '2026-10-23T10:00:00Z',
      );

      expect(proofPending.isPending, isTrue);
      expect(proofPending.isConfirmed, isFalse);
      expect(proofPending.statusDisplayLabel, 'Bukti sedang diproses');
      expect(proofPending.blockExplorerUrl, isNull);

      const proofFailed = TripProofModel(
        userId: 1,
        tripId: 10,
        proofId: '0x1111',
        proofHash: '0x2222',
        snapshotJson: '{}',
        salt: 'abcdef',
        contractAddress: '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
        status: 'failed',
        createdAt: '2026-10-23T10:00:00Z',
      );

      expect(proofFailed.isFailed, isTrue);
      expect(proofFailed.statusDisplayLabel, 'Gagal mencatat bukti. Coba lagi');
    });

    test('Serialization toMap and deserialization fromMap konsisten', () {
      final map = {
        'id': 5,
        'user_id': 2,
        'trip_id': 99,
        'proof_id': '0xabcd1234',
        'proof_hash': '0xhash5678',
        'payload_version': '1.0.0',
        'snapshot_json': '{"test":"ok"}',
        'salt': 'somerandomsalt',
        'chain_id': 11155111,
        'contract_address': '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D',
        'tx_hash': '0xtx123',
        'status': 'confirmed',
        'confirmed_at': '2026-10-23T11:00:00Z',
        'created_at': '2026-10-23T10:30:00Z',
      };

      final model = TripProofModel.fromMap(map);

      expect(model.id, 5);
      expect(model.userId, 2);
      expect(model.tripId, 99);
      expect(model.proofId, '0xabcd1234');
      expect(model.proofHash, '0xhash5678');
      expect(model.status, 'confirmed');
      expect(model.chainId, 11155111);
      expect(model.decodedSnapshot['test'], 'ok');

      final serialized = model.toMap();
      expect(serialized['proof_id'], '0xabcd1234');
      expect(serialized['chain_id'], 11155111);
      expect(serialized['status'], 'confirmed');
    });
  });
}
