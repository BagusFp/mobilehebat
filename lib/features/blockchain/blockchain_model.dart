import '../../core/utils/crypto_helper.dart';

class BlockModel {
  final int index;
  final String timestamp;
  final String title;
  final String referenceId;
  final String previousHash;
  final String hash;
  final String dataPayload;
  final String authoritySigner;
  final bool isTampered;

  const BlockModel({
    required this.index,
    required this.timestamp,
    required this.title,
    required this.referenceId,
    required this.previousHash,
    required this.hash,
    required this.dataPayload,
    required this.authoritySigner,
    this.isTampered = false,
  });

  /// Menghitung hash SHA-256 aktual berdasarkan muatan data blok
  static String computeHash({
    required int index,
    required String timestamp,
    required String referenceId,
    required String previousHash,
    required String dataPayload,
  }) {
    final rawString = '$index|$timestamp|$referenceId|$previousHash|$dataPayload';
    return CryptoHelper.hashPassword(rawString);
  }

  BlockModel copyWith({
    int? index,
    String? timestamp,
    String? title,
    String? referenceId,
    String? previousHash,
    String? hash,
    String? dataPayload,
    String? authoritySigner,
    bool? isTampered,
  }) {
    return BlockModel(
      index: index ?? this.index,
      timestamp: timestamp ?? this.timestamp,
      title: title ?? this.title,
      referenceId: referenceId ?? this.referenceId,
      previousHash: previousHash ?? this.previousHash,
      hash: hash ?? this.hash,
      dataPayload: dataPayload ?? this.dataPayload,
      authoritySigner: authoritySigner ?? this.authoritySigner,
      isTampered: isTampered ?? this.isTampered,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'index_num': index,
      'timestamp': timestamp,
      'title': title,
      'reference_id': referenceId,
      'previous_hash': previousHash,
      'current_hash': hash,
      'data_payload': dataPayload,
      'authority_signer': authoritySigner,
      'is_tampered': isTampered ? 1 : 0,
    };
  }

  factory BlockModel.fromMap(Map<String, dynamic> map) {
    return BlockModel(
      index: map['index_num'] as int,
      timestamp: map['timestamp'] as String,
      title: map['title'] as String,
      referenceId: map['reference_id'] as String,
      previousHash: map['previous_hash'] as String,
      hash: map['current_hash'] as String,
      dataPayload: map['data_payload'] as String,
      authoritySigner: map['authority_signer'] as String,
      isTampered: (map['is_tampered'] as int?) == 1,
    );
  }
}
