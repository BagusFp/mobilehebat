import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/trip_expense_model.dart';
import '../../data/models/trip_item_model.dart';
import '../../data/models/trip_model.dart';
import '../config/supabase_config.dart';

/// Service terpusat untuk mengelola koneksi dan query data ke Supabase.
/// Memisahkan logika database cloud dari halaman UI.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  @visibleForTesting
  static bool? mockIsInitialized;

  /// Mendapatkan instance SupabaseClient
  SupabaseClient get client => Supabase.instance.client;

  /// Memeriksa status inisialisasi Supabase
  bool get isInitialized {
    if (mockIsInitialized != null) return mockIsInitialized!;
    try {
      final isTest =
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isTest) return false;
      if (!SupabaseConfig.isConfigured) return false;
      // Memastikan instance Supabase sudah selesai di-initialize
      final _ = Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Menguji konektivitas ke server Supabase
  Future<bool> checkConnection() async {
    if (!isInitialized) return false;
    try {
      // Query sederhana ke tabel destinations untuk mengecek koneksi dan RLS
      final res = await client
          .from('destinations')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      debugPrint('SupabaseService: Koneksi berhasil tersambung ($res)');
      return true;
    } catch (e) {
      debugPrint('SupabaseService checkConnection: $e');
      return false;
    }
  }

  // ===========================================================================
  // AUTHENTICATION
  // ===========================================================================

  User? get currentUser => isInitialized ? client.auth.currentUser : null;
  Session? get currentSession => isInitialized ? client.auth.currentSession : null;
  Stream<AuthState> get onAuthStateChange =>
      isInitialized ? client.auth.onAuthStateChange : const Stream.empty();

  /// Pendaftaran pengguna baru ke Supabase Auth
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        if (name != null) 'name': name.trim(),
      },
    );

    // Otomatis buat / update data di tabel profiles jika user terbuat
    if (response.user != null) {
      try {
        await upsertProfile({
          'id': response.user!.id,
          'email': response.user!.email,
          'name': name ?? response.user!.userMetadata?['name'] ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('SupabaseService signUp profile upsert error: $e');
      }
    }

    return response;
  }

  /// Masuk dengan email & password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Keluar dari sesi Supabase
  Future<void> signOut() async {
    if (isInitialized) {
      try {
        await client.auth.signOut();
      } catch (_) {}
    }
  }

  // ===========================================================================
  // PROFILES
  // ===========================================================================

  /// Mengambil profil pengguna dari tabel 'profiles'
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      return data;
    } catch (e) {
      debugPrint('SupabaseService.getProfile error: $e');
      return null;
    }
  }

  /// Menyimpan atau memperbarui profil pengguna
  Future<bool> upsertProfile(Map<String, dynamic> profileData) async {
    try {
      await client
          .from('profiles')
          .upsert(profileData)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.upsertProfile error: $e');
      return false;
    }
  }

  String? _lastAvatarUploadError;
  String? get lastAvatarUploadError => _lastAvatarUploadError;

  /// Mengunggah foto profil / avatar ke Supabase Storage (bucket 'avatars')
  /// Selalu menimpa (upsert) file avatar milik user tersebut ($userId/avatar.$fileExt)
  /// Mengembalikan public URL dengan timestamp cache buster agar langsung diperbarui di UI.
  Future<String?> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    String fileExt = 'webp',
  }) async {
    _lastAvatarUploadError = null;
    if (!isInitialized) {
      _lastAvatarUploadError = 'Supabase belum terhubung atau konfigurasi belum lengkap.';
      return null;
    }
    try {
      // Path konsisten per user sehingga file lama selalu ditimpa (overwritten)
      final fileName = '$userId/avatar.$fileExt';
      final mimeType = fileExt == 'webp'
          ? 'image/webp'
          : fileExt == 'png'
              ? 'image/png'
              : 'image/jpeg';

      await client.storage.from('avatars').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: mimeType,
            ),
          );

      // Dapatkan public URL dengan query cache buster timestamp
      final publicUrl = client.storage.from('avatars').getPublicUrl(fileName);
      final cacheBustedUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('SupabaseService.uploadAvatar sukses: $cacheBustedUrl');
      return cacheBustedUrl;
    } on StorageException catch (e) {
      debugPrint('SupabaseService.uploadAvatar StorageException: ${e.message} (status: ${e.statusCode})');
      if (e.statusCode == '404' || e.message.toLowerCase().contains('bucket not found') || e.message.toLowerCase().contains('not found')) {
        _lastAvatarUploadError =
            "Bucket 'avatars' belum dibuat di Supabase Storage. Harap buat bucket 'avatars' (Public: ON) di Dashboard Supabase.";
      } else if (e.statusCode == '403' || e.message.toLowerCase().contains('row-level security') || e.message.toLowerCase().contains('policy')) {
        _lastAvatarUploadError =
            "Izin akses penyimpanan Supabase ditolak (RLS). Pastikan Policy Storage untuk bucket 'avatars' sudah diatur.";
      } else {
        _lastAvatarUploadError = 'Supabase Storage error: ${e.message}';
      }
      return null;
    } catch (e) {
      debugPrint('SupabaseService.uploadAvatar error: $e');
      _lastAvatarUploadError = 'Gagal mengunggah foto ke Supabase: $e';
      return null;
    }
  }

  // ===========================================================================
  // DESTINATIONS
  // ===========================================================================

  /// Mengambil seluruh destinasi dari tabel Supabase 'destinations'
  Future<List<DestinationModel>?> fetchDestinations() async {
    if (!isInitialized) return null;
    try {
      final List<dynamic> data = await client
          .from('destinations')
          .select()
          .order('id', ascending: true)
          .timeout(const Duration(seconds: 6));

      if (data.isEmpty) return null;

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        return _mapToDestinationModel(map);
      }).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchDestinations error: $e');
      return null;
    }
  }

  /// Mengambil destinasi berdasarkan ID
  Future<DestinationModel?> fetchDestinationById(int id) async {
    if (!isInitialized) return null;
    try {
      final data = await client
          .from('destinations')
          .select()
          .eq('id', id)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (data == null) return null;
      return _mapToDestinationModel(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('SupabaseService.fetchDestinationById error: $e');
      return null;
    }
  }

  /// Mencari destinasi berdasarkan nama atau deskripsi
  Future<List<DestinationModel>> searchDestinations(String query) async {
    if (!isInitialized) return [];
    try {
      final cleanQuery = query.trim();
      if (cleanQuery.isEmpty) return [];

      final List<dynamic> data = await client
          .from('destinations')
          .select()
          .or('name.ilike.%$cleanQuery%,description.ilike.%$cleanQuery%,address.ilike.%$cleanQuery%')
          .limit(10)
          .timeout(const Duration(seconds: 5));

      return data.map((item) {
        return _mapToDestinationModel(Map<String, dynamic>.from(item));
      }).toList();
    } catch (e) {
      debugPrint('SupabaseService.searchDestinations error: $e');
      return [];
    }
  }

  /// Mapping dari baris database Supabase ke DestinationModel
  DestinationModel _mapToDestinationModel(Map<String, dynamic> map) {
    List<String> parsedFacilities = [];
    if (map['facilities'] is List) {
      parsedFacilities = (map['facilities'] as List).map((f) => f.toString()).toList();
    }

    return DestinationModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      categoryId: (map['category_id'] as num?)?.toInt() ?? 1,
      categoryName: map['category_name'] ?? 'Wisata Merapi',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      elevationMdpl: (map['elevation_mdpl'] as num?)?.toInt() ?? 0,
      ticketPrice: (map['ticket_price'] as num?)?.toDouble() ?? 0.0,
      ticketPriceLabel: map['ticket_price_label'] ?? 'Tiket Masuk',
      openingHours: map['opening_hours'] ?? '06.00 - 17.00 WIB',
      estimatedDuration: map['estimated_duration'] ?? '45 - 60 Menit',
      temperatureRange: map['temperature_range'] ?? '18°C - 24°C',
      address: map['address'] ?? 'Kawasan Lereng Merapi',
      imageUrl: map['image_url'],
      isSavedOffline: true,
      rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: (map['review_count'] as num?)?.toInt() ?? 500,
      facilities: parsedFacilities,
      distanceKm: (map['distance_km'] as num?)?.toDouble() ?? 0.0,
      bestVisitingTime: map['best_visiting_time'] ?? 'Pagi hari untuk langit jernih',
    );
  }

  // ===========================================================================
  // TRIPS
  // ===========================================================================

  /// Mengambil daftar trip pengguna dari tabel Supabase 'trips'
  Future<List<TripModel>> fetchUserTrips({int? localUserId, String? status}) async {
    if (!isInitialized) return [];
    try {
      final user = currentUser;
      if (user == null) return [];

      var query = client
          .from('trips')
          .select()
          .eq('user_id', user.id);

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }

      final List<dynamic> data = await query
          .order('id', ascending: false)
          .timeout(const Duration(seconds: 6));

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        final List<TripItemModel> items = [];

        if (map['items'] is List) {
          for (final itemJson in map['items']) {
            if (itemJson is Map) {
              items.add(TripItemModel.fromMap(Map<String, dynamic>.from(itemJson)));
            }
          }
        }

        return TripModel(
          id: (map['id'] as num?)?.toInt(),
          userId: localUserId ?? 1, // mapping kompatibel dengan ID akun lokal
          tripName: map['trip_name'] ?? 'Trip Merapi',
          startDate: map['start_date'] ?? DateTime.now().toIso8601String().substring(0, 10),
          participantCount: (map['participant_count'] as num?)?.toInt() ?? 2,
          targetBudget: (map['target_budget'] as num?)?.toDouble() ?? 400000.0,
          totalEstimatedCost: (map['total_estimated_cost'] as num?)?.toDouble() ?? 0.0,
          totalActualCost: (map['total_actual_cost'] as num?)?.toDouble() ?? 0.0,
          status: map['status'] ?? 'upcoming',
          reminderEnabled: map['reminder_enabled'] == true,
          isSavedOffline: true,
          bannerImageUrl: map['banner_image_url'],
          startedAt: map['started_at'],
          completedAt: map['completed_at'],
          createdAt: map['created_at'] ?? DateTime.now().toIso8601String(),
          originCity: map['origin_city'],
          originTimezone: map['origin_timezone'],
          destinationCity: map['destination_city'],
          destinationTimezone: map['destination_timezone'],
          currencySource: map['currency_source'] ?? 'IDR',
          currencyTarget: map['currency_target'] ?? 'USD',
          currentStep: (map['current_step'] as num?)?.toInt() ?? (items.isNotEmpty ? 2 : 1),
          updatedAt: map['updated_at'] as String?,
          items: items,
        );
      }).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchUserTrips error: $e');
      return [];
    }
  }

  /// Membuat trip baru di Supabase
  Future<bool> createTrip(TripModel trip) async {
    if (!isInitialized) return false;
    try {
      final user = currentUser;
      final payload = {
        if (user != null) 'user_id': user.id,
        'trip_name': trip.tripName,
        'start_date': trip.startDate,
        'participant_count': trip.participantCount,
        'target_budget': trip.targetBudget,
        'total_estimated_cost': trip.totalEstimatedCost,
        'status': trip.status,
        'reminder_enabled': trip.reminderEnabled,
        'is_saved_offline': trip.isSavedOffline,
        'banner_image_url': trip.bannerImageUrl,
        'current_step': trip.currentStep,
        'items': trip.items.map((it) => it.toMap()).toList(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('trips').insert(payload).timeout(const Duration(seconds: 6));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.createTrip error: $e');
      return false;
    }
  }

  /// Menghapus trip dari Supabase (berdasarkan ID dan/atau nama trip)
  Future<bool> deleteTrip(int tripId, {String? tripName}) async {
    if (!isInitialized) return false;
    try {
      if (tripId > 0) {
        await client
            .from('trips')
            .delete()
            .eq('id', tripId)
            .timeout(const Duration(seconds: 5));
      }
      if (tripName != null && tripName.trim().isNotEmpty) {
        final user = currentUser;
        var query = client.from('trips').delete().eq('trip_name', tripName.trim());
        if (user != null) {
          query = query.eq('user_id', user.id);
        }
        await query.timeout(const Duration(seconds: 5));
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteTrip error: $e');
      return false;
    }
  }

  /// Memperbarui seluruh data trip di Supabase (nama, jadwal, destinasi, dsb)
  Future<bool> updateTrip(TripModel trip) async {
    if (!isInitialized) return false;
    try {
      final user = currentUser;
      final payload = {
        if (user != null) 'user_id': user.id,
        'trip_name': trip.tripName,
        'start_date': trip.startDate,
        'participant_count': trip.participantCount,
        'target_budget': trip.targetBudget,
        'total_estimated_cost': trip.totalEstimatedCost,
        'total_actual_cost': trip.totalActualCost,
        'status': trip.status,
        'reminder_enabled': trip.reminderEnabled,
        'is_saved_offline': trip.isSavedOffline,
        if (trip.bannerImageUrl != null) 'banner_image_url': trip.bannerImageUrl,
        if (trip.startedAt != null) 'started_at': trip.startedAt,
        if (trip.completedAt != null) 'completed_at': trip.completedAt,
        if (trip.originCity != null) 'origin_city': trip.originCity,
        if (trip.originTimezone != null) 'origin_timezone': trip.originTimezone,
        if (trip.destinationCity != null) 'destination_city': trip.destinationCity,
        if (trip.destinationTimezone != null) 'destination_timezone': trip.destinationTimezone,
        'currency_source': trip.currencySource,
        'currency_target': trip.currencyTarget,
        'current_step': trip.currentStep,
        'items': trip.items.map((it) => it.toMap()).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (trip.id != null) {
        await client
            .from('trips')
            .update(payload)
            .eq('id', trip.id!)
            .timeout(const Duration(seconds: 5));
      }
      if (user != null) {
        await client
            .from('trips')
            .update(payload)
            .eq('user_id', user.id)
            .eq('trip_name', trip.tripName)
            .timeout(const Duration(seconds: 5));
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateTrip error: $e');
      return false;
    }
  }

  /// Memperbarui status trip di Supabase (upcoming, active, completed)
  Future<bool> updateTripStatus(
    int tripId,
    String status, {
    String? tripName,
    String? startedAt,
    String? completedAt,
    double? totalActualCost,
  }) async {
    if (!isInitialized) return false;
    try {
      final user = currentUser;
      final Map<String, dynamic> payload = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (startedAt != null) payload['started_at'] = startedAt;
      if (completedAt != null) payload['completed_at'] = completedAt;
      if (totalActualCost != null) payload['total_actual_cost'] = totalActualCost;

      // Coba update berdasarkan ID lokal
      await client
          .from('trips')
          .update(payload)
          .eq('id', tripId)
          .timeout(const Duration(seconds: 5));

      // Jika user login di Supabase, update juga berdasarkan user_id dan trip_name
      if (user != null && tripName != null) {
        await client
            .from('trips')
            .update(payload)
            .eq('user_id', user.id)
            .eq('trip_name', tripName)
            .timeout(const Duration(seconds: 5));
      }
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateTripStatus error: $e');
      return false;
    }
  }

  /// Memperbarui items (destinasi) trip di Supabase
  Future<bool> updateTripItems(int tripId, List<TripItemModel> items) async {
    if (!isInitialized) return false;
    try {
      await client
          .from('trips')
          .update({
            'items': items.map((it) => it.toMap()).toList(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', tripId)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.updateTripItems error: $e');
      return false;
    }
  }

  /// Menambahkan pengeluaran trip ke Supabase
  Future<bool> createTripExpense(TripExpenseModel expense) async {
    if (!isInitialized) return false;
    try {
      final user = currentUser;
      final payload = {
        'trip_id': expense.tripId,
        if (user != null) 'user_id': user.id,
        if (expense.destinationId != null) 'destination_id': expense.destinationId,
        'destination_name': expense.destinationName,
        'category': expense.category,
        'amount': expense.amount,
        'notes': expense.notes,
        'spent_at': expense.spentAt,
        'created_at': expense.createdAt,
      };

      await client.from('trip_expenses').insert(payload).timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.createTripExpense error: $e');
      return false;
    }
  }

  /// Mengambil daftar pengeluaran trip dari Supabase
  Future<List<TripExpenseModel>> fetchTripExpenses(int tripId) async {
    if (!isInitialized) return [];
    try {
      final List<dynamic> data = await client
          .from('trip_expenses')
          .select()
          .eq('trip_id', tripId)
          .order('spent_at', ascending: false)
          .timeout(const Duration(seconds: 5));

      return data.map((item) {
        final map = Map<String, dynamic>.from(item);
        return TripExpenseModel.fromMap(map);
      }).toList();
    } catch (e) {
      debugPrint('SupabaseService.fetchTripExpenses error: $e');
      return [];
    }
  }

  /// Menghapus pengeluaran trip dari Supabase
  Future<bool> deleteTripExpense(int expenseId) async {
    if (!isInitialized) return false;
    try {
      await client
          .from('trip_expenses')
          .delete()
          .eq('id', expenseId)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (e) {
      debugPrint('SupabaseService.deleteTripExpense error: $e');
      return false;
    }
  }
}
