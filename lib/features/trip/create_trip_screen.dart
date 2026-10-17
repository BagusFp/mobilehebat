import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import 'package:timezone/timezone.dart' as tz;
import '../auth/auth_provider.dart';
import '../explore/destination_provider.dart';
import '../utility/utility_provider.dart';
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
  bool _isTimezoneExpanded = false;
  bool _isCurrencyExpanded = false;
  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  DateTime _lastShakeTime = DateTime.now();
  bool _isGachaOpen = false;

  @override
  void initState() {
    super.initState();
    _tripNameController = TextEditingController(
      text: 'Rencana Trip Baru',
    );
    _initShakeSensor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tripProvider = context.read<TripProvider>();
      final util = context.read<UtilityProvider>();
      if (!util.hasRates) {
        util.loadCachedRates();
      }

      if (widget.existingTrip != null) {
        tripProvider.initBuilderTrip(existingTrip: widget.existingTrip);
        _tripNameController.text = widget.existingTrip!.tripName;
      } else if (widget.initialDestination != null) {
        tripProvider.initBuilderWithDestination(widget.initialDestination!);
        _tripNameController.text = 'Wisata ${widget.initialDestination!.name}';
      } else {
        if (tripProvider.builderTrip == null) {
          tripProvider.initBuilderTrip(empty: true);
        }
        if (tripProvider.builderTrip != null) {
          _tripNameController.text = tripProvider.builderTrip!.tripName;
        }
      }
    });
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _tripNameController.dispose();
    super.dispose();
  }

  void _initShakeSensor() {
    try {
      _shakeSubscription = accelerometerEventStream().listen(
        (event) {
          if (!mounted || _currentStep != 2 || _isGachaOpen) return;
          final double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          // Deteksi hentakan goyang ponsel (> 14.5 m/s^2)
          if (gForce > 14.5) {
            final now = DateTime.now();
            if (now.difference(_lastShakeTime).inMilliseconds > 1600) {
              _lastShakeTime = now;
              HapticFeedback.heavyImpact();
              _openGachaShakeDialog(context);
            }
          }
        },
        onError: (err) {
          debugPrint('Shake sensor in create trip unavailable: $err');
        },
      );
    } catch (e) {
      debugPrint('Shake sensor init catch: $e');
    }
  }

  void _openGachaShakeDialog(BuildContext context) {
    if (_isGachaOpen) return;
    final destProvider = context.read<DestinationProvider>();
    final tripProvider = context.read<TripProvider>();
    final destinations = destProvider.allDestinations;

    if (destinations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daftar destinasi belum termuat.'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _isGachaOpen = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _GachaShakeDestinationDialog(
        availableDestinations: destinations,
        existingItems: tripProvider.builderItems,
        onAddDestination: (selectedDest) {
          tripProvider.addDestinationToBuilder(selectedDest);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${selectedDest.name} berhasil ditambahkan ke rute trip!'),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isGachaOpen = false;
        });
      }
    });
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
    // Parse start time from plannedTime (e.g. "08:00 - 09:30" or "08:00")
    TimeOfDay selectedStart = const TimeOfDay(hour: 8, minute: 0);
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(item.plannedTime);
    if (match != null) {
      final h = int.tryParse(match.group(1) ?? '') ?? 8;
      final m = int.tryParse(match.group(2) ?? '') ?? 0;
      selectedStart = TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    }

    double selectedDuration = item.durationHours > 0 ? item.durationHours : 1.5;

    String formatTimeOfDay(TimeOfDay tod) {
      final h = tod.hour.toString().padLeft(2, '0');
      final m = tod.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    TimeOfDay computeEndTime(TimeOfDay start, double durationHours) {
      final startMins = start.hour * 60 + start.minute;
      final durMins = (durationHours * 60).round();
      final endTotal = startMins + durMins;
      return TimeOfDay(
        hour: (endTotal ~/ 60) % 24,
        minute: endTotal % 60,
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final endTod = computeEndTime(selectedStart, selectedDuration);
          final formattedRange =
              '${formatTimeOfDay(selectedStart)} - ${formatTimeOfDay(endTod)}';

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                const Icon(Icons.access_time_filled, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jadwal di ${item.itemName}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih jam mulai kunjungan menggunakan pemilih jam visual:',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Pop-up Jam Visual Button Card
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: dialogContext,
                        initialTime: selectedStart,
                        helpText: 'PILIH JAM MULAI KUNJUNGAN',
                        cancelText: 'BATAL',
                        confirmText: 'PILIH JAM',
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                              alwaysUse24HourFormat: true,
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedStart = picked;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(80),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.schedule,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jam Mulai',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.outline,
                                  ),
                                ),
                                Text(
                                  '${formatTimeOfDay(selectedStart)} WIB',
                                  style: AppTypography.titleLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.touch_app,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Pilih Jam',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Preset Jam Mulai Cepat
                  Text(
                    'Preset Jam Mulai:',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const TimeOfDay(hour: 7, minute: 0),
                      const TimeOfDay(hour: 8, minute: 0),
                      const TimeOfDay(hour: 9, minute: 30),
                      const TimeOfDay(hour: 11, minute: 0),
                      const TimeOfDay(hour: 13, minute: 30),
                      const TimeOfDay(hour: 15, minute: 0),
                    ].map((tod) {
                      final isSelected =
                          selectedStart.hour == tod.hour &&
                          selectedStart.minute == tod.minute;
                      return ChoiceChip(
                        label: Text(
                          formatTimeOfDay(tod),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : AppColors.onSurface,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceContainerLow,
                        visualDensity: VisualDensity.compact,
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() {
                              selectedStart = tod;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  // Durasi Kunjungan
                  Text(
                    'Durasi Waktu Santai:',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [0.5, 1.0, 1.5, 2.0, 2.5, 3.0].map((d) {
                      final isSelected = selectedDuration == d;
                      final label = d % 1 == 0 ? '${d.toInt()} Jam' : '$d Jam';
                      return ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? Colors.white
                                : AppColors.onSurface,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.secondary,
                        backgroundColor: AppColors.surfaceContainerLow,
                        visualDensity: VisualDensity.compact,
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() {
                              selectedDuration = d;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),
                  // Preview Rentang Jam
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceContainer),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timelapse_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rentang Jam Kunjungan:',
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.outline,
                                  fontSize: 10.5,
                                ),
                              ),
                              Text(
                                '$formattedRange WIB',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  tripProvider.updateBuilderItemSchedule(
                    index,
                    plannedTime: formattedRange,
                    durationHours: selectedDuration,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Terapkan Jadwal'),
              ),
            ],
          );
        },
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              final parsed = double.tryParse(
                controller.text.replaceAll(RegExp(r'[^0-9]'), ''),
              );
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _openGachaShakeDialog(context);
                      },
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          border: Border.all(
                            color: AppColors.primary.withAlpha(60),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.screen_rotation_alt, size: 20, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Bingung Memilih? Goyang HP untuk Destinasi',
                                    style: AppTypography.labelMd.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Kocok ponselmu secara fisik dengan sensor akselerometer',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontSize: 10.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.margin,
                      ),
                      itemCount: availableDestinations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (c, idx) {
                        final dest = availableDestinations[idx];
                        final isAlreadyAdded = tripProvider.builderItems.any(
                          (item) => item.destinationId == dest.id,
                        );

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppDimensions.roundedLg,
                            border: Border.all(
                              color: AppColors.surfaceContainer,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: AppDimensions.roundedSm,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: AppColors.primaryContainer,
                                  child:
                                      dest.imageUrl != null &&
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppDimensions.roundedSm,
                                  ),
                                ),
                                onPressed: isAlreadyAdded
                                    ? null
                                    : () {
                                        tripProvider.addDestinationToBuilder(
                                          dest,
                                        );
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${dest.name} ditambahkan ke rute!',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      },
                                child: Text(
                                  isAlreadyAdded ? 'Ditambahkan' : '+ Pilih',
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
        actions: [
          TextButton.icon(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              final tripProvider = context.read<TripProvider>();
              final userId = authProvider.currentUser?.id ?? 1;
              await tripProvider.saveBuilderTrip(userId, status: 'draft');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rencana perjalanan berhasil disimpan sebagai draft.'),
                    backgroundColor: AppColors.secondary,
                    duration: Duration(seconds: 2),
                  ),
                );
                tripProvider.setActiveTab('draft');
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.drafts_outlined, size: 16, color: AppColors.primary),
            label: Text(
              'Simpan Draft',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                            onTap: () {
                              if (tripProvider.builderItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Silakan tambah minimal 1 destinasi terlebih dahulu.',
                                    ),
                                    backgroundColor:
                                        AppColors.volcanoStatusWaspada,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              setState(() => _currentStep = 3);
                            },
                          ),
                          _buildStepLine(isDone: _currentStep > 3),
                          _buildStepNode(
                            step: '4',
                            title: 'Budget',
                            isDone: false,
                            isActive: _currentStep == 4,
                            onTap: () {
                              if (tripProvider.builderItems.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Silakan tambah minimal 1 destinasi terlebih dahulu.',
                                    ),
                                    backgroundColor:
                                        AppColors.volcanoStatusWaspada,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              setState(() => _currentStep = 4);
                            },
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
                  const SizedBox(height: AppDimensions.spaceSm),

                  // 4. Destination Reorderable List Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                    ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
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
                            const Icon(
                              Icons.drag_indicator,
                              size: 14,
                              color: AppColors.onSurfaceVariant,
                            ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                    ),
                    child: items.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: AppDimensions.roundedXl,
                              border: Border.all(
                                color: AppColors.surfaceContainer,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer
                                        .withAlpha(50),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add_location_alt_outlined,
                                    size: 28,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Belum Ada Destinasi Terpilih',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Daftar destinasi masih kosong. Silakan tambah destinasi wisata Merapi untuk mulai menyusun itinerary dan rincian waktu kunjungan.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: List.generate(items.length, (idx) {
                              final item = items[idx];
                              return Column(
                                children: [
                                  _buildDestinationCard(
                                    context,
                                    item,
                                    idx,
                                    tripProvider,
                                  ),
                                  if (idx < items.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
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
                                          Flexible(
                                            child: Text(
                                              'Perjalanan via Jl. Kaliurang (${item.connectingTimeMinutes} mnt • ${item.connectingDistanceKm} km)',
                                              style:
                                                  AppTypography.labelSm.copyWith(
                                                color:
                                                    AppColors.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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

                  // Button: Tambah Destinasi
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                    ),
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
                        icon: const Icon(
                          Icons.add_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        label: Text(
                          items.isEmpty
                              ? 'Tambah Destinasi di Sekitar Merapi'
                              : 'Tambah Destinasi Lain di Sekitar Merapi',
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Gamified Kocok HP / Gacha Destination Banner
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryContainer.withAlpha(220),
                            AppColors.secondaryContainer.withAlpha(200),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: AppDimensions.roundedLg,
                        border: Border.all(
                          color: AppColors.primary.withAlpha(90),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: AppDimensions.roundedMd,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(40),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.screen_rotation_alt,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Bingung Mau ke Mana?',
                                        style: AppTypography.titleSmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC58A32),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'GACHA',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Goyang HP atau ketuk tombol untuk rekomendasi acak lereng Merapi.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusMd,
                                ),
                              ),
                            ),
                            onPressed: () => _openGachaShakeDialog(context),
                            icon: const Icon(Icons.screen_rotation_alt, size: 16),
                            label: const Text(
                              'Goyang HP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spaceMd),

                  // 6. Live Estimate & Budget Summary Card
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                    ),
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
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.analytics,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Kalkulator Rencana Trip',
                                        style: AppTypography.titleMd.copyWith(
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
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
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

                          // Budget Breakdown
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.payments,
                                      size: 16,
                                      color: AppColors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Total Tiket & Donasi (${tripProvider.builderTrip?.participantCount ?? 1} Orang)',
                                        style: AppTypography.bodySm,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.local_parking,
                                      size: 16,
                                      color: AppColors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Estimasi Parkir Kendaraan',
                                        style: AppTypography.bodySm,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest
                                  .withAlpha(80),
                              borderRadius: AppDimensions.roundedMd,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Estimasi Biaya Wajib',
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatCurrency(
                                    tripProvider.totalMandatoryCost,
                                  ),
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
                            padding: const EdgeInsets.all(
                              AppDimensions.spaceSm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer.withAlpha(
                                120,
                              ),
                              borderRadius: AppDimensions.roundedLg,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
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
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Sisa Target Budget',
                                              style: AppTypography.labelSm
                                                  .copyWith(
                                                    color: AppColors
                                                        .onSecondaryContainer,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              _formatCurrency(
                                                tripProvider.remainingBudget,
                                              ),
                                              style: AppTypography.titleMd
                                                  .copyWith(
                                                    color: AppColors.primary,
                                                    fontWeight:
                                                        FontWeight.bold,
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
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.surfaceContainerLowest,
                                          borderRadius:
                                              AppDimensions.roundedSm,
                                        ),
                                        child: Text(
                                          'SANGAT AMAN',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Untuk makan & oleh-oleh',
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
                            if (_currentStep == 2 &&
                                tripProvider.builderItems.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Silakan tambah minimal 1 destinasi sebelum melanjutkan.',
                                  ),
                                  backgroundColor:
                                      AppColors.volcanoStatusWaspada,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            if (_currentStep < 4) {
                              setState(() => _currentStep++);
                            } else {
                              final userId = authProvider.currentUser?.id ?? 1;
                              await tripProvider.saveBuilderTrip(userId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Rencana Perjalanan berhasil disimpan ke My Trip!',
                                    ),
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
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: AppColors.onPrimary,
                      )
                    : Text(
                        step,
                        style: TextStyle(
                          color: isActive
                              ? AppColors.onPrimary
                              : AppColors.onSurfaceVariant,
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
                fontWeight: isActive || isDone
                    ? FontWeight.bold
                    : FontWeight.normal,
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
                  child:
                      item.imageUrl != null && item.imageUrl!.startsWith('http')
                      ? Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.landscape,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.landscape, color: AppColors.onPrimary),
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
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: AppColors.outline,
                      ),
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
                    const Icon(
                      Icons.confirmation_number,
                      size: 14,
                      color: AppColors.secondary,
                    ),
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
  Widget _buildStep1Information(
    BuildContext context,
    TripProvider tripProvider,
  ) {
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
                    const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Nama Perjalanan',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                    prefixIcon: const Icon(
                      Icons.terrain_rounded,
                      color: AppColors.primary,
                    ),
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
                    const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tanggal Perjalanan',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                      final dayNames = [
                        'Senin',
                        'Selasa',
                        'Rabu',
                        'Kamis',
                        'Jumat',
                        'Sabtu',
                        'Minggu',
                      ];
                      final monthNames = [
                        'Jan',
                        'Feb',
                        'Mar',
                        'Apr',
                        'Mei',
                        'Jun',
                        'Jul',
                        'Agu',
                        'Sep',
                        'Okt',
                        'Nov',
                        'Des',
                      ];
                      final dayName = dayNames[picked.weekday - 1];
                      final monthName = monthNames[picked.month - 1];
                      final formatted =
                          '$dayName, ${picked.day} $monthName ${picked.year}';
                      tripProvider.updateBuilderTripInfo(startDate: formatted);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.event,
                              color: AppColors.secondary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              startDate,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.outline,
                        ),
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
                    const Icon(
                      Icons.people_alt_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Jumlah Peserta',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Wisatawan',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
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
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
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
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.outline,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // 4. Kartu Zona Waktu Perjalanan (Bisa Dibuka-Tutup)
          _buildTimezoneCard(context, tripProvider),
          const SizedBox(height: AppDimensions.spaceMd),

          // 5. Kartu Konversi Mata Uang (Bisa Dibuka-Tutup)
          _buildCurrencyCard(context, tripProvider),
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
                const Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.onSecondaryContainer,
                  size: 22,
                ),
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
                    const Icon(
                      Icons.timeline_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Atur Jadwal & Waktu Kunjungan',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Sesuaikan jam tiba dan durasi waktu santai di tiap destinasi wisata agar perjalanan teratur.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      tripProvider.autoScheduleBuilderItems(
                        startHour: 7,
                        startMinute: 30,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Jadwal berhasil diselaraskan otomatis mulai 07:30 WIB!',
                          ),
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

          // Dynamic Total Durasi Aktivitas & Perjalanan (Pindah dari Langkah 2 ke Jadwal)
          if (items.isNotEmpty) ...[
            Builder(
              builder: (ctx) {
                final totalActivityMins =
                    (tripProvider.totalActivityHours * 60).round();
                final totalTravelMins = tripProvider.totalTravelMinutes;
                final totalTripMins = totalActivityMins + totalTravelMins;
                final tripHours = totalTripMins ~/ 60;
                final tripMins = totalTripMins % 60;
                final totalDurationString = tripHours > 0
                    ? (tripMins > 0
                        ? '$tripHours Jam $tripMins Menit'
                        : '$tripHours Jam')
                    : '$tripMins Menit';

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.surfaceContainer),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          size: 24,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Durasi Aktivitas & Perjalanan',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              totalDurationString,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(tripProvider.totalActivityHours).toStringAsFixed(1).replaceAll('.0', '')} Jam kunjungan • $totalTravelMins mnt perjalanan antar lokasi',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppDimensions.spaceMd),
          ],

          // List of items in schedule
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.spaceLg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppDimensions.roundedXl,
                border: Border.all(color: AppColors.surfaceContainer),
              ),
              child: Center(
                child: Text(
                  'Belum ada destinasi untuk dijadwalkan. Silakan kembali ke langkah Destinasi dan tambahkan destinasi terlebih dahulu.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, index) {
              final currentItem = items[index];
              final nextItem = index + 1 < items.length
                  ? items[index + 1]
                  : null;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 24,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 2,
                      height: 24,
                      color: AppColors.outlineVariant,
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.directions_car_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Perjalanan ~${currentItem.connectingTimeMinutes > 0 ? currentItem.connectingTimeMinutes : 15} mnt (${currentItem.connectingDistanceKm > 0 ? currentItem.connectingDistanceKm : 3.5} km)${nextItem != null ? " ke ${nextItem.itemName}" : ""}',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        Flexible(
                          child: InkWell(
                            onTap: () => _showEditTimeDialog(
                              context,
                              i,
                              item,
                              tripProvider,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withAlpha(140),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_filled,
                                    size: 15,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      item.plannedTime,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppColors.onPrimaryContainer,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              label: Text(
                                '${d % 1 == 0 ? d.toInt() : d} Jam',
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  tripProvider.updateBuilderItemSchedule(
                                    i,
                                    durationHours: d,
                                  );
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
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet,
                            color: AppColors.primary,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Target Anggaran (Pagu Awal)',
                              style: AppTypography.titleMedium.copyWith(
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
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      onPressed: () =>
                          _showEditBudgetDialog(context, tripProvider),
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
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // Tombol Pintas 1-Ketuk: Samakan dengan Biaya Destinasi!
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      tripProvider.setBuilderTargetBudget(mandatoryCost);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Target anggaran disamakan dengan biaya destinasi (${_formatCurrency(mandatoryCost)})!',
                          ),
                          backgroundColor: AppColors.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sync_alt_rounded, size: 18),
                    label: Text(
                      'Samakan Target dengan Biaya Destinasi (${_formatCurrency(mandatoryCost)})',
                      style: const TextStyle(fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Quick Choice Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ActionChip(
                        label: Text(
                          'Sesuai Tiket (${_formatCurrency(mandatoryCost)})',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            tripProvider.setBuilderTargetBudget(mandatoryCost),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text(
                          'Rp 150.000',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            tripProvider.setBuilderTargetBudget(150000),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text(
                          'Rp 250.000',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            tripProvider.setBuilderTargetBudget(250000),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text(
                          'Rp 400.000 (Pagu Standar)',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            tripProvider.setBuilderTargetBudget(400000),
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text(
                          'Kustom...',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () =>
                            _showEditBudgetDialog(context, tripProvider),
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
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Rincian Biaya Tiket Destinasi',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: AppColors.outline,
                              ),
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
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: const [
                          Icon(
                            Icons.local_parking_rounded,
                            size: 16,
                            color: AppColors.outline,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Parkir Kendaraan & Retribusi Kawasan',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatCurrency(parkingFee),
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Biaya Wajib',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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
                color: isDeficit
                    ? AppColors.volcanoStatusWaspada
                    : AppColors.secondaryContainer,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isDeficit
                      ? Icons.warning_amber_rounded
                      : Icons.savings_rounded,
                  color: isDeficit
                      ? AppColors.volcanoStatusWaspada
                      : AppColors.secondary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDeficit
                            ? 'Defisit Anggaran'
                            : 'Sisa Anggaran Fleksibel',
                        style: AppTypography.labelLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDeficit
                              ? AppColors.volcanoStatusWaspada
                              : AppColors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrency(remainingBudget.abs()),
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDeficit
                              ? AppColors.error
                              : AppColors.secondary,
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
          const SizedBox(height: AppDimensions.spaceMd),

          // 4. Konversi Valuta Anggaran (Step 4)
          _buildStep4CurrencyConversion(context, tripProvider),
        ],
      ),
    );
  }

  // ===========================================================================
  // ZONA WAKTU PERJALANAN (COLLAPSIBLE CARD)
  // ===========================================================================
  static const List<Map<String, String>> _availableCities = [
    {
      'city': 'Yogyakarta / Sleman',
      'region': 'DIY (Kawasan Merapi)',
      'iana': 'Asia/Jakarta',
      'zone': 'WIB',
    },
    {
      'city': 'Jakarta',
      'region': 'DKI Jakarta',
      'iana': 'Asia/Jakarta',
      'zone': 'WIB',
    },
    {
      'city': 'Surabaya',
      'region': 'Jawa Timur',
      'iana': 'Asia/Jakarta',
      'zone': 'WIB',
    },
    {
      'city': 'Bandung',
      'region': 'Jawa Barat',
      'iana': 'Asia/Jakarta',
      'zone': 'WIB',
    },
    {
      'city': 'Denpasar / Kuta',
      'region': 'Bali',
      'iana': 'Asia/Makassar',
      'zone': 'WITA',
    },
    {
      'city': 'Makassar',
      'region': 'Sulawesi Selatan',
      'iana': 'Asia/Makassar',
      'zone': 'WITA',
    },
    {
      'city': 'Mataram / Lombok',
      'region': 'Nusa Tenggara Barat',
      'iana': 'Asia/Makassar',
      'zone': 'WITA',
    },
    {
      'city': 'Jayapura',
      'region': 'Papua',
      'iana': 'Asia/Jayapura',
      'zone': 'WIT',
    },
    {
      'city': 'Ambon',
      'region': 'Maluku',
      'iana': 'Asia/Jayapura',
      'zone': 'WIT',
    },
    {
      'city': 'London',
      'region': 'Inggris (UK)',
      'iana': 'Europe/London',
      'zone': 'London',
    },
  ];

  void _showCityPicker({
    required BuildContext context,
    required TripProvider tripProvider,
  }) {
    final currentSelection = tripProvider.builderTrip?.originCity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pilih Kota Asal Perjalanan',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: currentSelection == null
                          ? AppColors.primary
                          : AppColors.surfaceContainer,
                    ),
                  ),
                  tileColor: currentSelection == null
                      ? AppColors.primary.withAlpha(15)
                      : AppColors.surfaceContainerLow,
                  leading: const Icon(
                    Icons.location_off_outlined,
                    color: AppColors.outline,
                  ),
                  title: const Text(
                    'Belum Dipilih / Kosongkan',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'Zona waktu tidak akan diasumsikan atau dikarang',
                  ),
                  trailing: currentSelection == null
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : null,
                  onTap: () {
                    tripProvider.updateBuilderTripInfo(clearOrigin: true);
                    Navigator.pop(ctx);
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: _availableCities.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final opt = _availableCities[index];
                    final isSelected = currentSelection == opt['city'];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceContainer,
                        ),
                      ),
                      tileColor: isSelected
                          ? AppColors.primary.withAlpha(15)
                          : AppColors.surfaceContainerLow,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          opt['zone']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      title: Text(
                        opt['city']!,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('${opt['region']} • ${opt['iana']}'),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : const Icon(
                              Icons.chevron_right,
                              color: AppColors.outline,
                            ),
                      onTap: () {
                        tripProvider.updateBuilderTripInfo(
                          originCity: opt['city'],
                          originTimezone: opt['iana'],
                        );
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimezoneCard(BuildContext context, TripProvider tripProvider) {
    final trip = tripProvider.builderTrip;
    final originCity = trip?.originCity;
    final originTimezone = trip?.originTimezone;
    final destCity = trip?.destinationCity ?? 'Gunung Merapi (Kaliadem)';
    final destTimezone = trip?.destinationTimezone ?? 'Asia/Jakarta';

    final headerSummary = originCity == null
        ? 'Belum dipilih (Pilih kota asal)'
        : '$originCity ➔ $destCity';

    String originLocalTime = '-';
    String destLocalTime = '-';
    String originZoneLabel = '-';
    String destZoneLabel = 'WIB';
    String timeDiffMessage = '';
    Color timeDiffColor = AppColors.secondary;

    if (originTimezone != null && originCity != null) {
      try {
        final nowUtc = DateTime.now().toUtc();
        final origLoc = tz.getLocation(originTimezone);
        final origTz = tz.TZDateTime.from(nowUtc, origLoc);
        originLocalTime = DateFormat('HH:mm').format(origTz);
        originZoneLabel =
            '${origTz.timeZoneName} (UTC${origTz.timeZoneOffset.inHours >= 0 ? "+${origTz.timeZoneOffset.inHours}" : "${origTz.timeZoneOffset.inHours}"})';

        final destLoc = tz.getLocation(destTimezone);
        final destTz = tz.TZDateTime.from(nowUtc, destLoc);
        destLocalTime = DateFormat('HH:mm').format(destTz);
        destZoneLabel =
            '${destTz.timeZoneName} (UTC${destTz.timeZoneOffset.inHours >= 0 ? "+${destTz.timeZoneOffset.inHours}" : "${destTz.timeZoneOffset.inHours}"})';

        final diffHours =
            destTz.timeZoneOffset.inHours - origTz.timeZoneOffset.inHours;
        if (diffHours == 0) {
          timeDiffMessage =
              'Kota asal dan tujuan berada di zona waktu yang sama.';
          timeDiffColor = AppColors.primary;
        } else if (diffHours > 0) {
          timeDiffMessage =
              'Waktu tujuan $diffHours jam lebih cepat dari kota asal.';
          timeDiffColor = AppColors.secondary;
        } else {
          timeDiffMessage =
              'Waktu tujuan ${diffHours.abs()} jam lebih lambat dari kota asal.';
          timeDiffColor = AppColors.volcanoStatusWaspada;
        }
      } catch (_) {}
    } else {
      try {
        final nowUtc = DateTime.now().toUtc();
        final destLoc = tz.getLocation(destTimezone);
        final destTz = tz.TZDateTime.from(nowUtc, destLoc);
        destLocalTime = DateFormat('HH:mm').format(destTz);
        destZoneLabel =
            '${destTz.timeZoneName} (UTC+${destTz.timeZoneOffset.inHours})';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedXl,
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header
          InkWell(
            onTap: () {
              setState(() {
                _isTimezoneExpanded = !_isTimezoneExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_rounded,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Zona Waktu Perjalanan',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: originCity == null
                                    ? AppColors.volcanoStatusWaspada.withAlpha(
                                        25,
                                      )
                                    : AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                originCity == null ? 'Opsional' : 'Aktif',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: originCity == null
                                      ? AppColors.volcanoStatusWaspada
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerSummary,
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
                  Icon(
                    _isTimezoneExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),
          ),

          if (_isTimezoneExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih lokasi asal dan tujuan untuk menyesuaikan waktu itinerary (WIB, WITA, WIT, London GMT/BST).',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Selector Kota Asal
                  Text(
                    'KOTA ASAL',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showCityPicker(
                      context: context,
                      tripProvider: tripProvider,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: originCity == null
                              ? AppColors.outline.withAlpha(50)
                              : AppColors.secondary.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            originCity == null
                                ? Icons.location_on_outlined
                                : Icons.flight_takeoff_rounded,
                            size: 20,
                            color: originCity == null
                                ? AppColors.outline
                                : AppColors.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  originCity ??
                                      'Belum dipilih (Ketuk untuk memilih)',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: originCity == null
                                        ? AppColors.outline
                                        : AppColors.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  originCity == null
                                      ? 'Zona waktu belum ditentukan'
                                      : '$originZoneLabel ($originTimezone)',
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
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            color: AppColors.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Destinasi Tujuan (Terkunci ke Kawasan Gunung Merapi)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'KOTA TUJUAN DESTINASI',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lock_rounded,
                              size: 10,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Terkunci ke Merapi',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.landscape_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destCity,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$destZoneLabel ($destTimezone) • Kawasan Wisata Merapi',
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
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Destinasi perjalanan dikunci ke Kawasan Gunung Merapi (WIB). Silakan pilih kota asal Anda di atas untuk melihat penyesuaian zona waktu.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.outline,
                      fontSize: 10.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Live Comparison Display
                  if (originCity == null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lokasi asal belum dipilih. Zona waktu belum ditentukan secara otomatis.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.secondary.withAlpha(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      originCity,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      originLocalTime,
                                      style: AppTypography.titleLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    Text(
                                      originZoneLabel,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      destCity,
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      destLocalTime,
                                      style: AppTypography.titleLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      destZoneLabel,
                                      style: AppTypography.bodySmall.copyWith(
                                        fontSize: 10,
                                        color: AppColors.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.compare_arrows_rounded,
                                size: 16,
                                color: timeDiffColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  timeDiffMessage,
                                  style: AppTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: timeDiffColor,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // NILAI TUKAR MATA UANG (KURS ACUAN 1 UNIT) - STEP 1
  // ===========================================================================
  Widget _buildCurrencyCard(BuildContext context, TripProvider tripProvider) {
    final util = context.watch<UtilityProvider>();
    final trip = tripProvider.builderTrip;
    final targetCode = trip?.currencyTarget ?? 'USD';

    // Perhitungan nilai tukar acuan per harga 1
    final double usdToIdr = util.convert(
      amount: 1.0,
      fromCode: 'USD',
      toCode: 'IDR',
    );
    final double idrToUsd = util.convert(
      amount: 1.0,
      fromCode: 'IDR',
      toCode: 'USD',
    );

    final double eurToIdr = util.convert(
      amount: 1.0,
      fromCode: 'EUR',
      toCode: 'IDR',
    );
    final double idrToEur = util.convert(
      amount: 1.0,
      fromCode: 'IDR',
      toCode: 'EUR',
    );

    final double jpyToIdr = util.convert(
      amount: 1.0,
      fromCode: 'JPY',
      toCode: 'IDR',
    );
    final double idrToJpy = util.convert(
      amount: 1.0,
      fromCode: 'IDR',
      toCode: 'JPY',
    );

    final double eurToUsd = util.convert(
      amount: 1.0,
      fromCode: 'EUR',
      toCode: 'USD',
    );
    final double usdToEur = util.convert(
      amount: 1.0,
      fromCode: 'USD',
      toCode: 'EUR',
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedXl,
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header
          InkWell(
            onTap: () {
              setState(() {
                _isCurrencyExpanded = !_isCurrencyExpanded;
              });
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Konversi Mata Uang',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Kurs 1 Unit • $targetCode',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          util.hasRates
                              ? 'Kurs Referensi Frankfurter (${util.formattedApiDate})'
                              : (util.errorMessage ?? 'Ambil kurs online...'),
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
                  Icon(
                    _isCurrencyExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.outline,
                  ),
                ],
              ),
            ),
          ),

          if (_isCurrencyExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status bar & Refresh button
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                util.isUsingCachedRates
                                    ? Icons.cloud_off_rounded
                                    : Icons.cloud_done_rounded,
                                size: 16,
                                color: util.isUsingCachedRates
                                    ? AppColors.secondary
                                    : AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  util.hasRates
                                      ? 'Kurs API Frankfurt (${util.formattedApiDate})'
                                      : (util.errorMessage ??
                                            'Belum ada data kurs'),
                                  style: AppTypography.bodySmall.copyWith(
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
                                              ? 'Kurs diperbarui dari Frankfurter API (${util.formattedApiDate}).'
                                              : (util.errorMessage ??
                                                    'Gagal memperbarui kurs.'),
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.sync,
                                        size: 14,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Perbarui',
                                        style: AppTypography.labelSmall
                                            .copyWith(
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
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              util.errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // Pilihan Mata Uang Acuan Trip
                  Text(
                    'MATA UANG ACUAN ESTIMASI TRIP',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCurrencyChip(
                          code: 'USD',
                          symbol: r'$',
                          flag: '🇺🇸',
                          isSelected: targetCode == 'USD',
                          onTap: () => tripProvider.updateBuilderTripInfo(
                            currencyTarget: 'USD',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCurrencyChip(
                          code: 'EUR',
                          symbol: '€',
                          flag: '🇪🇺',
                          isSelected: targetCode == 'EUR',
                          onTap: () => tripProvider.updateBuilderTripInfo(
                            currencyTarget: 'EUR',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCurrencyChip(
                          code: 'JPY',
                          symbol: '¥',
                          flag: '🇯🇵',
                          isSelected: targetCode == 'JPY',
                          onTap: () => tripProvider.updateBuilderTripInfo(
                            currencyTarget: 'JPY',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Daftar Nilai Tukar Acuan Per 1 Unit
                  Text(
                    'NILAI TUKAR ACUAN (PER 1 UNIT)',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (util.hasRates) ...[
                    // 1 USD & 1 IDR
                    _buildRateRow(
                      flag: '🇺🇸',
                      pair: 'USD / IDR',
                      rate1: '1 USD = Rp ${_formatRateIdr(usdToIdr)} IDR',
                      rate2: '1 IDR = ${_formatSmallRate(idrToUsd)} USD',
                      isHighlighted: targetCode == 'USD',
                    ),
                    const SizedBox(height: 8),

                    // 1 EUR & 1 IDR
                    _buildRateRow(
                      flag: '🇪🇺',
                      pair: 'EUR / IDR',
                      rate1: '1 EUR = Rp ${_formatRateIdr(eurToIdr)} IDR',
                      rate2: '1 IDR = ${_formatSmallRate(idrToEur)} EUR',
                      isHighlighted: targetCode == 'EUR',
                    ),
                    const SizedBox(height: 8),

                    // 1 JPY & 1 IDR
                    _buildRateRow(
                      flag: '🇯🇵',
                      pair: 'JPY / IDR',
                      rate1: '1 JPY = Rp ${_formatRateIdr(jpyToIdr)} IDR',
                      rate2: '1 IDR = ${_formatSmallRate(idrToJpy)} JPY',
                      isHighlighted: targetCode == 'JPY',
                    ),
                    const SizedBox(height: 8),

                    // 1 EUR & 1 USD (Cross Rate)
                    _buildRateRow(
                      flag: '🌐',
                      pair: 'EUR / USD',
                      rate1: '1 EUR = ${_formatSmallRate(eurToUsd)} USD',
                      rate2: '1 USD = ${_formatSmallRate(usdToEur)} EUR',
                      isHighlighted: false,
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('Memuat nilai tukar per harga 1...'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Keterangan bahwa konversi budget dihitung di Langkah 4
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceContainer),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Nilai tukar di atas menampilkan kurs acuan per 1 unit mata uang. Konversi total target pagu anggaran trip Anda akan dihitung di Bagian 4 (Rincian Anggaran).',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 11,
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
        ],
      ),
    );
  }

  // ===========================================================================
  // STEP 4: KONVERSI ANGGARAN KE VALUTA ASING
  // ===========================================================================
  Widget _buildStep4CurrencyConversion(
    BuildContext context,
    TripProvider tripProvider,
  ) {
    final util = context.watch<UtilityProvider>();
    final trip = tripProvider.builderTrip;
    final targetCode = trip?.currencyTarget ?? 'USD';
    final targetBudget = trip?.targetBudget ?? 400000.0;
    final mandatoryCost = tripProvider.totalMandatoryCost;
    final remainingBudget = tripProvider.remainingBudget;
    final isDeficit = remainingBudget < 0;

    double convertedTarget = 0.0;
    double convertedMandatory = 0.0;
    double convertedRemaining = 0.0;
    double unitRate = 0.0;

    if (util.hasRates) {
      convertedTarget = util.convertFromIdr(targetBudget, targetCode);
      convertedMandatory = util.convertFromIdr(mandatoryCost, targetCode);
      convertedRemaining = util.convertFromIdr(
        remainingBudget.abs(),
        targetCode,
      );
      unitRate = util.convert(amount: 1.0, fromCode: targetCode, toCode: 'IDR');
    }

    final currencyOptions = [
      {'code': 'USD', 'symbol': r'$', 'flag': '🇺🇸'},
      {'code': 'EUR', 'symbol': '€', 'flag': '🇪🇺'},
      {'code': 'JPY', 'symbol': '¥', 'flag': '🇯🇵'},
    ];

    return Container(
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.currency_exchange_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Konversi Valuta Anggaran',
                        style: AppTypography.titleMedium.copyWith(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'IDR ➔ $targetCode',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Pilih mata uang untuk melihat estimasi anggaran dalam valuta asing:',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),

          // Pilihan valuta (Chips)
          Row(
            children: currencyOptions.map((opt) {
              final isSelected = targetCode == opt['code'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Center(
                      child: Text(
                        '${opt['flag']} ${opt['code']} (${opt['symbol']})',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.onSurface,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceContainerLow,
                    padding: EdgeInsets.zero,
                    onSelected: (selected) {
                      if (selected) {
                        tripProvider.updateBuilderTripInfo(
                          currencyTarget: opt['code']!,
                        );
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Tabel konversi budget
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainer),
            ),
            child: Column(
              children: [
                // Target Anggaran
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Anggaran',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatCurrency(targetBudget),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      util.hasRates
                          ? util.formatCurrency(convertedTarget, targetCode)
                          : 'Kurs belum siap',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Total Biaya Wajib
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Biaya Wajib (Tiket + Retribusi)',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatCurrency(mandatoryCost),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      util.hasRates
                          ? util.formatCurrency(convertedMandatory, targetCode)
                          : '-',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Sisa / Defisit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDeficit
                                ? 'Defisit Anggaran'
                                : 'Sisa Anggaran Fleksibel',
                            style: AppTypography.bodySmall.copyWith(
                              color: isDeficit
                                  ? AppColors.error
                                  : AppColors.secondary,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${isDeficit ? "-" : ""}${_formatCurrency(remainingBudget.abs())}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.outline,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      util.hasRates
                          ? '${isDeficit ? "-" : ""}${util.formatCurrency(convertedRemaining, targetCode)}'
                          : '-',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDeficit
                            ? AppColors.error
                            : AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Footnote Kurs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  util.hasRates
                      ? 'Acuan: 1 $targetCode = Rp ${_formatRateIdr(unitRate)} IDR (Frankfurter API, ${util.formattedApiDate})'
                      : 'Data kurs belum dimuat',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.outline,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (util.isSyncing)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                InkWell(
                  onTap: () async {
                    await util.syncRates();
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sync,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Perbarui',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '*Anggaran utama tetap disimpan dalam Rupiah (IDR). Konversi mata uang disediakan sebagai panduan estimasi pengeluaran bagi wisatawan.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.outline,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // HELPER WIDGETS & FORMATTER UNTUK KURS 1 UNIT
  // ===========================================================================
  Widget _buildCurrencyChip({
    required String code,
    required String symbol,
    required String flag,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(flag, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '$code ($symbol)',
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  fontSize: 11.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRateRow({
    required String flag,
    required String pair,
    required String rate1,
    required String rate2,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primary.withAlpha(12)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary.withAlpha(60)
              : AppColors.surfaceContainer,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? AppColors.primary.withAlpha(20)
                  : AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(flag, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rate1,
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isHighlighted
                        ? AppColors.primary
                        : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rate2,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.outline,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          if (isHighlighted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Dipilih',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 9.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatRateIdr(double rate) {
    if (rate <= 0) return '0';
    final formatter = NumberFormat('#,##0.##', 'id_ID');
    return formatter.format(rate);
  }

  String _formatSmallRate(double rate) {
    if (rate <= 0) return '0';
    if (rate < 0.001) {
      return rate.toStringAsFixed(6);
    } else if (rate < 1) {
      return rate.toStringAsFixed(4);
    } else {
      return rate.toStringAsFixed(2);
    }
  }
}

// ----------------------------------------------------------------------------
// DIALOG GACHA: KOCOK HP MENGGUNAKAN SENSOR AKSELEROMETER FISIK (BUKAN DADU)
// ----------------------------------------------------------------------------
enum _GachaPhase { waitingShake, rollingSuspense, revealed }

class _GachaShakeDestinationDialog extends StatefulWidget {
  final List<DestinationModel> availableDestinations;
  final List<TripItemModel> existingItems;
  final Function(DestinationModel) onAddDestination;

  const _GachaShakeDestinationDialog({
    required this.availableDestinations,
    required this.existingItems,
    required this.onAddDestination,
  });

  @override
  State<_GachaShakeDestinationDialog> createState() => _GachaShakeDestinationDialogState();
}

class _GachaShakeDestinationDialogState extends State<_GachaShakeDestinationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  StreamSubscription<AccelerometerEvent>? _dialogShakeSub;
  Timer? _shufflingTimer;
  Timer? _countdownTimer;

  _GachaPhase _phase = _GachaPhase.waitingShake;
  String _rollingStepText = '⚡ Goyangan HP Terdeteksi! Mengacak rute...';
  String _currentCandidateName = 'Menyiapkan opsi destinasi...';
  DestinationModel? _revealedDestination;
  double _currentGForce = 9.8;
  DateTime _lastDialogShake = DateTime.now();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..repeat(reverse: true);

    _initDialogSensor();
  }

  void _initDialogSensor() {
    try {
      _dialogShakeSub = accelerometerEventStream().listen(
        (event) {
          if (!mounted || _phase != _GachaPhase.waitingShake) return;
          final double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          setState(() {
            _currentGForce = gForce;
          });

          // Deteksi hentakan fisik ponsel (> 13.5 m/s^2)
          if (gForce > 13.5) {
            final now = DateTime.now();
            if (now.difference(_lastDialogShake).inMilliseconds > 1200) {
              _lastDialogShake = now;
              _triggerRollSuspense();
            }
          }
        },
        onError: (err) {
          debugPrint('Shake sensor in dialog error: $err');
        },
      );
    } catch (e) {
      debugPrint('Shake sensor in dialog catch: $e');
    }
  }

  @override
  void dispose() {
    _dialogShakeSub?.cancel();
    _shufflingTimer?.cancel();
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _triggerRollSuspense() {
    _shufflingTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _phase = _GachaPhase.rollingSuspense;
      _rollingStepText = '⚡ Goyangan HP Terdeteksi! Mengacak rute...';
    });

    HapticFeedback.heavyImpact();

    final rand = Random();
    int shuffleIndex = 0;
    _shufflingTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      shuffleIndex++;
      final candidate = widget.availableDestinations[rand.nextInt(widget.availableDestinations.length)];
      setState(() {
        _currentCandidateName = candidate.name;
        if (shuffleIndex == 7) {
          _rollingStepText = '⛰️ Menganalisis spot lereng Merapi...';
        } else if (shuffleIndex == 14) {
          _rollingStepText = '✨ Destinasi kejutan ditemukan!';
        }
      });
    });

    // Jeda suspense 2.1 detik layaknya gacha
    _countdownTimer = Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      _shufflingTimer?.cancel();

      // Utamakan destinasi yang belum ada di itinerary trip
      final unadded = widget.availableDestinations.where((d) {
        return !widget.existingItems.any((item) => item.destinationId == d.id);
      }).toList();

      final pool = unadded.isNotEmpty ? unadded : widget.availableDestinations;
      final selected = pool[rand.nextInt(pool.length)];

      HapticFeedback.heavyImpact();

      setState(() {
        _revealedDestination = selected;
        _phase = _GachaPhase.revealed;
      });
    });
  }

  void _resetToWaitingShake() {
    setState(() {
      _phase = _GachaPhase.waitingShake;
    });
    _animController.repeat(reverse: true);
    HapticFeedback.lightImpact();
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
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.margin),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildCurrentPhaseView(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPhaseView() {
    switch (_phase) {
      case _GachaPhase.waitingShake:
        return _buildWaitingShakeView();
      case _GachaPhase.rollingSuspense:
        return _buildRollingSuspenseView();
      case _GachaPhase.revealed:
        return _buildRevealedView();
    }
  }

  // 1. PHASE 1: Menunggu HP Digoyang (Shake Listener Aktif)
  Widget _buildWaitingShakeView() {
    return Column(
      key: const ValueKey('waiting_shake_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // Visual Smartphone Shaking
        _buildSmartphoneGraphic(isShaking: true, isPulsing: false),
        const SizedBox(height: 20),

        // Main Instruction
        Text(
          'Goyangkan Ponselmu Sekarang!',
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),

        Text(
          'Kocok HP fisikmu ke kiri dan kanan. Sensor akselerometer akan otomatis memilihkan destinasi terbaik di lereng Merapi.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Status Sensor Aktif Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondaryContainer,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: AppColors.primary.withAlpha(60),
            ),
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
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Sensor Akselerometer Siaga: ${_currentGForce.toStringAsFixed(1)} m/s²',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Tombol Simulasi Manual (Fallback Emulator / Desktop)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(color: AppColors.primary.withAlpha(120)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
          ),
          onPressed: _triggerRollSuspense,
          icon: const Icon(Icons.touch_app, size: 18),
          label: const Text(
            'Simulasi Goyang HP (Ketuk Manual)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }

  // 2. PHASE 2: Animasi Jeda Suspense Gacha
  Widget _buildRollingSuspenseView() {
    return Column(
      key: const ValueKey('rolling_suspense_view'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),

        // Visual Smartphone Shaking & Glowing
        _buildSmartphoneGraphic(isShaking: true, isPulsing: true),
        const SizedBox(height: 20),

        // Rolling Step Status Text
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _rollingStepText,
            key: ValueKey(_rollingStepText),
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 6),

        Text(
          'Sedang mengocok destinasi terbaik lereng Merapi...',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Rapid Shuffling Candidate Ticker Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            border: Border.all(
              color: AppColors.primary.withAlpha(80),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  _currentCandidateName,
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Progress line
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          child: SizedBox(
            width: 140,
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 16),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    );
  }

  // 3. PHASE 3: Hasil Destinasi Terpilih (Reveal)
  Widget _buildRevealedView() {
    final dest = _revealedDestination;
    if (dest == null) return const SizedBox.shrink();

    return Column(
      key: const ValueKey('revealed_view'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Celebratory Header Pill
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFC58A32).withAlpha(25),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              border: Border.all(color: const Color(0xFFC58A32).withAlpha(120)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFC58A32), size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'DESTINASI KEJUTAN TERPILIH!',
                    style: AppTypography.labelSm.copyWith(
                      color: const Color(0xFFC58A32),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Destination Card
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(color: AppColors.surfaceContainer),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Image with Overlays
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: dest.imageUrl != null && dest.imageUrl!.startsWith('http')
                          ? Image.network(
                              dest.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.primaryContainer,
                                child: const Center(
                                  child: Icon(Icons.landscape, size: 40, color: Colors.white70),
                                ),
                              ),
                            )
                          : Container(
                              color: AppColors.primaryContainer,
                              child: const Center(
                                child: Icon(Icons.landscape, size: 40, color: Colors.white70),
                              ),
                            ),
                    ),
                    // Kategori Tag
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(220),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Text(
                          dest.categoryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // MDPL Badge
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                        child: Text(
                          '${dest.elevationMdpl} mdpl',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dest.name,
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Tiket: ${_formatCurrency(dest.ticketPrice)}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            dest.address,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dest.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              elevation: 2,
            ),
            onPressed: () {
              widget.onAddDestination(dest);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle, size: 20),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Tambahkan ke Rencana Trip',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                onPressed: _resetToWaitingShake,
                icon: const Icon(Icons.screen_rotation_alt, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Goyang HP Lagi (Kocok Ulang)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ],
    );
  }

  // Visual Ilustrasi Smartphone Bergetar / Bergoyang
  Widget _buildSmartphoneGraphic({required bool isShaking, required bool isPulsing}) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final angle = isShaking ? sin(_animController.value * pi * 4) * 0.22 : 0.0;
        final offsetX = isShaking ? sin(_animController.value * pi * 6) * 10.0 : 0.0;
        final scale = isPulsing ? 1.0 + (sin(_animController.value * pi * 2) * 0.08) : 1.0;

        return Transform.translate(
          offset: Offset(offsetX, 0),
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outer glowing halo
                  if (isPulsing)
                    Container(
                      width: 100,
                      height: 140,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(90),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                    ),

                  // Phone Body Frame
                  Container(
                    width: 72,
                    height: 124,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF263238), Color(0xFF1E282D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPulsing ? AppColors.primary : const Color(0xFF607D8B),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withAlpha(isPulsing ? 120 : 40),
                          blurRadius: isPulsing ? 20 : 10,
                          spreadRadius: isPulsing ? 4 : 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top Speaker Notch
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Container(
                            width: 18,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Center Screen Display
                        Container(
                          width: 58,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isPulsing
                                ? AppColors.primaryContainer
                                : const Color(0xFF101619),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              isPulsing ? Icons.auto_awesome : Icons.vibration,
                              color: isPulsing ? AppColors.onPrimary : AppColors.primary,
                              size: 28,
                            ),
                          ),
                        ),

                        // Bottom Home Indicator Bar
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            width: 24,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Left & Right Vibration Arc Icons
                  Positioned(
                    left: -18,
                    child: Icon(
                      Icons.graphic_eq,
                      color: AppColors.primary.withAlpha(isShaking ? 220 : 80),
                      size: 20,
                    ),
                  ),
                  Positioned(
                    right: -18,
                    child: Icon(
                      Icons.graphic_eq,
                      color: AppColors.primary.withAlpha(isShaking ? 220 : 80),
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


