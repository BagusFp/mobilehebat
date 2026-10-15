import 'package:flutter/foundation.dart';
import '../../data/models/destination_model.dart';
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

  // Builder State (Untuk Layar Buat Trip)
  TripModel? _builderTrip;
  List<TripItemModel> _builderItems = [];

  TripProvider({TripRepository? repository})
      : _repository = repository ?? TripRepository();

  // Getters
  List<TripModel> get allTrips => _allTrips;
  String get activeTab => _activeTab;
  TripModel? get selectedTrip => _selectedTrip;
  bool get isLoading => _isLoading;
  TripModel? get builderTrip => _builderTrip;
  List<TripItemModel> get builderItems => _builderItems;
  bool get isUsingCachedData => _repository.isUsingCachedData;
  String? get emptyCacheMessage => _emptyCacheMessage;

  List<TripModel> get displayedTrips {
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
    _allTrips = await _repository.getUserTrips(userId, forceOffline: forceOffline);

    if (_allTrips.isNotEmpty) {
      // Prioritaskan trip upcoming pertama
      final upcoming = _allTrips.where((t) => t.status == 'upcoming');
      _selectedTrip = upcoming.isNotEmpty ? upcoming.first : _allTrips.first;
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
        orElse: () => const TripModel(userId: 1, tripName: '', startDate: '', createdAt: ''),
      );
      return trip.items.any((item) => item.destinationId == destinationId);
    }
    return _allTrips.any((t) => t.items.any((item) => item.destinationId == destinationId));
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
    final itemCost = destination.ticketPrice > 0 ? (destination.ticketPrice * 2) : 10000.0;
    final newItem = TripItemModel(
      tripId: tripId,
      destinationId: destination.id,
      itemName: destination.name,
      itemSubtitle: '${destination.categoryName} • ${destination.address}',
      visitOrder: newItems.length + 1,
      plannedTime: '${12 + (newItems.length % 5)}:00 - ${13 + (newItems.length % 5)}:30',
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
    final newItems = trip.items.where((item) => item.destinationId != destinationId).toList();
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
    final finalTrip = (_builderTrip ?? const TripModel(userId: 1, tripName: 'Trip Baru', startDate: '', createdAt: '')).copyWith(
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
}
