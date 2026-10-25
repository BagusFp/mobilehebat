import 'package:flutter/material.dart';

/// Kategori objek alam resmi yang didukung AI Nature Scanner MeraTrip.
/// Sesuai dengan bentang alam kawasan Gunung Merapi.
enum NatureCategory {
  mountain, // Gunung / Puncak Vulkanik
  water, // Air / Sungai / Danau
  waterfall, // Air Terjun
  vegetation, // Pohon / Hutan / Vegetasi
  wood, // Kayu / Batang Pohon / Ranting
  rock, // Batu / Bebatuan Andesit
  soil, // Tanah / Pasir Vulkanik
  building, // Bangunan / Fasilitas Wisata
  unknown,
}

/// Model objek alam yang terdeteksi oleh Computer Vision engine
class DetectedNatureObject {
  final String id;
  final NatureCategory category;
  final String label; // Nama objek Bahasa Indonesia
  final String englishLabel;
  final String educationalDetail; // Penjelasan edukatif bentang alam
  final double confidence; // Skor keyakinan (0.0 - 1.0)
  final Rect? boundingBox; // Koordinat relatif ternormalisasi (0.0-1.0) jika object detection

  const DetectedNatureObject({
    required this.id,
    required this.category,
    required this.label,
    required this.englishLabel,
    required this.educationalDetail,
    required this.confidence,
    this.boundingBox,
  });

  /// Persentase confidence score terformat
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Warna tema representatif sesuai kategori alam
  Color get themeColor {
    switch (category) {
      case NatureCategory.mountain:
        return const Color(0xFFE89005); // Amber Vulkanik
      case NatureCategory.water:
        return const Color(0xFF0284C7); // Biru Air Segar
      case NatureCategory.waterfall:
        return const Color(0xFF06B6D4); // Cyan Air Terjun
      case NatureCategory.vegetation:
        return const Color(0xFF15803D); // Hijau Hutan Merapi
      case NatureCategory.wood:
        return const Color(0xFF854D0E); // Cokelat Kayu / Timber Brown
      case NatureCategory.rock:
        return const Color(0xFF64748B); // Abu-abu Andesit
      case NatureCategory.soil:
        return const Color(0xFF92400E); // Cokelat Tanah Vulkanik
      case NatureCategory.building:
        return const Color(0xFF475569); // Slate Struktur
      case NatureCategory.unknown:
        return const Color(0xFF94A3B8);
    }
  }

  /// Ikon representatif kategori
  IconData get icon {
    switch (category) {
      case NatureCategory.mountain:
        return Icons.terrain_rounded;
      case NatureCategory.water:
        return Icons.water_drop_rounded;
      case NatureCategory.waterfall:
        return Icons.waves_rounded;
      case NatureCategory.vegetation:
        return Icons.park_rounded;
      case NatureCategory.wood:
        return Icons.forest_rounded;
      case NatureCategory.rock:
        return Icons.landscape_rounded;
      case NatureCategory.soil:
        return Icons.grain_rounded;
      case NatureCategory.building:
        return Icons.cottage_rounded;
      case NatureCategory.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.name,
      'label': label,
      'englishLabel': englishLabel,
      'educationalDetail': educationalDetail,
      'confidence': confidence,
      if (boundingBox != null)
        'boundingBox': {
          'left': boundingBox!.left,
          'top': boundingBox!.top,
          'width': boundingBox!.width,
          'height': boundingBox!.height,
        },
    };
  }
}

/// Kumpulan hasil analisis pemindaian objek alam
class NatureScanResult {
  final List<DetectedNatureObject> objects;
  final String? imagePath;
  final DateTime scanTime;
  final int inferenceTimeMs;

  const NatureScanResult({
    required this.objects,
    this.imagePath,
    required this.scanTime,
    required this.inferenceTimeMs,
  });

  bool get hasDetections => objects.isNotEmpty;

  /// Objek utama dengan confidence tertinggi
  DetectedNatureObject? get primaryObject {
    if (objects.isEmpty) return null;
    return objects.reduce((a, b) => a.confidence >= b.confidence ? a : b);
  }
}
