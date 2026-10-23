import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project/core/services/blockchain_service.dart';
import 'package:project/core/database/database_helper.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_proof_model.dart';
import 'package:project/core/utils/blockchain_proof_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  final nowStr = DateTime.now().toIso8601String();

  setUpAll(() async {
    dbHelper = DatabaseHelper.instance;
  });

  TripModel createTrip({
    required int id,
    required String status,
    String tripName = 'Test Trip Merapi',
    int userId = 1,
  }) {
    return TripModel(
      id: id,
      userId: userId,
      tripName: tripName,
      startDate: '2026-10-20',
      targetBudget: 250000,
      status: status,
      completedAt: status == 'completed' ? '2026-10-21T18:00:00Z' : null,
      createdAt: nowStr,
      items: [
        TripItemModel(
          id: id * 10 + 1,
          tripId: id,
          itemName: 'Basecamp Selo',
          visitOrder: 1,
          elevationMdpl: 1564,
          isCompleted: true,
        ),
        TripItemModel(
          id: id * 10 + 2,
          tripId: id,
          itemName: 'Pasar Bubrah',
          visitOrder: 2,
          elevationMdpl: 2680,
          isCompleted: true,
        ),
      ],
    );
  }

  group('Proof of Visit End-to-End & Integrity Test Suite', () {
    // -------------------------------------------------------------------------
    // 1. TRIP UPCOMING: Tidak boleh bisa membuat proof
    // -------------------------------------------------------------------------
    test('1. Trip Upcoming tidak dapat membuat proof dan memberikan pesan jelas', () async {
      final trip = createTrip(id: 101, status: 'upcoming');
      final service = BlockchainService();

      await expectLater(
        () => service.generateAndRecordProof(
          trip: trip,
          userId: 1,
          userJwtToken: 'valid_jwt_token',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Trip belum selesai. Hanya trip berstatus selesai yang dapat dibuatkan bukti perjalanan.'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 2. TRIP ONGOING: Tidak boleh bisa membuat proof
    // -------------------------------------------------------------------------
    test('2. Trip Ongoing tidak dapat membuat proof', () async {
      final trip = createTrip(id: 102, status: 'ongoing');
      final service = BlockchainService();

      await expectLater(
        () => service.generateAndRecordProof(
          trip: trip,
          userId: 1,
          userJwtToken: 'valid_jwt_token',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Trip belum selesai. Hanya trip berstatus selesai yang dapat dibuatkan bukti perjalanan.'),
          ),
        ),
      );
    });

    // -------------------------------------------------------------------------
    // 3. UNAUTHENTICATED: Request tanpa token ditolak secara eksplisit
    // -------------------------------------------------------------------------
    test('3. Request tanpa autentikasi ditolak dan status ditandai failed', () async {
      final trip = createTrip(id: 103, status: 'completed');
      final service = BlockchainService();

      await expectLater(
        () => service.generateAndRecordProof(
          trip: trip,
          userId: 1,
          userJwtToken: null,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Sesi autentikasi tidak ditemukan'),
          ),
        ),
      );

      // Verifikasi bahwa status di database lokal tercatat sebagai 'failed', bukan 'pending'
      final storedMap = await dbHelper.getTripProofByTripId(trip.id!);
      expect(storedMap, isNotNull);
      expect(storedMap!['status'], 'failed');
    });

    // -------------------------------------------------------------------------
    // 4. TRIP TIDAK DITEMUKAN (HTTP 404 dari Edge Function)
    // -------------------------------------------------------------------------
    test('4. Trip tidak ditemukan di backend (404) ditolak dan ditandai failed', () async {
      final trip = createTrip(id: 104, status: 'completed');
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Trip not found'}),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockClient);

      await expectLater(
        () => service.generateAndRecordProof(
          trip: trip,
          userId: 1,
          userJwtToken: 'valid_jwt_mock',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Trip not found'),
          ),
        ),
      );

      final storedMap = await dbHelper.getTripProofByTripId(trip.id!);
      expect(storedMap, isNotNull);
      expect(storedMap!['status'], 'failed');
    });

    // -------------------------------------------------------------------------
    // 5. TRIP MILIK USER LAIN (HTTP 403 dari Edge Function)
    // -------------------------------------------------------------------------
    test('5. Trip milik user lain ditolak 403 Forbidden dan ditandai failed', () async {
      final trip = createTrip(id: 105, status: 'completed');
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Trip does not belong to the authenticated user'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockClient);

      await expectLater(
        () => service.generateAndRecordProof(
          trip: trip,
          userId: 1,
          userJwtToken: 'valid_jwt_mock',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Trip does not belong to the authenticated user'),
          ),
        ),
      );

      final storedMap = await dbHelper.getTripProofByTripId(trip.id!);
      expect(storedMap, isNotNull);
      expect(storedMap!['status'], 'failed');
    });

    // -------------------------------------------------------------------------
    // 6. NETWORK ERROR / TIMEOUT (Koneksi bermasalah)
    // -------------------------------------------------------------------------
    test('6. Network error/server error 500 ditangani dan ditandai failed (anti-false-success)', () async {
      final trip = createTrip(id: 106, status: 'completed');
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'error': 'Database connection timeout'}),
          500,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockClient);

      await expectLater(
        () => service.generateAndRecordProof(
          trip: trip,
          userId: 1,
          userJwtToken: 'valid_jwt_mock',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Database connection timeout'),
          ),
        ),
      );

      final storedMap = await dbHelper.getTripProofByTripId(trip.id!);
      expect(storedMap, isNotNull);
      expect(storedMap!['status'], 'failed');
    });

    // -------------------------------------------------------------------------
    // 7. DUPLICATE PROOF / IDEMPOTENCY
    // -------------------------------------------------------------------------
    test('7. Duplicate proof: bukti terkonfirmasi tidak dikirim ulang ke backend', () async {
      final trip = createTrip(id: 107, status: 'completed');

      // Simpan bukti terkonfirmasi di lokal
      final confirmedProof = TripProofModel(
        userId: 1,
        tripId: trip.id!,
        proofId: '0x1111222233334444555566667777888899990000111122223333444455556666',
        proofHash: '0xaaaabbbbccccddddeeeeffff0000111122223333444455556666777788889999',
        snapshotJson: '{}',
        salt: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        contractAddress: BlockchainService.defaultContractAddress,
        status: 'confirmed',
        txHash: '0x20742131fcf628680240d8b7cfc0d44b666e71d181de48c210607cd28271afc1',
        createdAt: nowStr,
      );

      await dbHelper.insertOrUpdateTripProof(confirmedProof.toMap());

      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      });

      final service = BlockchainService(httpClient: mockClient);
      final proof = await service.generateAndRecordProof(
        trip: trip,
        userId: 1,
        userJwtToken: 'valid_jwt_mock',
      );

      expect(proof.isConfirmed, isTrue);
      expect(requestCount, 0, reason: 'Request ke backend TIDAK boleh dikirim jika bukti sudah confirmed (idempotency)');
    });

    // -------------------------------------------------------------------------
    // 8. TRIP COMPLETED DENGAN RESPONS SERVER BERHASIL (200/201)
    // -------------------------------------------------------------------------
    test('8. Trip completed dengan backend berhasil tersimpan dan sinkron dengan SQLite', () async {
      final trip = createTrip(id: 108, status: 'completed');
      final mockProofId = '0x99887766554433221100ffeeddccbbaa99887766554433221100ffeeddccbbaa';
      final mockProofHash = '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Proof generated and registered for processing',
            'proof': {
              'user_id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
              'trip_id': trip.id,
              'proof_id': mockProofId,
              'proof_hash': mockProofHash,
              'payload_version': '1.0.0',
              'snapshot_json': '{"canonical": true}',
              'salt': 'abcdef1234567890abcdef1234567890',
              'chain_id': 11155111,
              'contract_address': BlockchainService.defaultContractAddress,
              'status': 'pending',
              'created_at': nowStr,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockClient);
      final proof = await service.generateAndRecordProof(
        trip: trip,
        userId: 1,
        userJwtToken: 'valid_session_jwt_mock',
      );

      expect(proof.proofId, mockProofId);
      expect(proof.proofHash, mockProofHash);
      expect(proof.contractAddress, BlockchainService.defaultContractAddress);
      expect(proof.isPending, isTrue);

      // Verifikasi di database lokal tersimpan persis dengan data backend
      final localRecord = await dbHelper.getTripProofByTripId(trip.id!);
      expect(localRecord, isNotNull);
      expect(localRecord!['proof_id'], mockProofId);
      expect(localRecord['proof_hash'], mockProofHash);
      expect(localRecord['contract_address'], BlockchainService.defaultContractAddress);
      expect(localRecord['status'], 'pending');
    });

    // -------------------------------------------------------------------------
    // 9. MODE DRY-RUN: Tersimpan sebagai 'simulated' dan tidak menunggu tx receipt
    // -------------------------------------------------------------------------
    test('9. Respons Dry-Run backend menghasilkan status simulated dan tidak dianggap on-chain pending', () async {
      final trip = createTrip(id: 109, status: 'completed', tripName: 'Trip DryRun Merapi');
      final mockProofId = '0x11223344556677889900aabbccddeeff11223344556677889900aabbccddeeff';
      final mockProofHash = '0xaabbccddeeff11223344556677889900aabbccddeeff11223344556677889900';

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['trip_id'], trip.id);
        expect(body['trip_name'], trip.tripName);

        return http.Response(
          jsonEncode({
            'message': 'Dry-run mode aktif. Transaksi on-chain dinonaktifkan secara aman.',
            'mode': 'dry_run',
            'broadcast_enabled': false,
            'simulation_passed': true,
            'proof': {
              'user_id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d',
              'trip_id': trip.id,
              'proof_id': mockProofId,
              'proof_hash': mockProofHash,
              'payload_version': '1.0.0',
              'snapshot_json': '{"test":"dry_run"}',
              'salt': 'abcdef1234567890abcdef1234567890',
              'chain_id': 11155111,
              'contract_address': BlockchainService.defaultContractAddress,
              'status': 'simulated',
              'tx_hash': null,
              'created_at': nowStr,
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockClient);
      final proof = await service.generateAndRecordProof(
        trip: trip,
        userId: 1,
        userJwtToken: 'valid_session_jwt_mock',
      );

      expect(proof.isSimulated, isTrue);
      expect(proof.isPending, isFalse);
      expect(proof.isConfirmed, isFalse);
      expect(proof.txHash, isNull);
      expect(proof.blockExplorerUrl, isNull);
      expect(proof.statusDisplayLabel, 'Simulasi Valid (Dry-Run)');

      // Verifikasi di database lokal juga berstatus simulated
      final localRecord = await dbHelper.getTripProofByTripId(trip.id!);
      expect(localRecord, isNotNull);
      expect(localRecord!['status'], 'simulated');
    });

    // -------------------------------------------------------------------------
    // 10. VERIFIKASI INTEGRITAS MODE DRY-RUN: Cepat dan tidak stuck menunggu blok
    // -------------------------------------------------------------------------
    test('10. verifyProofIntegrity pada bukti simulated segera sukses tanpa receipt polling', () async {
      final trip = createTrip(id: 110, status: 'completed');
      const snapshot = '{"test":"dry_run"}';
      final validHash = BlockchainProofHelper.computeSha256Hash(snapshot);
      final proof = TripProofModel(
        userId: 1,
        tripId: trip.id!,
        proofId: '0xabc1',
        proofHash: validHash,
        snapshotJson: snapshot,
        salt: 'salt1',
        contractAddress: BlockchainService.defaultContractAddress,
        status: 'simulated',
        txHash: null,
        createdAt: nowStr,
      );

      int rpcCallCount = 0;
      final mockClient = MockClient((request) async {
        rpcCallCount++;
        return http.Response('{}', 200);
      });

      final service = BlockchainService(httpClient: mockClient);
      final report = await service.verifyProofIntegrity(proof);

      expect(report['isSimulated'], isTrue);
      expect(report['isTxReceiptValid'], isFalse);
      expect(report['isOnChainConfirmed'], isFalse);
      expect(report['details'], contains('Mode Dry-Run'));
      expect(rpcCallCount, 0, reason: 'Dry-run verification must not make RPC receipt polling calls to Sepolia');
    });
  });
}
