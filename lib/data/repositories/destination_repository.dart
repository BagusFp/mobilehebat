import '../../core/database/database_helper.dart';
import '../../core/services/supabase_service.dart';
import '../mock/mock_destinations.dart';
import '../models/category_model.dart';
import '../models/destination_model.dart';

class DestinationRepository {
  final DatabaseHelper _dbHelper;

  DestinationRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  bool _isUsingCachedData = false;
  bool get isUsingCachedData => _isUsingCachedData;

  /// Memastikan data awal sudah ada di database jika diizinkan
  Future<void> initDestinations({bool seedIfEmpty = true}) async {
    if (!seedIfEmpty) return;
    try {
      await _dbHelper.ensureDestinationsSeeded();
    } catch (_) {
      // Fallback diam jika pada platform testing in-memory
    }
  }

  /// Mengambil daftar kategori
  List<CategoryModel> getCategories() {
    return MockDestinations.categories;
  }

  /// Mengambil seluruh destinasi: Coba dari cloud database Supabase, perbarui cache SQLite, atau fallback SQLite
  Future<List<DestinationModel>> getAllDestinations({bool forceOffline = false}) async {
    // 1. Coba ambil data terverifikasi dari Supabase Cloud jika tidak dipaksa offline
    if (!forceOffline) {
      try {
        final remoteList = await SupabaseService().fetchDestinations();
        if (remoteList != null && remoteList.isNotEmpty) {
          // Perbarui cache SQLite lokal dengan data terbaru dari cloud
          try {
            await _dbHelper.saveDestinations(remoteList);
          } catch (_) {}

          _isUsingCachedData = false;
          return remoteList;
        }
      } catch (_) {}
    }

    // 2. Fallback ke database lokal SQLite
    _isUsingCachedData = true;
    try {
      final cached = await _dbHelper.getCachedDestinations();
      if (cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}

    // 3. Cache kosong dan offline
    return [];
  }

  /// Mengambil destinasi berdasarkan ID
  Future<DestinationModel?> getDestinationById(int id) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'destinations',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return DestinationModel.fromMap(results.first);
      }
    } catch (_) {}

    try {
      final remote = await SupabaseService().fetchDestinationById(id);
      if (remote != null) {
        try {
          await _dbHelper.saveDestinations([remote]);
        } catch (_) {}
        return remote;
      }
    } catch (_) {}

    try {
      return MockDestinations.destinations.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Mencari dan memfilter destinasi berdasarkan query, kategori, dan sorting
  Future<List<DestinationModel>> searchAndFilterDestinations({
    String query = '',
    String categoryName = 'Semua',
    String sortBy = 'Destinasi Populer',
  }) async {
    final all = await getAllDestinations();

    var filtered = all.where((dest) {
      final matchQuery = query.isEmpty ||
          dest.name.toLowerCase().contains(query.toLowerCase()) ||
          dest.address.toLowerCase().contains(query.toLowerCase()) ||
          dest.categoryName.toLowerCase().contains(query.toLowerCase()) ||
          dest.description.toLowerCase().contains(query.toLowerCase());

      final matchCategory = categoryName == 'Semua' ||
          dest.categoryName.toLowerCase().contains(categoryName.toLowerCase());

      return matchQuery && matchCategory;
    }).toList();

    // Sorting
    switch (sortBy) {
      case 'Biaya Terendah':
        filtered.sort((a, b) => a.ticketPrice.compareTo(b.ticketPrice));
        break;
      case 'Terdekat':
        filtered.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case 'Destinasi Populer':
      default:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }

    return filtered;
  }

  /// Mengambil ID destinasi yang difavoritkan oleh user tertentu
  Future<Set<int>> getFavoriteDestinationIds(int userId) async {
    if (userId <= 0) return {};
    try {
      return await _dbHelper.getFavoriteIds(userId);
    } catch (_) {
      return {};
    }
  }

  /// Toggle favorit (tambah jika belum, hapus jika sudah ada) untuk user tertentu
  Future<bool> toggleFavorite(int userId, int destinationId) async {
    if (userId <= 0) return false;
    try {
      return await _dbHelper.toggleFavorite(userId, destinationId);
    } catch (_) {
      return false;
    }
  }

  /// Toggle status simpan offline destinasi
  Future<bool> toggleSavedOffline(int destinationId, bool isSaved) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'destinations',
        {'is_saved_offline': isSaved ? 1 : 0},
        where: 'id = ?',
        whereArgs: [destinationId],
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
