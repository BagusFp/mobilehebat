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
  int _currentStep = 1; // Mulai urut dari langkah 1 (Informasi & Peserta)
  late TextEditingController _tripNameController;

  @override
  void initState() {
    super.initState();
    _tripNameController = TextEditingController(text: 'Eksplorasi Merapi 1 Hari');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = context.read<TripProvider>();
      if (widget.existingTrip != null) {
        tripProvider.initBuilderTrip(existingTrip: widget.existingTrip);
        _tripNameController.text = widget.existingTrip!.tripName;
      } else if (widget.initialDestination != null) {
        tripProvider.initBuilderWithDestination(widget.initialDestination!);
        _tripNameController.text = 'Wisata ${widget.initialDestination!.name}';
      } else {
        tripProvider.initBuilderTrip();
        if (tripProvider.builderTrip != null) {
          _tripNameController.text = tripProvider.builderTrip!.tripName;
        }
      }
    });
  }

  @override
  void dispose() {
    _tripNameController.dispose();
    super.dispose();
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 1:
        return 'Informasi & Peserta';
      case 2:
        return 'Pilih & Atur Destinasi';
      case 3:
        return 'Atur Jadwal & Waktu';
      case 4:
        return 'Rincian & Pagu Budget';
      default:
        return '';
    }
  }

  void _showEditTimeDialog(
    BuildContext context,
    int index,
    TripItemModel item,
    TripProvider tripProvider,
  ) {
    final controller = TextEditingController(text: item.plannedTime);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.access_time_filled, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Waktu di ${item.itemName}',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Format rentang waktu kunjungan (WIB):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Rentang Jam',
                hintText: 'Contoh: 08:00 - 09:30',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text('07:00 - 08:30', style: TextStyle(fontSize: 11)),
                  onPressed: () => controller.text = '07:00 - 08:30',
                ),
                ActionChip(
                  label: const Text('09:00 - 10:30', style: TextStyle(fontSize: 11)),
                  onPressed: () => controller.text = '09:00 - 10:30',
                ),
                ActionChip(
                  label: const Text('11:00 - 12:30', style: TextStyle(fontSize: 11)),
                  onPressed: () => controller.text = '11:00 - 12:30',
                ),
                ActionChip(
                  label: const Text('13:30 - 15:00', style: TextStyle(fontSize: 11)),
                  onPressed: () => controller.text = '13:30 - 15:00',
                ),
              ],
            ),
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
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                tripProvider.updateBuilderItemSchedule(
                  index,
                  plannedTime: controller.text.trim(),
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context, TripProvider tripProvider) {
    final controller = TextEditingController(
      text: tripProvider.targetBudget.toInt().toString(),
    );
    final mandatoryCost = tripProvider.totalMandatoryCost;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.account_balance_wallet, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Atur Target Budget'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan total pagu anggaran yang ingin Anda siapkan untuk trip ini:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                prefixText: 'Rp ',
                labelText: 'Jumlah Anggaran',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                controller.text = mandatoryCost.toInt().toString();
              },
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: Text(
                'Gunakan Biaya Destinasi (${_formatCurrency(mandatoryCost)})',
                style: const TextStyle(fontSize: 11),
              ),
            ),
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
            onPressed: () {
              final parsed = double.tryParse(controller.text.replaceAll(RegExp(r'[^0-9]'), ''));
              if (parsed != null && parsed >= 0) {
                tripProvider.setBuilderTargetBudget(parsed);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Terapkan'),
          ),
        ],
      ),
    );
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
                            'LANGKAH $_currentStep DARI 4',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            _stepTitle,
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
                          _buildStepNode(
                            step: '1',
                            title: 'Informasi',
                            isDone: _currentStep > 1,
                            isActive: _currentStep == 1,
                            onTap: () => setState(() => _currentStep = 1),
                          ),
                          _buildStepLine(isDone: _currentStep > 1),
                          _buildStepNode(
                            step: '2',
                            title: 'Destinasi',
                            isDone: _currentStep > 2,
                            isActive: _currentStep == 2,
                            onTap: () => setState(() => _currentStep = 2),
                          ),
                          _buildStepLine(isDone: _currentStep > 2),
                          _buildStepNode(
                            step: '3',
                            title: 'Jadwal',
                            isDone: _currentStep > 3,
                            isActive: _currentStep == 3,
                            onTap: () => setState(() => _currentStep = 3),
                          ),
                          _buildStepLine(isDone: _currentStep > 3),
                          _buildStepNode(
                            step: '4',
                            title: 'Budget',
                            isDone: false,
                            isActive: _currentStep == 4,
                            onTap: () => setState(() => _currentStep = 4),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Dynamic Step Content
                if (_currentStep == 1)
                  _buildStep1Information(context, tripProvider),
                if (_currentStep == 2) ...[
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
                        InkWell(
                          onTap: () {
                            setState(() => _currentStep = 1);
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                          ),
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
                if (_currentStep == 3)
                  _buildStep3Schedule(context, tripProvider, items),
                if (_currentStep == 4)
                  _buildStep4Budget(context, tripProvider, items),
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
                        onPressed: () {
                          if (_currentStep > 1) {
                            setState(() => _currentStep--);
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: Icon(
                          _currentStep == 1 ? Icons.close : Icons.arrow_back,
                          size: 18,
                        ),
                        label: Text(_currentStep == 1 ? 'Batal' : 'Kembali'),
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
                            if (_currentStep < 4) {
                              setState(() => _currentStep++);
                            } else {
                              final userId = authProvider.currentUser?.id ?? 1;
                              await tripProvider.saveBuilderTrip(userId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Rencana Perjalanan berhasil disimpan ke My Trip!'),
                                    backgroundColor: AppColors.primary,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            }
                          },
                          icon: Text(
                            _currentStep == 1
                                ? 'Lanjut ke Destinasi'
                                : _currentStep == 2
                                    ? 'Lanjut ke Atur Jadwal'
                                    : _currentStep == 3
                                        ? 'Lanjut ke Rincian Budget'
                                        : 'Simpan & Buat Trip',
                            style: AppTypography.labelLg.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onPrimary,
                            ),
                          ),
                          label: Icon(
                            _currentStep == 4
                                ? Icons.check_circle_rounded
                                : Icons.arrow_forward,
                            size: 18,
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

  Widget _buildStepNode({
    required String step,
    required String title,
    bool isDone = false,
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
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
        ),
      ),
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

  // ===========================================================================
  // STEP 1: INFORMASI & PESERTA
  // ===========================================================================
  Widget _buildStep1Information(BuildContext context, TripProvider tripProvider) {
    final trip = tripProvider.builderTrip;
    final participantCount = trip?.participantCount ?? 2;
    final startDate = trip?.startDate ?? 'Sabtu, 19 Okt 2024';

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kartu Nama Trip
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
                Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Nama Perjalanan',
                      style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tripNameController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Eksplorasi Lereng Merapi 1 Hari',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.terrain_rounded, color: AppColors.primary),
                  ),
                  onChanged: (val) {
                    tripProvider.updateBuilderTripInfo(tripName: val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Kartu Tanggal Perjalanan
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
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tanggal Perjalanan',
                      style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      final dayNames = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
                      final monthNames = [
                        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
                        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
                      ];
                      final dayName = dayNames[picked.weekday - 1];
                      final monthName = monthNames[picked.month - 1];
                      final formatted = '$dayName, ${picked.day} $monthName ${picked.year}';
                      tripProvider.updateBuilderTripInfo(startDate: formatted);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event, color: AppColors.secondary, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              startDate,
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.outline),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Kartu Jumlah Orang (Partisipan)
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
                Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Jumlah Peserta',
                      style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wisatawan',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: participantCount > 1
                              ? () {
                                  tripProvider.updateBuilderTripInfo(
                                    participantCount: participantCount - 1,
                                  );
                                }
                              : null,
                        ),
                        Container(
                          constraints: const BoxConstraints(minWidth: 44),
                          alignment: Alignment.center,
                          child: Text(
                            '$participantCount Orang',
                            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: () {
                            tripProvider.updateBuilderTripInfo(
                              participantCount: participantCount + 1,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Estimasi biaya tiket destinasi akan otomatis dikalikan dengan jumlah peserta.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // Rekomendasi Tip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.secondaryContainer),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: AppColors.onSecondaryContainer, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tips Perjalanan Gunung Merapi',
                        style: AppTypography.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Waktu terbaik menikmati pemandangan Merapi adalah pagi hari antara pukul 06:30 - 09:30 WIB saat langit cerah dan belum berkabut tebal.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSecondaryContainer.withAlpha(220),
                          fontSize: 12,
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
    );
  }

  // ===========================================================================
  // STEP 3: ATUR JADWAL & WAKTU
  // ===========================================================================
  Widget _buildStep3Schedule(
    BuildContext context,
    TripProvider tripProvider,
    List<TripItemModel> items,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.margin),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.schedule, size: 48, color: AppColors.outline),
              const SizedBox(height: 12),
              const Text('Belum ada destinasi yang dipilih.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => setState(() => _currentStep = 2),
                child: const Text('Pilih Destinasi Dulu'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Smart Schedule Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timeline_rounded, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Atur Jadwal & Waktu Kunjungan',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sesuaikan jam tiba dan durasi waktu santai di tiap destinasi wisata agar perjalanan teratur.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      tripProvider.autoScheduleBuilderItems(startHour: 7, startMinute: 30);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Jadwal berhasil diselaraskan otomatis mulai 07:30 WIB!'),
                          backgroundColor: AppColors.primary,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Otomatis Susun Jadwal (Mulai 07:30)'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // List of items in schedule
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, index) {
              final currentItem = items[index];
              final nextItem = index + 1 < items.length ? items[index + 1] : null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      width: 2,
                      height: 24,
                      color: AppColors.outlineVariant,
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Text(
                      'Perjalanan ~${currentItem.connectingTimeMinutes > 0 ? currentItem.connectingTimeMinutes : 15} mnt (${currentItem.connectingDistanceKm > 0 ? currentItem.connectingDistanceKm : 3.5} km)${nextItem != null ? " ke ${nextItem.itemName}" : ""}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
            itemBuilder: (ctx, i) {
              final item = items[i];
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.surfaceContainer),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${item.visitOrder}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                item.itemSubtitle,
                                style: AppTypography.bodySmall.copyWith(
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
                    const SizedBox(height: 12),
                    // Time Selector Badge & Edit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        InkWell(
                          onTap: () => _showEditTimeDialog(context, i, item, tripProvider),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withAlpha(140),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time_filled, size: 15, color: AppColors.onPrimaryContainer),
                                const SizedBox(width: 6),
                                Text(
                                  item.plannedTime,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 12, color: AppColors.onPrimaryContainer),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          'Durasi: ${item.durationHours} Jam',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Quick Duration Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [1.0, 1.5, 2.0, 2.5].map((d) {
                          final isSelected = item.durationHours == d;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text('${d % 1 == 0 ? d.toInt() : d} Jam', style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  tripProvider.updateBuilderItemSchedule(i, durationHours: d);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 4: BUDGET & ALOKASI ANGGARAN
  // ===========================================================================
  Widget _buildStep4Budget(
    BuildContext context,
    TripProvider tripProvider,
    List<TripItemModel> items,
  ) {
    final targetBudget = tripProvider.targetBudget;
    final mandatoryCost = tripProvider.totalMandatoryCost;
    final parkingFee = tripProvider.parkingFee;
    final remainingBudget = tripProvider.remainingBudget;
    final isDeficit = remainingBudget < 0;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.margin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Kartu Target Pagu Anggaran (Dapat Diedit & Disamakan)
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: AppColors.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Target Anggaran (Pagu Awal)',
                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                      onPressed: () => _showEditBudgetDialog(context, tripProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(targetBudget),
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Batas alokasi anggaran yang Anda siapkan untuk seluruh rute trip ini.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                // Tombol Pintas 1-Ketuk: Samakan dengan Biaya Destinasi!
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      tripProvider.setBuilderTargetBudget(mandatoryCost);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Target anggaran disamakan dengan biaya destinasi (${_formatCurrency(mandatoryCost)})!'),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sync_alt_rounded, size: 18),
                    label: Text('Samakan Target dengan Biaya Destinasi (${_formatCurrency(mandatoryCost)})'),
                  ),
                ),
                const SizedBox(height: 8),
                // Quick Choice Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: Text('Sesuai Tiket (${_formatCurrency(mandatoryCost)})', style: const TextStyle(fontSize: 11)),
                        onPressed: () => tripProvider.setBuilderTargetBudget(mandatoryCost),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 150.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => tripProvider.setBuilderTargetBudget(150000),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 250.000', style: TextStyle(fontSize: 11)),
                        onPressed: () => tripProvider.setBuilderTargetBudget(250000),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Rp 400.000 (Pagu Standar)', style: TextStyle(fontSize: 11)),
                        onPressed: () => tripProvider.setBuilderTargetBudget(400000),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('Kustom...', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showEditBudgetDialog(context, tripProvider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // 2. Rincian Tiket & Biaya Wajib Per Destinasi
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
                Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Rincian Biaya Tiket Destinasi',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: AppColors.outline),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  it.itemName,
                                  style: AppTypography.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatCurrency(it.estimatedCost),
                          style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.local_parking_rounded, size: 16, color: AppColors.outline),
                        SizedBox(width: 6),
                        Text('Parkir Kendaraan & Retribusi Kawasan'),
                      ],
                    ),
                    Text(
                      _formatCurrency(parkingFee),
                      style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Biaya Wajib',
                      style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatCurrency(mandatoryCost),
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // 3. Status Sisa Anggaran (Health Indicator)
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: isDeficit
                  ? AppColors.volcanoStatusWaspada.withAlpha(25)
                  : AppColors.secondaryContainer.withAlpha(80),
              borderRadius: AppDimensions.roundedXl,
              border: Border.all(
                color: isDeficit ? AppColors.volcanoStatusWaspada : AppColors.secondaryContainer,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isDeficit ? Icons.warning_amber_rounded : Icons.savings_rounded,
                  color: isDeficit ? AppColors.volcanoStatusWaspada : AppColors.secondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDeficit ? 'Defisit Anggaran' : 'Sisa Anggaran Fleksibel',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDeficit ? AppColors.volcanoStatusWaspada : AppColors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(remainingBudget.abs()),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDeficit ? AppColors.error : AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDeficit
                            ? 'Target budget Anda lebih kecil dari total biaya tiket wajib. Disarankan menaikkan target minimal ${_formatCurrency(mandatoryCost)}.'
                            : 'Alokasi aman untuk keperluan kuliner khas Merapi (Kopi Merapi, Jadah Tempe), oleh-oleh, dan dana cadangan.',
                        style: AppTypography.bodySmall.copyWith(
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
        ],
      ),
    );
  }
}
