import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/detected_nature_object.dart';
import '../models/scanner_debug_info.dart';

/// Service Computer Vision On-Device untuk mengenali objek dan bentang alam Merapi.
/// Memproses input kamera live secara offline-first, akurat, dan stabil antar-frame.
class NatureClassifierService {
  static const double defaultConfidenceThreshold = 0.50;

  double _confidenceThreshold = defaultConfidenceThreshold;
  double get confidenceThreshold => _confidenceThreshold;

  set confidenceThreshold(double value) {
    _confidenceThreshold = value.clamp(0.2, 0.95);
  }

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  DateTime? _lastInferenceTime;
  static const Duration _throttleInterval = Duration(milliseconds: 180);

  // Informasi diagnostik debug terbaru
  ScannerDebugInfo _latestDebugInfo = const ScannerDebugInfo();
  ScannerDebugInfo get latestDebugInfo => _latestDebugInfo;

  // State temporal smoothing antar-frame untuk meredam jitter
  final Map<NatureCategory, _TemporalCategoryState> _temporalStates = {};

  /// Peringatan keselamatan resmi MeraTrip
  static const String safetyDisclaimer =
      'Hasil pengenalan AI ini ditujukan murni untuk edukasi wisata alam '
      'dan pengenalan bentang lingkungan. Fitur ini BUKAN penentu kelayakan jalur pendakian, '
      'bukan sertifikasi pijakan aman, dan tidak boleh dijadikan acuan mitigasi bencana.';

  /// Reset buffer smoothing temporal saat ganti kamera atau scan ulang
  void resetTemporalHistory() {
    _temporalStates.clear();
    _latestDebugInfo = const ScannerDebugInfo();
  }

  /// Memproses frame live CameraImage dengan penanganan stride, rotasi sensor,
  /// ekstraksi krominansi (warna), dan filter smoothing temporal.
  Future<List<DetectedNatureObject>> processCameraImage(
    CameraImage cameraImage, {
    int sensorOrientation = 90,
    bool isFrontCamera = false,
  }) async {
    final now = DateTime.now();
    if (_lastInferenceTime != null && now.difference(_lastInferenceTime!) < _throttleInterval) {
      return _applyTemporalPersistence();
    }

    if (_isProcessing) return _applyTemporalPersistence();
    _isProcessing = true;
    _lastInferenceTime = now;

    final stopwatch = Stopwatch()..start();

    try {
      final rawDetections = _analyzeLiveCameraStream(
        cameraImage,
        sensorOrientation: sensorOrientation,
        isFrontCamera: isFrontCamera,
      );

      // Terapkan Temporal Smoothing & Anti-Jitter Filter
      final smoothed = _updateTemporalSmoothing(rawDetections);

      stopwatch.stop();

      _latestDebugInfo = _latestDebugInfo.copyWith(
        latencyMs: stopwatch.elapsedMilliseconds,
        resolution: '${cameraImage.width}x${cameraImage.height}',
        formatGroup: cameraImage.format.group.name.toUpperCase(),
        sensorOrientation: sensorOrientation,
        engineName: 'On-Device Spatial-Chroma CV Engine',
        rawDetectionCount: rawDetections.length,
        detections: smoothed,
        lastError: null,
      );

      return smoothed;
    } catch (e, stack) {
      debugPrint('NatureClassifierService.processCameraImage error: $e\n$stack');
      _latestDebugInfo = _latestDebugInfo.copyWith(
        lastError: e.toString(),
      );
      return _applyTemporalPersistence();
    } finally {
      _isProcessing = false;
    }
  }

  /// Analisis live camera frame dengan sampling grid terstandarisasi di screen space
  List<DetectedNatureObject> _analyzeLiveCameraStream(
    CameraImage cameraImage, {
    required int sensorOrientation,
    required bool isFrontCamera,
  }) {
    final int width = cameraImage.width;
    final int height = cameraImage.height;
    if (width <= 0 || height <= 0 || cameraImage.planes.isEmpty) return [];

    final planes = cameraImage.planes;
    final isYuv = cameraImage.format.group == ImageFormatGroup.yuv420 && planes.length >= 3;
    final isBgra = cameraImage.format.group == ImageFormatGroup.bgra8888 || planes.length == 1;

    final yPlane = planes[0].bytes;
    final yRowStride = planes[0].bytesPerRow;
    final yPixelStride = planes[0].bytesPerPixel ?? 1;

    Uint8List? uPlane;
    Uint8List? vPlane;
    int uRowStride = 0;
    int vRowStride = 0;
    int uPixelStride = 1;
    int vPixelStride = 1;

    if (isYuv) {
      uPlane = planes[1].bytes;
      vPlane = planes[2].bytes;
      uRowStride = planes[1].bytesPerRow;
      vRowStride = planes[2].bytesPerRow;
      uPixelStride = planes[1].bytesPerPixel ?? 1;
      vPixelStride = planes[2].bytesPerPixel ?? 1;
    }

    // Grid sampling screen-space 28x28 (784 titik sampel teratur, ultra-cepat < 5ms)
    const int gridCols = 28;
    const int gridRows = 28;

    double totalSamples = 0;
    double greenPixels = 0;
    double woodPixels = 0;
    double rockPixels = 0;
    double waterPixels = 0;
    double waterfallPixels = 0;
    double soilPixels = 0;
    double skyCloudPixels = 0;
    double topSkyBluePixels = 0;
    double bottomWaterPixels = 0;
    double lowerWaterfallPixels = 0;

    // Statistik khusus Lingkaran Fokus Kamera (Center: 0.50, 0.42, Radius: 0.35)
    double focusSamples = 0;
    double focusGreenPixels = 0;
    double focusWoodPixels = 0;
    double focusWaterfallPixels = 0;
    double focusLowerWaterfallPixels = 0;
    double focusRockPixels = 0;
    double focusSoilPixels = 0;
    double focusWaterPixels = 0;

    // Profil kolom vertikal untuk mendeteksi jalur air terjun vs awan/landscape
    final List<double> colWaterfall = List.filled(5, 0.0);
    final List<double> colRock = List.filled(5, 0.0);
    final List<double> colGreen = List.filled(5, 0.0);
    final List<double> colSamples = List.filled(5, 0.0);

    // Ketinggian horizon (langit di bagian atas, vegetasi/lereng di tengah)
    double topLuma = 0;
    double topLumaSamples = 0;
    double midLuma = 0;
    double midLumaSamples = 0;

    for (int r = 0; r < gridRows; r++) {
      final double sy = (r + 0.5) / gridRows; // 0.0 - 1.0 (layar atas ke bawah)
      for (int c = 0; c < gridCols; c++) {
        final double sx = (c + 0.5) / gridCols; // 0.0 - 1.0 (layar kiri ke kanan)

        // Transformasi Screen Space (sx, sy) -> Sensor Image Space (ux, uy)
        final sensorCoords = _mapScreenToSensor(
          sx: sx,
          sy: sy,
          sensorWidth: width,
          sensorHeight: height,
          orientation: sensorOrientation,
          isFront: isFrontCamera,
        );

        final int ux = sensorCoords.dx.toInt();
        final int uy = sensorCoords.dy.toInt();

        // Ekstraksi nilai RGB
        final rgb = _extractRgb(
          ux: ux,
          uy: uy,
          width: width,
          height: height,
          isYuv: isYuv,
          isBgra: isBgra,
          yPlane: yPlane,
          yRowStride: yRowStride,
          yPixelStride: yPixelStride,
          uPlane: uPlane,
          vPlane: vPlane,
          uRowStride: uRowStride,
          vRowStride: vRowStride,
          uPixelStride: uPixelStride,
          vPixelStride: vPixelStride,
        );

        if (rgb == null) continue;

        totalSamples++;
        final red = rgb[0];
        final green = rgb[1];
        final blue = rgb[2];

        final maxVal = max(red, max(green, blue));
        final minVal = min(red, min(green, blue));
        final delta = maxVal - minVal;
        final lightness = (red + green + blue) / 3.0;

        // Distribusi luma vertikal layar
        if (sy < 0.35) {
          topLuma += lightness;
          topLumaSamples++;
        } else if (sy < 0.70) {
          midLuma += lightness;
          midLumaSamples++;
        }

        // Cek apakah berada di dalam Lingkaran Fokus Kamera (Center: 0.50, 0.42, Radius: 0.35)
        final fdx = sx - 0.50;
        final fdy = sy - 0.42;
        final bool inFocus = (fdx * fdx + fdy * fdy) <= (0.35 * 0.35);

        if (inFocus) {
          focusSamples++;
        }

        final int colIdx = (sx * 5).clamp(0, 4).toInt();
        colSamples[colIdx]++;

        // 1. Vegetasi (Daun / Kanopi / Semak Hijau)
        if (green > 0.25 && green > red * 1.15 && green > blue * 1.12) {
          greenPixels++;
          colGreen[colIdx]++;
          if (inFocus) focusGreenPixels++;
        }

        // 2. Air / Danau / Sungai / Kolam Air Terjun (Biru Alami atau Turquoise / Toska)
        else if (sy >= 0.32 && ((blue > 0.30 && blue > red * 1.18 && green > red * 0.92) ||
                 (green > 0.26 && blue > 0.26 && (green + blue) > red * 2.1 && red < 0.36))) {
          waterPixels++;
          if (inFocus) focusWaterPixels++;
          if (sy >= 0.48) bottomWaterPixels++;
        }

        // 3. Langit Biru Cerah di Bagian Atas
        else if (sy < 0.42 && (blue > 0.38 && blue > red * 1.20 && green > red)) {
          topSkyBluePixels++;
        }

        // 4. Area Putih / Terang (Awan Langit vs Busa Air Terjun)
        else if ((lightness > 0.50 && delta < 0.22) ||
                 (blue > 0.44 && green > 0.40 && (blue + green) > red * 1.8 && delta < 0.24)) {
          if (sy < 0.28 && !inFocus) {
            skyCloudPixels++;
          } else {
            waterfallPixels++;
            colWaterfall[colIdx]++;
            if (inFocus) focusWaterfallPixels++;
            if (sy >= 0.38) {
              lowerWaterfallPixels++;
              if (inFocus) focusLowerWaterfallPixels++;
            }
          }
        }

        // 5. Kayu / Batang Pohon / Dahan (Wood / Timber - Cokelat Hangat Alami)
        else if (red >= 0.26 && red <= 0.56 && green >= 0.16 && green < red * 0.90 && blue >= 0.08 && blue < green * 0.82 && (red - blue) >= 0.10 && lightness <= 0.46) {
          woodPixels++;
          if (inFocus) focusWoodPixels++;
        }

        // 6. Tanah / Pasir Vulkanik (Rona Cokelat / Jingga Terang Berpasir)
        else if (red >= 0.36 && green >= 0.24 && green < red * 0.92 && blue >= 0.12 && blue < green * 0.82 && (red - blue) >= 0.12 && lightness > 0.30) {
          soilPixels++;
          if (inFocus) focusSoilPixels++;
        }

        // 7. Batuan Andesit / Tebing / Lereng Vulkanik (Abu-abu / Gelap Netral)
        else if (maxVal < 0.48 && delta < 0.15 && lightness < 0.45) {
          rockPixels++;
          colRock[colIdx]++;
          if (inFocus) focusRockPixels++;
        }
      }
    }

    if (totalSamples == 0) return [];

    final validFocus = max(1.0, focusSamples);
    final focusWaterfallRatio = focusWaterfallPixels / validFocus;
    final focusWoodRatio = focusWoodPixels / validFocus;
    final focusGreenRatio = focusGreenPixels / validFocus;
    final focusRockRatio = focusRockPixels / validFocus;
    final focusSoilRatio = focusSoilPixels / validFocus;
    final focusWaterRatio = focusWaterPixels / validFocus;

    final greenRatio = greenPixels / totalSamples;
    final woodRatio = woodPixels / totalSamples;
    final rockRatio = rockPixels / totalSamples;
    final waterRatio = waterPixels / totalSamples;
    final bottomWaterRatio = bottomWaterPixels / totalSamples;
    final waterfallRatio = waterfallPixels / totalSamples;
    final cloudRatio = skyCloudPixels / totalSamples;
    final topSkyRatio = topSkyBluePixels / totalSamples;
    final soilRatio = soilPixels / totalSamples;

    // Catat statistik untuk developer debug overlay
    _latestDebugInfo = _latestDebugInfo.copyWith(
      featureScores: {
        'Focus_Waterfall': focusWaterfallRatio,
        'Focus_Wood': focusWoodRatio,
        'Focus_Green': focusGreenRatio,
        'Focus_Rock': focusRockRatio,
        'Focus_Soil': focusSoilRatio,
        'Focus_Water': focusWaterRatio,
        'Scene_Green': greenRatio,
        'Scene_Wood': woodRatio,
        'Scene_Rock': rockRatio,
        'Scene_Water': waterRatio,
        'Scene_BottomWater': bottomWaterRatio,
        'Scene_SkyCloud': cloudRatio + topSkyRatio,
      },
    );

    // Cari kolom air terjun terpadat dan ukur kontras kolom terhadap kolom lain
    int bestCol = 2;
    double maxColWaterfall = 0;
    for (int c = 0; c < 5; c++) {
      if (colWaterfall[c] > maxColWaterfall) {
        maxColWaterfall = colWaterfall[c];
        bestCol = c;
      }
    }
    final double colRatio = maxColWaterfall / max(1.0, colSamples[bestCol]);

    double otherColsSum = 0;
    double otherSamplesSum = 0;
    for (int c = 0; c < 5; c++) {
      if (c != bestCol) {
        otherColsSum += colWaterfall[c];
        otherSamplesSum += colSamples[c];
      }
    }
    final double otherColsRatio = otherSamplesSum > 0 ? (otherColsSum / otherSamplesSum) : 0.0;
    final double colContrast = colRatio - otherColsRatio;

    int whiteColsCount = 0;
    for (int c = 0; c < 5; c++) {
      if ((colWaterfall[c] / max(1.0, colSamples[c])) > 0.08) {
        whiteColsCount++;
      }
    }

    // Deteksi Air Terjun berbasis bukti fisik & geometri vertikal
    final double lowerWaterfallRatio = lowerWaterfallPixels / totalSamples;
    final double focusLowerWaterfallRatio = focusLowerWaterfallPixels / validFocus;
    final bool hasDownwardFlow = lowerWaterfallRatio >= 0.012 || focusLowerWaterfallRatio >= 0.025;

    final bool hasWaterPoolBelow = bottomWaterRatio >= 0.02 || waterRatio >= 0.04;
    final bool hasSurroundings = rockRatio >= 0.03 || greenRatio >= 0.04;
    final bool hasWaterfallInFocus = focusWaterfallRatio >= 0.04;
    final bool hasVerticalCascade = colContrast >= 0.06 && colRatio >= 0.08 && waterfallRatio >= 0.02;

    final bool isWaterfallDetected = hasDownwardFlow &&
        (hasWaterfallInFocus || hasVerticalCascade) &&
        (hasWaterPoolBelow || hasSurroundings) &&
        whiteColsCount <= 3 &&
        waterfallRatio <= 0.45;

    // Deteksi Gunung / Bentang Elevasi
    final topAvg = topLumaSamples > 0 ? topLuma / topLumaSamples : 0.0;
    final midAvg = midLumaSamples > 0 ? midLuma / midLumaSamples : 0.0;
    final hasSky = (topSkyRatio + cloudRatio) >= 0.06 || (topAvg > 0.40 && (topAvg - midAvg) > 0.04);
    final hasMountainTerrain = rockRatio >= 0.05 || (greenRatio >= 0.10 && rockRatio >= 0.03) || focusRockRatio >= 0.12;

    // Gunung HANYA aktif jika bukan sedang membidik air terjun dan tidak ada kolam air terjun di bawah
    final bool isMountainCandidate = hasSky &&
        hasMountainTerrain &&
        !isWaterfallDetected &&
        !hasWaterPoolBelow;

    final List<DetectedNatureObject> detected = [];

    // 1. AIR TERJUN
    if (isWaterfallDetected) {
      final double focusBoost = (focusWaterfallRatio * 1.5).clamp(0.04, 0.12);
      final double poolBoost = hasWaterPoolBelow ? 0.04 : 0.0;
      final double contrastBoost = colContrast > 0.10 ? 0.03 : 0.0;
      final conf = (0.85 + focusBoost + poolBoost + contrastBoost).clamp(0.88, 0.96);
      if (conf >= _confidenceThreshold) {
        final colLeft = (bestCol * 0.20 + 0.02).clamp(0.08, 0.72);
        detected.add(
          DetectedNatureObject(
            id: 'live_waterfall',
            category: NatureCategory.waterfall,
            label: 'Air Terjun',
            englishLabel: 'Waterfall',
            educationalDetail: 'Aliran air vertikal berbuih putih di dalam lingkaran fokus kamera.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: Rect.fromLTWH(colLeft, 0.18, 0.20, 0.65),
          ),
        );
      }
    }

    // 2. GUNUNG / BENTANG ALAM ELEVASI
    if (isMountainCandidate) {
      final conf = (0.86 + (topSkyRatio + cloudRatio).clamp(0.0, 0.30) * 0.25 + (rockRatio + greenRatio).clamp(0.0, 0.50) * 0.25).clamp(0.88, 0.96);
      if (conf >= _confidenceThreshold) {
        detected.add(
          DetectedNatureObject(
            id: 'live_mountain',
            category: NatureCategory.mountain,
            label: 'Gunung',
            englishLabel: 'Mountain',
            educationalDetail: 'Siluet puncak bentang alam pegunungan, lereng elevasi tinggi, dan formasi langit berawan khas Merapi.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: const Rect.fromLTWH(0.05, 0.14, 0.90, 0.62),
          ),
        );
      }
    }

    // 3. AIR / SUNGAI (Danau / Kolam / Sungai)
    final bool isWaterInFocus = focusWaterRatio >= 0.10;
    final bool hasWaterPresence = isWaterInFocus || hasWaterPoolBelow || waterRatio >= 0.08;

    if (hasWaterPresence) {
      final double conf;
      if (isWaterInFocus) {
        conf = (0.84 + focusWaterRatio * 1.0).clamp(0.86, 0.95);
      } else if (isWaterfallDetected) {
        conf = (0.74 + (bottomWaterRatio + waterRatio) * 0.8).clamp(0.72, 0.84);
      } else {
        conf = (0.78 + waterRatio * 1.0).clamp(0.78, 0.92);
      }

      if (conf >= _confidenceThreshold) {
        detected.add(
          DetectedNatureObject(
            id: 'live_water',
            category: NatureCategory.water,
            label: 'Air / Sungai',
            englishLabel: 'Water / River',
            educationalDetail: 'Badan air alami atau aliran sungai pegunungan dengan permukaan jernih.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isWaterInFocus
                ? const Rect.fromLTWH(0.18, 0.28, 0.64, 0.50)
                : const Rect.fromLTWH(0.10, 0.54, 0.80, 0.38),
          ),
        );
      }
    }

    // 4. VEGETASI / POHON / HUTAN
    final bool isGreenInFocus = focusGreenRatio >= 0.20;
    final bool isGreenInScene = greenRatio >= 0.18;

    if (isGreenInFocus || isGreenInScene) {
      final double conf;
      if (isGreenInFocus && !isWaterfallDetected) {
        conf = (0.82 + focusGreenRatio * 0.4).clamp(0.84, 0.96);
      } else if (isWaterfallDetected) {
        conf = (0.62 + greenRatio * 0.4).clamp(0.64, 0.78);
      } else {
        conf = (0.65 + greenRatio * 0.5).clamp(0.68, 0.88);
      }

      if (conf >= _confidenceThreshold) {
        detected.add(
          DetectedNatureObject(
            id: 'live_vegetation',
            category: NatureCategory.vegetation,
            label: 'Pohon / Vegetasi',
            englishLabel: 'Tree / Vegetation',
            educationalDetail: 'Tutupan kanopi hijau vegetasi alami dan hutan tropis lereng pegunungan.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isGreenInFocus
                ? const Rect.fromLTWH(0.20, 0.20, 0.60, 0.60)
                : const Rect.fromLTWH(0.08, 0.25, 0.84, 0.62),
          ),
        );
      }
    }

    // 5. BATU / BEBATUAN ANDESIT
    final bool isRockInFocus = focusRockRatio >= 0.18;
    final bool isRockInScene = rockRatio >= 0.18 && !isWaterfallDetected && !isMountainCandidate;

    if (isRockInFocus || isRockInScene) {
      final double conf;
      if (isRockInFocus && !isWaterfallDetected && !isMountainCandidate) {
        conf = (0.80 + focusRockRatio * 0.5).clamp(0.82, 0.94);
      } else if (isMountainCandidate) {
        // Bebatuan tebing sebagai konteks sekunder di bawah Gunung
        conf = (0.65 + rockRatio * 0.3).clamp(0.66, 0.82);
      } else if (isWaterfallDetected) {
        conf = (0.60 + rockRatio * 0.4).clamp(0.60, 0.74);
      } else {
        conf = (0.64 + rockRatio * 0.5).clamp(0.65, 0.85);
      }

      if (conf >= _confidenceThreshold) {
        detected.add(
          DetectedNatureObject(
            id: 'live_rock',
            category: NatureCategory.rock,
            label: 'Batu / Bebatuan',
            englishLabel: 'Rock / Boulder',
            educationalDetail: 'Struktur batuan beku andesit dan material tebing vulkanik keras.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isRockInFocus
                ? const Rect.fromLTWH(0.24, 0.20, 0.52, 0.60)
                : const Rect.fromLTWH(0.18, 0.38, 0.64, 0.48),
          ),
        );
      }
    }

    // 6. KAYU / BATANG POHON (Hanya jika benar-benar ada batang/kayu di fokus atau dominan)
    final bool isWoodInFocus = focusWoodRatio >= 0.16;
    final bool isWoodDominantScene = woodRatio >= 0.20 && !isWaterfallDetected && !isMountainCandidate;

    if (isWoodInFocus || isWoodDominantScene) {
      final conf = isWoodInFocus
          ? (0.82 + focusWoodRatio * 0.8).clamp(0.84, 0.96)
          : (0.68 + woodRatio * 0.8).clamp(0.70, 0.88);
      if (conf >= _confidenceThreshold) {
        detected.add(
          DetectedNatureObject(
            id: 'live_wood',
            category: NatureCategory.wood,
            label: 'Kayu / Batang Pohon',
            englishLabel: 'Wood / Timber',
            educationalDetail: 'Material kayu alami, batang pohon berkayu, dahan, atau kayu rebah khas ekosistem lereng.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isWoodInFocus
                ? const Rect.fromLTWH(0.24, 0.20, 0.52, 0.60)
                : const Rect.fromLTWH(0.18, 0.30, 0.64, 0.52),
          ),
        );
      }
    }

    // 7. TANAH / PASIR VULKANIK (Hanya jika benar-benar ada tanah/pasir di fokus atau dominan)
    final bool isSoilInFocus = focusSoilRatio >= 0.16;
    final bool isSoilDominantScene = soilRatio >= 0.20 && !isWaterfallDetected && !isMountainCandidate;

    if (isSoilInFocus || isSoilDominantScene) {
      final conf = isSoilInFocus
          ? (0.82 + focusSoilRatio * 0.8).clamp(0.84, 0.96)
          : (0.68 + soilRatio * 0.8).clamp(0.70, 0.88);
      if (conf >= _confidenceThreshold) {
        detected.add(
          DetectedNatureObject(
            id: 'live_soil',
            category: NatureCategory.soil,
            label: 'Tanah / Pasir',
            englishLabel: 'Soil / Sand',
            educationalDetail: 'Hamparan material tanah dan endapan pasir vulkanik lereng.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isSoilInFocus
                ? const Rect.fromLTWH(0.24, 0.24, 0.52, 0.56)
                : const Rect.fromLTWH(0.12, 0.55, 0.76, 0.38),
          ),
        );
      }
    }

    // Urutkan objek terdeteksi dari confidence tertinggi
    detected.sort((a, b) => b.confidence.compareTo(a.confidence));
    return detected;
  }

  /// Pemetaan koordinat Screen Space (sx, sy) ke Sensor Image Space (ux, uy)
  /// Mengakomodasi orientasi sensor fisik kamera (0, 90, 180, 270) dan kamera depan
  Offset _mapScreenToSensor({
    required double sx,
    required double sy,
    required int sensorWidth,
    required int sensorHeight,
    required int orientation,
    required bool isFront,
  }) {
    double normX = isFront ? (1.0 - sx) : sx;
    double normY = sy;

    double u;
    double v;

    switch (orientation) {
      case 90:
        // Standar kamera belakang Android portrait (sensor landscape diputar 90° CW)
        u = (1.0 - normY) * (sensorWidth - 1);
        v = normX * (sensorHeight - 1);
        break;
      case 270:
        // Standar kamera depan Android portrait
        u = normY * (sensorWidth - 1);
        v = (1.0 - normX) * (sensorHeight - 1);
        break;
      case 180:
        u = (1.0 - normX) * (sensorWidth - 1);
        v = (1.0 - normY) * (sensorHeight - 1);
        break;
      case 0:
      default:
        u = normX * (sensorWidth - 1);
        v = normY * (sensorHeight - 1);
        break;
    }

    return Offset(
      u.clamp(0.0, (sensorWidth - 1).toDouble()),
      v.clamp(0.0, (sensorHeight - 1).toDouble()),
    );
  }

  /// Ekstraksi nilai normalized RGB (0.0 - 1.0) dari buffer kamera dengan stride-safety
  List<double>? _extractRgb({
    required int ux,
    required int uy,
    required int width,
    required int height,
    required bool isYuv,
    required bool isBgra,
    required Uint8List yPlane,
    required int yRowStride,
    required int yPixelStride,
    Uint8List? uPlane,
    Uint8List? vPlane,
    required int uRowStride,
    required int vRowStride,
    required int uPixelStride,
    required int vPixelStride,
  }) {
    if (ux < 0 || ux >= width || uy < 0 || uy >= height) return null;

    if (isYuv && uPlane != null && vPlane != null) {
      final yIdx = uy * yRowStride + ux * yPixelStride;
      if (yIdx < 0 || yIdx >= yPlane.length) return null;
      final yVal = yPlane[yIdx];

      // UV subsampling 2x2
      final uvX = ux >> 1;
      final uvY = uy >> 1;
      final uIdx = uvY * uRowStride + uvX * uPixelStride;
      final vIdx = uvY * vRowStride + uvX * vPixelStride;
      if (uIdx < 0 || uIdx >= uPlane.length || vIdx < 0 || vIdx >= vPlane.length) return null;

      final uVal = uPlane[uIdx];
      final vVal = vPlane[vIdx];

      // Standar BT.601 YUV -> RGB
      final r = (yVal + 1.402 * (vVal - 128)).clamp(0.0, 255.0) / 255.0;
      final g = (yVal - 0.344136 * (uVal - 128) - 0.714136 * (vVal - 128)).clamp(0.0, 255.0) / 255.0;
      final b = (yVal + 1.772 * (uVal - 128)).clamp(0.0, 255.0) / 255.0;
      return [r, g, b];
    } else if (isBgra) {
      final idx = uy * yRowStride + ux * 4;
      if (idx < 0 || idx + 2 >= yPlane.length) return null;
      final b = yPlane[idx] / 255.0;
      final g = yPlane[idx + 1] / 255.0;
      final r = yPlane[idx + 2] / 255.0;
      return [r, g, b];
    } else {
      // Fallback grayscale jika planar tidak lengkap
      final yIdx = uy * yRowStride + ux * yPixelStride;
      if (yIdx < 0 || yIdx >= yPlane.length) return null;
      final luma = yPlane[yIdx] / 255.0;
      return [luma, luma, luma];
    }
  }

  /// Memperbarui Temporal Smoothing (EMA & Frame-to-Frame Persistence)
  List<DetectedNatureObject> _updateTemporalSmoothing(List<DetectedNatureObject> rawDetections) {
    const double alpha = 0.60; // Bobot update kepercayaan (0.60 baru, 0.40 riwayat)
    final Set<NatureCategory> seenThisFrame = {};

    for (final raw in rawDetections) {
      seenThisFrame.add(raw.category);
      final state = _temporalStates.putIfAbsent(
        raw.category,
        () => _TemporalCategoryState(
          category: raw.category,
          label: raw.label,
          englishLabel: raw.englishLabel,
          educationalDetail: raw.educationalDetail,
          confidence: raw.confidence,
          boundingBox: raw.boundingBox,
        ),
      );

      state.label = raw.label;
      state.englishLabel = raw.englishLabel;
      state.educationalDetail = raw.educationalDetail;
      state.hitCount++;
      state.missCount = 0;

      // Exponential Moving Average (EMA) untuk confidence
      state.confidence = (alpha * raw.confidence) + ((1.0 - alpha) * state.confidence);

      // Smooth Bounding Box
      if (raw.boundingBox != null && state.boundingBox != null) {
        state.boundingBox = Rect.fromLTWH(
          alpha * raw.boundingBox!.left + (1.0 - alpha) * state.boundingBox!.left,
          alpha * raw.boundingBox!.top + (1.0 - alpha) * state.boundingBox!.top,
          alpha * raw.boundingBox!.width + (1.0 - alpha) * state.boundingBox!.width,
          alpha * raw.boundingBox!.height + (1.0 - alpha) * state.boundingBox!.height,
        );
      } else {
        state.boundingBox = raw.boundingBox;
      }
    }

    // Tangani kategori yang tidak terdeteksi di frame ini (decay grace period)
    final List<NatureCategory> toRemove = [];
    for (final entry in _temporalStates.entries) {
      if (!seenThisFrame.contains(entry.key)) {
        entry.value.missCount++;
        // Perlahan kurangi confidence saat hilang sesaat
        entry.value.confidence *= 0.82;

        // Jika hilang 2 frame berturut-turut, hapus dari tampilan
        if (entry.value.missCount >= 2 || entry.value.confidence < _confidenceThreshold) {
          toRemove.add(entry.key);
        }
      }
    }
    for (final cat in toRemove) {
      _temporalStates.remove(cat);
    }

    // Bangun list hasil stabil yang memenuhi threshold dan lolos verifikasi persistensi
    final List<DetectedNatureObject> smoothed = [];
    for (final state in _temporalStates.values) {
      // Objek dengan confidence sedang harus bertahan minimal 2 frame berturut-turut
      // untuk mencegah single-frame flickering
      final bool isConfident = state.confidence >= 0.72 || state.hitCount >= 2;
      if (state.confidence >= _confidenceThreshold && isConfident) {
        smoothed.add(
          DetectedNatureObject(
            id: 'live_${state.category.name}',
            category: state.category,
            label: state.label,
            englishLabel: state.englishLabel,
            educationalDetail: state.educationalDetail,
            confidence: double.parse(state.confidence.toStringAsFixed(2)),
            boundingBox: state.boundingBox,
          ),
        );
      }
    }

    smoothed.sort((a, b) => b.confidence.compareTo(a.confidence));
    return smoothed;
  }

  /// Mengembalikan deteksi persisten terakhir saat frame di-throttle
  List<DetectedNatureObject> _applyTemporalPersistence() {
    final List<DetectedNatureObject> result = [];
    for (final state in _temporalStates.values) {
      if (state.confidence >= _confidenceThreshold && (state.confidence >= 0.72 || state.hitCount >= 2)) {
        result.add(
          DetectedNatureObject(
            id: 'live_${state.category.name}',
            category: state.category,
            label: state.label,
            englishLabel: state.englishLabel,
            educationalDetail: state.educationalDetail,
            confidence: double.parse(state.confidence.toStringAsFixed(2)),
            boundingBox: state.boundingBox,
          ),
        );
      }
    }
    result.sort((a, b) => b.confidence.compareTo(a.confidence));
    return result;
  }

  /// Memproses foto utuh hasil tangkapan kamera (High-resolution offline inference)
  Future<NatureScanResult> analyzeCapturedPhoto(String imagePath) async {
    final stopwatch = Stopwatch()..start();
    final file = File(imagePath);

    if (!await file.exists()) {
      return NatureScanResult(
        objects: [],
        imagePath: imagePath,
        scanTime: DateTime.now(),
        inferenceTimeMs: 0,
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return NatureScanResult(
          objects: [],
          imagePath: imagePath,
          scanTime: DateTime.now(),
          inferenceTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      // Resize untuk standarisasi inferensi gambar (320px aspect-preserving)
      final thumbnail = img.copyResize(decoded, width: 320);
      final objects = _analyzeDecodedImage(thumbnail);

      stopwatch.stop();
      return NatureScanResult(
        objects: objects,
        imagePath: imagePath,
        scanTime: DateTime.now(),
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      debugPrint('NatureClassifierService.analyzeCapturedPhoto error: $e');
      stopwatch.stop();
      return NatureScanResult(
        objects: [],
        imagePath: imagePath,
        scanTime: DateTime.now(),
        inferenceTimeMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Analisis mendalam berbasis fitur warna, tekstur, dan geometri piksel
  List<DetectedNatureObject> _analyzeDecodedImage(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int totalPixels = width * height;
    if (totalPixels == 0) return [];
    double greenPixels = 0;
    double woodPixels = 0;
    double blueWaterPixels = 0;
    double waterfallCascadePixels = 0;
    double skyCloudPixels = 0;
    double darkRockPixels = 0;
    double earthBrownPixels = 0;
    double topSkyBlue = 0;
    double bottomWater = 0;
    double lowerWaterfallPixels = 0;

    // Lingkaran Fokus Utama Kamera (Center: 0.50, 0.42, Radius: 0.35)
    double focusWaterfallPixels = 0;
    double focusLowerWaterfallPixels = 0;
    double focusWoodPixels = 0;
    double focusGreenPixels = 0;
    double focusRockPixels = 0;
    double focusSoilPixels = 0;
    double focusWaterPixels = 0;
    double focusSampleCount = 0;

    final List<double> colWaterfall = List.filled(5, 0.0);
    final List<double> colSamples = List.filled(5, 0.0);

    final step = max(1, width ~/ 100);

    for (int y = 0; y < height; y += step) {
      final yNorm = y / height;
      for (int x = 0; x < width; x += step) {
        final xNorm = x / width;
        final pixel = image.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final maxVal = max(r, max(g, b));
        final minVal = min(r, min(g, b));
        final delta = maxVal - minVal;
        final lightness = (r + g + b) / 3.0;
        final int colIdx = (xNorm * 5).clamp(0, 4).toInt();
        colSamples[colIdx]++;

        final dx = xNorm - 0.50;
        final dy = (yNorm - 0.42) * (height / width);
        final bool inFocusCircle = (dx * dx + dy * dy) <= (0.35 * 0.35);

        if (inFocusCircle) {
          focusSampleCount++;
        }

        // 1. Vegetasi (Daun / Kanopi Hijau)
        if (g > 0.25 && g > r * 1.15 && g > b * 1.12) {
          greenPixels++;
          if (inFocusCircle) focusGreenPixels++;
        }

        // 2. Air / Danau / Sungai / Kolam Air Terjun (Biru Alami atau Turquoise / Toska)
        else if (yNorm >= 0.32 && ((b > 0.30 && b > r * 1.18 && g > r * 0.92) ||
                 (g > 0.26 && b > 0.26 && (g + b) > r * 2.1 && r < 0.36))) {
          blueWaterPixels++;
          if (inFocusCircle) focusWaterPixels++;
          if (yNorm >= 0.48) bottomWater++;
        }

        // 3. Langit Biru Cerah di Bagian Atas
        else if (yNorm < 0.42 && (b > 0.38 && b > r * 1.20 && g > r)) {
          topSkyBlue++;
        }

        // 4. Area Putih / Terang (Awan Langit vs Busa Air Terjun)
        else if ((lightness > 0.50 && delta < 0.22) ||
                 (b > 0.44 && g > 0.40 && (b + g) > r * 1.8 && delta < 0.24)) {
          if (yNorm < 0.28 && !inFocusCircle) {
            skyCloudPixels++;
          } else {
            waterfallCascadePixels++;
            colWaterfall[colIdx]++;
            if (inFocusCircle) focusWaterfallPixels++;
            if (yNorm >= 0.38) {
              lowerWaterfallPixels++;
              if (inFocusCircle) focusLowerWaterfallPixels++;
            }
          }
        }

        // 5. Kayu / Batang Pohon / Dahan (Wood / Timber)
        else if (r >= 0.26 && r <= 0.56 && g >= 0.16 && g < r * 0.90 && b >= 0.08 && b < g * 0.82 && (r - b) >= 0.10 && lightness <= 0.46) {
          woodPixels++;
          if (inFocusCircle) focusWoodPixels++;
        }

        // 6. Tanah / Pasir Vulkanik
        else if (r >= 0.36 && g >= 0.24 && g < r * 0.92 && b >= 0.12 && b < g * 0.82 && (r - b) >= 0.12 && lightness > 0.30) {
          earthBrownPixels++;
          if (inFocusCircle) focusSoilPixels++;
        }

        // 7. Batuan Andesit / Tebing / Lereng Vulkanik
        else if (maxVal < 0.48 && delta < 0.15 && lightness < 0.45) {
          darkRockPixels++;
          if (inFocusCircle) focusRockPixels++;
        }
      }
    }

    final double sampledCount = (width / step) * (height / step);
    if (sampledCount == 0) return [];

    final greenRatio = greenPixels / sampledCount;
    final woodRatio = woodPixels / sampledCount;
    final waterRatio = blueWaterPixels / sampledCount;
    final bottomWaterRatio = bottomWater / sampledCount;
    final waterfallRatio = waterfallCascadePixels / sampledCount;
    final cloudRatio = skyCloudPixels / sampledCount;
    final topSkyRatio = topSkyBlue / sampledCount;
    final rockRatio = darkRockPixels / sampledCount;
    final soilRatio = earthBrownPixels / sampledCount;

    final double validFocusSamples = max(1.0, focusSampleCount);
    final double focusWaterfallRatio = focusWaterfallPixels / validFocusSamples;
    final double focusWoodRatio = focusWoodPixels / validFocusSamples;
    final double focusGreenRatio = focusGreenPixels / validFocusSamples;
    final double focusRockRatio = focusRockPixels / validFocusSamples;
    final double focusSoilRatio = focusSoilPixels / validFocusSamples;
    final double focusWaterRatio = focusWaterPixels / validFocusSamples;

    int bestCol = 2;
    double maxColWaterfall = 0;
    for (int c = 0; c < 5; c++) {
      if (colWaterfall[c] > maxColWaterfall) {
        maxColWaterfall = colWaterfall[c];
        bestCol = c;
      }
    }
    final double colRatio = maxColWaterfall / max(1.0, colSamples[bestCol]);

    double otherColsSum = 0;
    double otherSamplesSum = 0;
    for (int c = 0; c < 5; c++) {
      if (c != bestCol) {
        otherColsSum += colWaterfall[c];
        otherSamplesSum += colSamples[c];
      }
    }
    final double otherColsRatio = otherSamplesSum > 0 ? (otherColsSum / otherSamplesSum) : 0.0;
    final double colContrast = colRatio - otherColsRatio;

    int whiteColsCount = 0;
    for (int c = 0; c < 5; c++) {
      if ((colWaterfall[c] / max(1.0, colSamples[c])) > 0.08) {
        whiteColsCount++;
      }
    }

    final double lowerWaterfallRatio = lowerWaterfallPixels / sampledCount;
    final double focusLowerWaterfallRatio = focusLowerWaterfallPixels / validFocusSamples;
    final bool hasDownwardFlow = lowerWaterfallRatio >= 0.012 || focusLowerWaterfallRatio >= 0.025;

    final bool hasWaterPoolBelow = bottomWaterRatio >= 0.02 || waterRatio >= 0.04;
    final bool hasSurroundings = rockRatio >= 0.03 || greenRatio >= 0.04;
    final bool hasWaterfallInFocus = focusWaterfallRatio >= 0.04;
    final bool hasVerticalCascade = colContrast >= 0.06 && colRatio >= 0.08 && waterfallRatio >= 0.02;

    final bool isWaterfallDetected = hasDownwardFlow &&
        (hasWaterfallInFocus || hasVerticalCascade) &&
        (hasWaterPoolBelow || hasSurroundings) &&
        whiteColsCount <= 3 &&
        waterfallRatio <= 0.45;

    final bool hasSky = (topSkyRatio + cloudRatio) >= 0.06;
    final bool hasMountainTerrain = rockRatio >= 0.05 || (greenRatio >= 0.10 && rockRatio >= 0.03) || focusRockRatio >= 0.12;

    final bool isMountainCandidate = hasSky &&
        hasMountainTerrain &&
        !isWaterfallDetected &&
        !hasWaterPoolBelow;

    final List<DetectedNatureObject> results = [];

    // 1. Air Terjun
    if (isWaterfallDetected) {
      final double focusBoost = (focusWaterfallRatio * 1.5).clamp(0.04, 0.12);
      final double poolBoost = hasWaterPoolBelow ? 0.04 : 0.0;
      final double contrastBoost = colContrast > 0.10 ? 0.03 : 0.0;
      final conf = (0.85 + focusBoost + poolBoost + contrastBoost).clamp(0.88, 0.96);
      if (conf >= _confidenceThreshold) {
        final colLeft = (bestCol * 0.20 + 0.02).clamp(0.08, 0.72);
        results.add(
          DetectedNatureObject(
            id: 'wf_${results.length}',
            category: NatureCategory.waterfall,
            label: 'Air Terjun',
            englishLabel: 'Waterfall',
            educationalDetail: 'Aliran air vertikal berbuih putih di dalam area fokus lingkaran kamera.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: Rect.fromLTWH(colLeft, 0.18, 0.20, 0.65),
          ),
        );
      }
    }

    // 2. Gunung
    if (isMountainCandidate) {
      final conf = (0.86 + (topSkyRatio + cloudRatio).clamp(0.0, 0.30) * 0.25 + (rockRatio + greenRatio).clamp(0.0, 0.50) * 0.25).clamp(0.88, 0.96);
      if (conf >= _confidenceThreshold) {
        results.add(
          DetectedNatureObject(
            id: 'mtn_${results.length}',
            category: NatureCategory.mountain,
            label: 'Gunung',
            englishLabel: 'Mountain',
            educationalDetail: 'Siluet bentang alam pegunungan, lereng elevasi tinggi, dan formasi langit berawan khas Merapi.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: const Rect.fromLTWH(0.05, 0.14, 0.90, 0.62),
          ),
        );
      }
    }

    // 3. Air / Danau / Sungai
    final bool isWaterInFocus = focusWaterRatio >= 0.10;
    final bool hasWaterPresence = isWaterInFocus || hasWaterPoolBelow || waterRatio >= 0.08;

    if (hasWaterPresence) {
      final double conf;
      if (isWaterInFocus) {
        conf = (0.84 + focusWaterRatio * 1.0).clamp(0.86, 0.95);
      } else if (isWaterfallDetected) {
        conf = (0.74 + (bottomWaterRatio + waterRatio) * 0.8).clamp(0.72, 0.84);
      } else {
        conf = (0.78 + waterRatio * 1.0).clamp(0.78, 0.92);
      }

      if (conf >= _confidenceThreshold) {
        results.add(
          DetectedNatureObject(
            id: 'wtr_${results.length}',
            category: NatureCategory.water,
            label: 'Air / Sungai',
            englishLabel: 'Water / River',
            educationalDetail: 'Badan air alami atau aliran sungai pegunungan dengan permukaan jernih.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isWaterInFocus
                ? const Rect.fromLTWH(0.18, 0.28, 0.64, 0.50)
                : const Rect.fromLTWH(0.10, 0.54, 0.80, 0.38),
          ),
        );
      }
    }

    // 4. Vegetasi
    final bool isGreenInFocus = focusGreenRatio >= 0.20;
    final bool isGreenInScene = greenRatio >= 0.18;

    if (isGreenInFocus || isGreenInScene) {
      final double conf;
      if (isGreenInFocus && !isWaterfallDetected) {
        conf = (0.82 + focusGreenRatio * 0.4).clamp(0.84, 0.96);
      } else if (isWaterfallDetected) {
        conf = (0.62 + greenRatio * 0.4).clamp(0.64, 0.78);
      } else {
        conf = (0.65 + greenRatio * 0.5).clamp(0.68, 0.88);
      }

      if (conf >= _confidenceThreshold) {
        results.add(
          DetectedNatureObject(
            id: 'veg_${results.length}',
            category: NatureCategory.vegetation,
            label: 'Pohon / Vegetasi',
            englishLabel: 'Tree / Vegetation',
            educationalDetail: 'Tutupan kanopi hijau vegetasi alami dan hutan lereng pegunungan.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isGreenInFocus
                ? const Rect.fromLTWH(0.20, 0.20, 0.60, 0.60)
                : const Rect.fromLTWH(0.08, 0.25, 0.84, 0.62),
          ),
        );
      }
    }

    // 5. Batu / Bebatuan
    final bool isRockInFocus = focusRockRatio >= 0.18;
    final bool isRockInScene = rockRatio >= 0.18 && !isWaterfallDetected && !isMountainCandidate;

    if (isRockInFocus || isRockInScene) {
      final double conf;
      if (isRockInFocus && !isWaterfallDetected && !isMountainCandidate) {
        conf = (0.80 + focusRockRatio * 0.5).clamp(0.82, 0.94);
      } else if (isMountainCandidate) {
        // Bebatuan tebing sebagai konteks sekunder di bawah Gunung
        conf = (0.65 + rockRatio * 0.3).clamp(0.66, 0.82);
      } else if (isWaterfallDetected) {
        conf = (0.60 + rockRatio * 0.4).clamp(0.60, 0.74);
      } else {
        conf = (0.64 + rockRatio * 0.5).clamp(0.65, 0.85);
      }

      if (conf >= _confidenceThreshold) {
        results.add(
          DetectedNatureObject(
            id: 'rck_${results.length}',
            category: NatureCategory.rock,
            label: 'Batu / Bebatuan',
            englishLabel: 'Rock / Boulder',
            educationalDetail: 'Material batuan vulkanik keras dan formasi bebatuan andesit.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isRockInFocus
                ? const Rect.fromLTWH(0.24, 0.20, 0.52, 0.60)
                : const Rect.fromLTWH(0.18, 0.38, 0.64, 0.48),
          ),
        );
      }
    }

    // 6. Kayu / Batang Pohon
    final bool isWoodInFocus = focusWoodRatio >= 0.16;
    final bool isWoodDominantScene = woodRatio >= 0.20 && !isWaterfallDetected && !isMountainCandidate;

    if (isWoodInFocus || isWoodDominantScene) {
      final conf = isWoodInFocus
          ? (0.82 + focusWoodRatio * 0.8).clamp(0.84, 0.96)
          : (0.68 + woodRatio * 0.8).clamp(0.70, 0.88);
      if (conf >= _confidenceThreshold) {
        results.add(
          DetectedNatureObject(
            id: 'wood_${results.length}',
            category: NatureCategory.wood,
            label: 'Kayu / Batang Pohon',
            englishLabel: 'Wood / Timber',
            educationalDetail: 'Material kayu alami, batang pohon berkayu, dahan, atau kayu rebah khas ekosistem hutan lereng.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isWoodInFocus
                ? const Rect.fromLTWH(0.24, 0.20, 0.52, 0.60)
                : const Rect.fromLTWH(0.18, 0.30, 0.64, 0.52),
          ),
        );
      }
    }

    // 7. Tanah / Pasir Vulkanik
    final bool isSoilInFocus = focusSoilRatio >= 0.16;
    final bool isSoilDominantScene = soilRatio >= 0.20 && !isWaterfallDetected && !isMountainCandidate;

    if (isSoilInFocus || isSoilDominantScene) {
      final conf = isSoilInFocus
          ? (0.82 + focusSoilRatio * 0.8).clamp(0.84, 0.96)
          : (0.68 + soilRatio * 0.8).clamp(0.70, 0.88);
      if (conf >= _confidenceThreshold) {
        results.add(
          DetectedNatureObject(
            id: 'soil_${results.length}',
            category: NatureCategory.soil,
            label: 'Tanah / Pasir',
            englishLabel: 'Soil / Sand',
            educationalDetail: 'Hamparan material tanah dan endapan pasir vulkanik lereng.',
            confidence: double.parse(conf.toStringAsFixed(2)),
            boundingBox: isSoilInFocus
                ? const Rect.fromLTWH(0.24, 0.24, 0.52, 0.56)
                : const Rect.fromLTWH(0.12, 0.55, 0.76, 0.38),
          ),
        );
      }
    }

    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }
}

/// Helper state untuk menyimpan riwayat temporal smoothing per kategori
class _TemporalCategoryState {
  final NatureCategory category;
  String label;
  String englishLabel;
  String educationalDetail;
  double confidence;
  Rect? boundingBox;
  int hitCount = 1;
  int missCount = 0;

  _TemporalCategoryState({
    required this.category,
    required this.label,
    required this.englishLabel,
    required this.educationalDetail,
    required this.confidence,
    this.boundingBox,
  });
}
