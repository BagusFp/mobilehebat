import 'dart:convert';

/// Status siklus hidup transaksi blockchain Proof of Visit
enum TripProofStatus {
  uncreated, // Belum dibuat
  simulated, // Simulasi valid (Dry-Run off-chain)
  pending, // Menunggu transaksi / terkirim
  confirmed, // Terkonfirmasi (receipt valid & mined)
  failed, // Gagal dicatat
  needsReview, // Perlu pemeriksaan
}

class TripProofModel {
  final int? id;
  final int userId;
  final int tripId;
  final String proofId;
  final String proofHash;
  final String payloadVersion;
  final String snapshotJson;
  final String salt;
  final int chainId;
  final String contractAddress;
  final String? txHash;
  final String status; // 'uncreated', 'simulated', 'pending', 'confirmed', 'failed', 'needs_review'
  final String? confirmedAt;
  final String createdAt;

  const TripProofModel({
    this.id,
    required this.userId,
    required this.tripId,
    required this.proofId,
    required this.proofHash,
    this.payloadVersion = '1.0.0',
    required this.snapshotJson,
    required this.salt,
    this.chainId = 11155111, // Ethereum Sepolia Testnet
    required this.contractAddress,
    this.txHash,
    this.status = 'pending',
    this.confirmedAt,
    required this.createdAt,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending';
  bool get isSimulated => status == 'simulated' || status == 'dry_run';
  bool get isFailed => status == 'failed';
  bool get needsReview => status == 'needs_review';
  bool get isUncreated => status == 'uncreated';

  String get statusDisplayLabel {
    switch (status) {
      case 'confirmed':
        return 'Bukti tercatat di blockchain';
      case 'simulated':
      case 'dry_run':
        return 'Simulasi Valid (Dry-Run)';
      case 'pending':
        return 'Bukti sedang diproses';
      case 'failed':
        return 'Gagal mencatat bukti. Coba lagi';
      case 'needs_review':
        return 'Perlu pemeriksaan transaksi';
      case 'uncreated':
      default:
        return 'Belum dibuat';
    }
  }

  String? get blockExplorerUrl {
    if (isSimulated) return null;
    if (txHash == null || txHash!.isEmpty || !txHash!.startsWith('0x')) {
      return null;
    }
    return 'https://sepolia.etherscan.io/tx/$txHash';
  }

  Map<String, dynamic> get decodedSnapshot {
    try {
      return jsonDecode(snapshotJson) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  TripProofModel copyWith({
    int? id,
    int? userId,
    int? tripId,
    String? proofId,
    String? proofHash,
    String? payloadVersion,
    String? snapshotJson,
    String? salt,
    int? chainId,
    String? contractAddress,
    String? txHash,
    String? status,
    String? confirmedAt,
    String? createdAt,
  }) {
    return TripProofModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tripId: tripId ?? this.tripId,
      proofId: proofId ?? this.proofId,
      proofHash: proofHash ?? this.proofHash,
      payloadVersion: payloadVersion ?? this.payloadVersion,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      salt: salt ?? this.salt,
      chainId: chainId ?? this.chainId,
      contractAddress: contractAddress ?? this.contractAddress,
      txHash: txHash ?? this.txHash,
      status: status ?? this.status,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'trip_id': tripId,
      'proof_id': proofId,
      'proof_hash': proofHash,
      'payload_version': payloadVersion,
      'snapshot_json': snapshotJson,
      'salt': salt,
      'chain_id': chainId,
      'contract_address': contractAddress,
      'tx_hash': txHash,
      'status': status,
      'confirmed_at': confirmedAt,
      'created_at': createdAt,
    };
  }

  factory TripProofModel.fromMap(Map<String, dynamic> map) {
    int parsedUserId = 0;
    if (map['user_id'] is num) {
      parsedUserId = (map['user_id'] as num).toInt();
    } else if (map['user_id'] is String) {
      parsedUserId = int.tryParse(map['user_id'] as String) ?? 0;
    }

    int parsedTripId = 0;
    if (map['trip_id'] is num) {
      parsedTripId = (map['trip_id'] as num).toInt();
    } else if (map['trip_id'] is String) {
      parsedTripId = int.tryParse(map['trip_id'] as String) ?? 0;
    }

    return TripProofModel(
      id: map['id'] is num ? (map['id'] as num).toInt() : int.tryParse(map['id']?.toString() ?? ''),
      userId: parsedUserId,
      tripId: parsedTripId,
      proofId: (map['proof_id'] ?? '').toString(),
      proofHash: (map['proof_hash'] ?? '').toString(),
      payloadVersion: (map['payload_version'] ?? '1.0.0').toString(),
      snapshotJson: (map['snapshot_json'] ?? '{}').toString(),
      salt: (map['salt'] ?? '').toString(),
      chainId: (map['chain_id'] as num?)?.toInt() ?? 11155111,
      contractAddress: (map['contract_address'] ?? '').toString().trim(),
      txHash: map['tx_hash'] != null && map['tx_hash'].toString().trim().isNotEmpty
          ? map['tx_hash'].toString().trim()
          : null,
      status: (map['status'] ?? 'pending').toString(),
      confirmedAt: map['confirmed_at'] as String?,
      createdAt: (map['created_at'] ?? DateTime.now().toIso8601String()).toString(),
    );
  }
}
