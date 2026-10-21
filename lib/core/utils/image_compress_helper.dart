import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Hasil proses kompresi gambar
class CompressedImageResult {
  final Uint8List bytes;
  final String format; // 'webp'
  final String mimeType; // 'image/webp'
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int width;
  final int height;

  const CompressedImageResult({
    required this.bytes,
    required this.format,
    required this.mimeType,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.width,
    required this.height,
  });

  /// Persentase penghematan ukuran file (misal 85.5%)
  double get savedPercentage {
    if (originalSizeBytes <= 0) return 0.0;
    final diff = originalSizeBytes - compressedSizeBytes;
    if (diff <= 0) return 0.0;
    return (diff / originalSizeBytes) * 100.0;
  }

  /// Ringkasan statistik kompresi yang mudah dibaca user
  String get summaryText {
    final origKb = (originalSizeBytes / 1024).toStringAsFixed(1);
    final compKb = (compressedSizeBytes / 1024).toStringAsFixed(1);
    final saved = savedPercentage.toStringAsFixed(0);
    return '$origKb KB → $compKb KB (Hemat $saved%)';
  }
}

/// Helper kompresi gambar otomatis ke format WebP ringan
/// Mendukung decoding format apapun (JPG, PNG, GIF, BMP, TIFF, dll.)
/// Dijalankan di background Isolate menggunakan [compute] agar UI tidak lag
class ImageCompressHelper {
  /// Mengompresi byte gambar format apapun ke WebP
  /// [quality]: 1-100 (default 80, keseimbangan visual tinggi & ukuran sangat kecil)
  /// [maxDimension]: resolusi maksimal lebar/tinggi (default 512px untuk avatar)
  static Future<CompressedImageResult> compressToWebP(
    Uint8List rawBytes, {
    int quality = 80,
    int maxDimension = 512,
  }) async {
    // Jalankan pemrosesan gambar di Isolate latar belakang
    return await compute(
      _processImageToWebPIsolate,
      _CompressParams(
        rawBytes: rawBytes,
        quality: quality,
        maxDimension: maxDimension,
      ),
    );
  }
}

class _CompressParams {
  final Uint8List rawBytes;
  final int quality;
  final int maxDimension;

  const _CompressParams({
    required this.rawBytes,
    required this.quality,
    required this.maxDimension,
  });
}

/// Fungsi murni yang dieksekusi di background isolate
CompressedImageResult _processImageToWebPIsolate(_CompressParams params) {
  final origSize = params.rawBytes.lengthInBytes;

  // 1. Decode gambar dari format apapun secara otomatis
  final decoded = img.decodeImage(params.rawBytes);
  if (decoded == null) {
    // Jika format tidak dikenali, fallback gunakan bytes asli
    return CompressedImageResult(
      bytes: params.rawBytes,
      format: 'jpg',
      mimeType: 'image/jpeg',
      originalSizeBytes: origSize,
      compressedSizeBytes: origSize,
      width: 0,
      height: 0,
    );
  }

  // 2. Koreksi orientasi EXIF kamera jika ada (agar foto tidak terbalik/miring)
  final oriented = img.bakeOrientation(decoded);

  // 3. Resize jika dimensi gambar melebihi batas (untuk avatar 512x512 sudah sangat tajam)
  img.Image finalImage = oriented;
  if (oriented.width > params.maxDimension || oriented.height > params.maxDimension) {
    if (oriented.width >= oriented.height) {
      finalImage = img.copyResize(
        oriented,
        width: params.maxDimension,
        interpolation: img.Interpolation.linear,
      );
    } else {
      finalImage = img.copyResize(
        oriented,
        height: params.maxDimension,
        interpolation: img.Interpolation.linear,
      );
    }
  }

  // 4. Encode ke format WebP (lossy dengan kualitas optimal)
  final webpBytes = Uint8List.fromList(
    img.encodeWebP(
      finalImage,
      quality: params.quality,
      lossless: false,
    ),
  );

  return CompressedImageResult(
    bytes: webpBytes,
    format: 'webp',
    mimeType: 'image/webp',
    originalSizeBytes: origSize,
    compressedSizeBytes: webpBytes.lengthInBytes,
    width: finalImage.width,
    height: finalImage.height,
  );
}
