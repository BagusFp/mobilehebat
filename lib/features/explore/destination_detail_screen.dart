import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
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
  final GlobalKey _mapKey = GlobalKey();

  bool _isTripAdded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = context.read<TripProvider>();
      if (tripProvider.isDestinationInTrip(widget.destination.id)) {
        setState(() {
          _isTripAdded = true;
        });
      }
    });
  }

  void _scrollToMap() {
    final context = _mapKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
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
    final activeTrip = tripProvider.activeOrUpcomingTrip;
    final isAlreadyInActiveTrip = activeTrip != null &&
        activeTrip.items.any((item) => item.destinationId == dest.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.margin,
                  vertical: AppDimensions.spaceMd,
                ),
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
                        Text(
                          'Rencana Perjalanan (Itinerary)',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
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
                              child: dest.imageUrl != null && dest.imageUrl!.startsWith('http')
                                  ? Image.network(dest.imageUrl!, fit: BoxFit.cover)
                                  : Container(
                                      color: AppColors.primaryContainer,
                                      child: const Icon(Icons.landscape, color: AppColors.onPrimary),
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

                    if (isAlreadyInActiveTrip) ...[
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.spaceSm),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withAlpha(50),
                          borderRadius: AppDimensions.roundedMd,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Destinasi ini sudah tersimpan di rencana "${activeTrip.tripName}".',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
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
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: AppDimensions.roundedLg),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MyTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text('Buka Rencana di My Trip'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: AppDimensions.roundedLg),
                          ),
                          onPressed: () async {
                            await tripProvider.removeDestinationFromTrip(
                              tripId: activeTrip.id!,
                              destinationId: dest.id,
                            );
                            setState(() {
                              _isTripAdded = false;
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Destinasi dihapus dari itinerary.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Hapus dari Trip Ini'),
                        ),
                      ),
                    ] else ...[
                      if (activeTrip != null) ...[
                        InkWell(
                          onTap: () async {
                            await tripProvider.addDestinationToExistingTrip(
                              tripId: activeTrip.id!,
                              destination: dest,
                            );
                            setState(() {
                              _isTripAdded = true;
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Berhasil ditambahkan ke "${activeTrip.tripName}"! ✓'),
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
                          borderRadius: AppDimensions.roundedLg,
                          child: Container(
                            padding: const EdgeInsets.all(AppDimensions.spaceMd),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withAlpha(40),
                              borderRadius: AppDimensions.roundedLg,
                              border: Border.all(color: AppColors.primary.withAlpha(100)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add_task, color: AppColors.onPrimary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tambahkan ke Trip: ${activeTrip.tripName}',
                                        style: AppTypography.titleSm.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Jadwal: ${activeTrip.startDate} • ${activeTrip.items.length} Destinasi',
                                        style: AppTypography.bodySm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

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
                    ],
                    const SizedBox(height: AppDimensions.spaceSm),
                  ],
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
    final isOffline = destProvider.isSavedOffline(dest.id);

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
                          if (dest.imageUrl != null && dest.imageUrl!.startsWith('http'))
                            Image.network(
                              dest.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _buildHeroPlaceholder(),
                            )
                          else
                            _buildHeroPlaceholder(),

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
                                  Text(
                                    '${dest.categoryName} Vulkanik',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
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

                // Distance & Trail Notice Banner
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.margin,
                    vertical: AppDimensions.spaceSm,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceSm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppDimensions.roundedLg,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.explore,
                          size: 20,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: AppDimensions.spaceSm),
                        Expanded(
                          child: Text(
                            'Sekitar ${dest.distanceKm} km dari jalur pos • Akses jalan aspal & jalur lava',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Quick Action Buttons Row (3 tactile rounded boxes)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.margin,
                    vertical: AppDimensions.spaceSm,
                  ),
                  child: Row(
                    children: [
                      // Action 1: Simpan Offline
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            destProvider.toggleOfflineSave(dest.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  !isOffline
                                      ? 'Panduan ${dest.name} tersimpan offline!'
                                      : 'Status offline ${dest.name} dinonaktifkan.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: AppDimensions.roundedXl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isOffline
                                  ? AppColors.secondaryContainer
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: AppDimensions.roundedXl,
                              border: Border.all(
                                color: isOffline
                                    ? AppColors.secondary
                                    : AppColors.surfaceContainer,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isOffline
                                        ? AppColors.secondary.withAlpha(40)
                                        : AppColors.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isOffline
                                        ? Icons.check_circle
                                        : Icons.download_for_offline,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isOffline ? 'Tersimpan' : 'Simpan Offline',
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),

                      // Action 2: Tambah ke Trip
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _isTripAdded = !_isTripAdded;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _isTripAdded
                                      ? 'Berhasil ditambahkan ke rencana perjalanan!'
                                      : 'Dihapus dari rencana perjalanan.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: AppDimensions.roundedXl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isTripAdded
                                  ? AppColors.surfaceContainer
                                  : AppColors.surfaceContainerLowest,
                              borderRadius: AppDimensions.roundedXl,
                              border: Border.all(color: AppColors.surfaceContainer),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isTripAdded
                                        ? Icons.playlist_add_check
                                        : Icons.playlist_add,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isTripAdded ? 'Dalam Trip' : 'Tambah ke Trip',
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),

                      // Action 3: Buka di Peta
                      Expanded(
                        child: InkWell(
                          onTap: _scrollToMap,
                          borderRadius: AppDimensions.roundedXl,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: AppDimensions.roundedXl,
                              border: Border.all(color: AppColors.surfaceContainer),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceContainerLow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.directions,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Buka di Peta',
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
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
                        childAspectRatio: 1.45,
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
                          // Card 4: Suhu
                          _buildInfoTile(
                            icon: Icons.thermostat,
                            iconColor: AppColors.secondary,
                            title: 'Suhu Rata-rata',
                            value: dest.temperatureRange,
                            subValue: 'Sejuk & berkabut',
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
                                  Text(
                                    facility,
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.onSurface,
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
                  key: _mapKey,
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
                                  context.read<MapProvider>().selectDestination(dest);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MapScreen(initialDestination: dest),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tiket Masuk Mulai',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Row(
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
                      ],
                    ),
                    const SizedBox(width: AppDimensions.spaceMd),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isTripAdded
                                ? AppColors.primary
                                : AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimary,
                            shape: const StadiumBorder(),
                            elevation: 2,
                          ),
                          onPressed: () => _showItineraryModal(context, dest),
                          icon: Icon(
                            _isTripAdded ? Icons.task_alt : Icons.event_available,
                            size: 20,
                          ),
                          label: Text(
                            _isTripAdded
                                ? 'Tersimpan di Itinerary ✓'
                                : 'Tambahkan ke Itinerary',
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary,
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
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
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
              Text(
                value,
                style: AppTypography.titleMd.copyWith(
                  color: isPrimaryHighlight ? AppColors.primary : AppColors.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
