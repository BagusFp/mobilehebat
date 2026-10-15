import 'package:flutter/foundation.dart';
import 'blockchain_model.dart';

class BlockchainProvider extends ChangeNotifier {
  List<BlockModel> _blocks = [];
  bool _isAuditing = false;
  String _auditStatus = 'Rantai Tervalidasi (100% Valid)';
  bool _isTamperedState = false;

  BlockchainProvider() {
    _initChain();
  }

  void _initChain() {
    final b0 = _createBlock(
      index: 1,
      timestamp: '15 Okt 2024, 09:00 WIB',
      title: 'Pendaftaran Akun Penjelajah',
      referenceId: '#USR-0042',
      previousHash: '00000000000000000000000000000000',
      dataPayload: 'Registrasi akun wisatawan: Bima Sakti (ID 1), Verifikasi Sleman & Boyolali.',
      authoritySigner: 'Sistem Autentikasi TNGM',
    );

    final b1 = _createBlock(
      index: 2,
      timestamp: '18 Okt 2024, 14:20 WIB',
      title: 'Itinerary Eksplorasi Merapi 1 Hari',
      referenceId: '#ITN-9021',
      previousHash: b0.hash,
      dataPayload: 'Rencana perjalanan 3 titik: Plunyon, Bunker Kaliadem, Museum Sisa Hartaku. Anggaran Rp 64.000.',
      authoritySigner: 'MeraTrip Trip Builder Node',
    );

    final b2 = _createBlock(
      index: 3,
      timestamp: '19 Okt 2024, 07:15 WIB',
      title: 'Izin Konservasi & Tiket Plunyon',
      referenceId: '#TRP-2024-889',
      previousHash: b1.hash,
      dataPayload: 'Izin masuk kawasan Taman Nasional Gunung Merapi & 2 tiket Plunyon Kalikuning tervalidasi kuota aman.',
      authoritySigner: 'BPPTKG & Pengelola Kaliadem',
    );

    final b3 = _createBlock(
      index: 4,
      timestamp: '19 Okt 2024, 11:30 WIB',
      title: 'Sertifikat Gelar Jagawana Merapi',
      referenceId: '#CRT-2024-401',
      previousHash: b2.hash,
      dataPayload: 'Penyelesaian Kuis Edukasi Vulkanologi dengan skor 850 Poin. Pangkat: Jagawana Merapi Tingkat 3.',
      authoritySigner: 'Balai Konservasi TNGM',
    );

    _blocks = [b0, b1, b2, b3];
    _isTamperedState = false;
    _auditStatus = 'Rantai Tervalidasi (100% Valid)';
  }

  BlockModel _createBlock({
    required int index,
    required String timestamp,
    required String title,
    required String referenceId,
    required String previousHash,
    required String dataPayload,
    required String authoritySigner,
  }) {
    final computed = BlockModel.computeHash(
      index: index,
      timestamp: timestamp,
      referenceId: referenceId,
      previousHash: previousHash,
      dataPayload: dataPayload,
    );

    return BlockModel(
      index: index,
      timestamp: timestamp,
      title: title,
      referenceId: referenceId,
      previousHash: previousHash,
      hash: computed,
      dataPayload: dataPayload,
      authoritySigner: authoritySigner,
      isTampered: false,
    );
  }

  // Getters
  List<BlockModel> get blocks => _blocks;
  bool get isAuditing => _isAuditing;
  String get auditStatus => _auditStatus;
  bool get isTamperedState => _isTamperedState;

  bool get isChainValid {
    for (int i = 0; i < _blocks.length; i++) {
      final current = _blocks[i];
      if (current.isTampered) return false;

      final expectedHash = BlockModel.computeHash(
        index: current.index,
        timestamp: current.timestamp,
        referenceId: current.referenceId,
        previousHash: current.previousHash,
        dataPayload: current.dataPayload,
      );

      if (current.hash != expectedHash) return false;

      if (i > 0) {
        final previous = _blocks[i - 1];
        if (current.previousHash != previous.hash) return false;
      }
    }
    return true;
  }

  int? get invalidBlockIndex {
    for (int i = 0; i < _blocks.length; i++) {
      final current = _blocks[i];
      if (current.isTampered) return current.index;

      final expectedHash = BlockModel.computeHash(
        index: current.index,
        timestamp: current.timestamp,
        referenceId: current.referenceId,
        previousHash: current.previousHash,
        dataPayload: current.dataPayload,
      );

      if (current.hash != expectedHash) return current.index;

      if (i > 0) {
        final previous = _blocks[i - 1];
        if (current.previousHash != previous.hash) return current.index;
      }
    }
    return null;
  }

  // Actions
  /// Simulasi manipulasi data pada blok tertentu untuk mendemonstrasikan keandalan integritas kriptografi
  void simulateTamper(int blockIndex) {
    final idx = _blocks.indexWhere((b) => b.index == blockIndex);
    if (idx != -1) {
      final target = _blocks[idx];
      _blocks[idx] = target.copyWith(
        dataPayload: '[DATA DIMANIPULASI]: Kuota tiket dipalsukan secara ilegal.',
        isTampered: true,
      );
      _isTamperedState = true;
      _auditStatus = 'Peringatan: Integritas Rantai Terlanggar pada Blok #0$blockIndex!';
      notifyListeners();
    }
  }

  /// Memulihkan rantai blok asli
  void restoreChain() {
    _initChain();
    notifyListeners();
  }

  /// Menjalankan audit menyeluruh dengan simulasi validasi per blok
  Future<void> runChainAudit() async {
    _isAuditing = true;
    _auditStatus = 'Mengaudit SHA-256 Rantai...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1000));

    _isAuditing = false;
    if (isChainValid) {
      _auditStatus = 'Audit Selesai: 4/4 Blok Sah & Tidak Mengalami Perubahan (Hash Match).';
    } else {
      _auditStatus = 'Audit Gagal: Ketidaksesuaian Hash Terdeteksi pada Blok #0$invalidBlockIndex!';
    }
    notifyListeners();
  }
}
