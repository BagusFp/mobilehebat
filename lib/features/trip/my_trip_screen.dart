import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../auth/auth_provider.dart';
import '../map/map_screen.dart';
import '../utility/currency_time_screen.dart';
import '../utility/utility_provider.dart';
import 'active_trip_screen.dart';
import 'create_trip_screen.dart';
import 'trip_provider.dart';

class MyTripScreen extends StatefulWidget {
  const MyTripScreen({super.key});

  @override
  State<MyTripScreen> createState() => _MyTripScreenState();
}

class _MyTripScreenState extends State<MyTripScreen> {
  String _selectedCurrency = 'USD';
  DateTime? _customCompareDateTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.id != null) {
        context.read<TripProvider>().loadUserTrips(auth.currentUser!.id);
      } else if (context.read<TripProvider>().allTrips.isEmpty) {
        context.read<TripProvider>().loadUserTrips(1);
      }
      final util = Provider.of<UtilityProvider?>(context, listen: false);
      if (util != null && !util.hasRates && !util.isLoading) {
        util.init();
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

  Widget _buildConfirmRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.secondary),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110, minWidth: 60),
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
              Expanded(child: Text('Itinerary Kosong')),
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
              Expanded(child: Text('Mulai Perjalanan?')),
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
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
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
                  leading: const Icon(Icons.check_circle_outline, color: AppColors.secondary),
                  title: Text('Tandai Selesai', style: AppTypography.bodyMd),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (trip.id != null) {
                      await tripProvider.finishActiveTrip(trip.id!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perjalanan telah selesai dan dipindahkan ke tab Selesai.')),
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drafts_outlined, color: AppColors.onSurfaceVariant),
                  title: Text('Pindahkan ke Draft', style: AppTypography.bodyMd),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (trip.id != null) {
                      await tripProvider.updateTripStatus(trip.id!, 'draft');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Perjalanan dipindahkan ke tab Draft.')),
                        );
                      }
                    }
                  },
                ),
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
                    _showShareRouteSheet(context, trip);
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
          ),
        );
      },
    );
  }

  String _generateTripShareLink(TripModel trip) {
    final tripId = trip.id != null ? '${trip.id}' : 'shared';
    final safeName = Uri.encodeComponent(trip.tripName.trim());
    return 'https://meratrip.id/itinerary/$tripId?name=$safeName';
  }

  String _generateGoogleMapsRouteUrl(TripModel trip) {
    if (trip.items.isEmpty) {
      final query = Uri.encodeComponent(trip.destinationCity ?? 'Kawasan Wisata Merapi, Sleman, Yogyakarta');
      return 'https://www.google.com/maps/search/?api=1&query=$query';
    }

    final stopNames = trip.items
        .map((i) => i.itemName.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    if (stopNames.isEmpty) {
      final query = Uri.encodeComponent(trip.destinationCity ?? 'Kawasan Wisata Merapi, Sleman, Yogyakarta');
      return 'https://www.google.com/maps/search/?api=1&query=$query';
    }

    if (stopNames.length == 1) {
      return 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(stopNames.first)}';
    }

    final origin = Uri.encodeComponent(stopNames.first);
    final destination = Uri.encodeComponent(stopNames.last);
    final waypointsList = stopNames.sublist(1, stopNames.length - 1);
    final waypointsParam = waypointsList.isNotEmpty
        ? '&waypoints=${waypointsList.map(Uri.encodeComponent).join('|')}'
        : '';

    return 'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination$waypointsParam';
  }

  String _generateFullShareText(TripModel trip) {
    final itineraryLink = _generateTripShareLink(trip);
    final mapsUrl = _generateGoogleMapsRouteUrl(trip);

    final buffer = StringBuffer();
    buffer.writeln('🧭 *Rencana Perjalanan: ${trip.tripName}*');
    buffer.writeln('📅 Tanggal: ${trip.startDate}');
    buffer.writeln('👥 Peserta: ${trip.participantCount} Orang');
    if (trip.items.isNotEmpty) {
      buffer.writeln('\n📍 *Rute Destinasi (${trip.items.length}):*');
      for (int i = 0; i < trip.items.length; i++) {
        final item = trip.items[i];
        final time = item.plannedTime.isNotEmpty ? ' (${item.plannedTime})' : '';
        buffer.writeln('${i + 1}. ${item.itemName}$time');
      }
    }
    buffer.writeln('\n🔗 *Tautan Rencana Perjalanan (Itinerary):*');
    buffer.writeln(itineraryLink);
    buffer.writeln('\n🗺️ *Tautan Rute di Google Maps:*');
    buffer.writeln(mapsUrl);
    buffer.writeln('\n_Dibuat dengan aplikasi MeraTrip_');
    return buffer.toString().trim();
  }

  void _showShareRouteSheet(BuildContext context, TripModel trip) {
    final itineraryLink = _generateTripShareLink(trip);
    final mapsUrl = _generateGoogleMapsRouteUrl(trip);
    final fullShareText = _generateFullShareText(trip);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: AppDimensions.margin,
              right: AppDimensions.margin,
              top: AppDimensions.spaceMd,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppDimensions.spaceMd,
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.share_rounded, color: AppColors.onPrimary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bagikan Rute Perjalanan',
                              style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${trip.tripName} • ${trip.startDate}',
                              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Ringkasan Urutan Rute Destinasi
                  if (trip.items.isNotEmpty) ...[
                    Text(
                      'Rute Destinasi (${trip.items.length})',
                      style: AppTypography.titleSm.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
                      ),
                      child: Column(
                        children: trip.items.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final isLast = idx == trip.items.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 11,
                                  backgroundColor: AppColors.primary,
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.itemName,
                                    style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (item.plannedTime.isNotEmpty)
                                  Text(
                                    item.plannedTime,
                                    style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                                  ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spaceMd),
                  ],

                  // Tautan Rencana Perjalanan (Itinerary)
                  Text(
                    'Tautan Rencana Perjalanan (Itinerary)',
                    style: AppTypography.titleSm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            itineraryLink,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Salin Tautan',
                          icon: const Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: itineraryLink));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tautan itinerary berhasil disalin!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // Tautan Rute Google Maps
                  Text(
                    'Tautan Rute Navigasi Google Maps',
                    style: AppTypography.titleSm.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outlineVariant.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.map_outlined, color: AppColors.secondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mapsUrl,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.secondary,
                              decoration: TextDecoration.underline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Buka di Google Maps',
                          icon: const Icon(Icons.open_in_new_rounded, color: AppColors.secondary, size: 20),
                          onPressed: () async {
                            final uri = Uri.parse(mapsUrl);
                            try {
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tidak dapat membuka peta.')),
                                  );
                                }
                              }
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Gagal membuka tautan peta.')),
                                );
                              }
                            }
                          },
                        ),
                        IconButton(
                          tooltip: 'Salin Rute Maps',
                          icon: const Icon(Icons.copy_rounded, color: AppColors.secondary, size: 20),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: mapsUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Tautan rute Google Maps berhasil disalin!')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceLg),

                  // Tombol Salin Seluruh Ringkasan & Tautan
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.copy_all_rounded, size: 20),
                      label: const Text(
                        'Salin Semua Info & Tautan Rute',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fullShareText));
                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tautan dan rute "${trip.tripName}" berhasil disalin ke papan klip!'),
                          ),
                        );
                      },
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
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    // Upcoming trip hero: ambil trip aktif atau trip pertama dengan status upcoming/active
    final rawUpcomingTrips = tripProvider.allTrips.where((t) => t.status == 'upcoming' || t.status == 'active').toList();
    rawUpcomingTrips.sort((a, b) {
      if (a.status == 'active' && b.status != 'active') return -1;
      if (a.status != 'active' && b.status == 'active') return 1;
      return 0;
    });
    // Deduplikasi berdasarkan nama trip untuk mencegah chip ganda di filter bar
    final seenUpcomingNames = <String>{};
    final upcomingTrips = <TripModel>[];
    for (final t in rawUpcomingTrips) {
      final key = t.tripName.trim().toLowerCase();
      if (key.isNotEmpty && seenUpcomingNames.contains(key)) continue;
      if (key.isNotEmpty) seenUpcomingNames.add(key);
      upcomingTrips.add(t);
    }
    final activeTrip = tripProvider.selectedTrip != null && upcomingTrips.any((t) => t.id == tripProvider.selectedTrip!.id)
        ? tripProvider.selectedTrip
        : (upcomingTrips.isNotEmpty ? upcomingTrips.first : null);

    // Draft trips (pastikan bersih dari duplikasi jika ada data ganda di SQLite)
    final rawDraftTrips = tripProvider.allTrips.where((t) => t.status == 'draft').toList();
    final seenDraftNames = <String>{};
    final draftTrips = <TripModel>[];
    for (final d in rawDraftTrips) {
      final key = d.tripName.trim().toLowerCase();
      if (key.isNotEmpty && seenDraftNames.contains(key)) continue;
      if (key.isNotEmpty) seenDraftNames.add(key);
      draftTrips.add(d);
    }
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
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelMd.copyWith(
                    color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
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
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 2,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.calendar_today, size: 14, color: AppColors.secondary),
                                    const SizedBox(width: 4),
                                    Text(
                                      trip.startDate,
                                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
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
                              Expanded(
                                child: Row(
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Mulai Dalam',
                                            style: AppTypography.labelSm.copyWith(
                                              color: Colors.white70,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '14 Jam 25 Menit',
                                            style: AppTypography.labelMd.copyWith(
                                              color: Colors.white,
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
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(50),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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

                  // Utility Actions Row (Reminder & Finish)
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
                            side: const BorderSide(
                              color: AppColors.outlineVariant,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          ),
                          onPressed: () async {
                            if (trip.id == null) return;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                                ),
                                title: Row(
                                  children: const [
                                    Icon(Icons.check_circle_outline, color: AppColors.secondary),
                                    SizedBox(width: 8),
                                    Expanded(child: Text('Tandai Selesai?')),
                                  ],
                                ),
                                content: Text(
                                  'Apakah Anda ingin menandai trip "${trip.tripName}" ini selesai dan memindahkannya ke tab Selesai?',
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
                                    child: const Text('Ya, Selesai'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              await tripProvider.finishActiveTrip(trip.id!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Trip telah ditandai selesai dan dipindahkan ke tab Selesai.'),
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(
                            Icons.task_alt,
                            size: 16,
                            color: AppColors.secondary,
                          ),
                          label: Text(
                            'Tandai Selesai',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
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
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.route, color: AppColors.primary, size: 20),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Timeline Rencana Perjalanan',
                                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
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

                  // Currency Conversion Preview Section
                  _buildCurrencyEstimationSection(context, trip, mandatoryTotal, remainingBudget),

                  const SizedBox(height: AppDimensions.spaceMd),

                  // Travel Timezone Comparison Section
                  _buildTripTimeSection(context, trip, items),

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
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        item.estimatedCost > 0 ? Icons.confirmation_number : Icons.favorite,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          item.estimatedCost > 0
                                              ? 'Tiket ${_formatCurrency(item.estimatedCost / 2)} / org'
                                              : 'Donasi Sukarela (~Rp 10.000)',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Estimasi Anggaran Trip',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Sisa Anggaran Kuliner',
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _formatCurrency(remaining),
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'Tersedia aman',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Currency Conversion Preview Section
  Widget _buildCurrencyEstimationSection(
    BuildContext context,
    TripModel trip,
    double mandatoryTotal,
    double remainingBudget,
  ) {
    final util = Provider.of<UtilityProvider?>(context) ?? UtilityProvider(autoInit: false);
    final double actualCost = trip.totalActualCost > 0 ? trip.totalActualCost : mandatoryTotal;

    // Convert values to selected currency
    final convertedTarget = util.convertFromIdr(trip.targetBudget, _selectedCurrency);
    final convertedActual = util.convertFromIdr(actualCost, _selectedCurrency);
    final convertedRemaining = util.convertFromIdr(remainingBudget, _selectedCurrency);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.currency_exchange, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Konversi Mata Uang',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CurrencyTimeScreen(initialTab: 'currency'),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Kalkulator',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Status & Refresh Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        util.isUsingCachedRates ? Icons.cloud_done : Icons.cloud_outlined,
                        size: 15,
                        color: util.isUsingCachedRates ? AppColors.secondary : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Kurs Frankfurter (${util.formattedApiDate})',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: util.isSyncing
                      ? null
                      : () async {
                          final success = await util.syncRates();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success
                                      ? 'Kurs berhasil diperbarui dari Frankfurter API (${util.formattedApiDate}).'
                                      : (util.errorMessage ?? 'Gagal memperbarui kurs.'),
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: util.isSyncing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : Row(
                            children: [
                              const Icon(Icons.sync, size: 14, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'Perbarui',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),

          if (util.errorMessage != null && !util.hasRates) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      util.errorMessage!,
                      style: AppTypography.bodySm.copyWith(color: AppColors.error, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Currency Selector Tabs (IDR, USD, EUR, JPY)
          Row(
            children: ['IDR', 'USD', 'EUR', 'JPY'].map((code) {
              final isSelected = _selectedCurrency == code;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCurrency = code;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        code,
                        style: AppTypography.labelSm.copyWith(
                          color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // 3 Metric Boxes: Anggaran, Pengeluaran, Sisa
          Row(
            children: [
              Expanded(
                child: _buildCurrencyMetricCard(
                  title: 'Anggaran Target',
                  idrValue: _formatCurrency(trip.targetBudget),
                  convertedValue: util.hasRates || _selectedCurrency == 'IDR'
                      ? util.formatCurrency(convertedTarget, _selectedCurrency)
                      : '-',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCurrencyMetricCard(
                  title: 'Pengeluaran/Wajib',
                  idrValue: _formatCurrency(actualCost),
                  convertedValue: util.hasRates || _selectedCurrency == 'IDR'
                      ? util.formatCurrency(convertedActual, _selectedCurrency)
                      : '-',
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildCurrencyMetricCard(
                  title: 'Sisa Anggaran',
                  idrValue: _formatCurrency(remainingBudget),
                  convertedValue: util.hasRates || _selectedCurrency == 'IDR'
                      ? util.formatCurrency(convertedRemaining, _selectedCurrency)
                      : '-',
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Reference Footnote
          Text(
            '*Estimasi kurs referensi online (Frankfurter/ECB). Anggaran & pengeluaran asli tetap tersimpan dalam IDR.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyMetricCard({
    required String title,
    required String idrValue,
    required String convertedValue,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            convertedValue,
            style: AppTypography.labelMd.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            idrValue,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 9,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Travel Timezone Comparison Section
  Widget _buildTripTimeSection(
    BuildContext context,
    TripModel trip,
    List<TripItemModel> items,
  ) {
    final util = Provider.of<UtilityProvider?>(context) ?? UtilityProvider(autoInit: false);

    // Determine baseline trip datetime from itinerary
    DateTime baseDate;
    try {
      baseDate = DateTime.parse(trip.startDate);
    } catch (_) {
      baseDate = DateTime.now();
    }

    int baseHour = 8;
    int baseMinute = 0;
    String itineraryLabel = 'Jadwal Rencana Trip';

    if (items.isNotEmpty && items.first.plannedTime.isNotEmpty) {
      final raw = items.first.plannedTime.split('-').first.trim();
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0].trim());
        final m = int.tryParse(parts[1].trim());
        if (h != null && m != null) {
          baseHour = h;
          baseMinute = m;
          itineraryLabel = '${items.first.itemName} (${items.first.plannedTime})';
        }
      }
    }

    final originalTripDateTime = DateTime(baseDate.year, baseDate.month, baseDate.day, baseHour, baseMinute);
    final effectiveDateTime = _customCompareDateTime ?? originalTripDateTime;
    final comparisons = util.getPrimaryZoneComparisons(customDateTime: effectiveDateTime);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.secondary.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryFixedDim.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.schedule, color: AppColors.secondary, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Waktu Perjalanan',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CurrencyTimeScreen(initialTab: 'time'),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Konverter',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (trip.originCity != null && trip.originCity!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.secondary.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flight_takeoff_rounded, size: 14, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rute Perjalanan: ${trip.originCity} ➔ ${trip.destinationCity ?? "Gunung Merapi (WIB)"}',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Itinerary Time & Manual Picker Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _customCompareDateTime != null
                                  ? 'Waktu Uji Manual'
                                  : 'Itinerary: $itineraryLabel',
                              style: AppTypography.labelSm.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('dd MMM yyyy, HH:mm').format(effectiveDateTime)} WIB (Waktu Acuan Lokal)',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (_customCompareDateTime != null)
                      IconButton(
                        tooltip: 'Kembali ke jadwal asli itinerary',
                        icon: const Icon(Icons.undo, size: 16, color: AppColors.onSurfaceVariant),
                        onPressed: () {
                          setState(() {
                            _customCompareDateTime = null;
                          });
                        },
                      ),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: effectiveDateTime,
                          firstDate: DateTime(2024, 1, 1),
                          lastDate: DateTime(2030, 12, 31),
                        );
                        if (pickedDate == null || !context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(effectiveDateTime),
                        );
                        if (pickedTime != null && context.mounted) {
                          setState(() {
                            _customCompareDateTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.edit_calendar, size: 14, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Uji Waktu',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 4-Zone Comparison Cards (WIB, WITA, WIT, London)
          Row(
            children: comparisons.map((z) {
              final isWib = z.code == 'WIB';
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isWib
                        ? AppColors.primaryContainer.withAlpha(80)
                        : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: isWib ? Border.all(color: AppColors.primary.withAlpha(80)) : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            z.code,
                            style: AppTypography.labelSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isWib ? AppColors.primary : AppColors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          z.formattedTime,
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isWib ? AppColors.primary : AppColors.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Text(
                        z.timeZoneName,
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (z.dayDiff != 0)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            z.dayDiffBadge,
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 9,
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Footnote
          Text(
            '*Waktu lokal Gunung Merapi (WIB) adalah waktu acuan utama tur. Mengganti zona uji tidak mengubah jadwal itinerary asli.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
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
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.landscape, color: AppColors.primary, size: 20),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Kontur Elevasi Jalur',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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
                  children: [
                    Expanded(
                      child: Text(
                        'Plunyon (850 mdpl)',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                        textAlign: TextAlign.start,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Kaliadem (1.170 mdpl)',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Museum (980 mdpl)',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                        textAlign: TextAlign.end,
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

  // Draft Section Card (Shown on Mendatang Tab)
  Widget _buildDraftSection(
    BuildContext context,
    TripModel draftTrip,
    TripProvider tripProvider,
    int userId, {
    bool showHeader = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: AppDimensions.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.edit_note, color: AppColors.onSurfaceVariant, size: 20),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Rencana Tersimpan (Draft)',
                          style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '1 Draft Belum Selesai',
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () async {
                        if (draftTrip.id != null) {
                          await tripProvider.updateTripStatus(draftTrip.id!, 'upcoming');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Draft berhasil diaktifkan menjadi Trip Mendatang!'),
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.publish_rounded, size: 14, color: AppColors.primary),
                      label: Text(
                        'Jadwalkan',
                        style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
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
                          MaterialPageRoute(builder: (_) => CreateTripScreen(existingTrip: draftTrip)),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, size: 14),
                      label: Text('Lanjutkan Edit', style: AppTypography.labelMd),
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
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimary,
                ),
                onPressed: () {
                  tripProvider.initBuilderTrip();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Buat Draft Baru'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.margin,
            vertical: AppDimensions.spaceSm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: AppColors.onSurfaceVariant, size: 20),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Rencana Tersimpan (Draft)',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${drafts.length} Draft Belum Selesai',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        ...drafts.map((draft) {
          return _buildDraftSection(
            context,
            draft,
            tripProvider,
            userId,
            showHeader: false,
          );
        }),
      ],
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Pengeluaran', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatCurrency(totalCost),
                              style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Anggaran Awal', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          FittedBox(
                            alignment: Alignment.centerRight,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatCurrency(trip.targetBudget),
                              style: AppTypography.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                        label: Text('Ringkasan', style: AppTypography.labelSm),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onPressed: () async {
                          if (trip.id == null) return;
                          await tripProvider.updateTripStatus(trip.id!, 'upcoming');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Trip diaktifkan kembali ke tab Mendatang.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text('Aktifkan Lagi', style: AppTypography.labelSm),
                      ),
                    ),
                  ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceXl),
        child: Column(
          children: [
            const Icon(
              Icons.calendar_month,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Belum Ada Trip Mendatang',
              style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Buat rencana petualangan barumu di Lereng Merapi sekarang.',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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
