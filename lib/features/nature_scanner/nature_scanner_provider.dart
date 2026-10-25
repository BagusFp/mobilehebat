import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/detected_nature_object.dart';
import 'models/scanner_debug_info.dart';
import 'services/nature_classifier_service.dart';

enum ScannerStatus {
  initial,
  requestingPermission,
  permissionDenied,
  permissionPermanentlyDenied,
  cameraUnavailable,
  initializingCamera,
  ready,
  capturing,
  analyzing,
  error,
}

class NatureScannerProvider extends ChangeNotifier {
  final NatureClassifierService _classifierService;

  NatureScannerProvider({NatureClassifierService? classifierService})
      : _classifierService = classifierService ?? NatureClassifierService();

  NatureClassifierService get classifierService => _classifierService;

  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;

  List<CameraDescription> _cameras = [];
  List<CameraDescription> get cameras => _cameras;

  int _selectedCameraIndex = 0;
  int get selectedCameraIndex => _selectedCameraIndex;

  int _sensorOrientation = 90;
  int get sensorOrientation => _sensorOrientation;

  bool _isFrontCamera = false;
  bool get isFrontCamera => _isFrontCamera;

  // FPS Tracking
  int _frameCount = 0;
  DateTime? _lastFpsTimestamp;
  double _currentFps = 0.0;
  double get currentFps => _currentFps;

  ScannerStatus _status = ScannerStatus.initial;
  ScannerStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isTorchOn = false;
  bool get isTorchOn => _isTorchOn;

  List<DetectedNatureObject> _liveDetections = [];
  List<DetectedNatureObject> get liveDetections => _liveDetections;

  NatureScanResult? _lastCapturedResult;
  NatureScanResult? get lastCapturedResult => _lastCapturedResult;

  bool get isReady => _status == ScannerStatus.ready && _cameraController?.value.isInitialized == true;
  bool get isCapturingOrAnalyzing => _status == ScannerStatus.capturing || _status == ScannerStatus.analyzing;

  /// Informasi telemetri untuk Developer Debug Overlay
  ScannerDebugInfo get debugInfo => _classifierService.latestDebugInfo.copyWith(
        fps: double.parse(_currentFps.toStringAsFixed(1)),
      );

  /// Inisialisasi awal izin dan kamera
  Future<void> initScanner() async {
    _status = ScannerStatus.requestingPermission;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Cek & Minta Izin Kamera
      final permission = await Permission.camera.request();

      if (permission.isPermanentlyDenied) {
        _status = ScannerStatus.permissionPermanentlyDenied;
        _errorMessage = 'Izin kamera ditolak secara permanen. Silakan aktifkan izin kamera di Pengaturan HP Anda.';
        notifyListeners();
        return;
      }

      if (!permission.isGranted && !permission.isLimited) {
        _status = ScannerStatus.permissionDenied;
        _errorMessage = 'MeraTrip membutuhkan akses kamera untuk mengenali objek alam di sekitar Anda.';
        notifyListeners();
        return;
      }

      // 2. Temukan kamera perangkat
      _status = ScannerStatus.initializingCamera;
      notifyListeners();

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        _status = ScannerStatus.cameraUnavailable;
        _errorMessage = 'Tidak ditemukan modul kamera aktif pada perangkat ini.';
        notifyListeners();
        return;
      }

      // Default pilih kamera belakang
      _selectedCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex < 0) _selectedCameraIndex = 0;

      await _setupCameraController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('NatureScannerProvider.initScanner error: $e');
      _status = ScannerStatus.error;
      _errorMessage = 'Gagal menginisialisasi kamera: $e';
      notifyListeners();
    }
  }

  /// Setup instance CameraController dengan resolusi optimal dan image stream
  Future<void> _setupCameraController(CameraDescription camera) async {
    await _disposeControllerOnly();

    _sensorOrientation = camera.sensorOrientation;
    _isFrontCamera = camera.lensDirection == CameraLensDirection.front;
    _classifierService.resetTemporalHistory();

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      _cameraController = controller;
      _isTorchOn = false;
      _status = ScannerStatus.ready;
      notifyListeners();

      // Mulai frame stream untuk live object detection dengan auto-throttling
      await _startLiveImageStream();
    } catch (e) {
      debugPrint('Gagal inisialisasi controller: $e');
      _status = ScannerStatus.error;
      _errorMessage = 'Kamera tidak dapat diakses saat ini.';
      notifyListeners();
    }
  }

  /// Memulai stream gambar live dari kamera
  Future<void> _startLiveImageStream() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    try {
      if (_cameraController!.value.isStreamingImages) return;

      await _cameraController!.startImageStream((CameraImage image) async {
        if (_status != ScannerStatus.ready) return;

        // Hitung rolling FPS secara real-time
        _frameCount++;
        final now = DateTime.now();
        if (_lastFpsTimestamp == null) {
          _lastFpsTimestamp = now;
        } else {
          final diff = now.difference(_lastFpsTimestamp!).inMilliseconds;
          if (diff >= 1000) {
            _currentFps = (_frameCount * 1000.0) / diff;
            _frameCount = 0;
            _lastFpsTimestamp = now;
          }
        }

        final detections = await _classifierService.processCameraImage(
          image,
          sensorOrientation: _sensorOrientation,
          isFrontCamera: _isFrontCamera,
        );

        if (detections.isNotEmpty || _liveDetections.isNotEmpty) {
          _liveDetections = detections;
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('NatureScannerProvider._startLiveImageStream error: $e');
    }
  }

  /// Menghentikan image stream sementara (misal sebelum capture foto)
  Future<void> _stopLiveImageStream() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (e) {
        debugPrint('Error stopImageStream: $e');
      }
    }
  }

  /// Ambil foto resolusi tinggi dan lakukan inferensi mendalam
  Future<NatureScanResult?> captureAndAnalyze() async {
    if (!isReady || _cameraController == null) return null;

    try {
      _status = ScannerStatus.capturing;
      notifyListeners();

      await _stopLiveImageStream();

      // Tangkap gambar dari kamera
      final XFile photo = await _cameraController!.takePicture();

      _status = ScannerStatus.analyzing;
      notifyListeners();

      // Inferensi model Computer Vision secara lokal
      final result = await _classifierService.analyzeCapturedPhoto(photo.path);
      _lastCapturedResult = result;

      _status = ScannerStatus.ready;
      notifyListeners();

      return result;
    } catch (e) {
      debugPrint('NatureScannerProvider.captureAndAnalyze error: $e');
      _status = ScannerStatus.error;
      _errorMessage = 'Gagal menganalisis foto: $e';
      notifyListeners();
      return null;
    }
  }

  /// Toggle lampu senter / flash
  Future<void> toggleTorch() async {
    if (!isReady || _cameraController == null) return;

    try {
      if (_isTorchOn) {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isTorchOn = false;
      } else {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isTorchOn = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('toggleTorch error: $e');
    }
  }

  /// Ganti lensa kamera (Depan / Belakang)
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _status = ScannerStatus.initializingCamera;
    notifyListeners();

    await _setupCameraController(_cameras[_selectedCameraIndex]);
  }

  /// Buka pengaturan aplikasi di sistem Android / iOS
  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Reset hasil scan terakhir untuk kembali memindai secara live
  Future<void> resumeLiveScan() async {
    _lastCapturedResult = null;
    _liveDetections = [];
    _errorMessage = null;
    _classifierService.resetTemporalHistory();
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _status = ScannerStatus.ready;
      await _startLiveImageStream();
      notifyListeners();
    } else {
      await initScanner();
    }
  }

  Future<void> _disposeControllerOnly() async {
    if (_cameraController != null) {
      try {
        await _stopLiveImageStream();
        await _cameraController!.dispose();
      } catch (e) {
        debugPrint('Error disposing controller: $e');
      }
      _cameraController = null;
    }
  }

  @override
  void dispose() {
    _disposeControllerOnly();
    super.dispose();
  }
}
