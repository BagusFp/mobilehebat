import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project/core/config/supabase_config.dart';
import 'package:project/core/database/database_helper.dart';
import 'package:project/core/services/blockchain_service.dart';
import 'package:project/core/utils/blockchain_proof_helper.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/models/trip_proof_model.dart';
import 'package:project/features/blockchain/blockchain_provider.dart';
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

  TripModel createTrip50({required String status}) {
    return TripModel(
      id: 50,
      userId: 1,
      tripName: 'MeraTrip Expedition Merapi - Trip 50',
      startDate: '2026-10-20',
      targetBudget: 350000,
      status: status,
      completedAt: status == 'completed' ? '2026-10-23T07:24:34.157951+00:00' : null,
      createdAt: '2026-10-15T15:59:40.301952',
      items: [
        TripItemModel(
          id: 501,
          tripId: 50,
          itemName: 'Basecamp Selo',
          visitOrder: 1,
          elevationMdpl: 1564,
          isCompleted: true,
        ),
        TripItemModel(
          id: 502,
          tripId: 50,
          itemName: 'Pasar Bubrah',
          visitOrder: 2,
          elevationMdpl: 2680,
          isCompleted: true,
        ),
        TripItemModel(
          id: 503,
          tripId: 50,
          itemName: 'Puncak Garuda',
          visitOrder: 3,
          elevationMdpl: 2930,
          isCompleted: true,
        ),
      ],
    );
  }

  group('PENGUJIAN DRY-RUN PROOF OF VISIT TRIP ID 50 (ACTIVE BACKEND CONFIG)', () {
    // -------------------------------------------------------------------------
    // 1. User Menyelesaikan Trip 50
    // -------------------------------------------------------------------------
    test('1. Validasi status penyelesaian Trip ID 50 sebelum pembuatan proof', () async {
      final tripUpcoming = createTrip50(status: 'upcoming');
      final service = BlockchainService();

      expect(tripUpcoming.status == 'completed', isFalse);
      await expectLater(
        () => service.generateAndRecordProof(
          trip: tripUpcoming,
          userId: 1,
          userJwtToken: 'valid_mock_token',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Trip belum selesai. Hanya trip berstatus selesai yang dapat dibuatkan bukti perjalanan.'),
          ),
        ),
      );

      final tripCompleted = createTrip50(status: 'completed');
      expect(tripCompleted.status == 'completed', isTrue);
      expect(tripCompleted.id, 50);
      expect(tripCompleted.completedAt, isNotNull);
      expect(tripCompleted.items.length, 3);
    });

    // -------------------------------------------------------------------------
    // 2. Generate Snapshot Kanonis Bebas PII & Proof Hash SHA-256
    // -------------------------------------------------------------------------
    test('2. Generate snapshot kanonis dan proof hash SHA-256 untuk Trip 50', () async {
      final trip = createTrip50(status: 'completed');
      const salt = '745003be9e3e30265fd8e275755093ae36a89b24fcc26a6ec311223344556677';
      const proofId = '0x0f19f58185a5c294eff6ce89baf56fc918a8c4154d7e01be79b69b6f125a0a3';

      final destinationsData = trip.items.map((it) => {
        'destination_name': it.itemName.trim(),
        'elevation_mdpl': it.elevationMdpl,
        'is_visited': it.isCompleted,
      }).toList();

      final payload = BlockchainProofHelper.buildCanonicalPayload(
        proofId: proofId,
        tripId: trip.id!,
        startDate: trip.startDate,
        completedAt: trip.completedAt,
        destinations: destinationsData,
        salt: salt,
      );

      final canonicalJson = BlockchainProofHelper.toCanonicalJson(payload);
      final proofHash = BlockchainProofHelper.computeSha256Hash(canonicalJson);

      expect(canonicalJson, contains('"payload_version":"1.0.0"'));
      expect(canonicalJson, contains('"trip_identifier"'));
      expect(canonicalJson, contains('"total_destinations":3'));
      // Verifikasi anti-PII leak: tidak ada nama user, email, atau catatan
      expect(canonicalJson, isNot(contains('bima.sakti')));
      expect(canonicalJson, isNot(contains('@wisatawan.id')));

      expect(proofHash.startsWith('0x'), isTrue);
      expect(proofHash.length, 66); // 0x + 64 hex characters
    });

    // -------------------------------------------------------------------------
    // 3. Kirim Request record-proof ke Backend yang Saat Ini Aktif
    // -------------------------------------------------------------------------
    test('3A. Request aktual ke backend cloud aktif tanpa session ditolak 401 Unauthorized', () async {
      // Menguji secara aktual endpoint cloud Supabase aktif
      final edgeFunctionUrl = '${SupabaseConfig.url}/functions/v1/record-proof';
      final liveClient = http.Client();

      try {
        final liveResponse = await liveClient.post(
          Uri.parse(edgeFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'MeraTrip-Client/1.0',
          },
          body: jsonEncode({
            'trip_id': 50,
            'trip_name': 'MeraTrip Expedition Merapi - Trip 50',
          }),
        ).timeout(const Duration(seconds: 10));

        // ignore: avoid_print
        print('DEBUG 3A: status=${liveResponse.statusCode}, body=${liveResponse.body}');
        expect(liveResponse.statusCode, anyOf(400, 401));
      } finally {
        liveClient.close();
      }
    });

    test('3B. Request aktual dengan anon token ditolak 401 Unauthorized user session', () async {
      final edgeFunctionUrl = '${SupabaseConfig.url}/functions/v1/record-proof';
      final liveClient = http.Client();

      try {
        final liveResponse = await liveClient.post(
          Uri.parse(edgeFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'MeraTrip-Client/1.0',
            'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
          },
          body: jsonEncode({
            'trip_id': 50,
            'trip_name': 'MeraTrip Expedition Merapi - Trip 50',
          }),
        ).timeout(const Duration(seconds: 10));

        // ignore: avoid_print
        print('DEBUG 3B: status=${liveResponse.statusCode}, body=${liveResponse.body}');
        expect(liveResponse.statusCode, anyOf(400, 401));
        if (liveResponse.statusCode == 401 && liveResponse.body.isNotEmpty) {
          final resJson = jsonDecode(liveResponse.body);
          expect(resJson['error'] ?? resJson['message'], isNotNull);
        }
      } finally {
        liveClient.close();
      }
    });

    // -------------------------------------------------------------------------
    // 4. Verifikasi Response Backend dan Status Proof di Database (Dry-Run Mode)
    // -------------------------------------------------------------------------
    test('4. Backend aktif dry-run mengembalikan status simulated dan tersimpan aman di SQLite', () async {
      final trip = createTrip50(status: 'completed');
      const expectedProofId = '0x0f19f58185a5c294eff6ce89baf56fc918a8c4154d7e01be79b69b6f125a0a3';
      const expectedProofHash = '0x0935ee4dfbf8319e3b381705975da75c757d05943840384a896d8595568ef8c1';

      // Simulasi HTTP client yang menerima response dry-run backend saat ENABLE_ONCHAIN_BROADCAST=false
      final mockBackendClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['trip_id'], 50);

        return http.Response(
          jsonEncode({
            'message': 'Existing dry-run proof simulation verified',
            'mode': 'dry_run',
            'broadcast_enabled': false,
            'simulation_passed': true,
            'proof': {
              'id': 4, // Remote PostgreSQL id
              'user_id': '0',
              'trip_id': 50,
              'proof_id': expectedProofId,
              'proof_hash': expectedProofHash,
              'payload_version': '1.0.0',
              'snapshot_json': '{"test":"dry_run_trip_50"}',
              'salt': '745003be9e3e30265fd8e275755093ae36a89b24fcc26a6ec311223344556677',
              'chain_id': 11155111,
              'contract_address': BlockchainService.defaultContractAddress,
              'tx_hash': null,
              'status': 'simulated',
              'created_at': nowStr,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockBackendClient);
      final proofResult = await service.generateAndRecordProof(
        trip: trip,
        userId: 1,
        userJwtToken: 'valid_user_jwt_token',
      );

      // Verifikasi objek model hasil respons
      expect(proofResult.tripId, 50);
      expect(proofResult.status, 'simulated');
      expect(proofResult.isSimulated, isTrue);
      expect(proofResult.isPending, isFalse);
      expect(proofResult.isConfirmed, isFalse);
      expect(proofResult.txHash, isNull);
      expect(proofResult.proofId, expectedProofId);
      expect(proofResult.proofHash, expectedProofHash);

      // Verifikasi record tersimpan di SQLite lokal tanpa collision
      final localRow = await dbHelper.getTripProofByTripId(50);
      expect(localRow, isNotNull);
      expect(localRow!['trip_id'], 50);
      expect(localRow['status'], 'simulated');
      expect(localRow['tx_hash'], isNull);
      expect(localRow['proof_id'], expectedProofId);
      expect(localRow['proof_hash'], expectedProofHash);
    });

    // -------------------------------------------------------------------------
    // 5. Pastikan Status Simulated Ditangani Flutter Tanpa Polling Transaksi
    // -------------------------------------------------------------------------
    test('5. Status simulated dicegah dari polling transaksi RPC oleh Flutter', () async {
      const snapshot = '{"test":"dry_run_trip_50"}';
      final validHash = BlockchainProofHelper.computeSha256Hash(snapshot);
      final simulatedProof = TripProofModel(
        userId: 1,
        tripId: 50,
        proofId: '0x0f19f58185a5c294eff6ce89baf56fc918a8c4154d7e01be79b69b6f125a0a3',
        proofHash: validHash,
        snapshotJson: snapshot,
        salt: '745003be9e3e30265fd8e275755093ae36a89b24fcc26a6ec311223344556677',
        contractAddress: BlockchainService.defaultContractAddress,
        status: 'simulated',
        txHash: null,
        createdAt: nowStr,
      );

      int rpcRequestCount = 0;
      final mockRpcClient = MockClient((request) async {
        rpcRequestCount++;
        return http.Response('{}', 200);
      });

      final service = BlockchainService(httpClient: mockRpcClient);
      final provider = BlockchainProvider();

      // Panggil refreshProofStatus: harus langsung return karena isSimulated == true
      await provider.refreshProofStatus(simulatedProof);
      expect(rpcRequestCount, 0, reason: 'refreshProofStatus tidak boleh melakukan polling RPC untuk status simulated');

      // Panggil verifyProofIntegrity: harus mengecek integritas lokal tanpa polling receipt
      final report = await service.verifyProofIntegrity(simulatedProof);
      expect(report['isSimulated'], isTrue);
      expect(report['isTxReceiptValid'], isFalse);
      expect(report['isOnChainConfirmed'], isFalse);
      expect(report['details'], contains('Mode Dry-Run'));
      expect(rpcRequestCount, 0, reason: 'verifyProofIntegrity tidak boleh memanggil Sepolia RPC untuk status simulated');
    });

    // -------------------------------------------------------------------------
    // 6. Periksa Apakah Ada Duplikasi Proof atau Error ID Trip
    // -------------------------------------------------------------------------
    test('6A. Idempotensi Trip 50: Tidak ada duplikasi proof pada pemanggilan berulang', () async {
      final trip = createTrip50(status: 'completed');
      const proofId = '0x0f19f58185a5c294eff6ce89baf56fc918a8c4154d7e01be79b69b6f125a0a3';
      const proofHash = '0x0935ee4dfbf8319e3b381705975da75c757d05943840384a896d8595568ef8c1';

      final mockBackendClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Existing dry-run proof simulation verified',
            'mode': 'dry_run',
            'broadcast_enabled': false,
            'proof': {
              'id': 4,
              'trip_id': 50,
              'proof_id': proofId,
              'proof_hash': proofHash,
              'snapshot_json': '{}',
              'salt': 'salt',
              'contract_address': BlockchainService.defaultContractAddress,
              'status': 'simulated',
              'tx_hash': null,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BlockchainService(httpClient: mockBackendClient);

      // Panggilan 1
      await service.generateAndRecordProof(trip: trip, userId: 1, userJwtToken: 'mock_jwt');
      final db = await dbHelper.database;
      final rowsAfterFirst = await db.query('trip_proofs', where: 'trip_id = ?', whereArgs: [50]);
      expect(rowsAfterFirst.length, 1);

      // Panggilan 2 (Retry identik)
      await service.generateAndRecordProof(trip: trip, userId: 1, userJwtToken: 'mock_jwt');
      final rowsAfterSecond = await db.query('trip_proofs', where: 'trip_id = ?', whereArgs: [50]);
      expect(rowsAfterSecond.length, 1, reason: 'Jumlah record di SQLite untuk Trip 50 harus tepat 1 (tidak boleh ada duplikasi)');
    });

    test('6B. Error ID Trip: ID tidak valid (null) ditolak secara eksplisit', () async {
      final invalidTrip = TripModel(
        id: null, // ID tidak ada
        userId: 1,
        tripName: 'Trip Tanpa ID',
        startDate: '2026-10-20',
        targetBudget: 100000,
        status: 'completed',
        completedAt: nowStr,
        createdAt: nowStr,
      );

      final service = BlockchainService();
      await expectLater(
        () => service.generateAndRecordProof(trip: invalidTrip, userId: 1, userJwtToken: 'jwt'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
