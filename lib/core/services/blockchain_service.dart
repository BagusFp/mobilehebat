import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/models/trip_model.dart';
import '../../data/models/trip_proof_model.dart';
import '../config/supabase_config.dart';
import '../database/database_helper.dart';
import '../utils/blockchain_proof_helper.dart';

/// Service untuk berinteraksi dengan smart contract MeraTripProof pada Ethereum Sepolia Testnet.
///
/// PRINSIP UTAMA:
/// 1. Tidak pernah menyimpan private key relayer di client Flutter atau APK.
/// 2. Membaca data kontrak di Sepolia menggunakan public JSON-RPC (eth_call) yang 100% aman dan publik.
/// 3. Menghubungi backend (Supabase Edge Function / Relayer) untuk eksekusi pencatatan transaksi on-chain.
/// 4. HANYA menandai status 'confirmed' jika receipt transaksi benar-benar diverifikasi sukses di testnet!
class BlockchainService {
  static final BlockchainService _instance = BlockchainService._internal();
  factory BlockchainService({http.Client? httpClient, DatabaseHelper? dbHelper}) {
    if (httpClient != null || dbHelper != null) {
      return BlockchainService._internal(httpClient: httpClient, dbHelper: dbHelper);
    }
    return _instance;
  }
  BlockchainService._internal({http.Client? httpClient, DatabaseHelper? dbHelper})
      : _httpClient = httpClient ?? http.Client(),
        _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final http.Client _httpClient;
  final DatabaseHelper _dbHelper;

  // Konfigurasi Sepolia Testnet
  static const int chainId = 11155111;
  static const String networkName = 'Ethereum Sepolia Testnet';
  static const String defaultContractAddress = '0xB8Fa4B7600f5905B8E958b8E0A21378ffef80b9D';
  static const String explorerBaseUrl = 'https://sepolia.etherscan.io';

  // Daftar RPC endpoint Sepolia publik dengan fallback otomatis
  static const List<String> rpcEndpoints = [
    'https://ethereum-sepolia-rpc.publicnode.com',
    'https://1rpc.io/sepolia',
    'https://sepolia.drpc.org',
    'https://gateway.tenderly.co/public/sepolia',
  ];

  // Function selector keccak256 hash untuk:
  // getProof(bytes32) -> 0x1b80bb3a
  // verifyProof(bytes32,bytes32) -> 0x739808e5
  // isProofRecorded(bytes32) -> 0x2d1813f1
  static const String verifyProofSelector = '0x739808e5';
  static const String getProofSelector = '0x1b80bb3a';
  static const String isProofRecordedSelector = '0x2d1813f1';

  /// Mendapatkan RPC endpoint yang aktif merespons dan terbukti pada Sepolia Testnet
  Future<String> _getActiveRpc() async {
    for (final rpc in rpcEndpoints) {
      try {
        final response = await _httpClient
            .post(
              Uri.parse(rpc),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'jsonrpc': '2.0',
                'method': 'eth_chainId',
                'params': [],
                'id': 1,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['result'] != null) {
            final rawChainId = data['result'].toString();
            final parsedChainId = int.tryParse(rawChainId.replaceFirst('0x', ''), radix: 16);
            if (parsedChainId == chainId) {
              return rpc;
            }
          }
        }
      } catch (_) {
        continue;
      }
    }
    return rpcEndpoints.first;
  }

  /// Membuat dan mencatat bukti perjalanan (Proof of Visit)
  Future<TripProofModel> generateAndRecordProof({
    required TripModel trip,
    required int userId,
    String? userJwtToken,
  }) async {
    if (trip.status != 'completed') {
      throw Exception('Trip belum selesai. Hanya trip berstatus selesai yang dapat dibuatkan bukti perjalanan.');
    }

    if (trip.id == null) {
      throw Exception('Trip ID tidak valid.');
    }

    // 1. Cek apakah sudah ada bukti yang tersimpan secara lokal
    final existingMap = await _dbHelper.getTripProofByTripId(trip.id!);
    int? localId;
    if (existingMap != null) {
      localId = existingMap['id'] as int?;
      final existingProof = TripProofModel.fromMap(existingMap);
      if (existingProof.isConfirmed) {
        return existingProof;
      }
    }

    // 2. Buat payload kanonis & SHA-256 hash bebas PII
    final proofId = BlockchainProofHelper.generateProofId();
    final salt = BlockchainProofHelper.generateSecureSalt();

    final destinationsData = trip.items.map((item) {
      return {
        'destination_name': item.itemName,
        'elevation_mdpl': item.elevationMdpl,
        'is_completed': item.isCompleted,
      };
    }).toList();

    final canonicalPayload = BlockchainProofHelper.buildCanonicalPayload(
      proofId: proofId,
      tripId: trip.id!,
      startDate: trip.startDate,
      completedAt: trip.completedAt,
      destinations: destinationsData,
      salt: salt,
    );

    final canonicalJson = BlockchainProofHelper.toCanonicalJson(canonicalPayload);
    final proofHash = BlockchainProofHelper.computeSha256Hash(canonicalJson);

    // 3. Simpan awal dengan status 'pending'
    var proofModel = TripProofModel(
      id: localId,
      userId: userId,
      tripId: trip.id!,
      proofId: proofId,
      proofHash: proofHash,
      payloadVersion: BlockchainProofHelper.currentPayloadVersion,
      snapshotJson: canonicalJson,
      salt: salt,
      chainId: chainId,
      contractAddress: defaultContractAddress,
      txHash: null,
      status: 'pending',
      confirmedAt: null,
      createdAt: DateTime.now().toIso8601String(),
    );

    final initialId = await _dbHelper.insertOrUpdateTripProof(proofModel.toMap());
    localId ??= initialId;
    proofModel = proofModel.copyWith(id: localId);

    // 4. Kirim ke backend (Supabase Edge Function jika konfigurasi Supabase aktif)
    if (SupabaseConfig.isConfigured) {
      if (userJwtToken == null || userJwtToken.isEmpty) {
        proofModel = proofModel.copyWith(status: 'failed', id: localId);
        await _dbHelper.insertOrUpdateTripProof(proofModel.toMap());
        throw Exception('Sesi autentikasi tidak ditemukan. Silakan login ke akun Supabase untuk membuat bukti perjalanan.');
      }

      try {
        final edgeFunctionUrl = '${SupabaseConfig.url}/functions/v1/record-proof';
        final response = await _httpClient
            .post(
              Uri.parse(edgeFunctionUrl),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $userJwtToken',
              },
              body: jsonEncode({
                'trip_id': trip.id,
                'trip_name': trip.tripName,
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 202) {
          final resData = jsonDecode(response.body);
          if (resData['proof'] != null) {
            proofModel = TripProofModel.fromMap(resData['proof'] as Map<String, dynamic>);
            proofModel = proofModel.copyWith(id: localId);
            // Safeguard: Jika backend merespons mode dry_run / broadcast disabled, pastikan status lokal adalah simulated
            if ((resData['mode'] == 'dry_run' || resData['broadcast_enabled'] == false) && proofModel.isPending) {
              proofModel = proofModel.copyWith(status: 'simulated');
            }
            final updatedId = await _dbHelper.insertOrUpdateTripProof(proofModel.toMap());
            proofModel = proofModel.copyWith(id: updatedId);
          }
        } else {
          String serverError = 'Gagal memproses bukti perjalanan di server (HTTP ${response.statusCode})';
          try {
            final resData = jsonDecode(response.body);
            if (resData['error'] != null) {
              serverError = resData['error'].toString();
            } else if (resData['message'] != null) {
              serverError = resData['message'].toString();
            }
          } catch (_) {}

          proofModel = proofModel.copyWith(status: 'failed', id: localId);
          try {
            await _dbHelper.insertOrUpdateTripProof(proofModel.toMap());
          } catch (_) {}
          throw Exception(serverError);
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('Exception: ')) {
          rethrow;
        }
        proofModel = proofModel.copyWith(status: 'failed', id: localId);
        try {
          await _dbHelper.insertOrUpdateTripProof(proofModel.toMap());
        } catch (_) {}
        throw Exception('Koneksi ke backend Supabase gagal: $e');
      }
    }

    return proofModel;
  }

  /// Memeriksa status receipt transaksi pada node RPC Sepolia
  Future<String> checkTxReceiptStatus(String txHash) async {
    try {
      final rpc = await _getActiveRpc();
      final response = await _httpClient.post(
        Uri.parse(rpc),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_getTransactionReceipt',
          'params': [txHash],
          'id': 1,
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['result'];
        if (result == null) {
          return 'pending'; // Transaksi belum masuk blok / masih pending di mempool
        }
        final statusHex = result['status'];
        if (statusHex == '0x1') {
          return 'confirmed'; // Berhasil tereksekusi di blok
        } else if (statusHex == '0x0') {
          return 'failed'; // Reverted / gagal
        }
      }
    } catch (e) {
      debugPrint('Gagal memeriksa receipt transaksi: $e');
    }
    return 'pending';
  }

  /// Memverifikasi integritas bukti secara menyeluruh:
  /// 1. Hash snapshot lokal vs hash tersimpan
  /// 2. Mode simulasi dry-run vs mode broadcast on-chain
  /// 3. Cek status receipt transaksi di Ethereum Sepolia (jika ada txHash)
  /// 4. Query smart contract langsung via eth_call
  Future<Map<String, dynamic>> verifyProofIntegrity(TripProofModel proof) async {
    // 1. Verifikasi lokal terhadap snapshot asli
    final isLocalHashValid = BlockchainProofHelper.verifyLocalSnapshot(
      snapshotJson: proof.snapshotJson,
      expectedHash: proof.proofHash,
    );

    // Jika berstatus simulasi/dry-run, jangan tunggu konfirmasi blok Sepolia
    if (proof.isSimulated) {
      final details = isLocalHashValid
          ? 'Bukti valid secara kriptografis (Mode Dry-Run). Hash kanonis lokal konsisten dan lolos verifikasi simulasi smart contract.'
          : 'Peringatan: Hash snapshot lokal tidak cocok dengan hash tersimpan! Terdeteksi anomali integritas.';

      return {
        'isLocalHashValid': isLocalHashValid,
        'isTxReceiptValid': false,
        'isOnChainConfirmed': false,
        'isSimulated': true,
        'txBlockNumber': null,
        'details': details,
        'explorerUrl': null,
        'verifiedAt': DateTime.now().toIso8601String(),
      };
    }

    bool isOnChainConfirmed = false;
    bool isTxReceiptValid = false;
    String? txBlockNumber;
    String details = '';

    // 2. Jika ada TX Hash, periksa receipt langsung dari Ethereum Sepolia RPC
    if (proof.txHash != null && proof.txHash!.startsWith('0x') && proof.txHash!.length == 66) {
      try {
        final rpc = await _getActiveRpc();
        final response = await _httpClient.post(
          Uri.parse(rpc),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'eth_getTransactionReceipt',
            'params': [proof.txHash],
            'id': 2,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final receipt = data['result'];
          if (receipt != null) {
            isTxReceiptValid = receipt['status'] == '0x1';
            txBlockNumber = receipt['blockNumber'];
          }
        }
      } catch (e) {
        debugPrint('Gagal query receipt di Sepolia: $e');
      }
    }

    // 3. Query langsung kontrak MeraTripProof via eth_call (read-only, tanpa biaya gas)
    if (isTxReceiptValid || proof.isConfirmed) {
      try {
        final rpc = await _getActiveRpc();
        // Format calldata untuk verifyProof(bytes32 proofId, bytes32 proofHash)
        // verifyProof aman dan tidak akan revert jika bukti belum tercatat (mengembalikan false)
        final cleanProofId = proof.proofId.replaceFirst('0x', '').padLeft(64, '0');
        final cleanProofHash = proof.proofHash.replaceFirst('0x', '').padLeft(64, '0');
        final callData = '$verifyProofSelector$cleanProofId$cleanProofHash';
        final targetAddress = BlockchainProofHelper.sanitizeContractAddress(
          proof.contractAddress,
          fallback: defaultContractAddress,
        );

        final response = await _httpClient.post(
          Uri.parse(rpc),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'jsonrpc': '2.0',
            'method': 'eth_call',
            'params': [
              {
                'to': targetAddress,
                'data': callData,
              },
              'latest',
            ],
            'id': 3,
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final resultHex = data['result'] as String?;
          if (resultHex != null && resultHex != '0x') {
            final boolVal = int.tryParse(resultHex.replaceFirst('0x', ''), radix: 16);
            if (boolVal == 1) {
              isOnChainConfirmed = true;
            } else if (resultHex.length >= 66) {
              final onChainHash = '0x${resultHex.substring(2, 66)}';
              if (onChainHash.toLowerCase() == proof.proofHash.toLowerCase()) {
                isOnChainConfirmed = true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Gagal query contract di Sepolia: $e');
      }
    }

    if (!isLocalHashValid) {
      details = 'Peringatan: Hash snapshot lokal tidak cocok dengan hash tersimpan! Terdeteksi anomali integritas.';
    } else if (isOnChainConfirmed) {
      details = 'Bukti valid 100%! Hash kanonis cocok dan terkonfirmasi tercatat di Smart Contract Ethereum Sepolia.';
    } else if (isTxReceiptValid) {
      details = 'Transaksi tereksekusi pada blok $txBlockNumber di Ethereum Sepolia. Hash data lokal konsisten.';
    } else if (proof.isPending) {
      details = 'Bukti telah dibuat secara kriptografis dan sedang menunggu konfirmasi blok di testnet Sepolia.';
    } else {
      details = 'Hash snapshot lokal konsisten. Transaksi on-chain belum terkonfirmasi penuh.';
    }

    return {
      'isLocalHashValid': isLocalHashValid,
      'isTxReceiptValid': isTxReceiptValid,
      'isOnChainConfirmed': isOnChainConfirmed,
      'txBlockNumber': txBlockNumber,
      'details': details,
      'explorerUrl': proof.blockExplorerUrl,
      'verifiedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Mengambil semua bukti untuk user ID dari cache lokal
  Future<List<TripProofModel>> getUserTripProofs(int userId) async {
    try {
      final list = await _dbHelper.getTripProofsByUserId(userId);
      return list.map((m) => TripProofModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Catatan local db cache: $e');
      return [];
    }
  }

  /// Mengambil bukti trip spesifik
  Future<TripProofModel?> getProofByTripId(int tripId) async {
    try {
      final map = await _dbHelper.getTripProofByTripId(tripId);
      if (map == null) return null;
      return TripProofModel.fromMap(map);
    } catch (e) {
      debugPrint('Catatan local db cache: $e');
      return null;
    }
  }
}
