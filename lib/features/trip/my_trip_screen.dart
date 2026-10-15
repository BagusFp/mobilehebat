import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../auth/auth_provider.dart';
import '../map/map_screen.dart';
import '../map/offline_map_screen.dart';
import 'active_trip_screen.dart';
import 'create_trip_screen.dart';
import 'trip_provider.dart';

class MyTripScreen extends StatefulWidget {
  const MyTripScreen({super.key});

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<TripProvider>().loadUserTrips(auth.currentUser?.id);
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

  Widget _buildConfirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySm.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartTrip(
    BuildContext context,
    TripModel trip,
    TripProvider tripProvider,
  ) async {
    // 1. Validasi: jika itinerary tidak memiliki destinasi
    if (trip.items.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text('Itinerary Kosong'),
            ],
          ),
          content: const Text(
            'Rencana perjalanan ini belum memiliki destinasi wisata. Silakan tambahkan destinasi terlebih dahulu sebelum memulai perjalanan aktif.',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      return;
    }

    // 2. Deteksi apakah tanggal perjalanan masih di masa depan
    bool isFutureDate = false;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime? tripDate = DateTime.tryParse(trip.startDate);
      if (tripDate != null) {
        final pureTripDate = DateTime(tripDate.year, tripDate.month, tripDate.day);
        if (pureTripDate.isAfter(today)) {
          isFutureDate = true;
        }
      }
    } catch (_) {}

    // 3. Konfirmasi Mulai Sekarang
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
          title: Row(
            children: const [
              Icon(Icons.hiking, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Mulai Perjalanan?'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFutureDate) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixedDim.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.secondary.withAlpha(100)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.secondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Jadwal perjalanan ini adalah ${trip.startDate} (belum dijadwalkan untuk hari ini). Apakah Anda ingin memulainya lebih awal?',
                            style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text(
                  'Konfirmasi informasi perjalanan:',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                _buildConfirmRow(Icons.map_outlined, 'Nama', trip.tripName),
                _buildConfirmRow(Icons.calendar_today, 'Tanggal', trip.startDate),
                _buildConfirmRow(Icons.place_outlined, 'Destinasi', '${trip.items.length} Destinasi'),
                _buildConfirmRow(Icons.account_balance_wallet_outlined, 'Estimasi Anggaran', _formatCurrency(trip.targetBudget)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimary,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mulai Sekarang'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      if (trip.id == null) return;
      await tripProvider.startActiveTrip(trip.id!);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveTripScreen(tripId: trip.id!),
          ),
        );
      }
    }
  }

  void _showTripMenuSheet(BuildContext context, TripModel trip) {
    final tripProvider = context.read<TripProvider>();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? trip.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
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
                Text(
                  trip.tripName,
                  style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                  title: Text('Edit Rencana Itinerary', style: AppTypography.bodyMd),
                  onTap: () {
                    Navigator.pop(ctx);
                    tripProvider.initBuilderTrip(existingTrip: trip);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CreateTripScreen(existingTrip: trip)),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_outlined, color: AppColors.primary),
                  title: Text('Bagikan Rute Perjalanan', style: AppTypography.bodyMd),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Tautan itinerary "${trip.tripName}" berhasil disalin.')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text('Hapus Rencana Trip', style: AppTypography.bodyMd.copyWith(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (trip.id != null) {
                      tripProvider.deleteTrip(trip.id!, userId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rencana trip berhasil dihapus.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    // Upcoming trip hero: ambil trip aktif atau trip pertama dengan status upcoming/active
    final upcomingTrips = tripProvider.allTrips.where((t) => t.status == 'upcoming' || t.status == 'active').toList();
    upcomingTrips.sort((a, b) {
      if (a.status == 'active' && b.status != 'active') return -1;
      if (a.status != 'active' && b.status == 'active') return 1;
      return 0;
    });
    final activeTrip = tripProvider.selectedTrip != null && upcomingTrips.any((t) => t.id == tripProvider.selectedTrip!.id)
        ? tripProvider.selectedTrip
        : (upcomingTrips.isNotEmpty ? upcomingTrips.first : null);

    // Draft trips
    final draftTrips = tripProvider.allTrips.where((t) => t.status == 'draft').toList();
    // Completed trips
    final completedTrips = tripProvider.allTrips.where((t) => t.status == 'completed').toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: Text('Buat Trip', style: AppTypography.labelMd.copyWith(color: AppColors.onPrimary)),
        onPressed: () {
          tripProvider.initBuilderTrip();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTripScreen()),
          );
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await tripProvider.loadUserTrips(user?.id);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.spaceSm),
                // 1. Judul Halaman
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'My Trip',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      if (tripProvider.isUsingCachedData)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off_rounded, size: 14, color: AppColors.secondary),
                              const SizedBox(width: 5),
                              Text(
                                'Mode Tersimpan (Offline)',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                // 3. Segmented Tabs Filter: Mendatang, Draft, Selesai
                _buildSegmentedTabs(tripProvider, draftCount: draftTrips.length),

                // 4. Tab Body Content
                if (tripProvider.activeTab == 'upcoming') ...[
                  if (activeTrip != null) ...[
                    if (upcomingTrips.length > 1)
                      Container(
                        height: 38,
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                          scrollDirection: Axis.horizontal,
                          itemCount: upcomingTrips.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final t = upcomingTrips[idx];
                            final isSelected = t.id == activeTrip.id;
                            final isActive = t.status == 'active';
                            return ChoiceChip(
                              selected: isSelected,
                              showCheckmark: false,
                              avatar: Icon(
                                isActive ? Icons.play_circle_fill : Icons.backpack,
                                size: 14,
                                color: isSelected ? AppColors.onPrimary : AppColors.primary,
                              ),
                              label: Text(
                                t.tripName,
                                style: AppTypography.labelSm.copyWith(
                                  color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceContainerHigh,
                              onSelected: (_) {
                                tripProvider.selectTrip(t);
                              },
                            );
                          },
                        ),
                      ),
                    // Primary Active Trip Hero Card
                    _buildActiveTripHeroCard(context, activeTrip, tripProvider),
                    // Route Elevation Miniature Map Preview
                    _buildElevationProfileCard(),
                  ] else ...[
                    _buildEmptyUpcomingState(context),
                  ],

                  // Draft Itinerary Preview Card
                  if (draftTrips.isNotEmpty)
                    _buildDraftSection(context, draftTrips.first, tripProvider, user?.id ?? draftTrips.first.userId),

                  // Delightful Discovery Tip Box
                  _buildTipBox(),
                ] else if (tripProvider.activeTab == 'draft') ...[
                  _buildDraftTabList(context, draftTrips, tripProvider, user?.id ?? (draftTrips.isNotEmpty ? draftTrips.first.userId : 1)),
                ] else ...[
                  _buildCompletedTabContent(context, completedTrips, tripProvider),
                ],

                const SizedBox(height: 80), // Padding untuk Floating Action Button
              ],
            ),
          ),
        ),
      ),
    );
  }



  // 3. Segmented Tabs Filter
  Widget _buildSegmentedTabs(TripProvider provider, {required int draftCount}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: AppDimensions.roundedFull,
        ),
        child: Row(
          children: [
            _buildTabButton(
              title: 'Mendatang',
              isSelected: provider.activeTab == 'upcoming',
              onTap: () => provider.setActiveTab('upcoming'),
              trailingWidget: provider.activeTab == 'upcoming'
                  ? Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            _buildTabButton(
              title: 'Draft',
              isSelected: provider.activeTab == 'draft',
              onTap: () => provider.setActiveTab('draft'),
              trailingWidget: Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: provider.activeTab == 'draft'
                      ? AppColors.primary
                      : AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$draftCount',
                  style: AppTypography.labelSm.copyWith(
                    color: provider.activeTab == 'draft'
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            _buildTabButton(
              title: 'Selesai',
              isSelected: provider.activeTab == 'completed',
              onTap: () => provider.setActiveTab('completed'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailingWidget,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.roundedFull,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: AppDimensions.roundedFull,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
              ?trailingWidget,
            ],
          ),
        ),
      ),
    );
  }

  // 4. Active Trip Hero Card (Layar 7 Primary Card)
  Widget _buildActiveTripHeroCard(
    BuildContext context,
    TripModel trip,
    TripProvider tripProvider,
  ) {
    final items = trip.items;
    // Hitung budget
    double totalTicket = 0;
    for (final item in items) {
      totalTicket += item.estimatedCost;
    }
    final double mandatoryTotal = totalTicket;
    final double remainingBudget = (trip.targetBudget - mandatoryTotal).clamp(0, trip.targetBudget);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withAlpha(12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Subtle aura background
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryFixed.withAlpha(50),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: trip.status == 'active'
                                        ? AppColors.primary
                                        : AppColors.secondaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        trip.status == 'active' ? Icons.radar : Icons.check_circle,
                                        size: 12,
                                        color: trip.status == 'active' ? AppColors.onPrimary : AppColors.secondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        trip.status == 'active'
                                            ? 'Sedang Berlangsung • Perjalanan Aktif'
                                            : 'Terkonfirmasi • Siap Jalan',
                                        style: AppTypography.labelSm.copyWith(
                                          color: trip.status == 'active'
                                              ? AppColors.onPrimary
                                              : AppColors.onSecondaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '1 Hari Trip',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              trip.tripName,
                              style: AppTypography.headlineSm.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  trip.startDate,
                                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                                const SizedBox(width: 6),
                                const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                                const SizedBox(width: 6),
                                const Icon(Icons.group, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  '${trip.participantCount} Orang',
                                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: AppColors.onSurfaceVariant),
                        onPressed: () => _showTripMenuSheet(context, trip),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spaceMd),

                  // Hero Image & Countdown Overlay
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: Stack(
                      children: [
                        Image.network(
                          trip.bannerImageUrl ??
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuCwXWD1ehYGmjCp_tx9aHTlZ8jRBa3kBFwla81OgBF70OA_aTU48L3L1uWDxVKLOeOibal32sVtkWDwCjMGF8itjKr-NQN1L86Ee1mYoQwDS-J7cI5ZKVOVXKZ0Xc4FNEYAOodZRXRzOBzJxFqXOJ01UXhwtJqgj6WDkkS3RVXWzd2wa6g9UVa80DlrCKLRbVlgTZnEFnH0cSPkq-wv1H5RkhBThijYlO7htbYniIv84-mxlC7wZ7w',
                          height: 176,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 176,
                            color: AppColors.primaryContainer,
                            child: const Center(
                              child: Icon(Icons.landscape, size: 60, color: Colors.white70),
                            ),
                          ),
                        ),
                        // Dark Gradient Overlay
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withAlpha(60),
                                  Colors.black.withAlpha(200),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Countdown & Weather Pill at bottom
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withAlpha(40),
                                    ),
                                    child: const Icon(Icons.schedule, color: Colors.white, size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Mulai Dalam',
                                        style: AppTypography.labelSm.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        '14 Jam 25 Menit',
                                        style: AppTypography.labelMd.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wb_sunny, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cerah 06:00 WIB',
                                      style: AppTypography.labelSm.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
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

                  const SizedBox(height: AppDimensions.spaceSm),

                  // Utility Actions Row (Reminder & Offline)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLow,
                            side: BorderSide(
                              color: trip.reminderEnabled
                                  ? AppColors.primary.withAlpha(80)
                                  : AppColors.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                          onPressed: () {
                            if (trip.id != null) {
                              tripProvider.toggleReminder(trip.id!);
                              final status = !trip.reminderEnabled;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(status
                                      ? 'Pengingat perjalanan (H-2 Jam) telah diaktifkan.'
                                      : 'Pengingat perjalanan dimatikan.'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            trip.reminderEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                            size: 16,
                            color: trip.reminderEnabled ? AppColors.primary : AppColors.outline,
                          ),
                          label: Text(
                            trip.reminderEnabled ? 'Pengingat (H-2)' : 'Pengingat Mati',
                            style: AppTypography.labelSm.copyWith(
                              color: trip.reminderEnabled ? AppColors.primary : AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerLow,
                            side: BorderSide(
                              color: trip.isSavedOffline
                                  ? AppColors.secondary.withAlpha(80)
                                  : AppColors.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const OfflineMapScreen()),
                            );
                          },
                          icon: Icon(
                            trip.isSavedOffline ? Icons.cloud_done : Icons.cloud_download_outlined,
                            size: 16,
                            color: trip.isSavedOffline ? AppColors.secondary : AppColors.outline,
                          ),
                          label: Text(
                            trip.isSavedOffline ? 'Offline (34 MB)' : 'Unduh Offline',
                            style: AppTypography.labelSm.copyWith(
                              color: trip.isSavedOffline ? AppColors.secondary : AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spaceMd),

                  // Interactive Timeline Schedule Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.route, color: AppColors.primary, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Timeline Rencana Perjalanan',
                            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        '${items.length} Destinasi Utama',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppDimensions.spaceSm),

                  // Continuous Vertical Timeline Items
                  _buildTimelineItemsList(context, items, trip, tripProvider),

                  const SizedBox(height: AppDimensions.spaceMd),

                  // Budget & Expense Estimation Section
                  _buildBudgetSection(trip, mandatoryTotal, remainingBudget),

                  const SizedBox(height: AppDimensions.spaceMd),

                  // Action Buttons Row
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: trip.status == 'active'
                            ? AppColors.primary
                            : AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () {
                        if (trip.id == null) return;
                        if (trip.status == 'active') {
                          tripProvider.selectTripById(trip.id!);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ActiveTripScreen(tripId: trip.id!),
                            ),
                          );
                        } else {
                          _handleStartTrip(context, trip, tripProvider);
                        }
                      },
                      icon: Icon(
                        trip.status == 'active'
                            ? Icons.directions_walk_rounded
                            : Icons.play_circle_filled,
                        size: 22,
                      ),
                      label: Text(
                        trip.status == 'active'
                            ? 'Lanjutkan Perjalanan Aktif'
                            : 'Mulai Trip Sekarang',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 16,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spaceSm),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.secondaryContainer.withAlpha(120),
                        foregroundColor: AppColors.onSecondaryContainer,
                        side: const BorderSide(color: AppColors.secondaryContainer),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapScreen()),
                        );
                      },
                      icon: const Icon(Icons.map_outlined, size: 20, color: AppColors.secondary),
                      label: Text(
                        'Lihat di Peta Rute Interaktif',
                        style: AppTypography.titleMd.copyWith(
                          fontSize: 14,
                          color: AppColors.onSecondaryContainer,
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
    );
  }

  // Timeline Items List with Continuous Track Line
  Widget _buildTimelineItemsList(
    BuildContext context,
    List<TripItemModel> items,
    TripModel trip,
    TripProvider tripProvider,
  ) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Center(
          child: Text(
            'Belum ada destinasi pada trip ini.',
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final isLast = index == items.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical Timeline Line & Dot Column
              SizedBox(
                width: 24,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? AppColors.primary
                            : (index == 1 ? AppColors.secondary : AppColors.tertiary),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.surfaceContainerHighest,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Destination Card Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.onSurface.withAlpha(4),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              item.plannedTime,
                                              style: AppTypography.labelSm.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '• ${item.durationHours} Jam',
                                            style: AppTypography.bodySm.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.itemName,
                                        style: AppTypography.titleMd.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.itemSubtitle,
                                        style: AppTypography.bodySm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.imageUrl ?? '',
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      width: 52,
                                      height: 52,
                                      color: AppColors.surfaceContainerHighest,
                                      child: const Icon(Icons.image, size: 24, color: AppColors.outline),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Detail baris bawah
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      item.estimatedCost > 0 ? Icons.confirmation_number : Icons.favorite,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.estimatedCost > 0
                                          ? 'Tiket ${_formatCurrency(item.estimatedCost / 2)} / org'
                                          : 'Donasi Sukarela (~Rp 10.000)',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    index == 0
                                        ? 'Spot Foto • Trekking'
                                        : (index == 1 ? 'Edukasi Vulkanik' : 'Cagar Budaya'),
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Connecting Distance Indicator
                      if (!isLast && item.connectingDistanceKm > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.surfaceContainer),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(5),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.directions_car, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.connectingDistanceKm} km (${item.connectingTimeMinutes} mnt berkendara)',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primary,
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
              ),
            ],
          ),
        );
      }),
    );
  }

  // Budget & Expense Estimation Section
  Widget _buildBudgetSection(TripModel trip, double mandatoryCost, double remaining) {
    final double mandatoryRatio = (mandatoryCost / trip.targetBudget).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Estimasi Anggaran Trip',
                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'Alokasi ${_formatCurrency(trip.targetBudget)}',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Multi-Segment Visual Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: AppColors.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: mandatoryRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryContainer,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Wajib Tiket & Retribusi',
                    style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(mandatoryCost),
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Builder(
                    builder: (_) {
                      final destNames = trip.items.map((e) => e.itemName).toList();
                      final destLabel = destNames.isEmpty
                          ? ''
                          : ' (${destNames.take(2).join(' & ')}${destNames.length > 2 ? ' +${destNames.length - 2}' : ''})';
                      return Text(
                        '${trip.participantCount} Orang$destLabel',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Sisa Anggaran Kuliner',
                    style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatCurrency(remaining),
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Tersedia aman',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Route Elevation Miniature Map Preview
  Widget _buildElevationProfileCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.landscape, color: AppColors.primary, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Kontur Elevasi Jalur',
                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                'Tanjakan Sedang (+320m)',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: ElevationSparklinePainter(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Plunyon (850 mdpl)',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    Text(
                      'Kaliadem (1.170 mdpl)',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Museum (980 mdpl)',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
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

  // Draft Section Card (Shown on Mendatang Tab)
  Widget _buildDraftSection(
    BuildContext context,
    TripModel draftTrip,
    TripProvider tripProvider,
    int userId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.onSurfaceVariant, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Rencana Tersimpan (Draft)',
                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Text(
                '1 Draft Belum Selesai',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      child: Image.network(
                        draftTrip.bannerImageUrl ??
                            'https://lh3.googleusercontent.com/aida-public/AB6AXuAPCRJJgh8Rcxr67OUIBH0lTkBEjznYjV4dRG5FgHsyOkFAhrLdHE1wBAIXN3blB_0TSNHKVyKtZtLIFFJt8277BtD0ks8ED9PzBx9SXFgFt3jBWChmkm8uOCyZEr-Za1g-7k0Kf6oBpQhN5yO0mPcFO0P9mfeYovAYB9NngDAPmbdPG16QZGbdrhjEWVp_0C0G-8ZWCS0S3UFjvckAn-KVl5TQqS7Yl3ZlBbS98WpVL3OHNQ2Px1Q',
                        width: 76,
                        height: 76,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 76,
                          height: 76,
                          color: AppColors.surfaceContainerHigh,
                          child: const Icon(Icons.coffee, color: AppColors.outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Draft Terakhir Diedit Kemarin',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            draftTrip.tripName,
                            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kopi Merapi Petung, Gardu Pandang, Tlogo Putri',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.place, size: 13, color: AppColors.outline),
                              const SizedBox(width: 2),
                              Text(
                                '${draftTrip.items.length} Lokasi',
                                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(width: 6),
                              const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                              const SizedBox(width: 6),
                              const Icon(Icons.schedule, size: 13, color: AppColors.outline),
                              const SizedBox(width: 2),
                              Text(
                                'Sore Hari',
                                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () {
                        if (draftTrip.id != null) {
                          tripProvider.deleteTrip(draftTrip.id!, userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Draft trip berhasil dihapus.')),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Hapus'),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerHigh,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tautan draft dibagikan.')),
                            );
                          },
                          icon: const Icon(Icons.share, size: 14, color: AppColors.onSurface),
                          label: Text(
                            'Bagikan',
                            style: AppTypography.labelMd.copyWith(color: AppColors.onSurface),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: () {
                            tripProvider.initBuilderTrip(existingTrip: draftTrip);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.arrow_forward, size: 14),
                          label: Text('Lanjutkan Edit', style: AppTypography.labelMd),
                        ),
                      ],
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

  // Delightful Discovery Tip Box
  Widget _buildTipBox() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lightbulb, color: AppColors.onPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips Perjalanan Merapi',
                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Disarankan membawa jaket windbreaker dan kacamata debu saat menjelajahi Kaliadem sebelum pukul 11:00 WIB untuk pemandangan kawah paling bersih bebas kabut tebal.',
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
    );
  }

  // Tab Draft List (Saat tab "Draft" aktif)
  Widget _buildDraftTabList(
    BuildContext context,
    List<TripModel> drafts,
    TripProvider tripProvider,
    int userId,
  ) {
    if (drafts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Column(
            children: [
              const Icon(Icons.drafts_outlined, size: 64, color: AppColors.outline),
              const SizedBox(height: 12),
              Text(
                'Belum Ada Draft Tersimpan',
                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Mulai rencanakan trip dan simpan sebagai draft kapan saja.',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: drafts.map((draft) {
        return _buildDraftSection(context, draft, tripProvider, userId);
      }).toList(),
    );
  }

  // Tab Selesai Content (Saat tab "Selesai" aktif)
  Widget _buildCompletedTabContent(
    BuildContext context,
    List<TripModel> completedTrips,
    TripProvider tripProvider,
  ) {
    if (completedTrips.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spaceXl),
          child: Column(
            children: [
              const Icon(Icons.task_alt, size: 64, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(
                'Belum Ada Trip yang Selesai',
                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Riwayat perjalanan Merapi yang telah kamu selesaikan akan tercatat otomatis di sini bersama dokumentasi fotomu.',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      child: Column(
        children: completedTrips.map((trip) {
          final completedDestCount = trip.items.where((i) => i.isCompleted).length;
          final totalCost = trip.totalActualCost > 0 ? trip.totalActualCost : 0.0;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withAlpha(8),
                  blurRadius: 6,
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, size: 12, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(
                            'Selesai',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      trip.completedAt != null && trip.completedAt!.length >= 10
                          ? trip.completedAt!.substring(0, 10)
                          : trip.startDate,
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  trip.tripName,
                  style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '$completedDestCount/${trip.items.length} Destinasi Selesai Dikunjungi',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Pengeluaran', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        Text(
                          _formatCurrency(totalCost),
                          style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Anggaran Awal', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        Text(
                          _formatCurrency(trip.targetBudget),
                          style: AppTypography.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (trip.id == null) return;
                      tripProvider.selectTrip(trip);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ActiveTripScreen(tripId: trip.id!)),
                      );
                    },
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text('Lihat Ringkasan & Pengeluaran'),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Empty State untuk Tab Mendatang jika belum ada trip
  Widget _buildEmptyUpcomingState(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final isOfflineEmpty = tripProvider.emptyCacheMessage != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          children: [
            Icon(
              isOfflineEmpty ? Icons.cloud_off_rounded : Icons.calendar_month,
              size: 64,
              color: isOfflineEmpty ? AppColors.secondary : AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              isOfflineEmpty ? 'Data Butuh Koneksi Internet' : 'Belum Ada Trip Mendatang',
              style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isOfflineEmpty
                  ? tripProvider.emptyCacheMessage!
                  : 'Buat rencana petualangan barumu di Lereng Merapi sekarang.',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!isOfflineEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: () {
                  context.read<TripProvider>().initBuilderTrip();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Buat Trip Baru'),
              ),
          ],
        ),
      ),
    );
  }
}

/// CustomPainter untuk Grafik Sparkline Kontur Elevasi Jalur (Sesuai Stitch Screen 7 SVG)
class ElevationSparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Normalisasi titik ketinggian (0: Plunyon 850m, 1: Kaliadem 1170m, 2: Museum 980m)
    final p0 = Offset(0, height * 0.78);
    final p1 = Offset(width * 0.55, height * 0.25);
    final p2 = Offset(width, height * 0.45);

    final path = Path();
    path.moveTo(p0.dx, p0.dy);
    path.quadraticBezierTo(width * 0.25, height * 0.65, p1.dx, p1.dy);
    path.quadraticBezierTo(width * 0.78, height * 0.20, p2.dx, p2.dy);

    // Gradient fill di bawah kurva
    final fillPath = Path.from(path);
    fillPath.lineTo(width, height);
    fillPath.lineTo(0, height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.primaryContainer.withAlpha(80),
          AppColors.primaryContainer.withAlpha(0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke garis elevasi
    final strokePaint = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, strokePaint);

    // Waypoint dots
    final dotPaintFill = Paint()..color = Colors.white;
    final dotPaintStroke = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final dotPoints = [p0, p1, p2];
    for (final pt in dotPoints) {
      canvas.drawCircle(pt, 4.5, dotPaintFill);
      canvas.drawCircle(pt, 4.5, dotPaintStroke);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
