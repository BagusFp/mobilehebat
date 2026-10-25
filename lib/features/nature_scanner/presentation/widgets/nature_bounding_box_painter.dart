import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/detected_nature_object.dart';

/// CustomPainter untuk menggambar bounding box interaktif dan label objek Computer Vision
class NatureBoundingBoxPainter extends CustomPainter {
  final List<DetectedNatureObject> detections;
  final Animation<double>? scanAnimation;

  NatureBoundingBoxPainter({
    required this.detections,
    this.scanAnimation,
  }) : super(repaint: scanAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final primaryColor = detections.isNotEmpty ? detections.first.themeColor : const Color(0xFF4EE39D);

    // 1. Gambar Lingkaran Fokus Utama AI di tengah layar kamera
    _drawCameraFocusCircle(canvas, size, primaryColor);

    // 2. Gambar bounding box dan label pill jika ada deteksi aktif
    for (final obj in detections) {
      if (obj.boundingBox == null) continue;

      final rect = Rect.fromLTWH(
        obj.boundingBox!.left * size.width,
        obj.boundingBox!.top * size.height,
        obj.boundingBox!.width * size.width,
        obj.boundingBox!.height * size.height,
      );

      final color = obj.themeColor;

      // Fill transparan lembut di dalam kotak deteksi
      final fillPaint = Paint()
        ..color = color.withAlpha(24)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), fillPaint);

      // Garis batas kotak utama
      final borderPaint = Paint()
        ..color = color.withAlpha(160)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), borderPaint);

      // Sudut bracket futuristik (AI Scanner Reticle)
      _drawCornerBrackets(canvas, rect, color);

      // Pill badge label dan confidence score di bagian atas kotak
      _drawLabelPill(canvas, rect, obj, color);
    }
  }

  /// Gambar Lingkaran Fokus Utama Kamera yang interaktif dan jelas
  void _drawCameraFocusCircle(Canvas canvas, Size size, Color color) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final double radius = size.width * 0.35;

    // 1. Lingkaran luar fokus tipis
    final ringPaint = Paint()
      ..color = color.withAlpha(detections.isNotEmpty ? 140 : 80)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    // 2. 4 Bracket penanda batas fokus di 4 penjuru lingkaran
    final bracketPaint = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const double tick = 18.0;
    // Kiri
    canvas.drawLine(Offset(center.dx - radius - tick, center.dy), Offset(center.dx - radius + 8, center.dy), bracketPaint);
    // Kanan
    canvas.drawLine(Offset(center.dx + radius - 8, center.dy), Offset(center.dx + radius + tick, center.dy), bracketPaint);
    // Atas
    canvas.drawLine(Offset(center.dx, center.dy - radius - tick), Offset(center.dx, center.dy - radius + 8), bracketPaint);
    // Bawah
    canvas.drawLine(Offset(center.dx, center.dy + radius - 8), Offset(center.dx, center.dy + radius + tick), bracketPaint);

    // 3. Titik bidik tengah halus (center reticle dot)
    final dotPaint = Paint()
      ..color = color.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, dotPaint);

    // 4. Label petunjuk bidik fokus di bawah lingkaran
    final hintSpan = TextSpan(
      text: detections.isNotEmpty
          ? '🎯 Terfokus: ${detections.first.label}'
          : '🎯 Fokuskan Objek di Dalam Lingkaran',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: hintSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const double horizontalPadding = 10.0;
    const double verticalPadding = 5.0;
    final hintWidth = textPainter.width + (horizontalPadding * 2);
    final hintHeight = textPainter.height + (verticalPadding * 2);
    final hintLeft = center.dx - (hintWidth / 2);
    final hintTop = center.dy + radius + 14;

    final hintRect = Rect.fromLTWH(hintLeft, hintTop, hintWidth, hintHeight);

    final hintBg = Paint()
      ..color = const Color(0xFF0F172A).withAlpha(190)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(hintRect, const Radius.circular(20)), hintBg);

    final hintBorder = Paint()
      ..color = color.withAlpha(100)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(RRect.fromRectAndRadius(hintRect, const Radius.circular(20)), hintBorder);

    textPainter.paint(canvas, Offset(hintLeft + horizontalPadding, hintTop + verticalPadding));
  }

  void _drawCornerBrackets(Canvas canvas, Rect rect, Color color) {
    final bracketPaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final length = min(16.0, min(rect.width, rect.height) * 0.25);

    // Kiri atas
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(length, 0), bracketPaint);
    canvas.drawLine(rect.topLeft, rect.topLeft + Offset(0, length), bracketPaint);

    // Kanan atas
    canvas.drawLine(rect.topRight, rect.topRight + Offset(-length, 0), bracketPaint);
    canvas.drawLine(rect.topRight, rect.topRight + Offset(0, length), bracketPaint);

    // Kiri bawah
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(length, 0), bracketPaint);
    canvas.drawLine(rect.bottomLeft, rect.bottomLeft + Offset(0, -length), bracketPaint);

    // Kanan bawah
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(-length, 0), bracketPaint);
    canvas.drawLine(rect.bottomRight, rect.bottomRight + Offset(0, -length), bracketPaint);
  }

  void _drawLabelPill(Canvas canvas, Rect rect, DetectedNatureObject obj, Color color) {
    final textSpan = TextSpan(
      text: '${obj.label} ${obj.confidencePercentage}',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.2,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    const double hPad = 8.0;
    const double vPad = 4.0;
    final pillWidth = textPainter.width + (hPad * 2);
    final pillHeight = textPainter.height + (vPad * 2);

    final pillTop = (rect.top - pillHeight - 4).clamp(8.0, double.infinity);
    final pillLeft = rect.left.clamp(8.0, double.infinity);
    final pillRect = Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight);

    final bgPaint = Paint()
      ..color = color.withAlpha(220)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(RRect.fromRectAndRadius(pillRect, const Radius.circular(6)), bgPaint);

    textPainter.paint(canvas, Offset(pillLeft + hPad, pillTop + vPad));
  }

  @override
  bool shouldRepaint(covariant NatureBoundingBoxPainter oldDelegate) {
    return oldDelegate.detections != detections || oldDelegate.scanAnimation != scanAnimation;
  }
}
