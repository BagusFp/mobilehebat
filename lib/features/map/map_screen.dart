import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/geo_helper.dart';
import '../../data/mock/mock_destinations.dart';
import '../../data/models/destination_model.dart';

import '../explore/destination_detail_screen.dart';
import '../explore/destination_provider.dart';
import '../sensor/sensor_compass_screen.dart';
import '../sensor/sensor_provider.dart';
import 'package:flutter/services.dart';
import 'map_provider.dart';

class MapScreen extends StatefulWidget {
  final DestinationModel? initialDestination;

  const MapScreen({super.key, this.initialDestination});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late AnimationController _radarController;
  late Animation<double> _radarAnimation;
  bool _showCompassHUD = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _radarAnimation = Tween<double>(begin: 0.8, end: 1.8).animate(
      CurvedAnimation(parent: _radarController, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<DestinationProvider>().allDestinations.isEmpty) {
        context.read<DestinationProvider>().loadDestinations();
      }
      if (widget.initialDestination != null) {
        context.read<MapProvider>().selectDestination(widget.initialDestination!);
      }
      // Meminta menyalakan lokasi saat masuk ke layar peta
      _requestLocationOnEnter();
    });
  }

  /// Memeriksa status GPS & izin lokasi saat masuk ke layar peta
  Future<void> _requestLocationOnEnter() async {
    final isUnderWidgetTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isUnderWidgetTest) {
      context.read<MapProvider>().fetchLiveLocation();
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showSimpleLocationPrompt(isPermission: false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showSimpleLocationPrompt(isPermission: true);
        return;
      }

      if (mounted && (permission == LocationPermission.always || permission == LocationPermission.whileInUse)) {
        final mapProv = context.read<MapProvider>();
        final success = await mapProv.fetchLiveLocation();
        if (success && mounted) {
          _mapController.move(
            ll.LatLng(mapProv.userLat, mapProv.userLng),
            14.5,
          );
        }
      }
    } catch (e) {
      debugPrint('Error request location on enter: $e');
      if (mounted) {
        context.read<MapProvider>().fetchLiveLocation();
      }
    }
  }

  /// Dialog simpel permintaan menyalakan GPS / izin lokasi saat masuk peta
  void _showSimpleLocationPrompt({required bool isPermission}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.location_on_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(child: Text('Nyalakan Lokasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          ],
        ),
        content: Text(
          isPermission
              ? 'Izin akses lokasi belum diaktifkan. Buka pengaturan untuk mengizinkan aplikasi mengakses lokasi Anda.'
              : 'Aktifkan GPS perangkat untuk melihat posisi Anda dan navigasi di sekitar lereng Gunung Merapi.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Nanti Saja',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (isPermission) {
                await Geolocator.openAppSettings();
              } else {
                await Geolocator.openLocationSettings();
              }
            },
            child: Text(isPermission ? 'Pengaturan' : 'Nyalakan'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _radarController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String _formatCurrency(double price) {
    if (price <= 0) return 'Sukarela';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final destProvider = context.watch<DestinationProvider>();
    final sensorProvider = context.watch<SensorProvider>();

    // Gunakan seluruh daftar destinasi wisata lereng Merapi (16 titik lengkap)
    final allDestList = () {
      final base = List<DestinationModel>.from(MockDestinations.destinations);
      if (destProvider.allDestinations.isNotEmpty) {
        final remoteMap = {for (var d in destProvider.allDestinations) d.id: d};
        return base.map((d) => remoteMap[d.id] ?? d).toList();
      }
      return base;
    }();

    final selectedDest = mapProvider.selectedDestination;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(230),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.landscape,
                color: AppColors.onPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppDimensions.spaceSm),
            Text(
              'Peta Merapi Navigasi',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: SafeArea(
        child: mapProvider.viewMode == 'map'
            ? _buildMapModeView(context, mapProvider, destProvider, sensorProvider, selectedDest, allDestList)
            : _buildListModeView(context, mapProvider, destProvider, allDestList),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Alam':
        return Icons.forest;
      case 'Sejarah':
        return Icons.museum;
      case 'Petualangan':
        return Icons.hiking;
      case 'Edukasi':
        return Icons.school;
      default:
        return Icons.place;
    }
  }

  // 2. Map Mode View (Interactive Visual Canvas + Bottom Sheet Card)
  Widget _buildMapModeView(
    BuildContext context,
    MapProvider mapProvider,
    DestinationProvider destProvider,
    SensorProvider sensorProvider,
    DestinationModel? selectedDest,
    List<DestinationModel> allDestList,
  ) {
    return Column(
      children: [
        // Map Canvas Area
        Expanded(
          child: Stack(
            children: [
              // 1. Peta Interaktif OpenStreetMap menggunakan flutter_map
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: ll.LatLng(
                    selectedDest?.latitude ?? GeoHelper.userDefaultLat,
                    selectedDest?.longitude ?? GeoHelper.userDefaultLng,
                  ),
                  initialZoom: 12.8,
                  minZoom: 6.0,
                  maxZoom: 18.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.meratrip.app',
                  ),
                  // KRB III (Radius 3km dari Puncak Kawah Merapi) & KRB II (5km)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: const ll.LatLng(GeoHelper.merapiSummitLat, GeoHelper.merapiSummitLng),
                        radius: 3000,
                        useRadiusInMeter: true,
                        color: AppColors.error.withAlpha(40),
                        borderColor: AppColors.error,
                        borderStrokeWidth: 2.0,
                      ),
                      CircleMarker(
                        point: const ll.LatLng(GeoHelper.merapiSummitLat, GeoHelper.merapiSummitLng),
                        radius: 5000,
                        useRadiusInMeter: true,
                        color: Colors.orange.withAlpha(25),
                        borderColor: Colors.orange.withAlpha(120),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                  // OSRM Driving Route Polyline Layer
                  if (mapProvider.routePoints.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: mapProvider.routePoints,
                          strokeWidth: 4.5,
                          color: AppColors.primary,
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    )
                  else if (selectedDest != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            ll.LatLng(mapProvider.userLat, mapProvider.userLng),
                            ll.LatLng(selectedDest.latitude, selectedDest.longitude),
                          ],
                          strokeWidth: 3.0,
                          color: AppColors.primary.withAlpha(150),
                          borderColor: Colors.white,
                          borderStrokeWidth: 1.0,
                        ),
                      ],
                    ),
                  // Marker Layer
                  MarkerLayer(
                    markers: [
                      // Marker Puncak Merapi (2.930 mdpl)
                      Marker(
                        point: const ll.LatLng(GeoHelper.merapiSummitLat, GeoHelper.merapiSummitLng),
                        width: 220,
                        height: 48,
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest.withAlpha(235),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error, width: 1.5),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                                const SizedBox(width: 4),
                                Text(
                                  'PUNCAK MERAPI (2.930 MDPL)',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Marker Destinasi Terverifikasi (Hanya Lokasi Database Wisata)
                      ...allDestList.map((dest) {
                        final isSelected = selectedDest?.id == dest.id;
                        return Marker(
                          point: ll.LatLng(dest.latitude, dest.longitude),
                          width: isSelected ? 180 : 36,
                          height: isSelected ? 96 : 36,
                          alignment: isSelected ? Alignment.topCenter : Alignment.center,
                          child: _buildPoiMarker(
                            context,
                            title: dest.name,
                            icon: _getCategoryIcon(dest.categoryName),
                            isSelected: isSelected,
                            dest: dest,
                            onTap: (d) {
                              mapProvider.selectDestination(d);
                              _mapController.move(ll.LatLng(d.latitude, d.longitude), 14.0);
                            },
                          ),
                        );
                      }),
                      // Marker Lokasi Asli GPS Pengguna
                      Marker(
                        point: ll.LatLng(mapProvider.userLat, mapProvider.userLng),
                        width: 64,
                        height: 64,
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: _radarAnimation,
                          builder: (context, child) {
                            final double pulseSize = (28.0 + 16.0 * (_radarAnimation.value - 0.8)).clamp(28.0, 54.0);
                            return Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: pulseSize,
                                    height: pulseSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.primary.withAlpha(
                                        (90 / _radarAnimation.value).clamp(0, 255).toInt(),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(35),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.my_location, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 2. Mode Switch (Peta / Daftar) - Bersih di Pojok Kanan Atas
              Positioned(
                top: 8,
                right: AppDimensions.margin,
                child: _buildViewModeToggle(mapProvider),
              ),

              // 3. Shortcut Titik-Titik Maps Lokasi Wisata Database (16 Titik Lengkap)
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                    itemCount: allDestList.length,
                    itemBuilder: (context, index) {
                      final dest = allDestList[index];
                      final isSelected = selectedDest?.id == dest.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              mapProvider.selectDestination(dest);
                              _mapController.move(ll.LatLng(dest.latitude, dest.longitude), 14.5);
                            },
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surfaceContainerLowest.withAlpha(240),
                                borderRadius: AppDimensions.roundedFull,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.outlineVariant.withAlpha(130),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? AppColors.primary.withAlpha(70)
                                        : Colors.black.withAlpha(15),
                                    blurRadius: isSelected ? 6 : 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(dest.categoryName),
                                    size: 15,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    dest.name,
                                    style: AppTypography.labelSm.copyWith(
                                      color: isSelected ? Colors.white : AppColors.onSurface,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 4. Floating HUD Indikator Rute OSRM Aktif (Muncul saat rute dihitung)
              if (mapProvider.routeDistanceKm != null)
                Positioned(
                  top: 94,
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.directions_car, size: 18, color: AppColors.onPrimaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Rute OSRM: ${mapProvider.routeDistanceKm} km • ~${mapProvider.routeDurationMinutes} mnt',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => mapProvider.clearRoute(),
                          child: const Icon(Icons.close, size: 16, color: AppColors.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4b. Floating Mini Dial Kompas Overlay (Opsi 1)
              if (_showCompassHUD)
                Positioned(
                  top: mapProvider.routeDistanceKm != null ? 144 : 96,
                  left: AppDimensions.margin,
                  child: _buildFloatingMiniCompassHUD(context, sensorProvider, mapProvider),
                ),

              // 5. Atribusi Resmi Penyedia Peta (Wajib OpenStreetMap & OSRM)
              Positioned(
                bottom: 8,
                left: AppDimensions.margin,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '© OpenStreetMap contributors • OSRM',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.black.withAlpha(160),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              // 6. Floating Action Controls (Zoom In/Out, Recenter, Fokus Merapi, Kompas)
              Positioned(
                bottom: 16,
                right: AppDimensions.margin,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'zoomInBtn',
                      backgroundColor: AppColors.surfaceContainerLowest.withAlpha(240),
                      foregroundColor: AppColors.onSurface,
                      elevation: 3,
                      onPressed: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, (currentZoom + 1.0).clamp(6.0, 18.0));
                      },
                      child: const Icon(Icons.add, size: 20),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'zoomOutBtn',
                      backgroundColor: AppColors.surfaceContainerLowest.withAlpha(240),
                      foregroundColor: AppColors.onSurface,
                      elevation: 3,
                      onPressed: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, (currentZoom - 1.0).clamp(6.0, 18.0));
                      },
                      child: const Icon(Icons.remove, size: 20),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'focusMerapiBtn',
                      backgroundColor: AppColors.surfaceContainerLowest.withAlpha(240),
                      foregroundColor: AppColors.secondary,
                      elevation: 3,
                      tooltip: 'Fokus Kawasan Merapi',
                      onPressed: () {
                        _mapController.move(const ll.LatLng(-7.5850, 110.4350), 12.8);
                      },
                      child: const Icon(Icons.landscape, size: 20),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'compassBtn',
                      backgroundColor: _showCompassHUD
                          ? AppColors.primary
                          : AppColors.surfaceContainerLowest.withAlpha(240),
                      foregroundColor: _showCompassHUD ? Colors.white : AppColors.secondary,
                      elevation: 3,
                      tooltip: _showCompassHUD ? 'Sembunyikan Mini Kompas' : 'Buka Mini Kompas Peta',
                      onPressed: () {
                        setState(() {
                          _showCompassHUD = !_showCompassHUD;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Transform.rotate(
                        angle: -sensorProvider.headingDegrees * (pi / 180),
                        child: const Icon(Icons.explore, size: 20),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FloatingActionButton.small(
                      heroTag: 'recenterBtn',
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 4,
                      onPressed: () async {
                        final success = await mapProvider.fetchLiveLocation();
                        _mapController.move(
                          ll.LatLng(mapProvider.userLat, mapProvider.userLng),
                          14.8,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Lokasi GPS Asli: ${mapProvider.userLat.toStringAsFixed(4)}, ${mapProvider.userLng.toStringAsFixed(4)}'
                                    : 'Lokasimu: Pos Retribusi Kaliurang (-7.5950, 110.4280)',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      child: mapProvider.isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location, size: 20),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Bottom Sheet: Destinasi Terpilih (Sesuai Stitch Screen 8)
        if (selectedDest != null)
          _buildSelectedDestinationSheet(context, selectedDest, destProvider, mapProvider),
      ],
    );
  }

  // POI Marker Widget
  Widget _buildPoiMarker(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required DestinationModel dest,
    required Function(DestinationModel) onTap,
  }) {
    return GestureDetector(
      onTap: () => onTap(dest),
      child: SizedBox(
        width: isSelected ? 180 : 36,
        height: isSelected ? 96 : 36,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
              ],
              SizedBox(
                width: 46,
                height: 46,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      AnimatedBuilder(
                        animation: _radarAnimation,
                        builder: (context, child) {
                          final double pulseSize = (26.0 + 14.0 * (_radarAnimation.value - 0.8)).clamp(26.0, 44.0);
                          return Container(
                            width: pulseSize,
                            height: pulseSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withAlpha(
                                (70 / _radarAnimation.value).clamp(0, 255).toInt(),
                              ),
                            ),
                          );
                        },
                      ),
                    Container(
                      width: isSelected ? 32 : 28,
                      height: isSelected ? 32 : 28,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : AppColors.outlineVariant,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        size: isSelected ? 17 : 14,
                        color: isSelected ? AppColors.onPrimary : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom Sheet: Destinasi Terpilih (Layar 8 Stitch)
  Widget _buildSelectedDestinationSheet(
    BuildContext context,
    DestinationModel dest,
    DestinationProvider destProvider,
    MapProvider mapProvider,
  ) {
    final double dist = GeoHelper.distanceToUser(
      dest.latitude,
      dest.longitude,
      userLat: mapProvider.userLat,
      userLng: mapProvider.userLng,
    );
    final distanceText = GeoHelper.formatDistanceAndDuration(dist);
    final isFav = destProvider.isFavorite(dest.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.42,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.margin,
              8,
              AppDimensions.margin,
              12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Grabber Handle & Close Button Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 28),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    InkWell(
                      onTap: () => mapProvider.selectDestination(null),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: AppColors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Header Info & Mini Image
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Destinasi Terpilih',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.navigation, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    distanceText,
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dest.name,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.terrain, size: 14, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${dest.elevationMdpl} mdpl • ${dest.address.split(',').first}',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      child: Image.network(
                        dest.imageUrl ?? '',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 64,
                          height: 64,
                          color: AppColors.surfaceContainer,
                          child: const Icon(Icons.landscape, color: AppColors.outline),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Quick Stats Metric Strip (3 Columns)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Tiket Masuk',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatCurrency(dest.ticketPrice),
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: AppColors.surfaceContainerHighest),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Kondisi Jalur',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Aspal & Pasir',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 24, color: AppColors.surfaceContainerHighest),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Aktivitas',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Eksplorasi & Wisata',
                              style: AppTypography.labelLarge.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Action Buttons: Petunjuk Arah, Detail, Bookmark
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            elevation: 1,
                          ),
                          onPressed: () async {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Menghitung rute mengemudi OSRM ke "${dest.name}" ($distanceText)...'),
                                duration: const Duration(milliseconds: 1500),
                              ),
                            );
                            await mapProvider.fetchRouteToDestination(dest);
                            if (context.mounted && mapProvider.routePoints.isNotEmpty) {
                              _mapController.move(ll.LatLng(dest.latitude, dest.longitude), 13.5);
                            }
                          },
                          icon: const Icon(Icons.turn_right, size: 18),
                          label: Text(
                            'Petunjuk Arah',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainer,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DestinationDetailScreen(destination: dest),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                          label: Text(
                            'Detail',
                            style: AppTypography.labelMd.copyWith(color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 44,
                      width: 44,
                      child: IconButton.outlined(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainer,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                        ),
                        icon: Icon(
                          isFav ? Icons.bookmark : Icons.bookmark_border,
                          size: 20,
                          color: isFav ? AppColors.secondary : AppColors.onSurfaceVariant,
                        ),
                        onPressed: () {
                          destProvider.toggleFavorite(dest.id, userId: 1);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(!isFav
                                  ? '${dest.name} ditambahkan ke favorit.'
                                  : '${dest.name} dihapus dari favorit.'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. Proximity List Mode View
  Widget _buildListModeView(
    BuildContext context,
    MapProvider mapProvider,
    DestinationProvider destProvider,
    List<DestinationModel> allDestList,
  ) {
    final sortedDestinations = List<DestinationModel>.from(allDestList)
      ..sort((a, b) {
        final distA = GeoHelper.distanceToUser(a.latitude, a.longitude, userLat: mapProvider.userLat, userLng: mapProvider.userLng);
        final distB = GeoHelper.distanceToUser(b.latitude, b.longitude, userLat: mapProvider.userLat, userLng: mapProvider.userLng);
        return distA.compareTo(distB);
      });

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.margin,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(
                color: AppColors.outlineVariant.withAlpha(80),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Destinasi Terdekat (LBS GPS)',
                  style: AppTypography.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildViewModeToggle(mapProvider),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppDimensions.margin),
            itemCount: sortedDestinations.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final dest = sortedDestinations[index];
              final dist = GeoHelper.distanceToUser(
                dest.latitude,
                dest.longitude,
                userLat: mapProvider.userLat,
                userLng: mapProvider.userLng,
              );
              final distanceStr = GeoHelper.formatDistanceAndDuration(dist);
              final krbZone = GeoHelper.getKrbZone(dest.latitude, dest.longitude);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      child: Image.network(
                        dest.imageUrl ?? '',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surfaceContainer,
                          child: const Icon(Icons.landscape, color: AppColors.outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  distanceStr,
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                _formatCurrency(dest.ticketPrice),
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dest.name,
                            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dest.elevationMdpl} mdpl • $krbZone',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.onPrimary,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(60, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () {
                                  mapProvider.selectDestination(dest);
                                  mapProvider.setViewMode('map');
                                },
                                icon: const Icon(Icons.turn_right, size: 14),
                                label: const Text('Rute Peta', style: TextStyle(fontSize: 11)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(50, 32),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DestinationDetailScreen(destination: dest),
                                    ),
                                  );
                                },
                                child: const Text('Detail', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Toggle Peta / Daftar Reusable Pill
  Widget _buildViewModeToggle(MapProvider mapProvider) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withAlpha(240),
        borderRadius: AppDimensions.roundedFull,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => mapProvider.setViewMode('map'),
            borderRadius: AppDimensions.roundedFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: mapProvider.viewMode == 'map'
                    ? AppColors.primary
                    : Colors.transparent,
                borderRadius: AppDimensions.roundedFull,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map,
                    size: 14,
                    color: mapProvider.viewMode == 'map'
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Peta',
                    style: AppTypography.labelSm.copyWith(
                      color: mapProvider.viewMode == 'map'
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => mapProvider.setViewMode('list'),
            borderRadius: AppDimensions.roundedFull,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: mapProvider.viewMode == 'list'
                    ? AppColors.primary
                    : Colors.transparent,
                borderRadius: AppDimensions.roundedFull,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.format_list_bulleted,
                    size: 14,
                    color: mapProvider.viewMode == 'list'
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Daftar',
                    style: AppTypography.labelSm.copyWith(
                      color: mapProvider.viewMode == 'list'
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. Floating Mini Dial Kompas Overlay (Opsi 1)
  Widget _buildFloatingMiniCompassHUD(
    BuildContext context,
    SensorProvider sensorProvider,
    MapProvider mapProvider,
  ) {
    final distMerapi = GeoHelper.distanceFromMerapiSummit(mapProvider.userLat, mapProvider.userLng);
    final bearingMerapi = GeoHelper.bearingToMerapiSummit(mapProvider.userLat, mapProvider.userLng);
    final relativeAngle = (bearingMerapi - sensorProvider.headingDegrees) * (pi / 180);

    return Material(
      color: Colors.transparent,
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 196,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withAlpha(245),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withAlpha(90), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Bar: Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Mini Kompas',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showCompassHUD = false;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 16, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Interactive Rotating Compass Dial (~90 px)
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer Dial Ring with Cardinal Points (Tetap mengikuti orientasi fisik ponsel)
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerHigh.withAlpha(180),
                      border: Border.all(
                        color: AppColors.outlineVariant.withAlpha(140),
                        width: 1.5,
                      ),
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        // U / N (Utara / North - Menghadap depan ponsel)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Text(
                              'U / N',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w900,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ),
                        // T / E (Timur / East - Kanan ponsel)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Text(
                              'T / E',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                        // S (Selatan / South - Bawah ponsel)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text(
                              'S',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ),
                        // B / W (Barat / West - Kiri ponsel)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 3),
                            child: Text(
                              'B / W',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Rotating Compass Needle (Jarum berputar ke arah Utara magnetik sebenarnya)
                  AnimatedRotation(
                    turns: -sensorProvider.headingDegrees / 360,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: CustomPaint(
                      size: const Size(18, 64),
                      painter: _MiniCompassNeedlePainter(),
                    ),
                  ),

                  // Center Pivot Bezel
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Live Heading Degree & Direction (Contoh: 90° E (Timur) saat menghadap Timur)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withAlpha(160),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${sensorProvider.headingDegrees.round()}° ${_formatBilingualCardinal(sensorProvider.headingDegrees)}',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimaryContainer,
                  fontSize: 11,
                ),
              ),
            ),

            const SizedBox(height: 6),
            const Divider(height: 1, thickness: 0.8),
            const SizedBox(height: 6),

            // Vector to Puncak Merapi (Relative bearing + distance)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: relativeAngle,
                  child: const Icon(
                    Icons.navigation_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    'Puncak: ${distMerapi.toStringAsFixed(1)} km (${bearingMerapi.round()}°)',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Shortcut to Full Compass Screen
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SensorCompassScreen(initialMode: 'compass'),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.outlineVariant.withAlpha(100)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.fullscreen_rounded, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Kompas Penuh',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
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

  String _formatBilingualCardinal(double deg) {
    const list = [
      'N (Utara)', 'NNE', 'NE (Timur Laut)', 'ENE',
      'E (Timur)', 'ESE', 'SE (Tenggara)', 'SSE',
      'S (Selatan)', 'SSW', 'SW (Barat Daya)', 'WSW',
      'W (Barat)', 'WNW', 'NW (Barat Laut)', 'NNW'
    ];
    final index = ((deg + 11.25) % 360 / 22.5).floor();
    return list[index % 16];
  }
}

/// CustomPainter untuk Visualisasi Zona Bahaya Merapi & Rute Polyline
class MerapiMapOverlaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Titik pusat Puncak Merapi pada kanvas
    final summitCenter = Offset(width * 0.50, height * 0.20);

    // 1. Zona KRB III Merapi (Radius Bahaya 3km)
    final krb3PaintFill = Paint()
      ..color = AppColors.error.withAlpha(30)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(summitCenter, 80, krb3PaintFill);

    // Lingkaran putus-putus merah KRB III
    final krb3PaintStroke = Paint()
      ..color = AppColors.error
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    _drawDashedCircle(canvas, summitCenter, 80, krb3PaintStroke);

    // Titik Kawah Puncak
    final summitPointPaint = Paint()..color = AppColors.error;
    canvas.drawCircle(summitCenter, 8, summitPointPaint);
    canvas.drawCircle(summitCenter, 18, summitPointPaint..color = AppColors.error.withAlpha(60));

    // 2. Active Travel Route Line (Pos Retribusi -> Plunyon -> Batu Alien -> Bunker Kaliadem)
    final p0 = Offset(70, 360); // Pos Retribusi
    final p1 = Offset(245, 270); // Plunyon
    final p2 = Offset(150, 200); // Batu Alien
    final p3 = Offset(200, 140); // Bunker Kaliadem

    final routePath = Path();
    routePath.moveTo(p0.dx, p0.dy);
    routePath.quadraticBezierTo(140, 320, p1.dx, p1.dy);
    routePath.quadraticBezierTo(200, 240, p2.dx, p2.dy);
    routePath.quadraticBezierTo(175, 170, p3.dx, p3.dy);

    // Route Glow
    final glowPaint = Paint()
      ..color = AppColors.primaryFixed.withAlpha(90)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, glowPaint);

    // Route Core Line
    final coreRoutePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(routePath, coreRoutePaint);
  }

  void _drawDashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
    const int dashCount = 36;
    const double dashAngle = (2 * pi) / dashCount;
    for (int i = 0; i < dashCount; i++) {
      if (i % 2 == 0) {
        final double startAngle = i * dashAngle;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashAngle * 0.7,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter untuk Jarum Kompas Mini 3D Bevel (Utara Merah, Selatan Abu-abu)
class _MiniCompassNeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final needleHalfWidth = size.width / 2;
    final needleLength = size.height / 2;

    // Jarum Utara Sisi Terang (Merah Cerah)
    final northPath = Path()
      ..moveTo(centerX, centerY - needleLength)
      ..lineTo(centerX + needleHalfWidth, centerY)
      ..lineTo(centerX, centerY - 2)
      ..close();

    final northPaint = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.fill;
    canvas.drawPath(northPath, northPaint);

    // Jarum Utara Sisi Bayangan (Merah Tua untuk Efek 3D)
    final northShadePath = Path()
      ..moveTo(centerX, centerY - needleLength)
      ..lineTo(centerX - needleHalfWidth, centerY)
      ..lineTo(centerX, centerY - 2)
      ..close();

    final northShadePaint = Paint()
      ..color = const Color(0xFFB71C1C)
      ..style = PaintingStyle.fill;
    canvas.drawPath(northShadePath, northShadePaint);

    // Jarum Selatan Sisi Terang (Silver Terang)
    final southPath = Path()
      ..moveTo(centerX, centerY + needleLength)
      ..lineTo(centerX + needleHalfWidth, centerY)
      ..lineTo(centerX, centerY + 2)
      ..close();

    final southPaint = Paint()
      ..color = const Color(0xFFCFD8DC)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southPath, southPaint);

    // Jarum Selatan Sisi Bayangan (Silver Gelap untuk Efek 3D)
    final southShadePath = Path()
      ..moveTo(centerX, centerY + needleLength)
      ..lineTo(centerX - needleHalfWidth, centerY)
      ..lineTo(centerX, centerY + 2)
      ..close();

    final southShadePaint = Paint()
      ..color = const Color(0xFF90A4AE)
      ..style = PaintingStyle.fill;
    canvas.drawPath(southShadePath, southShadePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

