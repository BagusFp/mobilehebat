import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';

import '../explore/destination_detail_screen.dart';
import '../map/map_screen.dart';
import 'sensor_provider.dart';

class SensorCompassScreen extends StatefulWidget {
  final String initialMode; // 'shake' atau 'compass'

  const SensorCompassScreen({super.key, this.initialMode = 'shake'});

  @override
  State<SensorCompassScreen> createState() => _SensorCompassScreenState();
}

class _SensorCompassScreenState extends State<SensorCompassScreen> with SingleTickerProviderStateMixin {
  late String _activeMode;
  late AnimationController _shakeAnimController;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.initialMode;
    _shakeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _shakeAnimController.dispose();
    super.dispose();
  }

  void _triggerShakeAnimation() {
    _shakeAnimController.forward(from: 0.0);
  }

  String _formatCurrency(double price) {
    if (price <= 0) return 'Gratis';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    final sensorProvider = context.watch<SensorProvider>();



    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(230),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Eksplorasi Sensor & Kompas',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.margin,
            AppDimensions.spaceSm,
            AppDimensions.margin,
            AppDimensions.spaceXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Volcanic Seismic Alert & Sensor Status Banner
              _buildSensorStatusBanner(),
              const SizedBox(height: AppDimensions.spaceMd),

              // 2. Segmented Mode Switcher (Goyang Ponsel vs Kompas Lapangan)
              _buildModeSwitcher(),
              const SizedBox(height: AppDimensions.spaceLg),

              // 3. Dynamic Section Content
              if (_activeMode == 'shake')
                _buildShakeSection(context, sensorProvider)
              else
                _buildCompassSection(context, sensorProvider),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Status Banner: Seismik & Sensor Aktif
  Widget _buildSensorStatusBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS SENSOR PERANGKAT',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Akselerometer & Kompas: Siap Digunakan',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '2 Sensor Aktif',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Mode Switcher (Pill Segmented)
  Widget _buildModeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeMode = 'shake'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeMode == 'shake' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  boxShadow: _activeMode == 'shake'
                      ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.screen_rotation_alt,
                      size: 18,
                      color: _activeMode == 'shake'
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Goyang Ponsel',
                      style: AppTypography.labelLg.copyWith(
                        color: _activeMode == 'shake'
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeMode = 'compass'),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _activeMode == 'compass' ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  boxShadow: _activeMode == 'compass'
                      ? [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 4)]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.explore,
                      size: 18,
                      color: _activeMode == 'compass'
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kompas Lapangan',
                      style: AppTypography.labelLg.copyWith(
                        color: _activeMode == 'compass'
                            ? AppColors.onPrimary
                            : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // SECTION 1: GOYANG PONSEL (SHAKE TO DISCOVER)
  // --------------------------------------------------------------------------
  Widget _buildShakeSection(BuildContext context, SensorProvider provider) {
    final dest = provider.randomDestination;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Educational & Sensor Guide Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.smartphone,
                          size: 20,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Eksplorasi Goyang Ponsel',
                            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Accelerometer Lapangan Siaga',
                            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch(
                    value: provider.isShakeEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) => provider.toggleShake(val),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Goyang ponselmu untuk memilih destinasi petualangan Merapi secara acak dan temukan spot hidden gem hari ini!',
                style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.touch_app, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      provider.sensorStatusLabel,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),

        // Result Card: Destinasi Terpilih
        if (dest != null)
          AnimatedBuilder(
            animation: _shakeAnimController,
            builder: (context, child) {
              final offset = sin(_shakeAnimController.value * pi * 4) * 6;
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 180,
                          width: double.infinity,
                          child: Image.network(
                            dest.imageUrl ?? '',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: AppColors.surfaceContainer,
                              child: const Center(
                                child: Icon(Icons.landscape, size: 50, color: AppColors.outline),
                              ),
                            ),
                          ),
                        ),
                        // Badge Pilihan Acak Hari Ini
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(220),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_awesome, size: 14, color: AppColors.onPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  'Pilihan Acak Hari Ini',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Badge mdpl
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest.withAlpha(230),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              '${dest.elevationMdpl} mdpl',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Kategori & Tiket
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dest.categoryName,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• Tiket: ${_formatCurrency(dest.ticketPrice)}',
                        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title & Description
                  Text(
                    dest.name,
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dest.description,
                    style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DestinationDetailScreen(destination: dest),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: Text(
                        'Lihat Detail Destinasi',
                        style: AppTypography.labelLg.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer,
                        foregroundColor: AppColors.onSecondaryContainer,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        ),
                      ),
                      onPressed: () {
                        _triggerShakeAnimation();
                        provider.triggerRandomDestination();
                      },
                      icon: const Icon(Icons.shuffle, size: 20),
                      label: Text(
                        'Goyang Lagi (Acak Ulang)',
                        style: AppTypography.labelLg.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppDimensions.spaceMd),

        // Fallback Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.device_unknown, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Perangkat tanpa sensor getar?',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  _triggerShakeAnimation();
                  provider.triggerRandomDestination();
                },
                child: Text(
                  'Cari Destinasi Manual',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // SECTION 2: KOMPAS LAPANGAN (GYROSCOPE & MAGNETOMETER)
  // --------------------------------------------------------------------------
  Widget _buildCompassSection(BuildContext context, SensorProvider provider) {
    final target = provider.currentTarget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Info
        Text(
          'Kompas Arah Menuju Puncak & Destinasi',
          style: AppTypography.headlineSm.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Arahkan bagian atas ponselmu ke lanskap Merapi untuk mengetahui posisi kawah utama dan titik wisata.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.spaceMd),

        // Target Selector Dropdown
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Pilih Titik Target Orientasi:',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider.selectedTargetId,
                    isExpanded: true,
                    icon: const Icon(Icons.expand_more, color: AppColors.onSurfaceVariant),
                    items: provider.targets.map((t) {
                      return DropdownMenuItem<String>(
                        value: t.id,
                        child: Text(
                          t.subtitle,
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        provider.setCompassTarget(val);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLg),

        // Digital Compass Dial Card
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceLg),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Bearing & Elevation Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Azimuth Puncak',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        provider.headingDirection,
                        style: AppTypography.headlineLg.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Elevasi Estimasi',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        '+${target.elevationMdpl} mdpl',
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceLg),

              // Visual Compass Dial (Rotating Needle)
              SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Degree Marks & Cardinal Dial
                    CustomPaint(
                      size: const Size(240, 240),
                      painter: CompassDialPainter(),
                    ),

                    // Rotating Inner Needle
                    AnimatedRotation(
                      turns: -provider.headingDegrees / 360,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // North Needle (Red Volcano)
                            Positioned(
                              top: 15,
                              child: Column(
                                children: [
                                  CustomPaint(
                                    size: const Size(16, 65),
                                    painter: NeedleTrianglePainter(color: AppColors.error, pointingUp: true),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'MERAPI',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // South Needle (Green Pine)
                            Positioned(
                              bottom: 15,
                              child: CustomPaint(
                                size: const Size(16, 65),
                                painter: NeedleTrianglePainter(color: AppColors.primary, pointingUp: false),
                              ),
                            ),

                            // Center Pivot Circle
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(30),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
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
              const SizedBox(height: AppDimensions.spaceLg),

              // Live Target Indicator Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.landscape, size: 22, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.name,
                              style: AppTypography.labelLg.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'Jarak Garis Lurus: ${target.distanceKm.toStringAsFixed(1)} km',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: AppColors.primary),
                      tooltip: 'Kalibrasi Sensor Kompas',
                      onPressed: () {
                        provider.calibrateCompass();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sensor kompas berhasil dikalibrasi ulang.'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceMd),

        // Sensor Accuracy Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.accuracyText,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Menggabungkan data Gyroscope 3-Axis & Magnetometer',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),

        // Safe Guidance Disclaimer
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Peringatan Aman: Gunakan kompas sebagai panduan umum arah pandang visual kawah Merapi. Jangan gunakan sebagai satu-satunya alat evakuasi pada jalur berkabut tebal.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.spaceLg),

        // Buka di Peta Navigasi Lengkap Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              ),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
            icon: const Icon(Icons.map, size: 20),
            label: Text(
              'Buka di Peta Navigasi Lengkap',
              style: AppTypography.labelLg.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// CustomPainter untuk Dial Kompas Lapangan
class CompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle fill
    final bgPaint = Paint()
      ..color = AppColors.surfaceContainer
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = AppColors.outlineVariant
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 2, borderPaint);

    // Degree Ticks
    final tickPaint = Paint()
      ..color = AppColors.outline
      ..strokeWidth = 1.0;

    for (int i = 0; i < 360; i += 15) {
      final isMajor = i % 90 == 0;
      final tickLength = isMajor ? 12.0 : (i % 45 == 0 ? 8.0 : 5.0);
      final angle = i * pi / 180;

      final start = Offset(
        center.dx + (radius - 4) * cos(angle),
        center.dy + (radius - 4) * sin(angle),
      );
      final end = Offset(
        center.dx + (radius - 4 - tickLength) * cos(angle),
        center.dy + (radius - 4 - tickLength) * sin(angle),
      );

      tickPaint.strokeWidth = isMajor ? 2.0 : 1.0;
      tickPaint.color = isMajor ? AppColors.primary : AppColors.outline;
      canvas.drawLine(start, end, tickPaint);
    }

    // Cardinal Markers Text (U, T, S, B)
    _drawCardinalText(canvas, 'U', center.dx, 20, isNorth: true);
    _drawCardinalText(canvas, 'T', size.width - 20, center.dy);
    _drawCardinalText(canvas, 'S', center.dx, size.height - 20);
    _drawCardinalText(canvas, 'B', 20, center.dy);
  }

  void _drawCardinalText(Canvas canvas, String text, double x, double y, {bool isNorth = false}) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: isNorth ? AppColors.error : AppColors.onSurfaceVariant,
        fontSize: isNorth ? 14 : 11,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(x - textPainter.width / 2, y - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// CustomPainter untuk Jarum Segitiga Kompas (North Red / South Green)
class NeedleTrianglePainter extends CustomPainter {
  final Color color;
  final bool pointingUp;

  NeedleTrianglePainter({required this.color, required this.pointingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (pointingUp) {
      path.moveTo(size.width / 2, 0); // Tip
      path.lineTo(size.width, size.height); // Bottom Right
      path.lineTo(0, size.height); // Bottom Left
    } else {
      path.moveTo(0, 0); // Top Left
      path.lineTo(size.width, 0); // Top Right
      path.lineTo(size.width / 2, size.height); // Bottom Tip
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
