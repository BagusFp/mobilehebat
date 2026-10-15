import 'package:flutter/foundation.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_expense_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../../data/repositories/trip_repository.dart';

class TripProvider extends ChangeNotifier {
  final TripRepository _repository;

  List<TripModel> _allTrips = [];
  String _activeTab = 'upcoming'; // 'upcoming', 'draft', 'completed'
  TripModel? _selectedTrip;
  bool _isLoading = false;
  String? _emptyCacheMessage;

  // Active Trip Expenses State
  List<TripExpenseModel> _activeTripExpenses = [];
  bool _isLoadingExpenses = false;

  // Builder State (Untuk Layar Buat Trip)
  TripModel? _builderTrip;
  List<TripItemModel> _builderItems = [];

  TripProvider({TripRepository? repository})
    : _repository = repository ?? TripRepository();

  void setTripsForTesting(List<TripModel> trips) {
    _allTrips = List.from(trips);
    if (_allTrips.isNotEmpty) {
      _selectedTrip = _allTrips.first;
    }
    notifyListeners();
  }

  // Getters
  List<TripModel> get allTrips => _allTrips;
  String get activeTab => _activeTab;
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  TripModel? get builderTrip => _builderTrip;
  List<TripItemModel> get builderItems => _builderItems;
  bool get isUsingCachedData => _repository.isUsingCachedData;
  String? get emptyCacheMessage => _emptyCacheMessage;
  List<TripExpenseModel> get activeTripExpenses => _activeTripExpenses;
  bool get isLoadingExpenses => _isLoadingExpenses;

  // Active Trip Progress & Budget Getters
  double get activeTripTotalExpenses =>
      _activeTripExpenses.fold(0.0, (sum, e) => sum + e.amount);

  double get activeTripRemainingBudget {
    final budget = _selectedTrip?.targetBudget ?? 0.0;
    return budget - activeTripTotalExpenses;
  }

  int get activeTripCompletedCount =>
      (_selectedTrip?.items ?? []).where((i) => i.isCompleted).length;

  int get activeTripTotalCount => (_selectedTrip?.items ?? []).length;

  double get activeTripProgress => activeTripTotalCount > 0
      ? activeTripCompletedCount / activeTripTotalCount
      : 0.0;

  TripItemModel? get nextDestination {
    if (_selectedTrip == null || _selectedTrip!.items.isEmpty) return null;
    final pending = _selectedTrip!.items.where((i) => !i.isCompleted).toList();
    return pending.isNotEmpty ? pending.first : null;
  }

  List<TripModel> get displayedTrips {
    if (_activeTab == 'upcoming') {
      final list = _allTrips
          .where(
            (t) =>
                t.status == 'upcoming' ||
                t.status == 'active' ||
                t.status == 'planned',
          )
          .toList();
      list.sort((a, b) {
        if (a.status == 'active' && b.status != 'active') return -1;
        if (b.status == 'active' && a.status != 'active') return 1;
        return (b.id ?? 0).compareTo(a.id ?? 0);
      });
      return list;
    }
    return _allTrips.where((t) => t.status == _activeTab).toList();
  }

  // Kalkulasi Anggaran Trip Builder
  double get totalTicketCost {
    double total = 0.0;
    for (final item in _builderItems) {
      total += item.estimatedCost;
    }
    return total;
  }

  double get parkingFee => 10000.0;
  double get totalMandatoryCost => totalTicketCost + parkingFee;
  double get targetBudget => _builderTrip?.targetBudget ?? 400000.0;
  double get remainingBudget => targetBudget - totalMandatoryCost;

  /// Mengatur target pagu anggaran pada pembuatan/edit trip
  void setBuilderTargetBudget(double newBudget) {
    if (newBudget < 0) return;
    if (_builderTrip != null) {
      _builderTrip = _builderTrip!.copyWith(targetBudget: newBudget);
      notifyListeners();
    }
  }

  /// Memperbarui informasi dasar trip builder (nama, tanggal, jumlah partisipan, zona waktu, mata uang)
  void updateBuilderTripInfo({
    String? tripName,
    String? startDate,
    int? participantCount,
    double? targetBudget,
    String? originCity,
    String? originTimezone,
    String? destinationCity,
    String? destinationTimezone,
    String? currencySource,
    String? currencyTarget,
    bool clearOrigin = false,
  }) {
    if (_builderTrip != null) {
      _builderTrip = _builderTrip!.copyWith(
        tripName: tripName ?? _builderTrip!.tripName,
        startDate: startDate ?? _builderTrip!.startDate,
        participantCount: participantCount ?? _builderTrip!.participantCount,
        targetBudget: targetBudget ?? _builderTrip!.targetBudget,
        originCity: clearOrigin ? null : (originCity ?? _builderTrip!.originCity),
        originTimezone: clearOrigin ? null : (originTimezone ?? _builderTrip!.originTimezone),
        destinationCity: destinationCity ?? _builderTrip!.destinationCity,
        destinationTimezone: destinationTimezone ?? _builderTrip!.destinationTimezone,
        currencySource: currencySource ?? _builderTrip!.currencySource,
        currencyTarget: currencyTarget ?? _builderTrip!.currencyTarget,
      );
      notifyListeners();
    }
  }

  /// Memperbarui jadwal waktu destinasi tertentu pada builder
  void updateBuilderItemSchedule(
    int index, {
    String? plannedTime,
    double? durationHours,
    String? itemSubtitle,
  }) {
    if (index >= 0 && index < _builderItems.length) {
      _builderItems[index] = _builderItems[index].copyWith(
        plannedTime: plannedTime ?? _builderItems[index].plannedTime,
        durationHours: durationHours ?? _builderItems[index].durationHours,
        itemSubtitle: itemSubtitle ?? _builderItems[index].itemSubtitle,
      );
      notifyListeners();
    }
  }

  /// Otomatis menyusun jadwal berurutan mulai dari jam start tertentu (misal jam 07:30)
  void autoScheduleBuilderItems({int startHour = 7, int startMinute = 30}) {
    if (_builderItems.isEmpty) return;

    int currentMinutes = startHour * 60 + startMinute;

    for (int i = 0; i < _builderItems.length; i++) {
      final item = _builderItems[i];
      final durationMins = (item.durationHours * 60).round();

      final startH = currentMinutes ~/ 60;
      final startM = currentMinutes % 60;

      final endMinutes = currentMinutes + durationMins;
      final endH = endMinutes ~/ 60;
      final endM = endMinutes % 60;

      final formattedStart =
          '${startH.toString().padLeft(2, '0')}:${startM.toString().padLeft(2, '0')}';
      final formattedEnd =
          '${endH.toString().padLeft(2, '0')}:${endM.toString().padLeft(2, '0')}';

      _builderItems[i] = item.copyWith(
        plannedTime: '$formattedStart - $formattedEnd',
      );

      final travelMins =
          item.connectingTimeMinutes > 0 ? item.connectingTimeMinutes : 15;
      currentMinutes = endMinutes + travelMins;
    }
    notifyListeners();
  }

  // Total Jam Aktivitas & Perjalanan
  double get totalActivityHours {
    double total = 0.0;
    for (final item in _builderItems) {
      total += item.durationHours;
    }
    return total;
  }

  int get totalTravelMinutes {
    int total = 0;
    for (final item in _builderItems) {
      total += item.connectingTimeMinutes;
    }
    return total;
  }

  /// Reset data di memori ketika pengguna logout agar tidak bocor ke akun lain
  void clearSession() {
    _allTrips = [];
    _selectedTrip = null;
    _emptyCacheMessage = null;
    _builderTrip = null;
    _builderItems = [];
    _activeTripExpenses = [];
    notifyListeners();
  }

  /// Memuat trip user dari database (online Supabase atau offline SQLite cache)
  Future<void> loadUserTrips(
    int? userId, {
    bool forceOffline = false,
    bool seedIfEmpty = true,
  }) async {
    if (userId == null || userId <= 0) {
      _allTrips = [];
      _selectedTrip = null;
      _emptyCacheMessage = null;
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _emptyCacheMessage = null;
    notifyListeners();

    if (seedIfEmpty) {
      await _repository.initTrips();
    }
    _allTrips = await _repository.getUserTrips(
      userId,
      forceOffline: forceOffline,
    );

    if (_allTrips.isNotEmpty) {
      // Prioritaskan trip aktif jika ada, lalu upcoming
      final active = _allTrips.where((t) => t.status == 'active');
      if (active.isNotEmpty) {
        _selectedTrip = active.first;
      } else {
        final upcoming = _allTrips.where(
          (t) => t.status == 'upcoming' || t.status == 'planned',
        );
        _selectedTrip = upcoming.isNotEmpty ? upcoming.first : _allTrips.first;
      }
    } else {
      _selectedTrip = null;
      if (_repository.isUsingCachedData) {
        _emptyCacheMessage =
            'Belum ada itinerary tersimpan secara offline untuk akun ini. Hubungkan internet untuk memuat itinerary Anda.';
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Pindah tab segment
  void setActiveTab(String tab) {
    _activeTab = tab;
    notifyListeners();
  }

  /// Pilih trip aktif
  void selectTrip(TripModel trip) {
    _selectedTrip = trip;
    notifyListeners();
  }

  TripModel? get activeOrUpcomingTrip {
    if (_selectedTrip != null) return _selectedTrip;
    final upcoming = _allTrips.where((t) => t.status == 'upcoming');
    if (upcoming.isNotEmpty) return upcoming.first;
    return _allTrips.isNotEmpty ? _allTrips.first : null;
  }

  bool isDestinationInTrip(int destinationId, {int? tripId}) {
    if (tripId != null) {
      final trip = _allTrips.firstWhere(
        (t) => t.id == tripId,
        orElse: () => const TripModel(
          userId: 1,
          tripName: '',
          startDate: '',
          createdAt: '',
        ),
      );
      return trip.items.any((item) => item.destinationId == destinationId);
    }
    return _allTrips.any(
      (t) => t.items.any((item) => item.destinationId == destinationId),
    );
  }

  /// Inisialisasi builder untuk membuat trip baru atau mengedit trip
  void initBuilderTrip({TripModel? existingTrip}) {
    if (existingTrip != null) {
      _builderTrip = existingTrip;
      _builderItems = List.from(existingTrip.items);
    } else {
      // Inisialisasi template default Eksplorasi Merapi 1 Hari
      _builderTrip = const TripModel(
        userId: 1,
        tripName: 'Eksplorasi Merapi 1 Hari',
        startDate: 'Sabtu, 19 Okt 2024',
        participantCount: 2,
        targetBudget: 400000.0,
        totalEstimatedCost: 64000.0,
        status: 'upcoming',
        createdAt: '2026-10-12',
        originCity: null,
        originTimezone: null,
        destinationCity: 'Gunung Merapi (Kaliadem)',
        destinationTimezone: 'Asia/Jakarta',
        currencySource: 'IDR',
        currencyTarget: 'USD',
      );
      _builderItems = [
        const TripItemModel(
          destinationId: 4,
          itemName: 'Plunyon Kalikuning',
          itemSubtitle: 'Spot Pagi & Jembatan Kabut',
          visitOrder: 1,
          plannedTime: '07:30 - 09:00',
          durationHours: 1.5,
          estimatedCost: 24000.0,
          elevationMdpl: 850,
          connectingDistanceKm: 4.2,
          connectingTimeMinutes: 15,
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuA6HAQwaq7wq_8-eUImi4tjKnM1vOcvJ_hRSUbUz4qWiScVAOeByPmjSysA5H1oEtsz77T4LThBx3IoO2vjKzh9UkywqtgZnQA-kegtLW-VXRTotaUjQY4mslwgaqIKLZddIib6jEl0dPV2yc7jO1LVqhWHzaNMVxTf9uoN_ildf9E3e7ZDAmI0THeQHx_PNJE0fYPIGkL9U5xKrMe-vmrRQuoQFFCeN4liGmmwciXYL7863Q-uKSM',
        ),
        const TripItemModel(
          destinationId: 1,
          itemName: 'Bunker Kaliadem',
          itemSubtitle: 'Panorama Puncak & Edukasi Vulkanik',
          visitOrder: 2,
          plannedTime: '09:30 - 11:00',
          durationHours: 1.5,
          estimatedCost: 20000.0,
          elevationMdpl: 1165,
          connectingDistanceKm: 3.1,
          connectingTimeMinutes: 12,
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDZH75v3H_TMxQjZHfcUBtUAqj_5mxEGn7WAZEI6GQocm2pLjbV0b3DkA-9r_Jv8IrzDaN3a-7Ih5gNXYzgDusrT-ebJp7qz9hTLf06oKyU11JYAHGT0A8XfDW-7tM18Mv0QGbLseC-JfmVvPY---e-pBz24Jsju0rAH3V0gfqG7t4g1as7mFAVI21gOM_2oeue_dzxY-bUIY8JXnCgUP32iAQ9BiSdn45Tg-qiVl53FrbAu-5Sk-s',
        ),
        const TripItemModel(
          destinationId: 2,
          itemName: 'Museum Sisa Hartaku',
          itemSubtitle: 'Museum Memori Erupsi 2010',
          visitOrder: 3,
          plannedTime: '11:30 - 13:00',
          durationHours: 1.0,
          estimatedCost: 10000.0,
          elevationMdpl: 920,
          connectingDistanceKm: 0.0,
          connectingTimeMinutes: 0,
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuC5LH2AvqiTusX2RgGlXiopRQygq3lbqDOiDkoapnWWdq1mJcZo-6zYBQ8uqVNjoistBtgO7gnwSgQuPA74i7YZnjVdv4ZDg9MhsNCAbsn2zwP2BdnnAn34k2gL8gw0uoE7J5oopEZDt_NMrwj7-IT-HhfyJytQcI9SRMGu3A-wz0ZRsilU8YRG8nn_30BcKeKVSO_6q27cjK4pmm5FtfAgT--4GpGxbfTUHVvzxtqSJeVMw7WUGNQ',
        ),
      ];
    }
    notifyListeners();
  }

  /// Hapus item dari builder
  void removeBuilderItem(int index) {
    if (index >= 0 && index < _builderItems.length) {
      _builderItems.removeAt(index);
      // Re-index visit orders
      for (int i = 0; i < _builderItems.length; i++) {
        _builderItems[i] = _builderItems[i].copyWith(visitOrder: i + 1);
      }
      notifyListeners();
    }
  }

  /// Reorder items pada builder list
  void reorderBuilderItems(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _builderItems.removeAt(oldIndex);
    _builderItems.insert(newIndex, item);

    for (int i = 0; i < _builderItems.length; i++) {
      _builderItems[i] = _builderItems[i].copyWith(visitOrder: i + 1);
    }
    notifyListeners();
  }

  /// Tambah destinasi baru ke builder trip
  void addDestinationToBuilder(DestinationModel dest) {
    final newOrder = _builderItems.length + 1;
    final itemCost = dest.ticketPrice > 0 ? (dest.ticketPrice * 2) : 10000.0;

    final newItem = TripItemModel(
      destinationId: dest.id,
      itemName: dest.name,
      itemSubtitle: '${dest.categoryName} • ${dest.address}',
      visitOrder: newOrder,
      plannedTime: '13:30 - 15:00',
      durationHours: 1.5,
      estimatedCost: itemCost,
      imageUrl: dest.imageUrl,
      elevationMdpl: dest.elevationMdpl,
      connectingDistanceKm: 3.5,
      connectingTimeMinutes: 15,
    );

    _builderItems.add(newItem);
    notifyListeners();
  }

  /// Bersihkan builder items
  void clearBuilderItems() {
    _builderItems.clear();
    notifyListeners();
  }

  /// Inisialisasi builder trip baru dari satu destinasi awal
  void initBuilderWithDestination(DestinationModel dest) {
    final ticketCost = dest.ticketPrice > 0 ? (dest.ticketPrice * 2) : 10000.0;
    _builderTrip = TripModel(
      userId: 1,
      tripName: 'Wisata ${dest.name}',
      startDate: 'Sabtu, 26 Okt 2024',
      participantCount: 2,
      targetBudget: 450000.0,
      totalEstimatedCost: ticketCost + 10000.0,
      status: 'upcoming',
      createdAt: DateTime.now().toIso8601String(),
      originCity: null,
      originTimezone: null,
      destinationCity: dest.name,
      destinationTimezone: 'Asia/Jakarta',
      currencySource: 'IDR',
      currencyTarget: 'USD',
    );
    _builderItems = [
      TripItemModel(
        destinationId: dest.id,
        itemName: dest.name,
        itemSubtitle: '${dest.categoryName} • ${dest.address}',
        visitOrder: 1,
        plannedTime: '08:00 - 09:30',
        durationHours: 1.5,
        estimatedCost: ticketCost,
        imageUrl: dest.imageUrl,
        elevationMdpl: dest.elevationMdpl,
        connectingDistanceKm: 3.5,
        connectingTimeMinutes: 15,
      ),
    ];
    notifyListeners();
  }

  /// Tambahkan destinasi ke trip yang sudah ada (misalnya trip aktif saat ini)
  Future<bool> addDestinationToExistingTrip({
    required int tripId,
    required DestinationModel destination,
  }) async {
    final tripIndex = _allTrips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return false;

    final trip = _allTrips[tripIndex];
    if (trip.items.any((item) => item.destinationId == destination.id)) {
      return true; // Sudah ada di trip
    }

    final newItems = List<TripItemModel>.from(trip.items);
    final itemCost = destination.ticketPrice > 0
        ? (destination.ticketPrice * 2)
        : 10000.0;
    final newItem = TripItemModel(
      tripId: tripId,
      destinationId: destination.id,
      itemName: destination.name,
      itemSubtitle: '${destination.categoryName} • ${destination.address}',
      visitOrder: newItems.length + 1,
      plannedTime:
          '${12 + (newItems.length % 5)}:00 - ${13 + (newItems.length % 5)}:30',
      durationHours: 1.5,
      estimatedCost: itemCost,
      imageUrl: destination.imageUrl,
      elevationMdpl: destination.elevationMdpl,
      connectingDistanceKm: 4.0,
      connectingTimeMinutes: 15,
    );
    newItems.add(newItem);

    final updatedCost = trip.totalEstimatedCost + itemCost;

    final updatedTrip = trip.copyWith(
      items: newItems,
      totalEstimatedCost: updatedCost,
    );

    _allTrips[tripIndex] = updatedTrip;
    if (_selectedTrip?.id == tripId) {
      _selectedTrip = updatedTrip;
    }
    notifyListeners();

    await _repository.updateTrip(updatedTrip);
    return true;
  }

  /// Hapus destinasi dari trip yang sudah ada
  Future<bool> removeDestinationFromTrip({
    required int tripId,
    required int destinationId,
  }) async {
    final tripIndex = _allTrips.indexWhere((t) => t.id == tripId);
    if (tripIndex == -1) return false;

    final trip = _allTrips[tripIndex];
    final newItems = trip.items
        .where((item) => item.destinationId != destinationId)
        .toList();
    for (int i = 0; i < newItems.length; i++) {
      newItems[i] = newItems[i].copyWith(visitOrder: i + 1);
    }

    double newCost = 10000.0; // Biaya parkir dasar
    for (final it in newItems) {
      newCost += it.estimatedCost;
    }

    final updatedTrip = trip.copyWith(
      items: newItems,
      totalEstimatedCost: newCost,
    );

    _allTrips[tripIndex] = updatedTrip;
    if (_selectedTrip?.id == tripId) {
      _selectedTrip = updatedTrip;
    }
    notifyListeners();

    await _repository.updateTrip(updatedTrip);
    return true;
  }

  /// Simpan builder trip ke SQLite (menangani create baru maupun update edit)
  Future<void> saveBuilderTrip(int userId, {String status = 'upcoming'}) async {
    final finalTrip =
        (_builderTrip ??
                const TripModel(
                  userId: 1,
                  tripName: 'Trip Baru',
                  startDate: '',
                  createdAt: '',
                ))
            .copyWith(
              userId: userId,
              status: status,
              totalEstimatedCost: totalMandatoryCost,
              createdAt: DateTime.now().toIso8601String(),
              items: _builderItems,
            );

    if (_builderTrip?.id != null) {
      await _repository.updateTrip(finalTrip.copyWith(id: _builderTrip!.id));
    } else {
      await _repository.createTrip(finalTrip);
    }
    await loadUserTrips(userId);
  }

  /// Simpan trip kustom langsung (misalnya rekomendasi dari AI Assistant)
  Future<void> createTrip(TripModel trip) async {
    final id = await _repository.createTrip(trip);
    final savedTrip = trip.copyWith(id: id);
    await loadUserTrips(trip.userId);
    if (!_allTrips.any((t) => t.tripName == trip.tripName)) {
      _allTrips.insert(0, savedTrip);
    }
    notifyListeners();
  }

  /// Toggle reminder trip
  Future<void> toggleReminder(int tripId) async {
    final index = _allTrips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final newStatus = !_allTrips[index].reminderEnabled;
      _allTrips[index] = _allTrips[index].copyWith(reminderEnabled: newStatus);
      if (_selectedTrip?.id == tripId) {
        _selectedTrip = _selectedTrip!.copyWith(reminderEnabled: newStatus);
      }
      notifyListeners();
      await _repository.toggleReminder(tripId, newStatus);
    }
  }

  /// Toggle offline status trip
  Future<void> toggleOffline(int tripId) async {
    final index = _allTrips.indexWhere((t) => t.id == tripId);
    if (index != -1) {
      final newStatus = !_allTrips[index].isSavedOffline;
      _allTrips[index] = _allTrips[index].copyWith(isSavedOffline: newStatus);
      if (_selectedTrip?.id == tripId) {
        _selectedTrip = _selectedTrip!.copyWith(isSavedOffline: newStatus);
      }
      notifyListeners();
      await _repository.toggleOffline(tripId, newStatus);
    }
  }

  /// Hapus trip
  Future<void> deleteTrip(int tripId, int userId) async {
    await _repository.deleteTrip(tripId);
    await loadUserTrips(userId);
  }

  // ===========================================================================
  // MODE PERJALANAN AKTIF (ACTIVE TRIP & EXPENSES)
  // ===========================================================================

  /// Memuat riwayat pengeluaran aktual untuk trip tertentu
  Future<void> loadTripExpenses(int tripId) async {
    _isLoadingExpenses = true;
    notifyListeners();
    try {
      _activeTripExpenses = await _repository.getTripExpenses(tripId);
    } catch (_) {
      _activeTripExpenses = [];
    }
    _isLoadingExpenses = false;
    notifyListeners();
  }

  /// Memulai mode perjalanan aktif untuk suatu trip
  Future<void> startActiveTrip(int tripId) async {
    await _repository.startTrip(tripId);
    final updatedTrip = await _repository.getTripWithItems(tripId);
    if (updatedTrip != null) {
      _selectedTrip = updatedTrip;
      final idx = _allTrips.indexWhere((t) => t.id == tripId);
      if (idx != -1) {
        _allTrips[idx] = updatedTrip;
      }
    } else if (_selectedTrip != null && _selectedTrip!.id == tripId) {
      _selectedTrip = _selectedTrip!.copyWith(
        status: 'active',
        startedAt: DateTime.now().toIso8601String(),
      );
    }
    await loadTripExpenses(tripId);
    notifyListeners();
  }

  /// Menandai destinasi sudah dikunjungi secara manual
  Future<void> markDestinationCompleted(int tripId, int itemId) async {
    if (_selectedTrip == null) return;

    // Cegah double completion jika sudah selesai
    final item = _selectedTrip!.items.firstWhere(
      (it) => it.id == itemId,
      orElse: () => const TripItemModel(itemName: '', visitOrder: 0),
    );
    if (item.isCompleted) return;

    await _repository.markDestinationVisited(tripId, itemId, true);

    final updatedItems = _selectedTrip!.items.map((it) {
      if (it.id == itemId) {
        return it.copyWith(
          isCompleted: true,
          completedAt: DateTime.now().toIso8601String(),
        );
      }
      return it;
    }).toList();

    _selectedTrip = _selectedTrip!.copyWith(items: updatedItems);
    final tripIdx = _allTrips.indexWhere((t) => t.id == tripId);
    if (tripIdx != -1) {
      _allTrips[tripIdx] = _selectedTrip!;
    }

    // Auto-akumulasi: jika destinasi memiliki harga tiket dan belum dicatat,
    // otomatis masukkan ke daftar pengeluaran aktual
    if (item.estimatedCost > 0) {
      final alreadyRecorded = _activeTripExpenses.any(
        (exp) =>
            exp.destinationId == item.destinationId ||
            exp.destinationName == item.itemName,
      );
      if (!alreadyRecorded) {
        final autoExpense = TripExpenseModel(
          tripId: tripId,
          userId: _selectedTrip!.userId,
          destinationId: item.destinationId,
          destinationName: item.itemName,
          category: 'Tiket & Retribusi',
          amount: item.estimatedCost,
          notes: 'Tiket masuk ${item.itemName} (Otomatis saat kunjungan)',
          spentAt: DateTime.now().toIso8601String(),
          createdAt: DateTime.now().toIso8601String(),
        );
        await addExpense(autoExpense);
      }
    }

    notifyListeners();
  }

  /// Mengubah target alokasi anggaran trip
  Future<void> updateTripTargetBudget(int tripId, double newTargetBudget) async {
    if (newTargetBudget < 0) return;
    if (_selectedTrip != null && _selectedTrip!.id == tripId) {
      _selectedTrip = _selectedTrip!.copyWith(targetBudget: newTargetBudget);
    }
    final tripIdx = _allTrips.indexWhere((t) => t.id == tripId);
    if (tripIdx != -1) {
      _allTrips[tripIdx] =
          _allTrips[tripIdx].copyWith(targetBudget: newTargetBudget);
      await _repository.updateTrip(_allTrips[tripIdx]);
    }
    notifyListeners();
  }

  /// Mencatat pengeluaran aktual baru
  Future<void> addExpense(TripExpenseModel expense) async {
    final id = await _repository.addExpense(expense);
    final savedExpense = expense.copyWith(id: id);
    _activeTripExpenses.insert(0, savedExpense);

    if (_selectedTrip != null) {
      _selectedTrip = _selectedTrip!.copyWith(
        totalActualCost: activeTripTotalExpenses,
      );
      final tripIdx = _allTrips.indexWhere((t) => t.id == expense.tripId);
      if (tripIdx != -1) {
        _allTrips[tripIdx] = _selectedTrip!;
      }
    }
    notifyListeners();
  }

  /// Menghapus catatan pengeluaran
  Future<void> removeExpense(int expenseId, int tripId) async {
    await _repository.deleteExpense(expenseId, tripId);
    _activeTripExpenses.removeWhere((e) => e.id == expenseId);

    if (_selectedTrip != null) {
      _selectedTrip = _selectedTrip!.copyWith(
        totalActualCost: activeTripTotalExpenses,
      );
      final tripIdx = _allTrips.indexWhere((t) => t.id == tripId);
      if (tripIdx != -1) {
        _allTrips[tripIdx] = _selectedTrip!;
      }
    }
    notifyListeners();
  }

  /// Mengakhiri perjalanan aktif
  Future<void> finishActiveTrip(int tripId) async {
    final totalActual = activeTripTotalExpenses;
    await _repository.completeTrip(tripId, totalActualCost: totalActual);

    final completedTime = DateTime.now().toIso8601String();
    if (_selectedTrip != null && _selectedTrip!.id == tripId) {
      _selectedTrip = _selectedTrip!.copyWith(
        status: 'completed',
        completedAt: completedTime,
        totalActualCost: totalActual,
      );
    }
    final tripIdx = _allTrips.indexWhere((t) => t.id == tripId);
    if (tripIdx != -1) {
      _allTrips[tripIdx] = _allTrips[tripIdx].copyWith(
        status: 'completed',
        completedAt: completedTime,
        totalActualCost: totalActual,
      );
    }
    notifyListeners();
  }

  /// Memilih dan memuat trip berdasarkan ID beserta rincian item & pengeluarannya
  Future<TripModel?> selectTripById(int tripId) async {
    final trip = await _repository.getTripWithItems(tripId);
    if (trip != null) {
      _selectedTrip = trip;
      await loadTripExpenses(tripId);
      notifyListeners();
    }
    return trip;
  }
}
