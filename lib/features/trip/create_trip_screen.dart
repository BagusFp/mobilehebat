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
import '../../core/utils/geo_helper.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../auth/auth_provider.dart';
import '../explore/destination_provider.dart';
import '../utility/utility_provider.dart';
import '../../core/services/notification_service.dart';
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
  late int _currentStep; // 1: Info & Budget, 2: Destinasi & Jadwal, 3: Ringkasan & Notifikasi
  late TextEditingController _tripNameController;
  late TextEditingController _budgetController;
  String _selectedCurrency = 'IDR';
  String _selectedCurrencyDisplay = 'IDR (Rp)';
  String _selectedTimezoneDisplay = 'WIB (GMT+7) – Lokal Merapi';
  DateTime _selectedDate = DateTime.now();
  bool _isReminderEnabled = true;
  String _selectedReminderDisplay = 'H-1 Jam Sebelum Perjalanan (06:30 WIB)';
  int _reminderDays = 0;
  int _reminderHours = 1;
  int _reminderMinutes = 0;
  TimeOfDay? _specificReminderTime;

  DateTime _getCalculatedReminderDateTime(List<TripItemModel> items) {
    if (_specificReminderTime != null) {
      DateTime target = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _specificReminderTime!.hour,
        _specificReminderTime!.minute,
      );
      final now = DateTime.now();
      if (target.isBefore(now.subtract(const Duration(minutes: 1)))) {
        if (_selectedDate.year == now.year &&
            _selectedDate.month == now.month &&
            _selectedDate.day == now.day) {
          target = target.add(const Duration(days: 1));
        }
      }
      return target;
    }

    DateTime tripStart = _selectedDate;
    String firstTime = '07:30';
    if (items.isNotEmpty && items.first.plannedTime.isNotEmpty) {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(items.first.plannedTime);
      if (match != null) {
        firstTime = '${match.group(1)}:${match.group(2)}';
      }
    }
    final parts = firstTime.split(':');
    final hour = int.tryParse(parts[0]) ?? 7;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '30') ?? 30;
    tripStart = DateTime(tripStart.year, tripStart.month, tripStart.day, hour, minute);

    final totalBeforeDuration = Duration(
      days: _reminderDays,
      hours: _reminderHours,
      minutes: _reminderMinutes,
    );
    DateTime trigger = tripStart.subtract(totalBeforeDuration);
    final now = DateTime.now();
    if (trigger.isBefore(now.subtract(const Duration(minutes: 1)))) {
      if (_selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day) {
        trigger = trigger.add(const Duration(days: 1));
      }
    }
    return trigger;
  }

  StreamSubscription<AccelerometerEvent>? _shakeSubscription;
  DateTime _lastShakeTime = DateTime.now();
  bool _isGachaOpen = false;
  bool _isSavingDraft = false;
  bool _isSavingTrip = false;
  String _savingStatusText = 'Menyimpan trip...';

  double _parseBudget(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 0.0;
    final normalized = clean.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(normalized) ?? 0.0;
  }

  (double, double) _computeBudgets(String text, String currency) {
    final orig = _parseBudget(text);
    if (orig <= 0) return (0.0, 0.0);
    if (currency == 'IDR') return (orig, orig);
    UtilityProvider? util;
    try {
      util = context.read<UtilityProvider>();
    } catch (_) {}
    final rate = _getCurrencyRateToIdr(util, currency);
    final idr = (orig * rate).roundToDouble();
    return (orig, idr);
  }

  double _getCurrencyRateToIdr(UtilityProvider? util, String currency) {
    if (currency == 'IDR') return 1.0;
    if (util != null && util.hasRates && util.rates.containsKey(currency)) {
      final converted = util.convert(amount: 1.0, fromCode: currency, toCode: 'IDR');
      if (converted > 0) return converted;
    }
    switch (currency) {
      case 'USD':
        return 15873.015874;
      case 'EUR':
        return 17200.0;
      case 'SGD':
        return 11850.0;
      case 'JPY':
        return 105.0;
      case 'MYR':
        return 3580.0;
      default:
        return 1.0;
    }
  }

  String _getCurrencySymbol(String cur) {
    switch (cur.toUpperCase()) {
      case 'IDR':
        return 'Rp ';
      case 'USD':
        return r'$ ';
      case 'SGD':
        return r'S$ ';
      case 'EUR':
        return '€ ';
      case 'JPY':
        return '¥ ';
      case 'MYR':
        return 'RM ';
      default:
        return '$cur ';
    }
  }

  @override
  void initState() {
    super.initState();
    _currentStep = widget.existingTrip != null
        ? widget.existingTrip!.currentStep.clamp(1, 3)
        : 1;
    if (widget.existingTrip != null && widget.existingTrip!.startDate.isNotEmpty) {
      final parsed = DateTime.tryParse(widget.existingTrip!.startDate);
      _selectedDate = parsed ?? DateTime.now();
    } else {
      _selectedDate = DateTime.now();
    }

    if (widget.existingTrip != null &&
        widget.existingTrip!.currencySource != null &&
        widget.existingTrip!.currencySource!.isNotEmpty) {
      final cur = widget.existingTrip!.currencySource!.toUpperCase().trim();
      _selectedCurrency = cur;
      switch (cur) {
        case 'USD':
          _selectedCurrencyDisplay = r'USD ($)';
          break;
        case 'EUR':
          _selectedCurrencyDisplay = 'EUR (€)';
          break;
        case 'SGD':
          _selectedCurrencyDisplay = r'SGD (S$)';
          break;
        case 'JPY':
          _selectedCurrencyDisplay = 'JPY (¥)';
          break;
        case 'MYR':
          _selectedCurrencyDisplay = 'MYR (RM)';
          break;
        default:
          _selectedCurrencyDisplay = 'IDR (Rp)';
          _selectedCurrency = 'IDR';
      }
    }

    if (widget.existingTrip != null &&
        widget.existingTrip!.originTimezone != null &&
        widget.existingTrip!.originTimezone!.isNotEmpty) {
      final origin = widget.existingTrip!.originTimezone!;
      const availableTimezones = [
        'WIB (GMT+7) – Lokal Merapi',
        'London / GMT (-7 Jam)',
        'WITA (GMT+8) – Bali/Makassar',
        'WIT (GMT+9) – Maluku/Papua',
        'UTC (GMT+0) – Internasional',
        'JST (GMT+9) – Tokyo',
        'SGT (GMT+8) – Singapura',
      ];
      final matchedTz = availableTimezones.firstWhere(
        (tz) {
          if (tz == origin) return true;
          if (tz.startsWith('WITA') && origin.contains('WITA')) return true;
          if (tz.startsWith('WIT ') && origin.contains('WIT') && !origin.contains('WITA')) return true;
          if (tz.startsWith('London') && (origin.contains('London') || origin.contains('-7 Jam'))) return true;
          final code = tz.substring(0, 3);
          return origin.contains(code);
        },
        orElse: () => 'WIB (GMT+7) – Lokal Merapi',
      );
      _selectedTimezoneDisplay = matchedTz;
    }

    _tripNameController = TextEditingController(
      text: widget.existingTrip?.tripName ?? '',
    );

    String initialBudgetText = '';
    if (widget.existingTrip != null) {
      final orig = widget.existingTrip!.effectiveOriginalBudget;
      if (orig > 0) {
        initialBudgetText = orig % 1 == 0 ? orig.toInt().toString() : orig.toString();
      }
    }
    _budgetController = TextEditingController(text: initialBudgetText);

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
        _budgetController.text = initialBudgetText;
        if (mounted) {
          setState(() {
            _currentStep = widget.existingTrip!.currentStep.clamp(1, 3);
          });
        }
      } else if (widget.initialDestination != null) {
        tripProvider.initBuilderWithDestination(widget.initialDestination!);
        _tripNameController.text = 'Wisata ${widget.initialDestination!.name}';
      } else {
        // Mode Buat Trip Baru: selalu mulai kosong tanpa destinasi otomatis
        tripProvider.initBuilderTrip(empty: true);
        _tripNameController.text = '';
        _budgetController.text = '';
        _currentStep = 1;
        _selectedDate = DateTime.now();
        tripProvider.updateBuilderTripInfo(
          startDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        );
      }
    });
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _tripNameController.dispose();
    _budgetController.dispose();
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

  String get _stepProgressLabel {
    switch (_currentStep) {
      case 1:
        return 'LANGKAH 1 DARI 3: INFO & BUDGET';
      case 2:
        return 'LANGKAH 2 DARI 3: DESTINASI & JADWAL';
      case 3:
        return 'LANGKAH 3 DARI 3: RINGKASAN & NOTIFIKASI';
      default:
        return '';
    }
  }

  String get _stepProgressPercent {
    switch (_currentStep) {
      case 1:
        return '33%';
      case 2:
        return '67%';
      case 3:
        return '100%';
      default:
        return '100%';
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

  String _formatCurrency(double price) {
    if (price <= 0) return 'Gratis';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  String _formatIdr(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount.round());
  }

  Map<String, dynamic> _computeRealRouteBetween(
    TripItemModel fromItem,
    TripItemModel toItem,
    List<DestinationModel> allDestinations,
  ) {
    DestinationModel? findDest(TripItemModel item) {
      if (item.destinationId != null) {
        final match = allDestinations.where((d) => d.id == item.destinationId);
        if (match.isNotEmpty) return match.first;
      }
      final nameLower = item.itemName.toLowerCase().trim();
      final match = allDestinations.where(
        (d) =>
            d.name.toLowerCase().trim() == nameLower ||
            nameLower.contains(d.name.toLowerCase().trim()) ||
            d.name.toLowerCase().trim().contains(nameLower),
      );
      if (match.isNotEmpty) return match.first;
      return null;
    }

    final destA = findDest(fromItem);
    final destB = findDest(toItem);

    double distanceKm = fromItem.connectingDistanceKm;
    int timeMinutes = fromItem.connectingTimeMinutes;
    String roadName = 'Kawasan Wisata Merapi';

    if (destA != null && destB != null) {
      final directDist = GeoHelper.calculateDistanceKm(
        startLat: destA.latitude,
        startLng: destA.longitude,
        endLat: destB.latitude,
        endLng: destB.longitude,
      );
      // Jalan lereng berliku memiliki faktor liku jalan sekitar 1.25x - 1.35x
      final roadDist = (directDist * 1.3).clamp(0.8, 45.0);
      distanceKm = double.parse(roadDist.toStringAsFixed(1));
      // Kecepatan rata-rata motor/mobil di jalan lereng 25 km/jam
      timeMinutes = (roadDist / 25.0 * 60).clamp(5, 120).round();

      // Deteksi nama jalan dari alamat destinasi B atau A jika tersedia
      final addrB = destB.address.toLowerCase();
      if (addrB.contains('kaliurang')) {
        roadName = 'Jl. Kaliurang';
      } else if (addrB.contains('boyong')) {
        roadName = 'Jl. Boyong';
      } else if (addrB.contains('bebeng')) {
        roadName = 'Jl. Bebeng';
      } else if (addrB.contains('palagan')) {
        roadName = 'Jl. Palagan Tentara Pelajar';
      } else if (destB.categoryName.isNotEmpty) {
        roadName = 'Jalur Wisata ${destB.categoryName}';
      }
    }

    return {
      'distanceKm': distanceKm,
      'timeMinutes': timeMinutes,
      'roadName': roadName,
    };
  }

  Widget _buildConnectingRouteIndicator(
    BuildContext context,
    TripItemModel fromItem,
    TripItemModel toItem,
  ) {
    final destProvider = context.read<DestinationProvider>();
    final routeInfo = _computeRealRouteBetween(
      fromItem,
      toItem,
      destProvider.allDestinations,
    );
    final double distKm = routeInfo['distanceKm'] as double;
    final int timeMins = routeInfo['timeMinutes'] as int;
    final String road = routeInfo['roadName'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF045E44),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Perjalanan via $road ($timeMins mnt • ${distKm.toStringAsFixed(1)} km)',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF475569),
                fontWeight: FontWeight.w500,
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
              color: Color(0xFF045E44),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildStepNodeItem(int stepNumber, String title, IconData icon) {
    final isCurrent = _currentStep == stepNumber;
    final isDone = _currentStep > stepNumber;

    Widget circleWidget;
    if (isCurrent) {
      // Tahap aktif: Lingkaran hijau tua dengan halo hijau muda lembut di luarnya
      circleWidget = Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFD1FAE5),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF045E44),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
        ),
      );
    } else if (isDone) {
      // Tahap selesai: Lingkaran hijau tua dengan ikon checkmark putih
      circleWidget = Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF045E44),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.check,
          size: 16,
          color: Colors.white,
        ),
      );
    } else {
      // Tahap belum aktif: Lingkaran abu-abu/hijau pucat dengan ikon abu-abu
      circleWidget = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFE2EBE5),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 15,
          color: const Color(0xFF64748B),
        ),
      );
    }

    return InkWell(
      onTap: () {
        if (stepNumber == 3 && context.read<TripProvider>().builderItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Silakan tambah minimal 1 destinasi terlebih dahulu.'),
              backgroundColor: AppColors.volcanoStatusWaspada,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        context.read<TripProvider>().updateBuilderTripInfo(currentStep: stepNumber);
        setState(() => _currentStep = stepNumber);
      },
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 38,
            child: Center(child: circleWidget),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isCurrent
                  ? FontWeight.bold
                  : isDone
                      ? FontWeight.w600
                      : FontWeight.w500,
              color: isCurrent
                  ? const Color(0xFF045E44)
                  : isDone
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = context.watch<TripProvider>();
    final authProvider = context.watch<AuthProvider>();
    final items = tripProvider.builderItems;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top MeraTrip Branding Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF045E44),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.terrain_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'MeraTrip',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF045E44),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.notifications_none_rounded, size: 20, color: Color(0xFF334155)),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: const Color(0xFFD1FAE5),
                            backgroundImage: (authProvider.currentUser?.profilePhoto != null &&
                                    authProvider.currentUser!.profilePhoto!.isNotEmpty &&
                                    authProvider.currentUser!.profilePhoto!.startsWith('http'))
                                ? NetworkImage(authProvider.currentUser!.profilePhoto!)
                                : null,
                            child: (authProvider.currentUser?.profilePhoto == null ||
                                    authProvider.currentUser!.profilePhoto!.isEmpty)
                                ? const Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: Color(0xFF045E44),
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Title & Draft / Close Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Trip Baru',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Atur budget & jadwal',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: _isSavingDraft
                                ? null
                                : () async {
                                    setState(() => _isSavingDraft = true);
                                    try {
                                      final authProvider = context.read<AuthProvider>();
                                      final tripProvider = context.read<TripProvider>();
                                      final userId = authProvider.currentUser?.id ?? 1;
                                      final tripName = _tripNameController.text.trim();
                                      final budgets = _computeBudgets(_budgetController.text, _selectedCurrency);
                                      final finalIdrBudget = budgets.$2 > 0 ? budgets.$2 : (tripProvider.targetBudget > 0 ? tripProvider.targetBudget : null);
                                      final finalOrigBudget = budgets.$1 > 0 ? budgets.$1 : (tripProvider.builderTrip?.targetBudgetOriginal ?? finalIdrBudget);
                                      tripProvider.updateBuilderTripInfo(
                                        tripName: tripName.isNotEmpty ? tripName : null,
                                        targetBudget: finalIdrBudget,
                                        targetBudgetOriginal: finalOrigBudget,
                                        currencySource: _selectedCurrency,
                                        originTimezone: _selectedTimezoneDisplay,
                                        currentStep: _currentStep,
                                      );
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
                                    } finally {
                                      if (mounted) setState(() => _isSavingDraft = false);
                                    }
                                  },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.lock_outline, size: 12, color: Color(0xFF92400E)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Draft',
                                    style: TextStyle(
                                      color: Color(0xFF92400E),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stepper Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _stepProgressLabel,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              _stepProgressPercent,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final itemWidth = constraints.maxWidth / 3;
                            final circleCenterOffset = itemWidth / 2;
                            return Stack(
                              children: [
                                Positioned(
                                  top: 18,
                                  left: circleCenterOffset,
                                  right: circleCenterOffset,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 2.5,
                                          color: _currentStep > 1
                                              ? const Color(0xFF045E44)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 2.5,
                                          color: _currentStep > 2
                                              ? const Color(0xFF045E44)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildStepNodeItem(
                                        1,
                                        '1. Info & Budget',
                                        Icons.tune_rounded,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStepNodeItem(
                                        2,
                                        '2. Destinasi & Jadwal',
                                        Icons.place_outlined,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildStepNodeItem(
                                        3,
                                        '3. Ringkasan & Notifikasi',
                                        Icons.receipt_long_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Scrollable Step Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_currentStep == 1)
                          _buildStep1BudgetAwal(context, tripProvider),
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
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Destinasi Terpilih',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
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
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
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
                                  'Belum ada destinasi',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Pilih destinasi untuk memulai perjalanan',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF045E44),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _showAddDestinationModal(context),
                                  icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                                  label: const Text(
                                    'Pilih Destinasi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: items.length,
                            onReorderItem: (oldIdx, newIdx) {
                              tripProvider.reorderBuilderItems(oldIdx, oldIdx < newIdx ? newIdx + 1 : newIdx);
                            },
                            itemBuilder: (context, idx) {
                              final item = items[idx];
                              return Container(
                                key: ValueKey('dest_item_${item.id ?? idx}_${item.visitOrder}'),
                                child: Column(
                                  children: [
                                    _buildDestinationCard(
                                      context,
                                      item,
                                      idx,
                                      items.length,
                                      tripProvider,
                                    ),
                                    if (idx < items.length - 1)
                                      _buildConnectingRouteIndicator(
                                        context,
                                        item,
                                        items[idx + 1],
                                      ),
                                    const SizedBox(height: 8),
                                  ],
                                ),
                              );
                            },
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

                  // Gamified Kocok HP / Gacha Destination Banner (Enlarged)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFECFDF5),
                            const Color(0xFFFEF3C7).withAlpha(180),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF6EE7B7),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withAlpha(15),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF045E44),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(30),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.screen_rotation_alt_rounded,
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
                                        const Text(
                                          'Bingung Mau ke Mana?',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFD97706),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'GACHA',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Fitur Sensor Gyroscope & Accelerometer',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF059669),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Goyangkan HP Anda secara nyata atau ketuk tombol di bawah untuk mendapatkan rekomendasi destinasi acak terbaik di kawasan lereng Merapi.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF045E44),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => _openGachaShakeDialog(context),
                              icon: const Icon(Icons.screen_rotation_alt_rounded, size: 18),
                              label: const Text(
                                'Goyang HP / Buka Rekomendasi Gacha',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                ),
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
                    child: Builder(
                      builder: (context) {
                        final util = Provider.of<UtilityProvider?>(context);
                        final rate = _getCurrencyRateToIdr(util, _selectedCurrency);
                        final enteredBudget = _parseBudget(_budgetController.text);
                        final userBudget = enteredBudget > 0 ? enteredBudget : tripProvider.targetBudget;
                        final targetBudgetIdr = _selectedCurrency == 'IDR' ? userBudget : (userBudget * rate);
                        final totalMandatoryCost = tripProvider.totalMandatoryCost;
                        final remainingBudget = targetBudgetIdr - totalMandatoryCost;
                        final isOverBudget = remainingBudget < 0;

                        return Container(
                          padding: const EdgeInsets.all(AppDimensions.spaceMd),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppDimensions.roundedXl,
                            border: Border.all(
                              color: isOverBudget
                                  ? const Color(0xFFFDA4AF)
                                  : AppColors.surfaceContainer,
                              width: isOverBudget ? 1.5 : 1.0,
                            ),
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
                                        Icon(
                                          isOverBudget
                                              ? Icons.warning_amber_rounded
                                              : Icons.analytics,
                                          size: 20,
                                          color: isOverBudget
                                              ? const Color(0xFFE11D48)
                                              : AppColors.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            'Kalkulator Rencana Trip',
                                            style: AppTypography.titleMd.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isOverBudget
                                                  ? const Color(0xFFBE123C)
                                                  : AppColors.onSurface,
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
                                      color: isOverBudget
                                          ? const Color(0xFFFFE4E6)
                                          : AppColors.secondaryContainer,
                                      borderRadius: AppDimensions.roundedFull,
                                    ),
                                    child: Text(
                                      isOverBudget ? 'Perlu Disesuaikan' : 'Update Otomatis',
                                      style: AppTypography.labelSm.copyWith(
                                        color: isOverBudget
                                            ? const Color(0xFFBE123C)
                                            : AppColors.onSecondaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spaceMd),

                              // Baris Pagu Target Anggaran
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.account_balance_wallet_outlined,
                                          size: 16,
                                          color: AppColors.outline,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'Pagu Anggaran ($_selectedCurrency)',
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
                                    _selectedCurrency == 'IDR'
                                        ? _formatIdr(targetBudgetIdr)
                                        : '${_getCurrencySymbol(_selectedCurrency)}${userBudget.toStringAsFixed(0)} (≈ ${_formatIdr(targetBudgetIdr)})',
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

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

                          // Budget Health Indicator & Over Budget Warning
                          Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.spaceSm,
                            ),
                            decoration: BoxDecoration(
                              color: isOverBudget
                                  ? const Color(0xFFFFF1F2)
                                  : AppColors.secondaryContainer.withAlpha(120),
                              borderRadius: AppDimensions.roundedLg,
                              border: Border.all(
                                color: isOverBudget
                                    ? const Color(0xFFFECDD3)
                                    : Colors.transparent,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: isOverBudget
                                              ? const Color(0xFFE11D48)
                                              : AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isOverBudget
                                              ? Icons.warning_amber_rounded
                                              : Icons.check_circle,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isOverBudget
                                                  ? 'Sisa Target Budget (Defisit)'
                                                  : 'Sisa Target Budget',
                                              style: AppTypography.labelSm
                                                  .copyWith(
                                                    color: isOverBudget
                                                        ? const Color(0xFF9F1239)
                                                        : AppColors
                                                            .onSecondaryContainer,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              isOverBudget
                                                  ? '- ${_formatIdr(remainingBudget.abs())}'
                                                  : _formatIdr(remainingBudget),
                                              style: AppTypography.titleMd
                                                  .copyWith(
                                                    color: isOverBudget
                                                        ? const Color(0xFFE11D48)
                                                        : AppColors.primary,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (_selectedCurrency != 'IDR')
                                              Text(
                                                isOverBudget
                                                    ? '≈ - ${_getCurrencySymbol(_selectedCurrency)}${(remainingBudget.abs() / (rate > 0 ? rate : 1)).toStringAsFixed(1)}'
                                                    : '≈ ${_getCurrencySymbol(_selectedCurrency)}${(remainingBudget / (rate > 0 ? rate : 1)).toStringAsFixed(1)}',
                                                style: AppTypography.bodySm.copyWith(
                                                  color: isOverBudget
                                                      ? const Color(0xFFBE123C)
                                                      : AppColors.onSurfaceVariant,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
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
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isOverBudget
                                              ? const Color(0xFFFFE4E6)
                                              : AppColors.surfaceContainerLowest,
                                          borderRadius:
                                              AppDimensions.roundedSm,
                                        ),
                                        child: Text(
                                          isOverBudget
                                              ? 'OVER BUDGET'
                                              : 'SANGAT AMAN',
                                          style: AppTypography.labelSm.copyWith(
                                            color: isOverBudget
                                                ? const Color(0xFFBE123C)
                                                : AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isOverBudget
                                            ? 'Kurangi destinasi'
                                            : 'Untuk makan & oleh-oleh',
                                        style: AppTypography.bodySm.copyWith(
                                          color: isOverBudget
                                              ? const Color(0xFF9F1239)
                                              : AppColors.onSurfaceVariant,
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

                          if (isOverBudget) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: AppDimensions.roundedMd,
                                border: Border.all(
                                  color: const Color(0xFFFDA4AF),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFE11D48),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Perhatian: Estimasi biaya perjalanan melebihi target anggaran sebesar ${_formatIdr(remainingBudget.abs())}${_selectedCurrency != 'IDR' ? ' (≈ ${_getCurrencySymbol(_selectedCurrency)}${(remainingBudget.abs() / (rate > 0 ? rate : 1)).toStringAsFixed(1)})' : ''}. Harap kurangi destinasi berbayar atau sesuaikan budget di Langkah 1.',
                                      style: AppTypography.bodySm.copyWith(
                                        color: const Color(0xFF9F1239),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],

                        if (_currentStep == 3)
                          _buildStep3RingkasanNotif(context, tripProvider, items),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Sticky Action Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: _buildBottomButtons(context, tripProvider, authProvider, items),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(
    BuildContext context,
    TripProvider tripProvider,
    AuthProvider authProvider,
    List<TripItemModel> items,
  ) {
    if (_currentStep == 1) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF045E44),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
          onPressed: () {
            final budgets = _computeBudgets(_budgetController.text, _selectedCurrency);
            final validIdr = budgets.$2 > 0 ? budgets.$2 : tripProvider.targetBudget;
            final validOrig = budgets.$1 > 0 ? budgets.$1 : (tripProvider.builderTrip?.targetBudgetOriginal ?? validIdr);
            if (validIdr <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Silakan masukkan target budget yang valid.'),
                  backgroundColor: AppColors.volcanoStatusWaspada,
                  duration: Duration(seconds: 2),
                ),
              );
              return;
            }
            context.read<TripProvider>().updateBuilderTripInfo(
              tripName: _tripNameController.text.trim().isNotEmpty ? _tripNameController.text.trim() : null,
              targetBudget: validIdr,
              targetBudgetOriginal: validOrig,
              currencySource: _selectedCurrency,
              originTimezone: _selectedTimezoneDisplay,
              currentStep: 2,
            );
            setState(() => _currentStep = 2);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Lanjut ke Destinasi & Jadwal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      );
    }

    if (_currentStep == 2) {
      return Row(
        children: [
          SizedBox(
            width: 110,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                context.read<TripProvider>().updateBuilderTripInfo(currentStep: 1);
                setState(() => _currentStep = 1);
              },
              child: const Text(
                'Kembali',
                style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF045E44),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: () {
                  if (items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Silakan tambah minimal 1 destinasi terlebih dahulu.'),
                        backgroundColor: AppColors.volcanoStatusWaspada,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }
                  context.read<TripProvider>().updateBuilderTripInfo(currentStep: 3);
                  setState(() => _currentStep = 3);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Lanjut ke Ringkasan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // _currentStep == 3
    return Row(
      children: [
        SizedBox(
          width: 110,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isSavingTrip
                ? null
                : () {
                    context.read<TripProvider>().updateBuilderTripInfo(currentStep: 2);
                    setState(() => _currentStep = 2);
                  },
            child: const Text(
              'Kembali',
              style: TextStyle(color: Color(0xFF334155), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF045E44),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: _isSavingTrip
                  ? null
                  : () async {
                      setState(() {
                        _isSavingTrip = true;
                        _savingStatusText = 'Menyimpan info trip...';
                      });

                      try {
                        final userId = authProvider.currentUser?.id ?? 1;
                        final tripName = _tripNameController.text.trim().isNotEmpty
                            ? _tripNameController.text.trim()
                            : 'Eksplorasi Merapi';

                        final budgets = _computeBudgets(_budgetController.text, _selectedCurrency);
                        final budgetVal = budgets.$2 > 0 ? budgets.$2 : (tripProvider.targetBudget > 0 ? tripProvider.targetBudget : null);
                        final origVal = budgets.$1 > 0 ? budgets.$1 : (tripProvider.builderTrip?.targetBudgetOriginal ?? budgetVal);
                        tripProvider.updateBuilderTripInfo(
                          tripName: tripName,
                          targetBudget: budgetVal,
                          targetBudgetOriginal: origVal,
                          originTimezone: _selectedTimezoneDisplay,
                          currencySource: _selectedCurrency,
                        );

                        setState(() {
                          _savingStatusText = 'Menyimpan itinerary...';
                        });

                        await tripProvider.saveBuilderTrip(userId);

                        if (_isReminderEnabled) {
                          setState(() {
                            _savingStatusText = 'Menyiapkan pengingat notifikasi...';
                          });

                          final triggerTime = _getCalculatedReminderDateTime(items);
                          final savedTripId = tripProvider.builderTrip?.id ??
                              (tripProvider.allTrips.isNotEmpty
                                  ? (tripProvider.allTrips.firstWhere(
                                      (t) => t.tripName == tripName,
                                      orElse: () => tripProvider.allTrips.first,
                                    ).id ?? (DateTime.now().millisecondsSinceEpoch % 100000))
                                  : (DateTime.now().millisecondsSinceEpoch % 100000));

                          await NotificationService().scheduleTripReminderAtTime(
                            tripId: savedTripId,
                            tripTitle: tripName,
                            triggerTime: triggerTime,
                            startDestinationName: items.isNotEmpty ? items.first.itemName : null,
                          );
                        }

                        // Pilih trip baru sebagai active trip agar langsung tampil di My Trip
                        if (tripProvider.allTrips.isNotEmpty) {
                          final savedTrip = tripProvider.allTrips.firstWhere(
                            (t) => t.tripName == tripName,
                            orElse: () => tripProvider.allTrips.first,
                          );
                          tripProvider.selectTrip(savedTrip);
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Trip "$tripName" berhasil disimpan!'),
                              backgroundColor: const Color(0xFF045E44),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          Navigator.of(context).pop();
                        }
                      } catch (err) {
                        if (context.mounted) {
                          setState(() {
                            _isSavingTrip = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Gagal menyimpan trip: $err. Silakan coba lagi.'),
                              backgroundColor: const Color(0xFFE11D48),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      }
                    },
              child: _isSavingTrip
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _savingStatusText,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.check_circle_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Simpan Trip',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildDestinationCard(
    BuildContext context,
    TripItemModel item,
    int index,
    int totalItems,
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
          // Drag Handle & Stop Number Badge + Reorder controls
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: const Icon(
                    Icons.drag_indicator,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 2),
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
              if (totalItems > 1) ...[
                const SizedBox(height: 4),
                if (index > 0)
                  InkWell(
                    onTap: () {
                      provider.reorderBuilderItems(index, index - 1);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(1.0),
                      child: Icon(Icons.arrow_drop_up, size: 20, color: Color(0xFF045E44)),
                    ),
                  ),
                if (index < totalItems - 1)
                  InkWell(
                    onTap: () {
                      provider.reorderBuilderItems(index, index + 2);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(1.0),
                      child: Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF045E44)),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(width: 10),

          // Thumbnail with Image
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
                  : const Icon(Icons.landscape, color: AppColors.onPrimary),
            ),
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

                // Jam Kunjungan yang Jelas & Redesigned
                InkWell(
                  onTap: () => _showEditTimeDialog(context, index, item, provider),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    margin: const EdgeInsets.only(top: 6, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time_filled,
                          size: 14,
                          color: Color(0xFF045E44),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.plannedTime,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF045E44),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(width: 1, height: 12, color: const Color(0xFF6EE7B7)),
                        const SizedBox(width: 6),
                        Text(
                          '${item.durationHours} Jam',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_note_rounded,
                          size: 15,
                          color: Color(0xFF059669),
                        ),
                      ],
                    ),
                  ),
                ),

                // Biaya Tiket
                Row(
                  children: [
                    const Icon(
                      Icons.confirmation_number_outlined,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.estimatedCost > 0
                            ? _formatCurrency(item.estimatedCost)
                            : 'Gratis Tiket Masuk',
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
  // STEP 1: BUDGET AWAL & INFORMASI PERJALANAN (Screenshot 1)
  // ===========================================================================
  Widget _buildStep1BudgetAwal(
    BuildContext context,
    TripProvider tripProvider,
  ) {
    final trip = tripProvider.builderTrip;
    final participantCount = trip?.participantCount ?? 2;
    final util = Provider.of<UtilityProvider?>(context);
    final rate = _getCurrencyRateToIdr(util, _selectedCurrency);
    final enteredBudget = _parseBudget(_budgetController.text);
    final idrEquivalent = enteredBudget * rate;

    final String budgetSubtitleText;
    if (_selectedCurrency == 'IDR') {
      budgetSubtitleText = '*Pagu anggaran langsung disimpan dalam IDR Rupiah';
    } else {
      final formattedIdr = NumberFormat('#,###', 'id_ID').format(idrEquivalent.round());
      budgetSubtitleText = '*Setara dengan Rp $formattedIdr IDR';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARD 1: INFORMASI PERJALANAN
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.explore_outlined, color: Color(0xFF1E293B), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'INFO TRIP',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Nama Trip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tripNameController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: Eksplorasi Lereng Merapi',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF045E44), width: 1.5),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  onChanged: (val) {
                    tripProvider.updateBuilderTripInfo(tripName: val);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    // Tanggal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tanggal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _selectedDate = picked);
                                tripProvider.updateBuilderTripInfo(
                                  startDate: DateFormat('yyyy-MM-dd').format(picked),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('MM/dd/yyyy').format(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Peserta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Peserta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                InkWell(
                                  onTap: participantCount > 1
                                      ? () => tripProvider.updateBuilderTripInfo(
                                            participantCount: participantCount - 1,
                                          )
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.remove, size: 16, color: Color(0xFF059669)),
                                  ),
                                ),
                                Text(
                                  '$participantCount Orang',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => tripProvider.updateBuilderTripInfo(
                                    participantCount: participantCount + 1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add, size: 16, color: Color(0xFF059669)),
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
              ],
            ),
          ),
          const SizedBox(height: 14),

          // CARD 2: TARGET BUDGET & PERSONALISASI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF6EE7B7)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withAlpha(8),
                  blurRadius: 8,
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
                        Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E293B), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'TARGET BUDGET & PERSONALISASI',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Wajib',
                        style: TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Pagu Target Anggaran Utama',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Input TextField dengan simbol mata uang dinamis
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF6EE7B7)),
                        ),
                        child: Row(
                          children: [
                            Text(
                              _getCurrencySymbol(_selectedCurrency),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _budgetController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                                onChanged: (val) {
                                  final budgets = _computeBudgets(val, _selectedCurrency);
                                  if (budgets.$1 > 0) {
                                    tripProvider.setBuilderTargetBudget(
                                      budgets.$2,
                                      targetBudgetOriginal: budgets.$1,
                                    );
                                  }
                                  setState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Currency dropdown
                    Container(
                      height: 48,
                      width: 105,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF6EE7B7)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedCurrencyDisplay,
                          items: const [
                            DropdownMenuItem(value: 'IDR (Rp)', child: Text('IDR (Rp)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: r'USD ($)', child: Text(r'USD ($)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'EUR (€)', child: Text('EUR (€)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: r'SGD (S$)', child: Text(r'SGD (S$)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'JPY (¥)', child: Text('JPY (¥)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: 'MYR (RM)', child: Text('MYR (RM)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedCurrencyDisplay = val;
                                _selectedCurrency = val.split(' ').first;
                              });
                              final budgets = _computeBudgets(_budgetController.text, _selectedCurrency);
                              tripProvider.updateBuilderTripInfo(
                                currencySource: _selectedCurrency,
                                targetBudget: budgets.$2 > 0 ? budgets.$2 : null,
                                targetBudgetOriginal: budgets.$1 > 0 ? budgets.$1 : null,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  budgetSubtitleText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF0F5132),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFD1FAE5), height: 1, thickness: 1),
                const SizedBox(height: 12),
                const Text(
                  'Zona Waktu Asal Pengguna',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedTimezoneDisplay,
                      items: const [
                        DropdownMenuItem(value: 'WIB (GMT+7) – Lokal Merapi', child: Text('WIB (GMT+7) – Lokal Merapi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'London / GMT (-7 Jam)', child: Text('London / GMT (-7 Jam)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'WITA (GMT+8) – Bali/Makassar', child: Text('WITA (GMT+8) – Bali/Makassar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'WIT (GMT+9) – Maluku/Papua', child: Text('WIT (GMT+9) – Maluku/Papua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'UTC (GMT+0) – Internasional', child: Text('UTC (GMT+0) – Internasional', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'JST (GMT+9) – Tokyo', child: Text('JST (GMT+9) – Tokyo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'SGT (GMT+8) – Singapura', child: Text('SGT (GMT+8) – Singapura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedTimezoneDisplay = val);
                          tripProvider.updateBuilderTripInfo(originTimezone: val);
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
    );
  }

  // ===========================================================================
  // STEP 3: RINGKASAN ANGGARAN & NOTIFIKASI (Screenshot 2)
  // ===========================================================================
  Widget _buildStep3RingkasanNotif(
    BuildContext context,
    TripProvider tripProvider,
    List<TripItemModel> items,
  ) {
    final enteredVal = double.tryParse(_budgetController.text.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    final util = Provider.of<UtilityProvider?>(context);
    double rate = 1.0;
    if (_selectedCurrency != 'IDR') {
      if (util != null && util.hasRates && util.rates.containsKey(_selectedCurrency)) {
        final convertedRate = util.convert(amount: 1.0, fromCode: _selectedCurrency, toCode: 'IDR');
        rate = convertedRate > 0 ? convertedRate : rate;
      } else {
        switch (_selectedCurrency) {
          case 'USD':
            rate = 15873.015874;
            break;
          case 'EUR':
            rate = 17200.0;
            break;
          case 'SGD':
            rate = 11850.0;
            break;
          case 'JPY':
            rate = 105.0;
            break;
          case 'MYR':
            rate = 3580.0;
            break;
          default:
            rate = 1.0;
            break;
        }
      }
    }
    final isNonIdr = _selectedCurrency != 'IDR';
    final symbol = _getCurrencySymbol(_selectedCurrency);

    double targetBudgetIDR;
    double convertedTarget = 0.0;
    if (isNonIdr) {
      targetBudgetIDR = enteredVal * rate;
      convertedTarget = enteredVal;
    } else {
      targetBudgetIDR = enteredVal > 0 ? enteredVal : tripProvider.targetBudget;
    }

    final totalTicketIDR = tripProvider.totalTicketCost;
    final convertedTicket = isNonIdr && rate > 0 ? totalTicketIDR / rate : 0.0;

    final remainingIDR = targetBudgetIDR - totalTicketIDR;
    final convertedRemaining = isNonIdr && rate > 0 ? remainingIDR / rate : 0.0;

    final idrFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final secondaryCurCode = _selectedCurrency;
    final tripName = _tripNameController.text.trim().isNotEmpty
        ? _tripNameController.text.trim()
        : 'Trip Merapi';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CARD 0A: INFO TRIP
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.info_outline, color: Color(0xFF1E293B), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'INFO TRIP',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF1E293B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nama Trip',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tripName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tanggal & Peserta',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(_selectedDate)} • ${tripProvider.builderTrip?.participantCount ?? 2} Orang',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
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
          ),

          // CARD 0B: DAFTAR DESTINASI & JADWAL
          if (items.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(4),
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
                          Icon(Icons.route_outlined, color: Color(0xFF1E293B), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'DESTINASI & JADWAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${items.length} Tempat',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(items.length, (idx) {
                    final it = items[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF045E44),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              it.itemName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            it.plannedTime.isNotEmpty ? it.plannedTime : 'Belum dijadwalkan',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // CARD 1: RINGKASAN BUDGET
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
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
                        Icon(Icons.receipt_long_outlined, color: Color(0xFF1E293B), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'RINGKASAN BUDGET',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedCurrencyDisplay,
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Target Budget Awal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Target Budget Awal:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          idrFormatter.format(targetBudgetIDR),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (isNonIdr) ...[
                          const SizedBox(height: 1),
                          Text(
                            '$symbol ${convertedTarget.toStringAsFixed(2)} $secondaryCurCode',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Total Biaya Tiket
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Biaya Tiket:',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '- ${idrFormatter.format(totalTicketIDR)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                        if (isNonIdr) ...[
                          const SizedBox(height: 1),
                          Text(
                            '- $symbol ${convertedTicket.toStringAsFixed(2)} $secondaryCurCode',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFE11D48),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                // Sisa Anggaran
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sisa Anggaran:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          idrFormatter.format(remainingIDR),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (isNonIdr) ...[
                          const SizedBox(height: 1),
                          Text(
                            '$symbol ${convertedRemaining.toStringAsFixed(2)} $secondaryCurCode',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // CARD 2: ATUR PENGINGAT NOTIFIKASI TRIP
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(4),
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
                        Icon(Icons.notifications_active_outlined, color: Color(0xFF059669), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'PENGINGAT TRIP',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isReminderEnabled,
                      activeThumbColor: const Color(0xFF059669),
                      activeTrackColor: const Color(0xFF059669).withAlpha(120),
                      onChanged: (val) {
                        setState(() => _isReminderEnabled = val);
                      },
                    ),
                  ],
                ),
                if (_isReminderEnabled) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Waktu Pengiriman Pengingat:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _showReminderSelectionModal(context),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedReminderDisplay,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _pickCustomReminderTime(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF045E44),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.schedule, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Pilih Jam',
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
                  const SizedBox(height: 10),
                  Builder(
                    builder: (context) {
                      final targetDt = _getCalculatedReminderDateTime(items);
                      final targetH = targetDt.hour.toString().padLeft(2, '0');
                      final targetM = targetDt.minute.toString().padLeft(2, '0');
                      final now = DateTime.now();
                      final isToday = targetDt.year == now.year &&
                          targetDt.month == now.month &&
                          targetDt.day == now.day;
                      final dateLabel = isToday
                          ? 'Hari Ini'
                          : '${targetDt.day}/${targetDt.month}/${targetDt.year}';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_alarm_rounded,
                              color: Color(0xFF045E44),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Notifikasi akan dikirimkan pada: $dateLabel pukul $targetH:$targetM WIB',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF045E44),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomReminderTime(BuildContext context) async {
    final nowTime = TimeOfDay.now();
    final initial = _specificReminderTime ??
        TimeOfDay(
          hour: (nowTime.hour + 1) % 24,
          minute: nowTime.minute,
        );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'PILIH JAM PENGIRIMAN NOTIFIKASI TRIP',
      confirmText: 'TERAPKAN',
      cancelText: 'BATAL',
    );
    if (picked != null) {
      final h = picked.hour.toString().padLeft(2, '0');
      final m = picked.minute.toString().padLeft(2, '0');
      setState(() {
        _specificReminderTime = picked;
        _selectedReminderDisplay = 'Tepat Pukul $h:$m WIB';
      });
    }
  }

  void _showReminderSelectionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pilih Waktu Pengingat Notifikasi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF045E44), size: 20),
                    ),
                    title: const Text(
                      'Pilih Jam Pengiriman Spesifik (Time Picker)',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF045E44)),
                    ),
                    subtitle: Text(
                      _specificReminderTime != null
                          ? 'Saat ini: ${_specificReminderTime!.hour.toString().padLeft(2, '0')}:${_specificReminderTime!.minute.toString().padLeft(2, '0')} WIB'
                          : 'Tentukan jam dan menit secara bebas',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Color(0xFF045E44)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickCustomReminderTime(context);
                    },
                  ),
                  const Divider(),
                  _buildReminderOption(
                    title: 'H-15 Menit Sebelum Perjalanan',
                    days: 0,
                    hours: 0,
                    minutes: 15,
                    ctx: ctx,
                  ),
                  _buildReminderOption(
                    title: 'H-30 Menit Sebelum Perjalanan',
                    days: 0,
                    hours: 0,
                    minutes: 30,
                    ctx: ctx,
                  ),
                  _buildReminderOption(
                    title: 'H-1 Jam Sebelum Perjalanan',
                    days: 0,
                    hours: 1,
                    minutes: 0,
                    ctx: ctx,
                  ),
                  _buildReminderOption(
                    title: 'H-2 Jam Sebelum Perjalanan',
                    days: 0,
                    hours: 2,
                    minutes: 0,
                    ctx: ctx,
                  ),
                  _buildReminderOption(
                    title: 'H-3 Jam Sebelum Perjalanan',
                    days: 0,
                    hours: 3,
                    minutes: 0,
                    ctx: ctx,
                  ),
                  _buildReminderOption(
                    title: 'H-1 Hari Sebelum Perjalanan',
                    days: 1,
                    hours: 0,
                    minutes: 0,
                    ctx: ctx,
                  ),
                  _buildReminderOption(
                    title: 'H-3 Hari Sebelum Perjalanan',
                    days: 3,
                    hours: 0,
                    minutes: 0,
                    ctx: ctx,
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.tune, color: Color(0xFF045E44)),
                    title: const Text(
                      'Kustom (Pilih Hari, Jam, Menit)...',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF045E44), fontSize: 13),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showCustomReminderDialog(context);
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

  Widget _buildReminderOption({
    required String title,
    required int days,
    required int hours,
    required int minutes,
    required BuildContext ctx,
  }) {
    final isSelected = _specificReminderTime == null && _selectedReminderDisplay == title;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF045E44) : const Color(0xFF0F172A),
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check, color: Color(0xFF045E44), size: 18) : null,
      onTap: () {
        setState(() {
          _specificReminderTime = null;
          _reminderDays = days;
          _reminderHours = hours;
          _reminderMinutes = minutes;
          _selectedReminderDisplay = title;
        });
        Navigator.pop(ctx);
      },
    );
  }

  void _showCustomReminderDialog(BuildContext context) {
    int tempDays = _reminderDays;
    int tempHours = _reminderHours;
    int tempMinutes = _reminderMinutes;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.alarm_add_rounded, color: Color(0xFF045E44)),
                  SizedBox(width: 8),
                  Text('Kustom Waktu Pengingat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tentukan H- berapa hari, jam, dan menit sebelum trip dimulai Anda ingin mendapatkan notifikasi:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  _buildStepperRow('Hari Sebelum', tempDays, 0, 30, (val) {
                    setDialogState(() => tempDays = val);
                  }),
                  const SizedBox(height: 10),
                  _buildStepperRow('Jam Sebelum', tempHours, 0, 23, (val) {
                    setDialogState(() => tempHours = val);
                  }),
                  const SizedBox(height: 10),
                  _buildStepperRow('Menit Sebelum', tempMinutes, 0, 59, (val) {
                    setDialogState(() => tempMinutes = val);
                  }),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF045E44),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final List<String> parts = [];
                    if (tempDays > 0) parts.add('$tempDays Hari');
                    if (tempHours > 0) parts.add('$tempHours Jam');
                    if (tempMinutes > 0) parts.add('$tempMinutes Menit');
                    final str = parts.isEmpty
                        ? 'Tepat Saat Perjalanan Dimulai'
                        : 'H-${parts.join(" ")} Sebelum Perjalanan';

                    setState(() {
                      _reminderDays = tempDays;
                      _reminderHours = tempHours;
                      _reminderMinutes = tempMinutes;
                      _selectedReminderDisplay = str;
                    });
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Terapkan Pengingat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStepperRow(String label, int value, int min, int max, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 22, color: Color(0xFF64748B)),
              onPressed: value > min ? () => onChanged(value - 1) : null,
            ),
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              alignment: Alignment.center,
              child: Text(
                '$value',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 22, color: Color(0xFF045E44)),
              onPressed: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

}

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


