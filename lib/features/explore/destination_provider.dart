import 'package:flutter/foundation.dart';
import '../../data/models/category_model.dart';
import '../../data/models/destination_model.dart';
import '../../data/repositories/destination_repository.dart';

class DestinationProvider extends ChangeNotifier {
  final DestinationRepository _repository;

  List<DestinationModel> _allDestinations = [];
  List<DestinationModel> _displayedDestinations = [];
  List<CategoryModel> _categories = [];
  Set<int> _favoriteIds = {};
  Set<int> _offlineSavedIds = {};

  String _searchQuery = '';
  String _selectedCategory = 'Semua';
  String _sortOption = 'Destinasi Populer';
  bool _isGridView = false;
  bool _isLoading = false;
  String? _offlineNotice;
  DestinationModel? _selectedDestination;

  DestinationProvider({DestinationRepository? repository})
      : _repository = repository ?? DestinationRepository() {
    _categories = [
      ..._repository.getCategories(),
      const CategoryModel(id: 99, name: 'Favorit', iconName: 'favorite', count: 0),
    ];
  }

  // Getters
  List<DestinationModel> get allDestinations => _allDestinations;
  List<DestinationModel> get displayedDestinations => _displayedDestinations;
  List<CategoryModel> get categories => _categories;
  Set<int> get favoriteIds => _favoriteIds;
  Set<int> get offlineSavedIds => _offlineSavedIds;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  String get sortOption => _sortOption;
  bool get isGridView => _isGridView;
  bool get isLoading => _isLoading;
  bool get isUsingCachedData => _repository.isUsingCachedData;
  String? get offlineNotice => _offlineNotice;
  DestinationModel? get selectedDestination => _selectedDestination;
  int get offlineSavedCount => _offlineSavedIds.length;

  /// Inisialisasi dan memuat destinasi serta status favorit
  Future<void> loadDestinations({
    int? userId,
    bool forceOffline = false,
    bool seedIfEmpty = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    if (seedIfEmpty) {
      await _repository.initDestinations();
    }
    _allDestinations = await _repository.getAllDestinations(forceOffline: forceOffline);

    // Cache status offline
    _offlineSavedIds = _allDestinations
        .where((d) => d.isSavedOffline)
        .map((d) => d.id)
        .toSet();

    if (userId != null && userId > 0) {
      _favoriteIds = await _repository.getFavoriteDestinationIds(userId);
    } else {
      _favoriteIds = {};
    }

    if (_allDestinations.isEmpty && isUsingCachedData) {
      _offlineNotice =
          'Data destinasi belum tersedia dalam penyimpanan lokal (cache kosong). Sambungkan perangkat ke internet untuk memuat data pertama kali.';
    } else {
      _offlineNotice = null;
    }

    _applyFilterAndSort();

    _isLoading = false;
    notifyListeners();
  }

  /// Update pencarian
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilterAndSort();
    notifyListeners();
  }

  /// Bersihkan pencarian
  void clearSearch() {
    _searchQuery = '';
    _applyFilterAndSort();
    notifyListeners();
  }

  /// Pilih kategori
  void setSelectedCategory(String category) {
    _selectedCategory = category;
    _applyFilterAndSort();
    notifyListeners();
  }

  /// Pilih opsi sorting
  void setSortOption(String option) {
    _sortOption = option;
    _applyFilterAndSort();
    notifyListeners();
  }

  /// Ubah mode tampilan list <-> grid
  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void setViewMode(bool isGrid) {
    _isGridView = isGrid;
    notifyListeners();
  }

  /// Pilih destinasi aktif untuk layar detail
  void selectDestination(DestinationModel destination) {
    _selectedDestination = destination;
    notifyListeners();
  }

  /// Toggle status favorit
  Future<void> toggleFavorite(int destinationId, {int? userId}) async {
    final effectiveUserId = userId ?? 1; // Default demo user Bima Sakti
    final isFav = _favoriteIds.contains(destinationId);

    if (isFav) {
      _favoriteIds.remove(destinationId);
    } else {
      _favoriteIds.add(destinationId);
    }
    _applyFilterAndSort();
    notifyListeners();

    await _repository.toggleFavorite(effectiveUserId, destinationId);
  }

  /// Cek apakah suatu destinasi adalah favorit
  bool isFavorite(int destinationId) {
    return _favoriteIds.contains(destinationId);
  }

  /// Toggle simpan offline
  Future<void> toggleOfflineSave(int destinationId) async {
    final isSaved = _offlineSavedIds.contains(destinationId);
    final newStatus = !isSaved;

    if (newStatus) {
      _offlineSavedIds.add(destinationId);
    } else {
      _offlineSavedIds.remove(destinationId);
    }

    // Perbarui model lokal
    final index = _allDestinations.indexWhere((d) => d.id == destinationId);
    if (index != -1) {
      _allDestinations[index] =
          _allDestinations[index].copyWith(isSavedOffline: newStatus);
    }
    if (_selectedDestination?.id == destinationId) {
      _selectedDestination =
          _selectedDestination!.copyWith(isSavedOffline: newStatus);
    }

    _applyFilterAndSort();
    notifyListeners();

    await _repository.toggleSavedOffline(destinationId, newStatus);
  }

  /// Cek apakah destinasi tersimpan offline
  bool isSavedOffline(int destinationId) {
    return _offlineSavedIds.contains(destinationId);
  }

  /// Penerapan filter dan sorting internal
  void _applyFilterAndSort() {
    var list = _allDestinations.where((dest) {
      final q = _searchQuery.toLowerCase().trim();
      final matchQuery = q.isEmpty ||
          dest.name.toLowerCase().contains(q) ||
          dest.address.toLowerCase().contains(q) ||
          dest.categoryName.toLowerCase().contains(q) ||
          dest.description.toLowerCase().contains(q);

      final matchCategory = _selectedCategory == 'Semua' ||
          (_selectedCategory == 'Favorit'
              ? _favoriteIds.contains(dest.id)
              : dest.categoryName.toLowerCase().contains(_selectedCategory.toLowerCase()));

      return matchQuery && matchCategory;
    }).toList();

    switch (_sortOption) {
      case 'Biaya Terendah':
        list.sort((a, b) => a.ticketPrice.compareTo(b.ticketPrice));
        break;
      case 'Terdekat':
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Destinasi Populer':
      default:
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    _displayedDestinations = list;
  }
}
