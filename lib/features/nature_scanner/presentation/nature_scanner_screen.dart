import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../nature_scanner_provider.dart';
import 'scanner_result_screen.dart';
import 'widgets/nature_bounding_box_painter.dart';

class NatureScannerScreen extends StatefulWidget {
  const NatureScannerScreen({super.key});

  @override
  State<NatureScannerScreen> createState() => _NatureScannerScreenState();
}

class _NatureScannerScreenState extends State<NatureScannerScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final NatureScannerProvider _provider;
  late final AnimationController _animController;
  bool _showDebugOverlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = NatureScannerProvider();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    // Mulai inisialisasi kamera dan izin
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.initScanner();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_provider.cameraController == null || !_provider.cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _provider.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _provider.initScanner();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NatureScannerProvider>.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Consumer<NatureScannerProvider>(
            builder: (context, provider, _) {
              return Stack(
                children: [
                  // 1. Layer Preview Kamera atau Fallback State
                  Positioned.fill(
                    child: _buildCameraLayer(context, provider),
                  ),

                  // 2. Top Bar Navigasi & Info Offline
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: _buildTopBar(context, provider),
                  ),

                  // 2b. Debug Overlay HUD (Debug Mode Only)
                  if (kDebugMode && _showDebugOverlay)
                    Positioned(
                      top: 68,
                      left: 16,
                      right: 16,
                      child: _buildDebugOverlay(provider),
                    ),

                  // 3. Status Toast / Empty State Message
                  if (provider.isReady)
                    Positioned(
                      bottom: 120,
                      left: 20,
                      right: 20,
                      child: _buildDetectionStatusBanner(provider),
                    ),

                  // 4. Bottom Controls (Shutter, Torch, Switch Camera)
                  if (provider.isReady || provider.isCapturingOrAnalyzing)
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: _buildBottomControls(context, provider),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCameraLayer(BuildContext context, NatureScannerProvider provider) {
    if (provider.status == ScannerStatus.requestingPermission ||
        provider.status == ScannerStatus.initializingCamera) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primaryFixed),
            SizedBox(height: 16),
            Text(
              'Menyiapkan AI Nature Scanner...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (provider.status == ScannerStatus.permissionDenied ||
        provider.status == ScannerStatus.permissionPermanentlyDenied) {
      return _buildPermissionErrorView(context, provider);
    }

    if (provider.status == ScannerStatus.cameraUnavailable ||
        provider.status == ScannerStatus.error) {
      return _buildGeneralErrorView(context, provider);
    }

    final controller = provider.cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryFixed),
      );
    }

    // Tampilkan Live Camera Preview dengan AspectRatio terjaga
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: CameraPreview(controller),
        ),

        // Overlay Bounding Box Real-Time
        CustomPaint(
          painter: NatureBoundingBoxPainter(
            detections: provider.liveDetections,
            scanAnimation: _animController,
          ),
          child: const SizedBox.expand(),
        ),

        // Loading Overlay saat capture & deep analysis
        if (provider.isCapturingOrAnalyzing)
          Container(
            color: Colors.black.withAlpha(160),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF4EE39D)),
                  SizedBox(height: 16),
                  Text(
                    'Menganalisis Objek Alam...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Memproses fitur visual secara lokal di HP',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context, NatureScannerProvider provider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Tombol Kembali
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(140),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
          ),
        ),

        // Judul Fitur & Offline Badge
        Flexible(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(160),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.camera_alt_rounded, color: Color(0xFF4EE39D), size: 15),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'AI Nature Scanner',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF04432F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      color: Color(0xFFB5EFD2),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (kDebugMode)
                  InkWell(
                    onTap: () => setState(() => _showDebugOverlay = !_showDebugOverlay),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _showDebugOverlay ? const Color(0xFFF59E0B) : Colors.black54,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Text(
                        'DEBUG',
                        style: TextStyle(
                          color: _showDebugOverlay ? Colors.black : const Color(0xFFFDE68A),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Senter / Torch Toggle
        InkWell(
          onTap: provider.isReady ? provider.toggleTorch : null,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: provider.isTorchOn
                  ? const Color(0xFFF59E0B)
                  : Colors.black.withAlpha(140),
              shape: BoxShape.circle,
              border: Border.all(
                color: provider.isTorchOn ? const Color(0xFFFDE68A) : Colors.white24,
              ),
            ),
            child: Icon(
              provider.isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: provider.isTorchOn ? Colors.black : Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugOverlay(NatureScannerProvider provider) {
    final info = provider.debugInfo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withAlpha(240),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bug_report_rounded, color: Color(0xFFF59E0B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'DEVELOPER CV DEBUG HUD',
                    style: TextStyle(
                      color: Color(0xFFFDE68A),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _showDebugOverlay = false),
                child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildDebugChip('FPS', '${info.fps.toStringAsFixed(1)} fps', const Color(0xFF10B981)),
              _buildDebugChip('Inference', '${info.latencyMs} ms', const Color(0xFF06B6D4)),
              _buildDebugChip('Sensor', '${info.resolution} @ ${info.sensorOrientation}°', const Color(0xFF8B5CF6)),
              _buildDebugChip('Format', info.formatGroup, const Color(0xFF64748B)),
              _buildDebugChip('Detections', '${info.detections.length} obj', const Color(0xFFF59E0B)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Raw Feature Signals (Focus Circle):',
            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          if (info.featureScores.isNotEmpty)
            Text(
              info.featureScores.entries
                  .map((e) => '${e.key.replaceAll("Focus_", "")}: ${(e.value * 100).toStringAsFixed(1)}%')
                  .join(' | '),
              style: const TextStyle(color: Colors.white60, fontSize: 9.5, fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (info.lastError != null) ...[
            const SizedBox(height: 4),
            Text(
              'Error: ${info.lastError}',
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebugChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120), width: 0.8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDetectionStatusBanner(NatureScannerProvider provider) {
    final hasDetections = provider.liveDetections.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasDetections
            ? const Color(0xFF042B1D).withAlpha(220)
            : const Color(0xFF0F172A).withAlpha(200),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasDetections ? const Color(0xFF4EE39D) : Colors.white24,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(90),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasDetections ? const Color(0xFF4EE39D).withAlpha(40) : Colors.white10,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasDetections ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
              color: hasDetections ? const Color(0xFF4EE39D) : const Color(0xFFFDE68A),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasDetections
                      ? 'Terdeteksi: ${provider.liveDetections.map((e) => e.label).join(", ")}'
                      : 'Mencari Objek Alam...',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasDetections
                      ? 'Tekan tombol shutter untuk melihat analisis lengkap.'
                      : 'Belum ada objek yang dapat dikenali. Coba arahkan kamera ke objek lain.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, NatureScannerProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Ganti Kamera (Depan / Belakang)
          IconButton(
            onPressed: provider.cameras.length > 1
                ? () => provider.switchCamera()
                : null,
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 28),
            tooltip: 'Ganti Kamera',
          ),

          // Tombol Capture / Shutter Utama
          GestureDetector(
            onTap: provider.isReady
                ? () async {
                    final result = await provider.captureAndAnalyze();
                    if (!mounted) return;
                    if (result != null) {
                      Navigator.push(
                        this.context,
                        MaterialPageRoute(
                          builder: (_) => ScannerResultScreen(result: result),
                        ),
                      ).then((_) {
                        provider.resumeLiveScan();
                      });
                    }
                  }
                : null,
            child: Container(
              width: 76,
              height: 76,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF4EE39D),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.camera_alt, color: Color(0xFF042B1D), size: 32),
                ),
              ),
            ),
          ),

          // Info / Tips Bantuan
          IconButton(
            onPressed: () => _showSafetyInfoDialog(context),
            icon: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
            tooltip: 'Panduan & Keselamatan',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionErrorView(BuildContext context, NatureScannerProvider provider) {
    final isPermanent = provider.status == ScannerStatus.permissionPermanentlyDenied;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.no_photography_rounded, color: Color(0xFFF87171), size: 40),
              ),
              const SizedBox(height: 18),
              const Text(
                'Izin Kamera Diperlukan',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                provider.errorMessage ??
                    'MeraTrip membutuhkan akses kamera untuk mengenali objek alam secara langsung di sekitar Anda.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4EE39D),
                    foregroundColor: const Color(0xFF042B1D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    if (isPermanent) {
                      provider.openSettings();
                    } else {
                      provider.initScanner();
                    }
                  },
                  icon: Icon(isPermanent ? Icons.settings : Icons.refresh),
                  label: Text(
                    isPermanent ? 'Buka Pengaturan HP' : 'Berikan Izin Kamera',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kembali ke Home', style: TextStyle(color: Colors.white60)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralErrorView(BuildContext context, NatureScannerProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFF59E0B), size: 44),
              const SizedBox(height: 16),
              const Text(
                'Kamera Tidak Dapat Diakses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.errorMessage ?? 'Terjadi kendala saat menghubungkan ke sensor kamera.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFixed,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => provider.initScanner(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSafetyInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0E1F17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.shield_rounded, color: Color(0xFF4EE39D)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Panduan & Keselamatan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '1. Privasi Terjaga',
                style: TextStyle(color: Color(0xFFB5EFD2), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 2),
              Text(
                'Pemrosesan analisis AI berjalan 100% lokal di HP Anda tanpa mengunggah foto ke internet.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              SizedBox(height: 12),
              Text(
                '2. Penafian Keselamatan (Safety Disclaimer)',
                style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(height: 2),
              Text(
                'Deteksi objek ini murni untuk edukasi wisata alam. Fitur ini BUKAN acuan keselamatan medan atau sertifikasi pijakan aman saat mendaki.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mengerti', style: TextStyle(color: Color(0xFF4EE39D), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
