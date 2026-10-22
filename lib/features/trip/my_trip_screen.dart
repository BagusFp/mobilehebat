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
import '../../data/mock/mock_destinations.dart';
import '../auth/auth_provider.dart';
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
  String _selectedCurrency = 'IDR';
  String _selectedTimezone = 'WIB (GMT+7)';
  int _selectedTimelineIndex = 0;

  String _getTimelineItemImageUrl(TripItemModel item, TripModel trip) {
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return item.imageUrl!;
    }
    try {
      if (item.destinationId != null) {
        final match = MockDestinations.destinations.firstWhere(
          (d) => d.id == item.destinationId,
          orElse: () => MockDestinations.destinations.first,
        );
        if (match.imageUrl != null && match.imageUrl!.isNotEmpty) {
          return match.imageUrl!;
        }
      }
      final cleanName = item.itemName.toLowerCase().trim();
      final matchByName = MockDestinations.destinations.firstWhere(
        (d) =>
            d.name.toLowerCase().contains(cleanName) ||
            cleanName.contains(d.name.toLowerCase()),
        orElse: () => MockDestinations.destinations.first,
      );
      if (matchByName.imageUrl != null && matchByName.imageUrl!.isNotEmpty) {
        return matchByName.imageUrl!;
      }
    } catch (_) {}
    return trip.bannerImageUrl ??
        'https://lh3.googleusercontent.com/aida-public/AB6AXuCwXWD1ehYGmjCp_tx9aHTlZ8jRBa3kBFwla81OgBF70OA_aTU48L3L1uWDxVKLOeOibal32sVtkWDwCjMGF8itjKr-NQN1L86Ee1mYoQwDS-J7cI5ZKVOVXKZ0Xc4FNEYAOodZRXRzOBzJxFqXOJ01UXhwtJqgj6WDkkS3RVXWzd2wa6g9UVa80DlrCKLRbVlgTZnEFnH0cSPkq-wv1H5RkhBThijYlO7htbYniIv84-mxlC7wZ7w';
  }

  double _getExchangeRate(String cur) {
    switch (cur) {
      case 'USD':
        return 15873.0;
      case 'EUR':
        return 17200.0;
      case 'SGD':
        return 11850.0;
      case 'JPY':
        return 105.0;
      case 'MYR':
        return 3580.0;
      case 'IDR':
      default:
        return 1.0;
    }
  }

  String _formatConvertedCurrency(double idrAmount, String cur) {
    final targetCur = cur == 'IDR' ? 'USD' : cur;
    final rate = _getExchangeRate(targetCur);
    final converted = idrAmount / rate;
    final symbol = _getCurrencySymbol(targetCur);
    if (targetCur == 'JPY') {
      return '$symbol${converted.toStringAsFixed(0)}';
    }
    return '$symbol${converted.toStringAsFixed(2)}';
  }

  String _formatTimeWithTimezone(String plannedTime, int defaultHour, int defaultMinute) {
    int hour = defaultHour;
    int minute = defaultMinute;
    if (plannedTime.isNotEmpty) {
      final clean = plannedTime.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = clean.split(':');
      if (parts.length >= 2) {
        hour = int.tryParse(parts[0]) ?? defaultHour;
        minute = int.tryParse(parts[1]) ?? defaultMinute;
      }
    }

    int offset = 0;
    String tzCode = 'WIB';
    if (_selectedTimezone.startsWith('WITA')) {
      offset = 1;
      tzCode = 'WITA';
    } else if (_selectedTimezone.startsWith('WIT')) {
      offset = 2;
      tzCode = 'WIT';
    } else if (_selectedTimezone.startsWith('UTC')) {
      offset = -7;
      tzCode = 'UTC';
    } else if (_selectedTimezone.startsWith('JST')) {
      offset = 2;
      tzCode = 'JST';
    } else if (_selectedTimezone.startsWith('SGT')) {
      offset = 1;
      tzCode = 'SGT';
    }

    int adjustedHour = (hour + offset) % 24;
    if (adjustedHour < 0) adjustedHour += 24;
    final hourStr = adjustedHour.toString().padLeft(2, '0');
    final minStr = minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr $tzCode';
  }

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
      backgroundColor: const Color(0xFFF8FAFC),
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
                const SizedBox(height: 12),
                // 1. Judul Halaman & Tombol + + Trip Baru
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DASHBOARD PERJALANAN',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'My Trip',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              fontSize: 22,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              tripProvider.initBuilderTrip(empty: false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF045E44),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF045E44).withAlpha(40),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.add, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '+ Trip Baru',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
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
                // 3. Segmented Tabs Filter: Mendatang, Draft, Selesai
                _buildSegmentedTabs(
                  tripProvider,
                  upcomingCount: upcomingTrips.length,
                  draftCount: draftTrips.length,
                  completedCount: completedTrips.length,
                ),

                // 4. Tab Body Content
                if (tripProvider.activeTab == 'upcoming') ...[
                  if (activeTrip != null) ...[
                    // Card 1: PILIH TRIP AKTIF
                    _buildActiveTripSelectorCard(context, activeTrip, upcomingTrips, draftTrips, tripProvider),
                    // Card 2: Merapi Hero Image Card (mengikuti rute timeline yang aktif)
                    _buildActiveTripHeroCard(
                      context,
                      activeTrip,
                      tripProvider,
                      activeTrip.items.isNotEmpty
                          ? activeTrip.items
                          : const [
                              TripItemModel(
                                tripId: 1,
                                visitOrder: 1,
                                itemName: 'Museum Sisa Hartaku',
                                itemSubtitle: 'Kunjungan Memoar Erupsi',
                                estimatedCost: 20000,
                                plannedTime: '07:30',
                                notes: 'Kunjungan Memoar Erupsi',
                              ),
                              TripItemModel(
                                tripId: 1,
                                visitOrder: 2,
                                itemName: 'Bunker Kaliadem',
                                itemSubtitle: 'Spot Panorama Puncak Merapi',
                                estimatedCost: 20000,
                                plannedTime: '09:15',
                                notes: 'Spot Panorama Puncak Merapi',
                              ),
                            ],
                    ),
                    // Card 3: KONVERSI AKSES CEPAT
                    _buildQuickConversionCard(context),
                    // Card 4: ESTIMASI & BUDGET
                    _buildEstimasiBudgetCard(activeTrip),
                    // Card 5: TIMELINE RUTE
                    _buildTimelineRuteCard(
                      activeTrip,
                      activeTrip.items.isNotEmpty
                          ? activeTrip.items
                          : const [
                              TripItemModel(
                                tripId: 1,
                                visitOrder: 1,
                                itemName: 'Museum Sisa Hartaku',
                                itemSubtitle: 'Kunjungan Memoar Erupsi',
                                estimatedCost: 20000,
                                plannedTime: '07:30',
                                notes: 'Kunjungan Memoar Erupsi',
                              ),
                              TripItemModel(
                                tripId: 1,
                                visitOrder: 2,
                                itemName: 'Bunker Kaliadem',
                                itemSubtitle: 'Spot Panorama Puncak Merapi',
                                estimatedCost: 20000,
                                plannedTime: '09:15',
                                notes: 'Spot Panorama Puncak Merapi',
                              ),
                            ],
                    ),
                  ] else ...[
                    _buildEmptyUpcomingState(context),
                  ],
                ] else if (tripProvider.activeTab == 'draft') ...[
                  _buildDraftTabList(context, draftTrips, tripProvider, user?.id ?? (draftTrips.isNotEmpty ? draftTrips.first.userId : 1)),
                ] else ...[
                  _buildCompletedTabContent(context, completedTrips, tripProvider),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. Segmented Tabs Filter
  Widget _buildSegmentedTabs(
    TripProvider provider, {
    required int upcomingCount,
    required int draftCount,
    required int completedCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildTabButton(
              title: 'Mendatang ($upcomingCount)',
              isSelected: provider.activeTab == 'upcoming',
              onTap: () => provider.setActiveTab('upcoming'),
            ),
            _buildTabButton(
              title: 'Draft ($draftCount)',
              isSelected: provider.activeTab == 'draft',
              onTap: () => provider.setActiveTab('draft'),
            ),
            _buildTabButton(
              title: 'Selesai ($completedCount)',
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
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF045E44) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTripShortDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final m = dt.month >= 1 && dt.month <= 12 ? months[dt.month - 1] : 'Okt';
      return '${dt.day} $m';
    } catch (_) {
      return '25 Okt';
    }
  }

  String _formatTripFullDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final m = dt.month >= 1 && dt.month <= 12 ? months[dt.month - 1] : 'Okt';
      return '${dt.day} $m ${dt.year}';
    } catch (_) {
      return '25 Okt 2026';
    }
  }

  String _getCurrencySymbol(String cur) {
    switch (cur) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'SGD':
        return 'S\$';
      case 'JPY':
        return '¥';
      case 'MYR':
        return 'RM';
      case 'IDR':
      default:
        return 'Rp';
    }
  }

  void _showSelectTripBottomSheet(
    BuildContext context,
    List<TripModel> upcomingTrips,
    List<TripModel> draftTrips,
    TripModel activeTrip,
    TripProvider tripProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: Color(0xFF059669),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Pilih Trip untuk Dimulai',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Pilih trip yang ingin Anda jalankan saat ini',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                Flexible(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shrinkWrap: true,
                    children: [
                      // Section Header Upcoming
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 4),
                        child: Row(
                          children: [
                            const Text(
                              'TRIP MENDATANG TERSEDIA',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${upcomingTrips.length}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...upcomingTrips.map((t) {
                        final isSelected = t.id == activeTrip.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF059669) : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.5 : 1,
                            ),
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
                                  Expanded(
                                    child: Text(
                                      t.tripName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? const Color(0xFF045E44) : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '✓ Aktif di Layar',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 12, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    t.startDate,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.people_outline, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${t.participantCount} Orang',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.place_outlined, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${t.items.length} Destinasi',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  if (!isSelected)
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Color(0xFF045E44)),
                                          foregroundColor: const Color(0xFF045E44),
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () {
                                          tripProvider.selectTrip(t);
                                          Navigator.pop(ctx);
                                        },
                                        child: const Text(
                                          'Pilih Aktif',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  if (!isSelected) const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF045E44),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                      label: Text(
                                        isSelected ? 'Mulai Trip Aktif Ini' : 'Mulai Trip Ini',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      onPressed: () {
                                        Navigator.pop(ctx);
                                        tripProvider.selectTrip(t);
                                        _handleStartTrip(context, t, tripProvider);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Draft trips if available
                      if (draftTrips.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, top: 4),
                          child: Row(
                            children: [
                              const Text(
                                'TRIP DRAFT (BISA DIAKTIFKAN)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD97706),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${draftTrips.length}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD97706),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ...draftTrips.map((draft) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        draft.tripName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF92400E),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Draft • ${draft.items.length} Destinasi',
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD97706),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () async {
                                    if (draft.id != null) {
                                      await tripProvider.updateTripStatus(draft.id!, 'upcoming');
                                      tripProvider.selectTrip(draft);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted) {
                                        _handleStartTrip(context, draft, tripProvider);
                                      }
                                    }
                                  },
                                  child: const Text('Aktifkan & Mulai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Button to create new trip
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF045E44),
                          side: const BorderSide(color: Color(0xFF045E44)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text(
                          '+ Buat Rencana Trip Baru',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          tripProvider.initBuilderTrip(empty: false);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Card 1: PILIH TRIP AKTIF
  Widget _buildActiveTripSelectorCard(
    BuildContext context,
    TripModel activeTrip,
    List<TripModel> upcomingTrips,
    List<TripModel> draftTrips,
    TripProvider tripProvider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.alt_route_rounded,
              color: Color(0xFF059669),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () {
                _showSelectTripBottomSheet(
                  context,
                  upcomingTrips,
                  draftTrips,
                  activeTrip,
                  tripProvider,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'PILIH TRIP AKTIF',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (upcomingTrips.length > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${upcomingTrips.length} Trip',
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${activeTrip.tripName} (${_formatTripShortDate(activeTrip.startDate)})',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF0F172A),
                        size: 18,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _handleStartTrip(context, activeTrip, tripProvider),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.play_arrow_rounded, color: Color(0xFF15803D), size: 14),
                  SizedBox(width: 2),
                  Text(
                    'Mulai',
                    style: TextStyle(
                      color: Color(0xFF15803D),
                      fontSize: 11,
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

  // Card 3: KONVERSI AKSES CEPAT
  Widget _buildQuickConversionCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF045E44),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF045E44).withAlpha(50),
            blurRadius: 8,
            offset: const Offset(0, 3),
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
                children: const [
                  Icon(Icons.tune, color: Color(0xFFA7F3D0), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'KONVERSI AKSES CEPAT',
                    style: TextStyle(
                      color: Color(0xFFA7F3D0),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF023829),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Auto-Convert',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Zona Waktu:',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF023829),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0D6E51)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTimezone,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF023829),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'WIB (GMT+7)', child: Text('WIB (GMT+7)')),
                            DropdownMenuItem(value: 'WITA (GMT+8)', child: Text('WITA (GMT+8)')),
                            DropdownMenuItem(value: 'WIT (GMT+9)', child: Text('WIT (GMT+9)')),
                            DropdownMenuItem(value: 'UTC (GMT+0)', child: Text('UTC (GMT+0)')),
                            DropdownMenuItem(value: 'JST (GMT+9)', child: Text('JST (GMT+9)')),
                            DropdownMenuItem(value: 'SGT (GMT+8)', child: Text('SGT (GMT+8)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedTimezone = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mata Uang:',
                      style: TextStyle(
                        color: Color(0xFFA7F3D0),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF023829),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF0D6E51)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF023829),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'IDR', child: Text('IDR (Rp)')),
                            DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                            DropdownMenuItem(value: 'SGD', child: Text('SGD (S\$)')),
                            DropdownMenuItem(value: 'JPY', child: Text('JPY (¥)')),
                            DropdownMenuItem(value: 'MYR', child: Text('MYR (RM)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCurrency = val;
                              });
                            }
                          },
                        ),
                      ),
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

  // Card 4: ESTIMASI & BUDGET
  Widget _buildEstimasiBudgetCard(TripModel trip) {
    final targetBudget = trip.targetBudget > 0 ? trip.targetBudget : 500000.0;
    double ticketCost = 0;
    for (final item in trip.items) {
      ticketCost += item.estimatedCost;
    }
    if (ticketCost == 0) ticketCost = 40000.0;
    final remaining = targetBudget - ticketCost;

    final targetConverted = _formatConvertedCurrency(targetBudget, _selectedCurrency);
    final ticketConverted = _formatConvertedCurrency(ticketCost, _selectedCurrency);
    final remainingConverted = _formatConvertedCurrency(remaining, _selectedCurrency);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
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
              Row(
                children: const [
                  Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1E293B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'ESTIMASI & BUDGET',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _selectedCurrency,
                  style: const TextStyle(
                    color: Color(0xFF059669),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Target Budget:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '${_formatCurrency(targetBudget)} ($targetConverted)',
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiket Wajib (${trip.participantCount} Pax):',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                '- ${_formatCurrency(ticketCost)} (-$ticketConverted)',
                style: const TextStyle(
                  color: Color(0xFFE11D48),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sisa Anggaran:',
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              Text(
                '${_formatCurrency(remaining)} ($remainingConverted)',
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 5: TIMELINE RUTE
  Widget _buildTimelineRuteCard(TripModel trip, List<TripItemModel> items) {
    final safeSelected = _selectedTimelineIndex.clamp(0, items.length - 1);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
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
              Row(
                children: const [
                  Icon(Icons.history_rounded, color: Color(0xFF1E293B), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'TIMELINE RUTE',
                    style: TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 12, color: Color(0xFF059669)),
                  const SizedBox(width: 4),
                  Text(
                    '${items.length} Destinasi (Ketuk untuk ganti foto)',
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            final isSelected = safeSelected == index;
            final timeDisplay = _formatTimeWithTimezone(
              item.plannedTime,
              index == 0 ? 7 : 9,
              index == 0 ? 30 : 15,
            );
            final noteDisplay = (item.notes != null && item.notes!.isNotEmpty)
                ? item.notes!
                : (index == 0 ? 'Kunjungan Memoar Erupsi' : 'Spot Panorama Puncak Merapi');

            return InkWell(
              onTap: () {
                setState(() {
                  _selectedTimelineIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0FDF4) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF86EFAC) : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 4),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF045E44) : const Color(0xFF059669),
                            shape: BoxShape.circle,
                            border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF045E44).withAlpha(100),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 2,
                            height: 38,
                            color: const Color(0xFF059669).withAlpha(150),
                          )
                        else
                          Container(
                            width: 2,
                            height: 14,
                            color: const Color(0xFF059669).withAlpha(150),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
                                    fontSize: 13,
                                    color: isSelected ? const Color(0xFF045E44) : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  margin: const EdgeInsets.only(left: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF045E44),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'Foto Aktif',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            noteDisplay,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFDCFCE7) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF86EFAC) : const Color(0xFFDCFCE7),
                        ),
                      ),
                      child: Text(
                        timeDisplay,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF045E44) : const Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Card 2: Merapi Destination Hero Image Card (mengikuti rute timeline yang aktif)
  Widget _buildActiveTripHeroCard(
    BuildContext context,
    TripModel trip,
    TripProvider tripProvider,
    List<TripItemModel> timelineItems,
  ) {
    final safeIndex = _selectedTimelineIndex.clamp(0, timelineItems.length - 1);
    final currentStop = timelineItems[safeIndex];
    final heroImageUrl = _getTimelineItemImageUrl(currentStop, trip);

    return InkWell(
      onTap: () => _handleStartTrip(context, trip, tripProvider),
      onLongPress: () => _showTripMenuSheet(context, trip),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 185,
        margin: const EdgeInsets.symmetric(
          horizontal: AppDimensions.margin,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Image.network(
                  heroImageUrl,
                  key: ValueKey<String>(heroImageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF334155),
                    child: const Icon(Icons.terrain_rounded, size: 48, color: Colors.white54),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(45),
                      Colors.black.withAlpha(200),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C288),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'TERKONFIRMASI',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(120),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.calendar_today, size: 10, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _formatTripFullDate(trip.startDate),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF045E44).withAlpha(225),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF6EE7B7).withAlpha(150)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 10, color: Color(0xFF6EE7B7)),
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 130),
                                child: Text(
                                  currentStop.itemName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                trip.tripName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${trip.participantCount} Peserta Wisatawan • Rute: ${currentStop.itemName}',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(230),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Cuaca Diprediksi',
                              style: TextStyle(
                                color: Color(0xFF6EE7B7),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.wb_sunny_rounded, color: Color(0xFFFBBF24), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Cerah 26°C',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${drafts.length} Draft Belum Selesai',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Text(
                'Tersimpan Otomatis',
                style: TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ...drafts.map((draft) {
          return _buildDraftCard(
            context,
            draft,
            tripProvider,
            userId,
          );
        }),
      ],
    );
  }

  Widget _buildDraftCard(
    BuildContext context,
    TripModel draft,
    TripProvider tripProvider,
    int userId,
  ) {
    final targetBudgetK = draft.targetBudget > 0
        ? (draft.targetBudget >= 1000 ? 'Rp ${(draft.targetBudget / 1000).toStringAsFixed(0)}k' : _formatCurrency(draft.targetBudget))
        : 'Rp 300k';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
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
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  draft.bannerImageUrl ??
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuAPCRJJgh8Rcxr67OUIBH0lTkBEjznYjV4dRG5FgHsyOkFAhrLdHE1wBAIXN3blB_0TSNHKVyKtZtLIFFJt8277BtD0ks8ED9PzBx9SXFgFt3jBWChmkm8uOCyZEr-Za1g-7k0Kf6oBpQhN5yO0mPcFO0P9mfeYovAYB9NngDAPmbdPG16QZGbdrhjEWVp_0C0G-8ZWCS0S3UFjvckAn-KVl5TQqS7Yl3ZlBbS98WpVL3OHNQ2Px1Q',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFFF1F5F9),
                    child: const Icon(Icons.coffee, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Langkah 2/3',
                            style: TextStyle(
                              color: Color(0xFFD97706),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Text(
                          ' • Kemarin',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.tripName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: const [
                        Icon(Icons.location_on, size: 12, color: Color(0xFF059669)),
                        SizedBox(width: 2),
                        Text(
                          'Kopi Merapi',
                          style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFCBD5E1), size: 20),
                onPressed: () {
                  if (draft.id != null) {
                    tripProvider.deleteTrip(draft.id!, userId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Draft trip berhasil dihapus.')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target: $targetBudgetK',
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () async {
                      if (draft.id != null) {
                        await tripProvider.updateTripStatus(draft.id!, 'upcoming');
                        tripProvider.setActiveTab('upcoming');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Draft berhasil diaktifkan menjadi Trip Mendatang!'),
                            ),
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8FDF3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Jadwalkan',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      tripProvider.initBuilderTrip(existingTrip: draft);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateTripScreen(existingTrip: draft),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF045E44),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Lanjutkan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
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
