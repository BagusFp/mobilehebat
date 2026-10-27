import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/weather_service.dart';
import '../../core/widgets/app_network_image.dart';
import '../../data/models/destination_model.dart';
import '../auth/auth_provider.dart';
import '../map/map_provider.dart';
import '../map/map_screen.dart';
import '../trip/create_trip_screen.dart';
import '../trip/my_trip_screen.dart';
import '../trip/trip_provider.dart';
import 'destination_provider.dart';

class DestinationDetailScreen extends StatefulWidget {
  final DestinationModel destination;

  const DestinationDetailScreen({
    super.key,
    required this.destination,
  });

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isTripAdded = false;
  DestinationWeather? _liveWeather;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _loadLiveWeather();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tripProvider = context.read<TripProvider>();
      final auth = context.read<AuthProvider>();
      if (tripProvider.allTrips.isEmpty) {
        await tripProvider.loadUserTrips(auth.currentUser?.id ?? 1);
      }
      if (mounted && tripProvider.isDestinationInTrip(widget.destination.id)) {
        setState(() {
          _isTripAdded = true;
        });
      }
    });
  }

  Future<void> _loadLiveWeather() async {
    final weather = await WeatherService.getWeatherForDestination(
      latitude: widget.destination.latitude,
      longitude: widget.destination.longitude,
      elevationMdpl: widget.destination.elevationMdpl,
      fallbackRange: widget.destination.temperatureRange,
    );
    if (mounted) {
      setState(() {
        _liveWeather = weather;
        _isLoadingWeather = false;
      });
    }
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

  void _showItineraryModal(BuildContext context, DestinationModel dest) {
    final tripProvider = context.read<TripProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 1;

    if (tripProvider.allTrips.isEmpty) {
      tripProvider.loadUserTrips(userId);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
        return Consumer<TripProvider>(
          builder: (modalContext, provider, _) {
            // Ambil semua trip yang belum selesai (upcoming, active, planned, draft)
            final availableTrips = provider.allTrips.where((t) => t.status != 'completed').toList();
            availableTrips.sort((a, b) {
              if (a.status == 'active' && b.status != 'active') return -1;
              if (b.status == 'active' && a.status != 'active') return 1;
              return (b.id ?? 0).compareTo(a.id ?? 0);
            });

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  top: AppDimensions.spaceMd,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + AppDimensions.spaceMd,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.outlineVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Kelola Rencana (Itinerary)',
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),

                      // Destination Card Preview
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppDimensions.roundedLg,
                          border: Border.all(color: AppColors.surfaceContainer),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: AppDimensions.roundedSm,
                              child: SizedBox(
                                width: 52,
                                height: 52,
                                child: AppNetworkImage(
                                  imageUrl: dest.imageUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dest.name,
                                    style: AppTypography.titleSm.copyWith(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${dest.categoryName} • ${dest.ticketPriceLabel.isNotEmpty ? dest.ticketPriceLabel : _formatCurrency(dest.ticketPrice)}',
                                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spaceMd),

                      // Daftar Trip Tersedia
                      if (availableTrips.isNotEmpty) ...[
                        Text(
                          'Pilih Trip untuk Ditambahkan:',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...availableTrips.map((trip) {
                          final isAlreadyInThisTrip = trip.items.any((i) => i.destinationId == dest.id);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(AppDimensions.spaceMd),
                            decoration: BoxDecoration(
                              color: isAlreadyInThisTrip
                                  ? AppColors.primaryContainer.withAlpha(40)
                                  : AppColors.surfaceContainerLow,
                              borderRadius: AppDimensions.roundedLg,
                              border: Border.all(
                                color: isAlreadyInThisTrip
                                    ? AppColors.primary.withAlpha(120)
                                    : AppColors.surfaceContainer,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: isAlreadyInThisTrip
                                            ? AppColors.primary
                                            : AppColors.surfaceContainerHighest,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isAlreadyInThisTrip ? Icons.task_alt : Icons.route_rounded,
                                        color: isAlreadyInThisTrip ? AppColors.onPrimary : AppColors.primary,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trip.tripName,
                                            style: AppTypography.titleSm.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${trip.startDate} • ${trip.items.length} Destinasi',
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
                                const SizedBox(height: 10),
                                if (isAlreadyInThisTrip) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.error,
                                            side: const BorderSide(color: AppColors.error),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                          onPressed: () async {
                                            await provider.removeDestinationFromTrip(
                                              tripId: trip.id!,
                                              destinationId: dest.id,
                                            );
                                            setState(() {
                                              _isTripAdded = provider.isDestinationInTrip(dest.id);
                                            });
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('${dest.name} dihapus dari "${trip.tripName}".')),
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                          label: const Text('Hapus dari Trip', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: AppColors.onPrimary,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                          ),
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(builder: (_) => const MyTripScreen()),
                                            );
                                          },
                                          icon: const Icon(Icons.open_in_new, size: 16),
                                          label: const Text('Buka Trip', style: TextStyle(fontSize: 12)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  SizedBox(
                                    width: double.infinity,
                                    height: 38,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.onPrimary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        elevation: 0,
                                      ),
                                      onPressed: () async {
                                        await provider.addDestinationToExistingTrip(
                                          tripId: trip.id!,
                                          destination: dest,
                                        );
                                        setState(() {
                                          _isTripAdded = true;
                                        });
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Berhasil ditambahkan ke "${trip.tripName}"! ✓'),
                                              duration: const Duration(seconds: 4),
                                              action: SnackBarAction(
                                                label: 'LIHAT TRIP',
                                                textColor: AppColors.primaryContainer,
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (_) => const MyTripScreen()),
                                                  );
                                                },
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Tambahkan ke Trip Ini', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 6),
                      ],

                      // Tombol Buat Rencana Trip Baru
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreateTripScreen(
                                initialDestination: dest,
                              ),
                            ),
                          );
                        },
                        borderRadius: AppDimensions.roundedLg,
                        child: Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceMd),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppDimensions.roundedLg,
                            border: Border.all(color: AppColors.surfaceContainer),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceContainerHighest,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Buat Rencana Trip Baru',
                                      style: AppTypography.titleSm.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mulai itinerary baru dengan titik awal ${dest.name}',
                                      style: AppTypography.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppColors.outline),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destProvider = context.watch<DestinationProvider>();
    final authProvider = context.watch<AuthProvider>();
    final dest = widget.destination;

    final isFav = destProvider.isFavorite(dest.id);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(220),
        elevation: 0.5,
        scrolledUnderElevation: 2.0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Kembali',
        ),
        titleSpacing: 0,
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
              'Trail Detail',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Hero Visual Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: Container(
                    height: 240,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: AppDimensions.roundedXl,
                      color: AppColors.primaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withAlpha(15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: AppDimensions.roundedXl,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AppNetworkImage(
                            imageUrl: dest.imageUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 800,
                            placeholder: _buildHeroPlaceholder(),
                            errorWidget: _buildHeroPlaceholder(),
                          ),

                          // Gradient Scrim
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withAlpha(40),
                                  Colors.transparent,
                                  AppColors.primary.withAlpha(220),
                                ],
                              ),
                            ),
                          ),

                          // Top Badges
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.48,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest.withAlpha(230),
                                borderRadius: AppDimensions.roundedFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.nature_people,
                                    size: 15,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${dest.categoryName} Vulkanik',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer.withAlpha(240),
                                borderRadius: AppDimensions.roundedFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    size: 15,
                                    color: AppColors.onSecondaryContainer,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Buka Hari Ini',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bottom Metadata
                          Positioned(
                            bottom: 12,
                            left: 14,
                            right: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.landscape,
                                      size: 16,
                                      color: AppColors.primaryFixed,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ketinggian ± ${dest.elevationMdpl} mdpl',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primaryFixed,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kawasan Wisata Lereng Selatan Gunung Merapi',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.surfaceVariant,
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
                  ),
                ),

                // 3. Core Destination Header
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.margin,
                    right: AppDimensions.margin,
                    top: AppDimensions.spaceMd,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dest.name,
                              style: AppTypography.headlineLg.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    dest.address,
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      // Favorite Toggle Button
                      InkWell(
                        onTap: () {
                          destProvider.toggleFavorite(
                            dest.id,
                            userId: authProvider.currentUser?.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                !isFav
                                    ? '${dest.name} ditambahkan ke favorit'
                                    : '${dest.name} dihapus dari favorit',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isFav
                                ? AppColors.errorContainer
                                : AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? AppColors.error : AppColors.onSurface,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 5. Key Travel Info Cards (Grid 2x2)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.margin,
                    right: AppDimensions.margin,
                    top: AppDimensions.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Ringkas',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: AppDimensions.spaceSm,
                        mainAxisSpacing: AppDimensions.spaceSm,
                        childAspectRatio: MediaQuery.sizeOf(context).width < 360 ? 1.12 : 1.25,
                        children: [
                          // Card 1: Tiket Masuk
                          _buildInfoTile(
                            icon: Icons.confirmation_number,
                            iconColor: AppColors.primary,
                            title: 'Tiket Masuk',
                            value: dest.ticketPrice > 0
                                ? _formatCurrency(dest.ticketPrice)
                                : 'Sukarela',
                            subValue: 'Termasuk retribusi kawasan',
                            isPrimaryHighlight: true,
                          ),
                          // Card 2: Jam Operasional
                          _buildInfoTile(
                            icon: Icons.schedule,
                            iconColor: AppColors.secondary,
                            title: 'Jam Buka',
                            value: dest.openingHours,
                            subValue: 'Setiap Hari',
                          ),
                          // Card 3: Estimasi Durasi
                          _buildInfoTile(
                            icon: Icons.timer,
                            iconColor: AppColors.primary,
                            title: 'Kunjungan',
                            value: dest.estimatedDuration,
                            subValue: 'Ideal foto pagi hari',
                          ),
                          // Card 4: Suhu Real-time / Live Dinamis
                          _buildInfoTile(
                            icon: Icons.thermostat,
                            iconColor: AppColors.secondary,
                            title: 'Suhu Rata-rata',
                            value: _liveWeather != null
                                ? '${_liveWeather!.displayTemp} (${_liveWeather!.rangeString})'
                                : dest.temperatureRange,
                            subValue: _liveWeather != null
                                ? _liveWeather!.subValue
                                : (_isLoadingWeather ? 'Memuat cuaca...' : 'Sejuk lereng Merapi'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 6. Complete Narrative Description
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.margin,
                    right: AppDimensions.margin,
                    top: AppDimensions.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deskripsi Lengkap',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceMd),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: AppDimensions.roundedXl,
                          border: Border.all(color: AppColors.surfaceContainer),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dest.description,
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurface,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceMd),
                            // Tip box
                            Container(
                              padding: const EdgeInsets.all(AppDimensions.spaceSm),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: AppDimensions.roundedLg,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.wb_twilight,
                                    size: 20,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: AppDimensions.spaceSm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Waktu Terbaik Kunjungan',
                                          style: AppTypography.labelMd.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dest.bestVisitingTime ??
                                              'Pukul 05.30 - 08.00 WIB untuk langit jernih.',
                                          style: AppTypography.bodySm.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 7. Facilities Tersedia
                if (dest.facilities.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppDimensions.margin,
                      right: AppDimensions.margin,
                      top: AppDimensions.spaceLg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Fasilitas Tersedia',
                                style: AppTypography.headlineSm.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${dest.facilities.length} Fasilitas Utama',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spaceSm),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: dest.facilities.map((facility) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: AppDimensions.roundedFull,
                                border: Border.all(color: AppColors.surfaceContainer),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getFacilityIcon(facility),
                                    size: 16,
                                    color: AppColors.secondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      facility,
                                      style: AppTypography.bodyMd.copyWith(
                                        color: AppColors.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                // 8. Peta Lokasi & Akses
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.margin,
                    right: AppDimensions.margin,
                    top: AppDimensions.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                            'Peta Lokasi & Akses',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${dest.latitude.toStringAsFixed(4)}° S, ${dest.longitude.toStringAsFixed(4)}° E',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceSm),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: AppDimensions.roundedXl,
                          border: Border.all(color: AppColors.surfaceContainer),
                        ),
                        child: Column(
                          children: [
                            // Map Preview Graphic
                            Container(
                              height: 160,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: AppDimensions.roundedLg,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.surfaceContainer,
                                    AppColors.surfaceContainerHigh,
                                  ],
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 72,
                                    color: AppColors.primary.withAlpha(40),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: AppDimensions.roundedFull,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withAlpha(80),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.pin_drop,
                                          size: 16,
                                          color: AppColors.onPrimary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          dest.name,
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.onPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceSm),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.navigation,
                                          size: 16,
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '32 km dari Tugu Yogyakarta',
                                            style: AppTypography.bodySm.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '± 55 menit perjalanan',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spaceSm),
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryContainer,
                                  foregroundColor: AppColors.onPrimary,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppDimensions.roundedLg,
                                  ),
                                ),
                                onPressed: () {
                                  // Hubungkan ke Peta Merapi Navigasi dan aktifkan navigasi rute ke destinasi ini
                                  final mapProv = context.read<MapProvider>();
                                  mapProv.selectDestination(dest);
                                  mapProv.fetchRouteToDestination(dest);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MapScreen(
                                        initialDestination: dest,
                                        autoRoute: true,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.near_me, size: 20),
                                label: Text(
                                  'Petunjuk Arah & Navigasi Rute',
                                  style: AppTypography.titleMd.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 10. Sticky Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.margin,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withAlpha(245),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withAlpha(20),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Tiket Masuk Mulai',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  dest.ticketPrice > 0
                                      ? _formatCurrency(dest.ticketPrice)
                                      : 'Gratis',
                                  style: AppTypography.headlineSm.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  ' /org',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTripAdded
                                ? AppColors.secondary
                                : AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: const StadiumBorder(),
                            elevation: 2,
                          ),
                          onPressed: () => _showItineraryModal(context, dest),
                          icon: Icon(
                            _isTripAdded ? Icons.task_alt : Icons.event_available,
                            size: 20,
                          ),
                          label: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _isTripAdded
                                  ? 'Kelola di Itinerary ✓'
                                  : 'Tambahkan ke Itinerary',
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onPrimary,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
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

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subValue,
    bool isPrimaryHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedXl,
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: AppTypography.titleMd.copyWith(
                    color: isPrimaryHighlight ? AppColors.primary : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subValue,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFacilityIcon(String facility) {
    final lower = facility.toLowerCase();
    if (lower.contains('parkir')) return Icons.local_parking;
    if (lower.contains('kopi') || lower.contains('makan')) return Icons.local_cafe;
    if (lower.contains('toilet') || lower.contains('wc')) return Icons.wc;
    if (lower.contains('pemandu')) return Icons.record_voice_over;
    if (lower.contains('foto') || lower.contains('panorama')) return Icons.photo_camera;
    if (lower.contains('mushola')) return Icons.mosque;
    return Icons.check_circle_outline;
  }

  Widget _buildHeroPlaceholder() {
    return Container(
      color: AppColors.primaryContainer,
      child: const Center(
        child: Icon(
          Icons.landscape,
          size: 64,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}
