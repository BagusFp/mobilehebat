import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../auth/auth_provider.dart';
import '../explore/destination_provider.dart';
import 'trip_provider.dart';

class CreateTripScreen extends StatefulWidget {
  final TripModel? existingTrip;
  final DestinationModel? initialDestination;

  const CreateTripScreen({
    super.key,
    this.existingTrip,
    this.initialDestination,
  });

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = context.read<TripProvider>();
      if (widget.existingTrip != null) {
        tripProvider.initBuilderTrip(existingTrip: widget.existingTrip);
      } else if (widget.initialDestination != null) {
        tripProvider.initBuilderWithDestination(widget.initialDestination!);
      } else {
        tripProvider.initBuilderTrip();
      }
    });
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

  void _showAddDestinationModal(BuildContext context) {
    final destProvider = context.read<DestinationProvider>();
    final tripProvider = context.read<TripProvider>();
    final availableDestinations = destProvider.allDestinations;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
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
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.margin),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Pilih Destinasi Merapi',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                      itemCount: availableDestinations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (c, idx) {
                        final dest = availableDestinations[idx];
                        final isAlreadyAdded = tripProvider.builderItems
                            .any((item) => item.destinationId == dest.id);

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppDimensions.roundedLg,
                            border: Border.all(color: AppColors.surfaceContainer),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: AppDimensions.roundedSm,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: AppColors.primaryContainer,
                                  child: dest.imageUrl != null &&
                                          dest.imageUrl!.startsWith('http')
                                      ? Image.network(
                                          dest.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.landscape,
                                            color: AppColors.onPrimary,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.landscape,
                                          color: AppColors.onPrimary,
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
                                      style: AppTypography.titleMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${dest.categoryName} • ${_formatCurrency(dest.ticketPrice)}',
                                      style: AppTypography.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAlreadyAdded
                                      ? AppColors.surfaceContainer
                                      : AppColors.primaryContainer,
                                  foregroundColor: isAlreadyAdded
                                      ? AppColors.onSurfaceVariant
                                      : AppColors.onPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppDimensions.roundedSm,
                                  ),
                                ),
                                onPressed: isAlreadyAdded
                                    ? null
                                    : () {
                                        tripProvider.addDestinationToBuilder(dest);
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${dest.name} ditambahkan ke rute!'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                child: Text(isAlreadyAdded ? 'Ditambahkan' : '+ Pilih'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final authProvider = context.watch<AuthProvider>();
    final items = tripProvider.builderItems;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(220),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).pop(),
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
              'Buat Trip Baru',
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
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Stepper Progress Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.margin,
                    vertical: AppDimensions.spaceMd,
                  ),
                  color: AppColors.surfaceContainerLow,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LANGKAH 2 DARI 4',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Pilih & Atur Destinasi',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),
                      // Stepper track line with 4 nodes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStepNode(step: '1', title: 'Informasi', isDone: true),
                          _buildStepLine(isDone: true),
                          _buildStepNode(step: '2', title: 'Destinasi', isActive: true),
                          _buildStepLine(isDone: false),
                          _buildStepNode(step: '3', title: 'Jadwal', isDone: false),
                          _buildStepLine(isDone: false),
                          _buildStepNode(step: '4', title: 'Budget', isDone: false),
                        ],
                      ),
                    ],
                  ),
                ),

                // 2. Trip Metadata Banner
                Padding(
                  padding: const EdgeInsets.all(AppDimensions.margin),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppDimensions.roundedXl,
                      border: Border.all(color: AppColors.surfaceContainer),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.onSurface.withAlpha(5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.terrain, size: 20, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      tripProvider.builderTrip?.tripName ?? 'Eksplorasi Merapi 1 Hari',
                                      style: AppTypography.titleMd.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_today, size: 14, color: AppColors.outline),
                                      const SizedBox(width: 4),
                                      Text(
                                        tripProvider.builderTrip?.startDate ?? 'Sabtu, 19 Okt 2024',
                                        style: AppTypography.bodySm,
                                      ),
                                    ],
                                  ),
                                  const Text('•', style: TextStyle(color: AppColors.outline)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.group, size: 14, color: AppColors.outline),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${tripProvider.builderTrip?.participantCount ?? 2} Orang',
                                        style: AppTypography.bodySm,
                                      ),
                                    ],
                                  ),
                                  const Text('•', style: TextStyle(color: AppColors.outline)),
                                  Text(
                                    'Target ${_formatCurrency(tripProvider.targetBudget)}',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                // 4. Destination Reorderable List Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Destinasi Terpilih',
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: AppDimensions.roundedFull,
                            ),
                            child: Text(
                              '${items.length} Destinasi',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.drag_indicator, size: 14, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'Geser untuk urutan',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),

                // List of Stops with connecting badges
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: Column(
                    children: List.generate(items.length, (idx) {
                      final item = items[idx];
                      return Column(
                        children: [
                          _buildDestinationCard(context, item, idx, tripProvider),
                          if (idx < items.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Perjalanan via Jl. Kaliurang (${item.connectingTimeMinutes} mnt • ${item.connectingDistanceKm} km)',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),

                // Button: Tambah Destinasi Lain
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerLow,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppDimensions.roundedLg,
                        ),
                      ),
                      onPressed: () => _showAddDestinationModal(context),
                      icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 20),
                      label: Text(
                        'Tambah Destinasi Lain di Sekitar Merapi',
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),

                // 6. Live Estimate & Budget Summary Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppDimensions.roundedXl,
                      border: Border.all(color: AppColors.surfaceContainer),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.analytics, size: 20, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Kalkulator Rencana Trip',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryContainer,
                                borderRadius: AppDimensions.roundedFull,
                              ),
                              child: Text(
                                'Update Otomatis',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),

                        // Time & Duration Gauge
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceSm),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppDimensions.roundedLg,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule, size: 22, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Durasi Aktivitas',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                      Text(
                                        '5 Jam 30 Menit',
                                        style: AppTypography.headlineSm.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                'Termasuk 45 mnt perjalanan',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),

                        // Budget Breakdown
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payments, size: 16, color: AppColors.outline),
                                const SizedBox(width: 4),
                                Text(
                                  'Total Tiket & Donasi (2 Orang)',
                                  style: AppTypography.bodySm,
                                ),
                              ],
                            ),
                            Text(
                              _formatCurrency(tripProvider.totalTicketCost),
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.local_parking, size: 16, color: AppColors.outline),
                                const SizedBox(width: 4),
                                Text(
                                  'Estimasi Parkir Kendaraan',
                                  style: AppTypography.bodySm,
                                ),
                              ],
                            ),
                            Text(
                              _formatCurrency(tripProvider.parkingFee),
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHighest.withAlpha(80),
                            borderRadius: AppDimensions.roundedMd,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimasi Biaya Wajib',
                                style: AppTypography.bodySm.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatCurrency(tripProvider.totalMandatoryCost),
                                style: AppTypography.titleMd.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceMd),

                        // Budget Health Indicator
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceSm),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryContainer.withAlpha(120),
                            borderRadius: AppDimensions.roundedLg,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check_circle,
                                      color: AppColors.onPrimary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Sisa Target Budget',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.onSecondaryContainer,
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(tripProvider.remainingBudget),
                                        style: AppTypography.titleMd.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: AppDimensions.roundedSm,
                                    ),
                                    child: Text(
                                      'SANGAT AMAN',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Untuk makan & oleh-oleh',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 7. Bottom Sticky Action Bar
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
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceContainer,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: AppDimensions.roundedLg,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text('Kembali'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDimensions.roundedLg,
                            ),
                            elevation: 2,
                          ),
                          onPressed: () async {
                            final userId = authProvider.currentUser?.id ?? 1;
                            await tripProvider.saveBuilderTrip(userId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Rencana Perjalanan berhasil disimpan ke My Trip!'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          },
                          icon: Text(
                            'Lanjut ke Atur Jadwal',
                            style: AppTypography.labelLg.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          label: const Icon(Icons.arrow_forward, size: 18),
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

  Widget _buildStepNode({
    required String step,
    required String title,
    bool isDone = false,
    bool isActive = false,
  }) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.primary
                : isActive
                    ? AppColors.primaryContainer
                    : AppColors.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: AppColors.secondaryContainer, width: 3)
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, size: 16, color: AppColors.onPrimary)
                : Text(
                    step,
                    style: TextStyle(
                      color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTypography.labelSm.copyWith(
            color: isActive
                ? AppColors.primary
                : isDone
                    ? AppColors.onSurface
                    : AppColors.outline,
            fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 2,
        color: isDone ? AppColors.primary : AppColors.outlineVariant,
        margin: const EdgeInsets.only(bottom: 16),
      ),
    );
  }

  Widget _buildDestinationCard(
    BuildContext context,
    TripItemModel item,
    int index,
    TripProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedXl,
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle & Stop Number Badge
          Column(
            children: [
              const Icon(Icons.drag_handle, size: 20, color: AppColors.outline),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${item.visitOrder}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Thumbnail with Scrim Planned Time
          Stack(
            children: [
              ClipRRect(
                borderRadius: AppDimensions.roundedMd,
                child: Container(
                  width: 72,
                  height: 72,
                  color: AppColors.primaryContainer,
                  child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.landscape,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(
                          Icons.landscape,
                          color: AppColors.onPrimary,
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(200),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                  child: Text(
                    item.plannedTime,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: AppTypography.titleMd.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        provider.removeBuilderItem(index);
                      },
                      child: const Icon(Icons.close, size: 18, color: AppColors.outline),
                    ),
                  ],
                ),
                Text(
                  item.itemSubtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.timer, size: 14, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${item.durationHours} Jam',
                      style: AppTypography.bodySm,
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.confirmation_number, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        _formatCurrency(item.estimatedCost),
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}
