import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import 'sensor_provider.dart';

/// Halaman Kompas Arah Puncak Gunung Merapi
/// Mengusung konsep kompas arah kiblat (Qibla Compass):
/// Menunjukkan posisi dan arah persis Gunung Merapi dari lokasi keberadaan pengguna saat ini.
class SensorCompassScreen extends StatefulWidget {
  final String initialMode; // Kompatibilitas rute ('compass' / 'shake')

  const SensorCompassScreen({super.key, this.initialMode = 'compass'});

  @override
  State<SensorCompassScreen> createState() => _SensorCompassScreenState();
}

class _SensorCompassScreenState extends State<SensorCompassScreen> with SingleTickerProviderStateMixin {
  bool _hasTriggeredHaptic = false;

  @override
  Widget build(BuildContext context) {
    final sensorProvider = context.watch<SensorProvider>();

    // Haptic feedback saat ponsel tepat sejajar menghadap Gunung Merapi
    if (sensorProvider.isFacingMerapi) {
      if (!_hasTriggeredHaptic) {
        _hasTriggeredHaptic = true;
        HapticFeedback.selectionClick();
      }
    } else {
      _hasTriggeredHaptic = false;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121619), // Dark Charcoal Slate sesuai Gambar 1
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Kompas',
          style: AppTypography.titleMd.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.white70),
            tooltip: 'Kalibrasi Kompas',
            onPressed: () {
              sensorProvider.calibrateCompass();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sensor kompas berhasil dikalibrasi ulang.'),
                  duration: Duration(seconds: 1),
                  backgroundColor: Color(0xFF04432F),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined, color: Color(0xFF10B981)),
            tooltip: 'Ganti / Deteksi Lokasi',
            onPressed: () => _showLocationSelector(context, sensorProvider),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // 1. Location Header (Sesuai Gambar 1: Lokasi & Negara)
                      GestureDetector(
                        onTap: () => _showLocationSelector(context, sensorProvider),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sensorProvider.userLocationName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFFD1A768),
                                  size: 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sensorProvider.userRegionName,
                              style: const TextStyle(
                                color: Color(0xFFD1A768), // Champagne Gold
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // 2. Central Compass Dial (Model Kompas Kiblat Merapi)
                      _buildCompassDial(sensorProvider),

                      const Spacer(),

                      // 3. Merapi Bearing & Distance Info (Sesuai Gambar 1)
                      Column(
                        children: [
                          Text(
                            'Arah Merapi ${sensorProvider.merapiBearing.toStringAsFixed(2).replaceAll('.', ',')}° dari Utara',
                            style: const TextStyle(
                              color: Color(0xFFD1A768), // Champagne Gold sesuai Gambar 1
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Jarak ke Puncak Merapi ± ${sensorProvider.merapiDistanceKm.toStringAsFixed(1)} KM',
                            style: TextStyle(
                              color: Colors.white.withAlpha(220),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 4. Status Alignment Pill / Panduan Putar Ponsel
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sensorProvider.isFacingMerapi
                              ? const Color(0xFF04432F)
                              : Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: sensorProvider.isFacingMerapi
                                ? const Color(0xFF10B981)
                                : Colors.white12,
                            width: 1.2,
                          ),
                          boxShadow: sensorProvider.isFacingMerapi
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withAlpha(80),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sensorProvider.isFacingMerapi
                                  ? Icons.check_circle_rounded
                                  : Icons.navigation_rounded,
                              size: 16,
                              color: sensorProvider.isFacingMerapi
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFD1A768),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                sensorProvider.isFacingMerapi
                                    ? 'Menghadap Langsung ke Puncak Merapi (2.930 mdpl)'
                                    : '${sensorProvider.turnSuggestion} • Arah Hadap: ${sensorProvider.headingDirection}',
                                style: TextStyle(
                                  color: sensorProvider.isFacingMerapi
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: sensorProvider.isFacingMerapi
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // 5. Bottom Calibration Advice (Teks persis Gambar 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text(
                          'Jauhkan perangkat dari objek yang berbahan besi atau logam, agar lebih akurat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withAlpha(90),
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Piringan Dial Kompas Interaktif yang berputar mengikuti sensor ponsel
  Widget _buildCompassDial(SensorProvider provider) {
    const double dialSize = 270.0;

    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: dialSize + 16,
        height: dialSize + 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            if (provider.isFacingMerapi)
              BoxShadow(
                color: const Color(0xFF10B981).withAlpha(100),
                blurRadius: 36,
                spreadRadius: 6,
              )
            else
              BoxShadow(
                color: Colors.black.withAlpha(80),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Cincin Luar Berwarna Teal/Emerald Khas Gambar 1
            Container(
              width: dialSize + 12,
              height: dialSize + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF222B2F),
                border: Border.all(
                  color: provider.isFacingMerapi
                      ? const Color(0xFF10B981)
                      : const Color(0xFF00897B), // Teal Ring persis Gambar 1
                  width: 6,
                ),
              ),
            ),

            // Piringan Dial Putih yang Berputar Mengikuti Heading Ponsel
            AnimatedRotation(
              turns: -provider.headingDegrees / 360,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: dialSize,
                height: dialSize,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Dial Background Plate (Bintang Mata Angin, Ticks, Cardinal N, E, S, W)
                    CustomPaint(
                      size: const Size(dialSize, dialSize),
                      painter: QiblaStyleDialPainter(
                        merapiBearing: provider.merapiBearing,
                        isAligned: provider.isFacingMerapi,
                      ),
                    ),

                    // Jarum Penunjuk Merah yang Mengarah Langsung ke Gunung Merapi
                    CustomPaint(
                      size: const Size(dialSize, dialSize),
                      painter: MerapiNeedlePainter(
                        bearingDegrees: provider.merapiBearing,
                        isAligned: provider.isFacingMerapi,
                      ),
                    ),

                    // Marker Ikon Gunung Merapi pada Pinggiran Dial Sesuai Sudut Bearing
                    _buildMerapiSummitMarker(dialSize, provider.merapiBearing, provider.isFacingMerapi),

                    // Pusat Poros Tengah (Pusat Dial)
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF04432F),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(60),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.isFacingMerapi
                                ? const Color(0xFF10B981)
                                : const Color(0xFFD1A768),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Marker Ikon Gunung Merapi yang diletakkan persis pada keliling dial di sudut bearing Merapi
  Widget _buildMerapiSummitMarker(double dialSize, double bearingDegrees, bool isAligned) {
    final double radius = dialSize / 2;
    // Offset sudut dari North (-90° pada sistem koordinat layar Flutter)
    final double rad = (bearingDegrees - 90) * pi / 180;
    final double markerDist = radius - 24;
    final double x = radius + markerDist * cos(rad);
    final double y = radius + markerDist * sin(rad);

    return Positioned(
      left: x - 15,
      top: y - 15,
      child: Transform.rotate(
        angle: (bearingDegrees) * pi / 180,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isAligned ? const Color(0xFF10B981) : const Color(0xFF1A2226),
            shape: BoxShape.circle,
            border: Border.all(
              color: isAligned ? Colors.white : const Color(0xFFD1A768),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.landscape_rounded, // Ikon Puncak Gunung Merapi
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// Modal Bottom Sheet untuk Pemilihan Titik Lokasi Pengguna atau Deteksi GPS
  void _showLocationSelector(BuildContext context, SensorProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2126),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pilih Lokasi Keberadaanmu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Arah panah dan sudut jarum kompas akan otomatis menyesuaikan posisi Gunung Merapi dari titik ini.',
                  style: TextStyle(color: Colors.white.withAlpha(160), fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Tombol Ambil GPS Otomatis
                ListTile(
                  tileColor: const Color(0xFF04432F),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: provider.isLocatingGps
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.my_location_rounded, color: Color(0xFF10B981)),
                  title: const Text(
                    'Deteksi GPS Otomatis (Live)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Gunakan sensor GPS ponsel saat ini',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(ctx);
                    final success = await provider.updateGpsLocation();
                    if (!mounted) return;
                    if (success) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Lokasi GPS berhasil diperbarui: ${provider.userLocationName}'),
                          backgroundColor: const Color(0xFF04432F),
                        ),
                      );
                    } else if (provider.gpsErrorMessage != null) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(provider.gpsErrorMessage!),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),

                const Text(
                  'Preset Titik Sekitar Merapi:',
                  style: TextStyle(color: Color(0xFFD1A768), fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Daftar Lokasi Preset
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: SensorProvider.presetLocations.length,
                    separatorBuilder: (_, _) => const Divider(color: Colors.white10, height: 1),
                    itemBuilder: (c, idx) {
                      final item = SensorProvider.presetLocations[idx];
                      final isSelected = provider.userLocationName == item['name'];

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        leading: Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.place_outlined,
                          color: isSelected ? const Color(0xFF10B981) : Colors.white60,
                          size: 20,
                        ),
                        title: Text(
                          item['name'] as String,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          item['description'] as String,
                          style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
                        ),
                        onTap: () {
                          provider.setManualLocation(
                            lat: item['lat'] as double,
                            lng: item['lng'] as double,
                            locationName: item['name'] as String,
                            regionName: item['region'] as String,
                          );
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter untuk Piringan Putih Dial Kompas (Qibla Style)
/// Menggambar piringan bulat putih, bintang 8 mata angin abu-abu muda, ticks derajat, dan teks kardinal
class QiblaStyleDialPainter extends CustomPainter {
  final double merapiBearing;
  final bool isAligned;

  QiblaStyleDialPainter({required this.merapiBearing, required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Lingkaran Dasar Putih Piringan Kompas (Sesuai Gambar 1)
    final bgPaint = Paint()
      ..color = const Color(0xFFF7FAF8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Border Halus Dalam
    final innerBorder = Paint()
      ..color = const Color(0xFFE2E8E4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 2, innerBorder);

    // 2. Gambar Bintang 8 Arah Mata Angin (Faint Navigational Rose Star)
    _drawCompassRoseStar(canvas, center, radius);

    // 3. Garis Ticks Derajat di Sepanjang Keliling Dial
    final tickPaint = Paint()..strokeCap = StrokeCap.round;

    for (int i = 0; i < 360; i += 5) {
      final isMajor = i % 90 == 0;
      final isMedium = i % 45 == 0;
      final tickLength = isMajor ? 10.0 : (isMedium ? 7.0 : 3.5);

      final rad = (i - 90) * pi / 180;
      final start = Offset(
        center.dx + (radius - 4) * cos(rad),
        center.dy + (radius - 4) * sin(rad),
      );
      final end = Offset(
        center.dx + (radius - 4 - tickLength) * cos(rad),
        center.dy + (radius - 4 - tickLength) * sin(rad),
      );

      tickPaint.strokeWidth = isMajor ? 2.0 : (isMedium ? 1.5 : 0.9);
      tickPaint.color = isMajor
          ? const Color(0xFF00897B)
          : (isMedium ? const Color(0xFF334155) : const Color(0xFF94A3B8));

      canvas.drawLine(start, end, tickPaint);
    }

    // 4. Label Mata Angin: N (Hijau), NE, E, SE, S, SW, W, NW
    _drawCardinalMarker(canvas, 'N', center.dx, 22, isNorth: true);
    _drawCardinalMarker(canvas, 'E', size.width - 22, center.dy);
    _drawCardinalMarker(canvas, 'S', center.dx, size.height - 22);
    _drawCardinalMarker(canvas, 'W', 22, center.dy);

    // Intercardinal (NE, SE, SW, NW)
    final interDist = radius - 30;
    _drawIntercardinalMarker(canvas, 'NE', center, 45, interDist);
    _drawIntercardinalMarker(canvas, 'SE', center, 135, interDist);
    _drawIntercardinalMarker(canvas, 'MS', center, 225, interDist); // MS / SW
    _drawIntercardinalMarker(canvas, 'NW', center, 315, interDist);
  }

  /// Menggambar Bintang 8 Mata Angin Faint (Klasik Gambar 1)
  void _drawCompassRoseStar(Canvas canvas, Offset center, double radius) {
    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = const Color(0xFFE4ECE7)
      ..style = PaintingStyle.fill;

    final double outerR = radius * 0.76;
    final double innerR = radius * 0.22;

    for (int i = 0; i < 8; i++) {
      final double mainAngle = (i * 45 - 90) * pi / 180;
      final double prevAngle = (i * 45 - 22.5 - 90) * pi / 180;
      final double nextAngle = (i * 45 + 22.5 - 90) * pi / 180;

      final tip = Offset(center.dx + outerR * cos(mainAngle), center.dy + outerR * sin(mainAngle));
      final leftInner = Offset(center.dx + innerR * cos(prevAngle), center.dy + innerR * sin(prevAngle));
      final rightInner = Offset(center.dx + innerR * cos(nextAngle), center.dy + innerR * sin(nextAngle));

      // Sisi Kiri
      final pathLeft = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(leftInner.dx, leftInner.dy)
        ..close();
      canvas.drawPath(pathLeft, shadowPaint);

      // Sisi Kanan
      final pathRight = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(rightInner.dx, rightInner.dy)
        ..close();
      canvas.drawPath(pathRight, lightPaint);
    }
  }

  void _drawCardinalMarker(Canvas canvas, String text, double x, double y, {bool isNorth = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: isNorth ? const Color(0xFF00897B) : const Color(0xFF1E293B),
        fontSize: isNorth ? 16 : 13,
        fontWeight: FontWeight.bold,
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

  void _drawIntercardinalMarker(Canvas canvas, String text, Offset center, double deg, double dist) {
    final rad = (deg - 90) * pi / 180;
    final x = center.dx + dist * cos(rad);
    final y = center.dy + dist * sin(rad);

    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 10,
        fontWeight: FontWeight.bold,
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

  @override
  bool shouldRepaint(covariant QiblaStyleDialPainter oldDelegate) {
    return oldDelegate.merapiBearing != merapiBearing || oldDelegate.isAligned != isAligned;
  }
}

/// CustomPainter untuk Jarum Kompas Merah 3D Tapered
/// Mengarah persis dari poros tengah menuju Gunung Merapi
class MerapiNeedlePainter extends CustomPainter {
  final double bearingDegrees;
  final bool isAligned;

  MerapiNeedlePainter({required this.bearingDegrees, required this.isAligned});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Sudut Jarum ke arah Merapi
    final double rad = (bearingDegrees - 90) * pi / 180;
    final double perpRad = rad + (pi / 2);

    final double needleLength = radius - 38;
    final double needleBaseWidth = 6.5;

    // Ujung Jarum (Tip)
    final tip = Offset(
      center.dx + needleLength * cos(rad),
      center.dy + needleLength * sin(rad),
    );

    // Titik Sayap Kiri Poros
    final leftBase = Offset(
      center.dx + needleBaseWidth * cos(perpRad),
      center.dy + needleBaseWidth * sin(perpRad),
    );

    // Titik Sayap Kanan Poros
    final rightBase = Offset(
      center.dx - needleBaseWidth * cos(perpRad),
      center.dy - needleBaseWidth * sin(perpRad),
    );

    // Ekor Belakang Jarum (Tail)
    final tail = Offset(
      center.dx - 18 * cos(rad),
      center.dy - 18 * sin(rad),
    );

    // Efek 3D Bevel (Separuh terang, separuh bayangan)
    final brightRed = Paint()
      ..color = isAligned ? const Color(0xFFFF3333) : const Color(0xFFE53935)
      ..style = PaintingStyle.fill;

    final darkRed = Paint()
      ..color = isAligned ? const Color(0xFFD32F2F) : const Color(0xFFB71C1C)
      ..style = PaintingStyle.fill;

    // 1. Sisi Kiri Jarum Depan
    final leftHalf = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawPath(leftHalf, brightRed);

    // 2. Sisi Kanan Jarum Depan
    final rightHalf = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..lineTo(tip.dx, tip.dy)
      ..close();
    canvas.drawPath(rightHalf, darkRed);

    // 3. Ekor Belakang Jarum
    final tailPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;

    final tailPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(leftBase.dx, leftBase.dy)
      ..lineTo(tail.dx, tail.dy)
      ..lineTo(rightBase.dx, rightBase.dy)
      ..close();
    canvas.drawPath(tailPath, tailPaint);
  }

  @override
  bool shouldRepaint(covariant MerapiNeedlePainter oldDelegate) {
    return oldDelegate.bearingDegrees != bearingDegrees || oldDelegate.isAligned != isAligned;
  }
}
