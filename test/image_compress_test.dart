import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:project/core/utils/image_compress_helper.dart';

void main() {
  test('Image package can create and encode WebP image', () {
    // Buat gambar uji 200x200 pixel
    final image = img.Image(width: 200, height: 200);
    img.fill(image, color: img.ColorRgb8(34, 139, 34)); // Hijau hutan Merapi

    // Encode ke WebP
    final webpBytes = Uint8List.fromList(img.encodeWebP(image, quality: 80));

    expect(webpBytes, isNotEmpty);
    // Verifikasi header WebP ('RIFF'....'WEBP')
    final headerRiff = String.fromCharCodes(webpBytes.sublist(0, 4));
    final headerWebp = String.fromCharCodes(webpBytes.sublist(8, 12));
    expect(headerRiff, 'RIFF');
    expect(headerWebp, 'WEBP');
  });

  test('ImageCompressHelper compresses PNG/JPG to WebP with downscaling', () async {
    // 1. Simulasikan gambar PNG berukuran besar 800x600
    final largeImage = img.Image(width: 800, height: 600);
    img.fill(largeImage, color: img.ColorRgb8(200, 50, 50));
    final pngBytes = Uint8List.fromList(img.encodePng(largeImage));

    // 2. Jalankan kompresi menggunakan ImageCompressHelper
    final result = await ImageCompressHelper.compressToWebP(
      pngBytes,
      quality: 80,
      maxDimension: 512,
    );

    // 3. Verifikasi hasil
    expect(result.format, 'webp');
    expect(result.mimeType, 'image/webp');
    expect(result.width, 512); // Lebar ter-downscale ke 512
    expect(result.height, (600 * 512 / 800).round()); // Rasio aspek terjaga (384)
    expect(result.compressedSizeBytes, lessThanOrEqualTo(result.originalSizeBytes));
    expect(result.savedPercentage, greaterThan(0.0));
    expect(result.summaryText, contains('KB'));
    expect(result.summaryText, contains('Hemat'));

    // Verifikasi header WebP
    final headerRiff = String.fromCharCodes(result.bytes.sublist(0, 4));
    final headerWebp = String.fromCharCodes(result.bytes.sublist(8, 12));
    expect(headerRiff, 'RIFF');
    expect(headerWebp, 'WEBP');
  });
}
