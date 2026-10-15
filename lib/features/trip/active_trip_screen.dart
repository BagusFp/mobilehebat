import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/mock/mock_destinations.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_expense_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../explore/destination_detail_screen.dart';
import '../explore/destination_provider.dart';
import '../map/map_screen.dart';
import 'trip_provider.dart';

class ActiveTripScreen extends StatefulWidget {
  final int tripId;

  const ActiveTripScreen({super.key, required this.tripId});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = context.read<TripProvider>();
      tripProvider.selectTripById(widget.tripId);
      if (context.read<DestinationProvider>().allDestinations.isEmpty) {
        context.read<DestinationProvider>().loadDestinations();
      }
    });
  }

  DestinationModel? _findDestination(int? destinationId, String itemName) {
    if (destinationId == null) return null;
    final destProvider = context.read<DestinationProvider>();
    try {
      return destProvider.allDestinations.firstWhere((d) => d.id == destinationId);
    } catch (_) {
      try {
        return MockDestinations.destinations.firstWhere((d) => d.id == destinationId);
      } catch (_) {
        return null;
      }
    }
  }

  Future<void> _openExternalMap(double lat, double lng, String label) async {
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      final canLaunch = await canLaunchUrl(googleMapsUrl);
      if (canLaunch) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi peta eksternal.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuka peta: $e')),
      );
    }
  }

  void _showRouteChoiceModal(BuildContext context, TripItemModel item) {
    final dest = _findDestination(item.destinationId, item.itemName);
    final lat = dest?.latitude ?? -7.5840;
    final lng = dest?.longitude ?? 110.4500;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Navigasi ke ${item.itemName}',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              dest != null
                  ? '${dest.address} • Ketinggian ${dest.elevationMdpl} mdpl'
                  : 'Kawasan Wisata Lereng Gunung Merapi',
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.map_rounded, color: AppColors.primary),
              ),
              title: const Text('Buka di Peta Interaktif MeraTrip', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Lihat rute mengemudi OSRM, zona KRB Merapi & elevasi'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapScreen(initialDestination: dest),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withAlpha(80),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car_rounded, color: AppColors.secondary),
              ),
              title: const Text('Buka di Google Maps', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Petunjuk arah giliran-demi-giliran (turn-by-turn navigation)'),
              onTap: () {
                Navigator.pop(ctx);
                _openExternalMap(lat, lng, item.itemName);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseModal(BuildContext context, TripModel trip, TripProvider tripProvider) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'Tiket Masuk';
    TripItemModel? selectedItem;

    final categories = [
      'Tiket Masuk',
      'Kuliner & Minuman',
      'Transportasi',
      'Parkir',
      'Souvenir / Belanja',
      'Lainnya',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Catat Pengeluaran Baru',
                          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Kategori Chips
                    Text('Kategori Biaya', style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSelected = selectedCategory == cat;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: isSelected,
                          selectedColor: AppColors.primaryContainer,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedCategory = cat;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Input Nominal
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nominal Biaya (Rp)',
                        hintText: 'Contoh: 25000',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Nominal wajib diisi';
                        }
                        final parsed = double.tryParse(val.replaceAll('.', '').replaceAll(',', ''));
                        if (parsed == null || parsed <= 0) {
                          return 'Masukkan nominal yang valid dan lebih dari 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Terkait Destinasi (Opsional)
                    if (trip.items.isNotEmpty) ...[
                      DropdownButtonFormField<TripItemModel?>(
                        initialValue: selectedItem,
                        decoration: InputDecoration(
                          labelText: 'Terkait Destinasi (Opsional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                        ),
                        items: [
                          const DropdownMenuItem<TripItemModel?>(
                            value: null,
                            child: Text('Umum / Tanpa Destinasi Spesifik'),
                          ),
                          ...trip.items.map((it) => DropdownMenuItem<TripItemModel?>(
                                value: it,
                                child: Text('${it.visitOrder}. ${it.itemName}', overflow: TextOverflow.ellipsis),
                              )),
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedItem = val;
                          });
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Catatan
                    TextFormField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan Tambahan (Opsional)',
                        hintText: 'Misal: Parkir motor & donasi museum',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Simpan Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final rawAmount = double.parse(
                              amountController.text.replaceAll('.', '').replaceAll(',', ''),
                            );

                            final newExpense = TripExpenseModel(
                              tripId: trip.id!,
                              userId: trip.userId,
                              destinationId: selectedItem?.destinationId,
                              destinationName: selectedItem?.itemName,
                              category: selectedCategory,
                              amount: rawAmount,
                              notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                              spentAt: DateTime.now().toIso8601String(),
                              createdAt: DateTime.now().toIso8601String(),
                            );

                            Navigator.pop(ctx);
                            await tripProvider.addExpense(newExpense);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Pengeluaran ${_currencyFormat.format(rawAmount)} berhasil dicatat!'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmFinishTrip(BuildContext context, TripModel trip, TripProvider tripProvider) {
    final unvisitedCount = trip.items.where((i) => !i.isCompleted).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.flag_rounded, color: AppColors.volcanoStatusWaspada, size: 28),
            SizedBox(width: 8),
            Text('Akhiri Perjalanan?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unvisitedCount > 0) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.volcanoStatusWaspada.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.volcanoStatusWaspada),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Perhatian: Masih ada $unvisitedCount destinasi yang belum Anda tandai selesai.',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Apakah Anda yakin ingin menyelesaikan petualangan rute "${trip.tripName}"? Status trip akan diubah menjadi Selesai dan total pengeluaran aktual akan disimpan.',
              style: AppTypography.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Lanjutkan Perjalanan'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await tripProvider.finishActiveTrip(trip.id!);
              if (context.mounted) {
                _showSummaryDialog(context, trip, tripProvider);
              }
            },
            child: const Text('Ya, Akhiri Sekarang'),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(BuildContext context, TripModel trip, TripProvider tripProvider) {
    final completedCount = tripProvider.activeTripCompletedCount;
    final totalCount = trip.items.length;
    final totalSpent = tripProvider.activeTripTotalExpenses;
    final targetBudget = trip.targetBudget;
    final balance = targetBudget - totalSpent;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Perjalanan Selesai!',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selamat! Anda telah menyelesaikan penjelajahan rute "${trip.tripName}".',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),

            // Kartu Ringkasan
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Destinasi Dikunjungi',
                    '$completedCount dari $totalCount Destinasi',
                    Icons.place_rounded,
                    AppColors.primary,
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    'Target Anggaran Awal',
                    _currencyFormat.format(targetBudget),
                    Icons.account_balance_wallet_outlined,
                    AppColors.onSurfaceVariant,
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    'Total Pengeluaran Aktual',
                    _currencyFormat.format(totalSpent),
                    Icons.receipt_long_rounded,
                    AppColors.primary,
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    balance >= 0 ? 'Sisa Anggaran Hemat' : 'Defisit Anggaran',
                    _currencyFormat.format(balance.abs()),
                    balance >= 0 ? Icons.savings_rounded : Icons.warning_rounded,
                    balance >= 0 ? AppColors.secondary : AppColors.error,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context); // Kembali ke My Trip
                },
                child: const Text('Kembali ke My Trip', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: AppTypography.labelMedium.copyWith(color: AppColors.onSurfaceVariant)),
        ),
        Text(value, style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final trip = tripProvider.selectedTrip;

    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perjalanan Aktif')),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final items = trip.items;
    final nextItem = tripProvider.nextDestination;
    final totalCount = items.length;
    final completedCount = tripProvider.activeTripCompletedCount;
    final progress = tripProvider.activeTripProgress;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.surfaceContainerLowest,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Perjalanan Aktif',
          style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSurface),
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Pengeluaran',
            icon: const Icon(Icons.add_card_rounded, color: AppColors.primary),
            onPressed: () => _showAddExpenseModal(context, trip, tripProvider),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Header Kartu Informasi Perjalanan & Progress
            _buildTripInfoCard(trip, completedCount, totalCount, progress),

            const SizedBox(height: 16),

            // B. Destinasi Berikutnya (Next Destination Card)
            if (nextItem != null)
              _buildNextDestinationCard(context, nextItem, tripProvider)
            else
              _buildAllCompletedCard(),

            const SizedBox(height: 20),

            // C. Daftar Seluruh Destinasi (Timeline & Checklist)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rencana Kunjungan Destinasi',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$completedCount/$totalCount Selesai',
                    style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _buildDestinationsTimeline(context, trip, items, tripProvider),

            const SizedBox(height: 24),

            // D. Ringkasan Anggaran & Pengeluaran Aktual
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pengeluaran & Anggaran Trip',
                    style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Catat Biaya'),
                    onPressed: () => _showAddExpenseModal(context, trip, tripProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildBudgetSummarySection(trip, tripProvider),

            const SizedBox(height: 16),
            _buildExpensesList(context, trip, tripProvider),
          ],
        ),
      ),

      // E. Tombol Sticky Bottom "Akhiri Perjalanan"
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.volcanoStatusWaspada,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const Icon(Icons.flag_rounded),
              label: const Text(
                'Akhiri Perjalanan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              onPressed: () => _confirmFinishTrip(context, trip, tripProvider),
            ),
          ),
        ),
      ),
    );
  }

  // A. Header Kartu Informasi Perjalanan & Progress
  Widget _buildTripInfoCard(TripModel trip, int completedCount, int totalCount, double progress) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.margin, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryContainer.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Perjalanan Sedang Aktif',
                      style: AppTypography.labelSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trip.startDate,
                style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            trip.tripName,
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.onSurface),
          ),
          const SizedBox(height: 14),

          // Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progres Kunjungan Destinasi',
                style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant),
              ),
              Text(
                '$completedCount dari $totalCount Selesai (${(progress * 100).toInt()}%)',
                style: AppTypography.labelSmall.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // B. Destinasi Berikutnya (Highlight Card)
  Widget _buildNextDestinationCard(BuildContext context, TripItemModel nextItem, TripProvider tripProvider) {
    final dest = _findDestination(nextItem.destinationId, nextItem.itemName);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withAlpha(120), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.near_me_rounded, size: 14, color: AppColors.secondary),
                    SizedBox(width: 4),
                    Text(
                      'Tujuan Berikutnya',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
              Text(
                nextItem.plannedTime,
                style: AppTypography.labelMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            nextItem.itemName,
            style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
          ),
          if (nextItem.itemSubtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              nextItem.itemSubtitle,
              style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
          if (dest != null && dest.categoryName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                dest.categoryName,
                style: AppTypography.labelSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${nextItem.durationHours} Jam Kunjungan', style: AppTypography.labelSmall),
              const SizedBox(width: 14),
              Icon(Icons.landscape_rounded, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${nextItem.elevationMdpl} mdpl', style: AppTypography.labelSmall),
            ],
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.directions_rounded, size: 20),
                  label: const Text('Lihat Rute', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _showRouteChoiceModal(context, nextItem),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await tripProvider.markDestinationCompleted(widget.tripId, nextItem.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kunjungan ke "${nextItem.itemName}" berhasil ditandai selesai!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Kartu saat seluruh destinasi sudah selesai
  Widget _buildAllCompletedCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withAlpha(60),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.done_all_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seluruh Destinasi Selesai!',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.onSecondaryContainer),
                ),
                const SizedBox(height: 2),
                Text(
                  'Semua tempat telah dikunjungi. Anda dapat meninjau pengeluaran atau mengakhiri perjalanan.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // C. Interactive Timeline & Checklist
  Widget _buildDestinationsTimeline(
    BuildContext context,
    TripModel trip,
    List<TripItemModel> items,
    TripProvider tripProvider,
  ) {
    if (items.isEmpty) {
      return const Center(child: Text('Tidak ada destinasi dalam trip ini'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      itemBuilder: (context, index) {
        final item = items[index];
        final isCompleted = item.isCompleted;
        final isNext = tripProvider.nextDestination?.id == item.id;
        final dest = _findDestination(item.destinationId, item.itemName);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCompleted
                ? AppColors.surfaceContainerLow.withAlpha(180)
                : (isNext ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLowest),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? Colors.transparent
                  : (isNext ? AppColors.primary : AppColors.outlineVariant),
              width: isNext ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge Urutan / Status Icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.secondary
                      : (isNext ? AppColors.primary : AppColors.surfaceContainerHighest),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 20)
                      : Text(
                          '${item.visitOrder}',
                          style: TextStyle(
                            color: isNext ? Colors.white : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Info Destinasi
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
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                              color: isCompleted ? AppColors.onSurfaceVariant : AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Selesai',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondary),
                            ),
                          )
                        else if (isNext)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Saat Ini',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.plannedTime} • Estimasi Tiket: ${_currencyFormat.format(item.estimatedCost)}',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Catatan: ${item.notes}',
                        style: AppTypography.labelSmall.copyWith(fontStyle: FontStyle.italic, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 10),

                    // Action buttons
                    Row(
                      children: [
                        if (dest != null)
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.info_outline, size: 16),
                            label: const Text('Detail Wisata', style: TextStyle(fontSize: 12)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DestinationDetailScreen(destination: dest),
                                ),
                              );
                            },
                          ),
                        const Spacer(),
                        if (!isCompleted)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isNext ? AppColors.primary : AppColors.surfaceContainerHigh,
                              foregroundColor: isNext ? Colors.white : AppColors.onSurface,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Sudah Dikunjungi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              await tripProvider.markDestinationCompleted(trip.id!, item.id!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('"${item.itemName}" ditandai selesai!'),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
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
    );
  }

  void _showEditTargetBudgetDialog(
    BuildContext context,
    TripModel trip,
    TripProvider tripProvider,
  ) {
    final controller = TextEditingController(
      text: trip.targetBudget.toInt().toString(),
    );
    final totalDestTickets =
        trip.items.fold<double>(0.0, (sum, it) => sum + it.estimatedCost);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Ubah Target Anggaran'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sesuaikan batas pagu anggaran untuk rute perjalanan ini:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Target Anggaran',
                border: OutlineInputBorder(),
              ),
            ),
            if (totalDestTickets > 0) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  controller.text = totalDestTickets.toInt().toString();
                },
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: Text(
                  'Samakan Biaya Destinasi (${_currencyFormat.format(totalDestTickets)})',
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final raw = double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), ''));
              if (raw != null && raw >= 0) {
                Navigator.pop(ctx);
                await tripProvider.updateTripTargetBudget(trip.id!, raw);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Target anggaran diubah menjadi ${_currencyFormat.format(raw)}'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // D. Ringkasan Anggaran
  Widget _buildBudgetSummarySection(TripModel trip, TripProvider tripProvider) {
    final target = trip.targetBudget;
    final totalSpent = tripProvider.activeTripTotalExpenses;
    final remaining = tripProvider.activeTripRemainingBudget;
    final isOverBudget = remaining < 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      child: Row(
        children: [
          Expanded(
            child: _buildMetricCard(
              'Target Awal',
              _currencyFormat.format(target),
              Icons.account_balance_wallet_rounded,
              AppColors.primary,
              onTap: () => _showEditTargetBudgetDialog(context, trip, tripProvider),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              'Aktual Biaya',
              _currencyFormat.format(totalSpent),
              Icons.receipt_long_rounded,
              AppColors.onSurface,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricCard(
              isOverBudget ? 'Defisit' : 'Sisa Budget',
              _currencyFormat.format(remaining.abs()),
              isOverBudget ? Icons.trending_down_rounded : Icons.savings_rounded,
              isOverBudget ? AppColors.error : AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: onTap != null
                  ? color.withAlpha(120)
                  : AppColors.outlineVariant.withAlpha(80),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, size: 18, color: color),
                  if (onTap != null)
                    Icon(Icons.edit_outlined, size: 12, color: color.withAlpha(180)),
                ],
              ),
              const SizedBox(height: 6),
              Text(label, style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.labelLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpensesList(BuildContext context, TripModel trip, TripProvider tripProvider) {
    final expenses = tripProvider.activeTripExpenses;

    if (expenses.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_outlined, size: 36, color: AppColors.onSurfaceVariant.withAlpha(120)),
              const SizedBox(height: 8),
              Text(
                'Belum ada pengeluaran tercatat',
                style: AppTypography.labelLarge.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                'Tekan tombol "Catat Biaya" saat membeli tiket, makanan, atau bahan bakar.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      child: Column(
        children: expenses.map((exp) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outlineVariant.withAlpha(60)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(exp.category),
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.category, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if (exp.destinationName != null)
                        Text('Terkait: ${exp.destinationName}', style: AppTypography.labelSmall.copyWith(color: AppColors.primary))
                      else if (exp.notes != null)
                        Text(exp.notes!, style: AppTypography.labelSmall.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(exp.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                    ),
                    InkWell(
                      onTap: () async {
                        if (exp.id != null) {
                          await tripProvider.removeExpense(exp.id!, trip.id!);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Hapus',
                          style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
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

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Tiket Masuk':
        return Icons.confirmation_number_rounded;
      case 'Kuliner & Minuman':
        return Icons.restaurant_rounded;
      case 'Transportasi':
        return Icons.directions_bus_rounded;
      case 'Parkir':
        return Icons.local_parking_rounded;
      case 'Souvenir / Belanja':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.attach_money_rounded;
    }
  }
}
