import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import 'sensor_provider.dart';

/// Halaman Kompas Sederhana Penunjuk Arah Mata Angin
/// Menunjukkan arah Utara, Timur, Selatan, Barat secara akurat dan bersih.
class SensorCompassScreen extends StatefulWidget {
  final String initialMode; // Kompatibilitas rute

  const SensorCompassScreen({super.key, this.initialMode = 'compass'});

  @override
  State<SensorCompassScreen> createState() => _SensorCompassScreenState();
}

class _SensorCompassScreenState extends State<SensorCompassScreen> {
  String _getCardinalName(double deg) {
    final d = (deg % 360 + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'UTARA';
    if (d >= 22.5 && d < 67.5) return 'TIMUR LAUT';
    if (d >= 67.5 && d < 112.5) return 'TIMUR';
    if (d >= 112.5 && d < 157.5) return 'TENGGARA';
    if (d >= 157.5 && d < 202.5) return 'SELATAN';
    if (d >= 202.5 && d < 247.5) return 'BARAT DAYA';
    if (d >= 247.5 && d < 292.5) return 'BARAT';
    return 'BARAT LAUT';
  }

  String _getCardinalCode(double deg) {
    final d = (deg % 360 + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'U';
    if (d >= 22.5 && d < 67.5) return 'TL';
    if (d >= 67.5 && d < 112.5) return 'T';
    if (d >= 112.5 && d < 157.5) return 'TG';
    if (d >= 157.5 && d < 202.5) return 'S';
    if (d >= 202.5 && d < 247.5) return 'BD';
    if (d >= 247.5 && d < 292.5) return 'B';
    return 'BL';
  }

  @override
  Widget build(BuildContext context) {
    final sensorProvider = context.watch<SensorProvider>();
    final double heading = (sensorProvider.headingDegrees % 360 + 360) % 360;
    final String cardinalName = _getCardinalName(heading);
    final String cardinalCode = _getCardinalCode(heading);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface, size: 20),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Kompas Arah',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            tooltip: 'Kalibrasi Kompas',
            onPressed: () {
              sensorProvider.calibrateCompass();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sensor kompas berhasil dikalibrasi ulang.'),
                  duration: Duration(seconds: 1),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin, vertical: 12),
          child: Column(
            children: [
              // 1. Tampilan Besar Derajat & Arah Hadap
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          heading.toStringAsFixed(0),
                          style: const TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '°',
                          style: TextStyle(
                            color: Color(0xFFE53935),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE53935).withAlpha(80)),
                          ),
                          child: Text(
                            cardinalCode,
                            style: const TextStyle(
                              color: Color(0xFFE53935),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cardinalName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 2. Dial Kompas Sederhana (Penunjuk Arah Mata Angin)
              _buildSimpleCompassDial(heading, context),

              const SizedBox(height: 28),

              // 3. Grid 4 Mata Angin Utama (Utara, Timur, Selatan, Barat)
              Row(
                children: [
                  _buildDirectionChip('UTARA (U)', '0° / 360°', heading >= 315 || heading < 45, isNorth: true),
                  const SizedBox(width: 8),
                  _buildDirectionChip('TIMUR (T)', '90°', heading >= 45 && heading < 135),
                  const SizedBox(width: 8),
                  _buildDirectionChip('SELATAN (S)', '180°', heading >= 135 && heading < 225),
                  const SizedBox(width: 8),
                  _buildDirectionChip('BARAT (B)', '270°', heading >= 225 && heading < 315),
                ],
              ),

              const SizedBox(height: 20),

              // 4. Keterangan Sensor & Panduan Akurasi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pegang ponsel secara mendatar. Jauhkan dari objek logam/magnet agar arah kompas presisi.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant.withAlpha(200),
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip Indikator Mata Angin Aktif
  Widget _buildDirectionChip(String label, String degrees, bool isActive, {bool isNorth = false}) {
    final activeColor = isNorth ? const Color(0xFFE53935) : AppColors.primary;

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? activeColor : AppColors.outlineVariant.withAlpha(80),
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.onSurface,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                degrees,
                style: TextStyle(
                  color: isActive ? Colors.white70 : AppColors.onSurfaceVariant,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Dial Kompas Klasik yang Berputar
  Widget _buildSimpleCompassDial(double heading, BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double dialSize = (screenWidth - 64).clamp(200.0, 280.0);

    return Center(
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Bezel Cincin Luar
          Container(
            width: dialSize + 16,
            height: dialSize + 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceContainerLowest,
              border: Border.all(color: AppColors.primary, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),

          // Piringan Dial yang Berputar Sesuai Derajat Heading
          AnimatedRotation(
            turns: -heading / 360.0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: dialSize,
              height: dialSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Latar Piringan dengan Skala Derajat & Huruf Mata Angin
                  CustomPaint(
                    size: Size(dialSize, dialSize),
                    painter: SimpleCompassDialPainter(),
                  ),

                  // Jarum Magnetik (Merah ke Utara, Gelap ke Selatan)
                  CustomPaint(
                    size: Size(dialSize, dialSize),
                    painter: SimpleCompassNeedlePainter(),
                  ),

                  // Poros Tengah (Center Cap)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Jarum Penunjuk Tetap di Arah Jam 12 (Arah Depan Ponsel)
          Positioned(
            top: -10,
            child: CustomPaint(
              size: const Size(18, 16),
              painter: TopFixedArrowPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter Penunjuk Tetap Arah Depan Ponsel (Segitiga Merah di Jam 12)
class TopFixedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter Piringan Dial Kompas
/// Menampilkan skala derajat dan tanda mata angin: U (Utara), T (Timur), S (Selatan), B (Barat)
class SimpleCompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Lingkaran Dasar Dial
    final bgPaint = Paint()
      ..color = AppColors.surfaceContainerLowest
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Bintang Mata Angin Faint di Pusat
    _drawCenterCompassRose(canvas, center, radius);

    // 3. Garis-garis Derajat (Tick Marks)
    final tickPaint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 5) {
      final isMajor = i % 90 == 0;
      final isMedium = i % 30 == 0;
      final tickLength = isMajor ? 11.0 : (isMedium ? 7.5 : 4.0);

      final rad = (i - 90) * pi / 180;
      final start = Offset(
        center.dx + (radius - 5) * cos(rad),
        center.dy + (radius - 5) * sin(rad),
      );
      final end = Offset(
        center.dx + (radius - 5 - tickLength) * cos(rad),
        center.dy + (radius - 5 - tickLength) * sin(rad),
      );

      tickPaint.strokeWidth = isMajor ? 2.2 : (isMedium ? 1.5 : 0.8);
      tickPaint.color = isMajor
          ? (i == 0 ? const Color(0xFFE53935) : AppColors.primary)
          : (isMedium ? AppColors.onSurface : AppColors.outlineVariant);

      canvas.drawLine(start, end, tickPaint);
    }

    // 4. Huruf Kardinal Utama: U (Merah), T, S, B
    _drawMarkerText(canvas, 'U', center.dx, 24, color: const Color(0xFFE53935), fontSize: 18, isBold: true);
    _drawMarkerText(canvas, 'T', size.width - 24, center.dy, color: AppColors.onSurface, fontSize: 16, isBold: true);
    _drawMarkerText(canvas, 'S', center.dx, size.height - 24, color: AppColors.onSurface, fontSize: 16, isBold: true);
    _drawMarkerText(canvas, 'B', 24, center.dy, color: AppColors.onSurface, fontSize: 16, isBold: true);

    // 5. Huruf Interkardinal: TL, TG, BD, BL
    final double interDist = radius - 32;
    _drawIntercardinalText(canvas, 'TL', center, 45, interDist);
    _drawIntercardinalText(canvas, 'TG', center, 135, interDist);
    _drawIntercardinalText(canvas, 'BD', center, 225, interDist);
    _drawIntercardinalText(canvas, 'BL', center, 315, interDist);
  }

  void _drawCenterCompassRose(Canvas canvas, Offset center, double radius) {
    final lightPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = AppColors.surfaceContainerLow
      ..style = PaintingStyle.fill;

    final double outerR = radius * 0.72;
    final double innerR = radius * 0.20;

    for (int i = 0; i < 8; i++) {
      final double mainAngle = (i * 45 - 90) * pi / 180;
      final double prevAngle = (i * 45 - 22.5 - 90) * pi / 180;
      final double nextAngle = (i * 45 + 22.5 - 90) * pi / 180;

      final tip = Offset(center.dx + outerR * cos(mainAngle), center.dy + outerR * sin(mainAngle));
      final leftInner = Offset(center.dx + innerR * cos(prevAngle), center.dy + innerR * sin(prevAngle));
      final rightInner = Offset(center.dx + innerR * cos(nextAngle), center.dy + innerR * sin(nextAngle));

      final pathLeft = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(leftInner.dx, leftInner.dy)
        ..close();
      canvas.drawPath(pathLeft, shadowPaint);

      final pathRight = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(rightInner.dx, rightInner.dy)
        ..close();
      canvas.drawPath(pathRight, lightPaint);
    }
  }

  void _drawMarkerText(Canvas canvas, String text, double x, double y,
      {required Color color, required double fontSize, bool isBold = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  void _drawIntercardinalText(Canvas canvas, String text, Offset center, double deg, double dist) {
    final rad = (deg - 90) * pi / 180;
    final x = center.dx + dist * cos(rad);
    final y = center.dy + dist * sin(rad);

    _drawMarkerText(canvas, text, x, y, color: AppColors.onSurfaceVariant.withAlpha(180), fontSize: 11, isBold: true);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Painter Jarum Kompas Klasik
/// Menunjuk ke Utara (Merah) dan Selatan (Abu-Abu)
class SimpleCompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const double needleLength = 88.0;
    const double needleBaseWidth = 7.0;

    // Jarum Utara (Menunjuk ke Atas / U)
    final northTip = Offset(center.dx, center.dy - needleLength);
    final leftBase = Offset(center.dx - needleBaseWidth, center.dy);
    final rightBase = Offset(center.dx + needleBaseWidth, center.dy);

    // Jarum Selatan (Menunjuk ke Bawah / S)
    final southTip = Offset(center.dx, center.dy + needleLength * 0.85);

    // Sisi Kiri Jarum Utara (Merah Terang)
    final northLeftPaint = Paint()
      ..color = const Color(0xFFEF5350)
      ..style = PaintingStyle.fill;
    final northLeftPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(northTip.dx, northTip.dy)
      ..close();
    canvas.drawPath(northLeftPath, northLeftPaint);

    // Sisi Kanan Jarum Utara (Merah Gelap untuk Efek 3D Bevel)
    final northRightPaint = Paint()
      ..color = const Color(0xFFC62828)
      ..style = PaintingStyle.fill;
    final northRightPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..lineTo(northTip.dx, northTip.dy)
      ..close();
    canvas.drawPath(northRightPath, northRightPaint);

    // Sisi Kiri Jarum Selatan (Abu-abu Terang)
    final southLeftPaint = Paint()
      ..color = const Color(0xFF9E9E9E)
      ..style = PaintingStyle.fill;
    final southLeftPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(southTip.dx, southTip.dy)
      ..close();
    canvas.drawPath(southLeftPath, southLeftPaint);

    // Sisi Kanan Jarum Selatan (Abu-abu Gelap)
    final southRightPaint = Paint()
      ..color = const Color(0xFF616161)
      ..style = PaintingStyle.fill;
    final southRightPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..lineTo(southTip.dx, southTip.dy)
      ..close();
    canvas.drawPath(southRightPath, southRightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
