import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../core/database/database_helper.dart';
import '../../core/services/supabase_service.dart';
import '../models/trip_expense_model.dart';
import '../models/trip_item_model.dart';
import '../models/trip_model.dart';

class TripRepository {
  final DatabaseHelper _dbHelper;
  bool _isUsingCachedData = false;
  bool get isUsingCachedData => _isUsingCachedData;

  TripRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Inisialisasi awal tabel trips jika belum ada dan diizinkan
  Future<void> initTrips({bool seedIfEmpty = true}) async {
    if (!seedIfEmpty) return;
    try {
      await _dbHelper.ensureTripsSeeded();
    } catch (_) {}
  }

  /// Mengambil daftar trips: coba dari cloud Supabase, perbarui cache SQLite, atau fallback SQLite
  Future<List<TripModel>> getUserTrips(int userId, {String? status, bool forceOffline = false}) async {
    if (userId <= 0) {
      _isUsingCachedData = false;
      return [];
    }

    // Ambil cache lokal SQLite terlebih dahulu
    List<TripModel> cachedTrips = [];
    try {
      cachedTrips = await _dbHelper.getCachedUserTrips(userId, status: status);
    } catch (_) {}

    // 1. Coba ambil data terverifikasi dari Supabase Cloud jika tidak dipaksa offline
    if (!forceOffline) {
      try {
        final remoteTrips = await SupabaseService().fetchUserTrips(
          localUserId: userId,
          status: status,
        );
        if (remoteTrips.isNotEmpty) {
          // Gabungkan data cloud dengan cache lokal agar status 'completed' dan edit lokal tidak tertimpa
          final mergedTrips = _mergeTripsPreservingLocalStatus(cachedTrips, remoteTrips);
          try {
            await _dbHelper.saveUserTrips(userId, mergedTrips);
          } catch (_) {}

          _isUsingCachedData = false;
          return mergedTrips;
        }
      } catch (_) {}
    }

    // 2. Fallback ke database lokal SQLite
    _isUsingCachedData = true;
    if (cachedTrips.isNotEmpty) {
      return cachedTrips;
    }

    // 3. Cache kosong dan offline
    return [];
  }

  /// Menggabungkan trips dari remote cloud dengan cache lokal
  /// Menjamin bahwa status 'completed' lokal dan penambahan destinasi/jam tidak tertimpa oleh data cloud lama
  List<TripModel> _mergeTripsPreservingLocalStatus(
    List<TripModel> cachedTrips,
    List<TripModel> remoteTrips,
  ) {
    if (cachedTrips.isEmpty) return remoteTrips;
    if (remoteTrips.isEmpty) return cachedTrips;

    final Map<dynamic, TripModel> mergedMap = {};

    for (final cached in cachedTrips) {
      final key = cached.id ?? cached.tripName;
      mergedMap[key] = cached;
    }

    for (final remote in remoteTrips) {
      final key = remote.id ?? remote.tripName;
      final cached = mergedMap[key] ??
          cachedTrips.cast<TripModel?>().firstWhere(
            (c) => c != null && c.tripName.toLowerCase() == remote.tripName.toLowerCase(),
            orElse: () => null,
          );

      if (cached != null) {
        // Hapus entri lama di mergedMap agar tidak terjadi duplikasi saat ID lokal berbeda dari ID cloud
        if (cached.id != null) mergedMap.remove(cached.id);
        mergedMap.remove(cached.tripName);

        final bool isLocallyCompleted =
            cached.status == 'completed' || (cached.completedAt != null && cached.completedAt!.isNotEmpty);
        final statusToKeep = isLocallyCompleted ? 'completed' : remote.status;
        final completedAtToKeep =
            isLocallyCompleted ? (cached.completedAt ?? remote.completedAt) : remote.completedAt;

        // Pertahankan item lokal jika baru diedit atau memiliki jumlah item yang valid
        final itemsToKeep = (cached.items.length >= remote.items.length && cached.items.isNotEmpty)
            ? cached.items
            : (remote.items.isNotEmpty ? remote.items : cached.items);

        mergedMap[key] = remote.copyWith(
          id: cached.id ?? remote.id,
          status: statusToKeep,
          completedAt: completedAtToKeep,
          totalActualCost: isLocallyCompleted && cached.totalActualCost > 0
              ? cached.totalActualCost
              : remote.totalActualCost,
          items: itemsToKeep,
        );
      } else {
        mergedMap[key] = remote;
      }
    }

    // Deduplikasi hasil akhir untuk memastikan tidak ada duplikat berdasarkan ID maupun nama & status
    final List<TripModel> result = [];
    final Set<String> seen = {};
    for (final trip in mergedMap.values) {
      final dedupKey = '${trip.tripName.trim().toLowerCase()}|${trip.status}';
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);
      result.add(trip);
    }

    return result;
  }

  /// Mengambil detail trip dengan item-itemnya
  Future<TripModel?> getTripWithItems(int tripId) async {
    try {
      final db = await _dbHelper.database;
      final tripMaps = await db.query(
        'trips',
        where: 'id = ?',
        whereArgs: [tripId],
        limit: 1,
      );

      if (tripMaps.isEmpty) return null;

      final itemMaps = await db.query(
        'trip_items',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'visit_order ASC',
      );
      final items = itemMaps.map((iMap) => TripItemModel.fromMap(iMap)).toList();
      return TripModel.fromMap(tripMaps.first, items: items);
    } catch (_) {
      final fallbacks = _getFallbackTrips(1);
      try {
        return fallbacks.firstWhere((t) => t.id == tripId);
      } catch (_) {
        return null;
      }
    }
  }

  /// Membuat trip baru beserta list item perjalanannya
  Future<int> createTrip(TripModel trip) async {
    try {
      final db = await _dbHelper.database;
      final tripId = await db.insert('trips', trip.toMap());

      final batch = db.batch();
      for (int i = 0; i < trip.items.length; i++) {
        final item = trip.items[i].copyWith(
          tripId: tripId,
          visitOrder: i + 1,
        );
        batch.insert('trip_items', item.toMap());
      }
      await batch.commit(noResult: true);

      // Sinkronisasi ke Supabase Cloud
      SupabaseService().createTrip(trip.copyWith(id: tripId)).ignore();

      return tripId;
    } catch (_) {
      return 1;
    }
  }

  /// Memperbarui trip beserta seluruh itemnya (menambah destinasi, merubah jam, dsb)
  Future<void> updateTrip(TripModel trip) async {
    if (trip.id == null) return;
    try {
      final db = await _dbHelper.database;
      await db.update(
        'trips',
        trip.toMap(),
        where: 'id = ?',
        whereArgs: [trip.id],
      );

      // Re-sync items jika ada
      await db.delete(
        'trip_items',
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );

      final batch = db.batch();
      for (int i = 0; i < trip.items.length; i++) {
        final item = trip.items[i].copyWith(
          tripId: trip.id,
          visitOrder: i + 1,
        );
        final itemMap = item.toMap();
        if (item.id == null) {
          itemMap.remove('id');
        }
        batch.insert('trip_items', itemMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      // Sinkronisasi pembaruan ke Supabase Cloud
      SupabaseService().updateTrip(trip).ignore();
    } catch (e) {
      debugPrint('TripRepository.updateTrip error: $e');
    }
  }

  /// Menghapus trip beserta seluruh item dan pengeluarannya
  Future<bool> deleteTrip(int tripId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('trip_expenses', where: 'trip_id = ?', whereArgs: [tripId]);
      await db.delete('trip_items', where: 'trip_id = ?', whereArgs: [tripId]);
      final count = await db.delete('trips', where: 'id = ?', whereArgs: [tripId]);
      // Sinkronisasi penghapusan ke Supabase Cloud
      try {
        await SupabaseService().deleteTrip(tripId);
      } catch (e) {
        debugPrint('SupabaseService.deleteTrip warning: $e');
      }
      return count > 0;
    } catch (e) {
      debugPrint('TripRepository.deleteTrip error: $e');
      return false;
    }
  }

  /// Toggle reminder
  Future<void> toggleReminder(int tripId, bool enabled) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'trips',
        {'reminder_enabled': enabled ? 1 : 0},
        where: 'id = ?',
        whereArgs: [tripId],
      );
    } catch (_) {}
  }

  /// Toggle offline
  Future<void> toggleOffline(int tripId, bool saved) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'trips',
        {'is_saved_offline': saved ? 1 : 0},
        where: 'id = ?',
        whereArgs: [tripId],
      );
    } catch (_) {}
  }

  // ===========================================================================
  // ACTIVE TRIP & EXPENSES
  // ===========================================================================

  /// Mengubah status trip menjadi 'active' (Memulai perjalanan)
  Future<void> startTrip(int tripId) async {
    final now = DateTime.now().toIso8601String();
    try {
      await _dbHelper.updateTripStatus(tripId, 'active', startedAt: now);
      final trip = await getTripWithItems(tripId);
      SupabaseService().updateTripStatus(
        tripId,
        'active',
        tripName: trip?.tripName,
        startedAt: now,
      ).ignore();
    } catch (_) {}
  }

  /// Mengubah status trip menjadi 'completed' (Mengakhiri perjalanan)
  Future<void> completeTrip(int tripId, {double? totalActualCost}) async {
    final now = DateTime.now().toIso8601String();
    try {
      await _dbHelper.updateTripStatus(
        tripId,
        'completed',
        completedAt: now,
        totalActualCost: totalActualCost,
      );
      final trip = await getTripWithItems(tripId);
      SupabaseService().updateTripStatus(
        tripId,
        'completed',
        tripName: trip?.tripName,
        completedAt: now,
        totalActualCost: totalActualCost,
      ).ignore();
    } catch (_) {}
  }

  /// Mengubah status trip umum (upcoming, draft, completed, active)
  Future<void> updateTripStatus(int tripId, String status) async {
    final now = DateTime.now().toIso8601String();
    try {
      if (status == 'completed') {
        await _dbHelper.updateTripStatus(tripId, status, completedAt: now);
      } else if (status == 'active') {
        await _dbHelper.updateTripStatus(tripId, status, startedAt: now);
      } else {
        await _dbHelper.updateTripStatus(tripId, status);
      }
      final trip = await getTripWithItems(tripId);
      SupabaseService().updateTripStatus(
        tripId,
        status,
        tripName: trip?.tripName,
        startedAt: status == 'active' ? now : null,
        completedAt: status == 'completed' ? now : null,
      ).ignore();
    } catch (_) {}
  }

  /// Menandai satu destinasi dalam trip sudah dikunjungi
  Future<void> markDestinationVisited(int tripId, int itemId, bool isCompleted) async {
    final now = isCompleted ? DateTime.now().toIso8601String() : null;
    try {
      await _dbHelper.markTripItemCompleted(tripId, itemId, isCompleted, completedAt: now);
      final trip = await getTripWithItems(tripId);
      if (trip != null) {
        SupabaseService().updateTripItems(tripId, trip.items).ignore();
      }
    } catch (_) {}
  }

  /// Menambahkan pengeluaran baru pada trip
  Future<int> addExpense(TripExpenseModel expense) async {
    try {
      final id = await _dbHelper.saveTripExpense(expense);
      SupabaseService().createTripExpense(expense.copyWith(id: id)).ignore();
      return id;
    } catch (_) {
      return 0;
    }
  }

  /// Menghapus pengeluaran trip
  Future<void> deleteExpense(int expenseId, int tripId) async {
    try {
      await _dbHelper.deleteTripExpense(expenseId, tripId);
      SupabaseService().deleteTripExpense(expenseId).ignore();
    } catch (_) {}
  }

  /// Mengambil daftar pengeluaran untuk trip tertentu
  Future<List<TripExpenseModel>> getTripExpenses(int tripId) async {
    try {
      final cached = await _dbHelper.getTripExpenses(tripId);
      if (cached.isNotEmpty) {
        return cached;
      }
      final remote = await SupabaseService().fetchTripExpenses(tripId);
      if (remote.isNotEmpty) {
        for (final exp in remote) {
          await _dbHelper.saveTripExpense(exp);
        }
        return remote;
      }
    } catch (_) {}
    return [];
  }

  /// Fallback demo trips
  List<TripModel> _getFallbackTrips(int userId, {String? status}) {
    final t1 = TripModel(
      id: 1,
      userId: userId,
      tripName: 'Eksplorasi Merapi 1 Hari',
      startDate: 'Sabtu, 19 Okt 2024',
      participantCount: 2,
      targetBudget: 400000.0,
      totalEstimatedCost: 64000.0,
      status: 'upcoming',
      reminderEnabled: true,
      isSavedOffline: true,
      bannerImageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCwXWD1ehYGmjCp_tx9aHTlZ8jRBa3kBFwla81OgBF70OA_aTU48L3L1uWDxVKLOeOibal32sVtkWDwCjMGF8itjKr-NQN1L86Ee1mYoQwDS-J7cI5ZKVOVXKZ0Xc4FNEYAOodZRXRzOBzJxFqXOJ01UXhwtJqgj6WDkkS3RVXWzd2wa6g9UVa80DlrCKLRbVlgTZnEFnH0cSPkq-wv1H5RkhBThijYlO7htbYniIv84-mxlC7wZ7w',
      createdAt: '2026-10-12',
      items: [
        const TripItemModel(
          id: 1,
          tripId: 1,
          destinationId: 4,
          itemName: 'Plunyon Kalikuning',
          itemSubtitle: 'Spot Pagi & Jembatan Kabut',
          visitOrder: 1,
          plannedTime: '07:30 - 09:00',
          durationHours: 1.5,
          estimatedCost: 24000.0,
          notes: 'Bawa kamera untuk foto jembatan gantung',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuDAX_XQHvcKR5gw0LBQYQmt-y9oQ0OHfiJ_CZ-5p5AKqNMAp5bKs2W2Jlt4o2oitrUq_VCelmuqVG7WTqmT7ASyRmOe1OHt9940R7ufin-tb3gNQoj6F0KxgeDrHHr5lg9v7Kv2GLOUKfy_-Cz5yaTztUc1JlWpB-M_Yl4d2vzYtCAOQBShTgDbVzEnFSR7qqmqYpBMeZk4ZCa6pHJC19uSnJfp55jNzI0aFceiOp71n9NRm-3kyB0',
          elevationMdpl: 850,
          connectingDistanceKm: 4.2,
          connectingTimeMinutes: 15,
        ),
        const TripItemModel(
          id: 2,
          tripId: 1,
          destinationId: 1,
          itemName: 'Bunker Kaliadem',
          itemSubtitle: 'Panorama Puncak & Edukasi Vulkanik',
          visitOrder: 2,
          plannedTime: '09:30 - 11:00',
          durationHours: 1.5,
          estimatedCost: 20000.0,
          notes: 'Spot utama pemandangan kerucut Merapi',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
          elevationMdpl: 1165,
          connectingDistanceKm: 3.1,
          connectingTimeMinutes: 12,
        ),
        const TripItemModel(
          id: 3,
          tripId: 1,
          destinationId: 2,
          itemName: 'Museum Sisa Hartaku',
          itemSubtitle: 'Museum Memori Erupsi 2010',
          visitOrder: 3,
          plannedTime: '11:30 - 13:00',
          durationHours: 1.0,
          estimatedCost: 10000.0,
          notes: 'Donasi sukarela & saksi bisu awan panas',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCrMdOhkFyi5cCCa57K_dji1aobrBXghl3FRpJRzpB6sn7bo6utRDLky6lzoF0DEGs94zbs_xZrmfkoF8iEb9n95_6toNdhXzL8CVAwPhteTB6vigjJXWqqiy5Fh9hGiLTrKhMACm4HgA9nMeFkfmS-cmlkoZwsu2PksDLjTIv8_-PI39q2JV4WAcBrrDXgM-b6Eef1b5md8zQyfrkKkaRGG6yn_9VtBJcqzFWJ2Ro0NmgIxXchwCQ',
          elevationMdpl: 920,
          connectingDistanceKm: 0.0,
          connectingTimeMinutes: 0,
        ),
      ],
    );

    final t2 = TripModel(
      id: 2,
      userId: userId,
      tripName: 'Sunset Kaliurang & Kopi Merapi',
      startDate: 'Minggu, 20 Okt 2024',
      participantCount: 2,
      targetBudget: 250000.0,
      totalEstimatedCost: 45000.0,
      status: 'draft',
      reminderEnabled: true,
      isSavedOffline: true,
      bannerImageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAPCRJJgh8Rcxr67OUIBH0lTkBEjznYjV4dRG5FgHsyOkFAhrLdHE1wBAIXN3blB_0TSNHKVyKtZtLIFFJt8277BtD0ks8ED9PzBx9SXFgFt3jBWChmkm8uOCyZEr-Za1g-7k0Kf6oBpQhN5yO0mPcFO0P9mfeYovAYB9NngDAPmbdPG16QZGbdrhjEWVp_0C0G-8ZWCS0S3UFjvckAn-KVl5TQqS7Yl3ZlBbS98WpVL3OHNQ2Px1Q',
      createdAt: '2026-10-12',
      items: [
        const TripItemModel(
          id: 4,
          tripId: 2,
          destinationId: 15,
          itemName: 'Kopi Klotok & Sawah Pakem',
          itemSubtitle: 'Kuliner Joglo Tradisional',
          visitOrder: 1,
          plannedTime: '15:30 - 17:00',
          durationHours: 1.5,
          estimatedCost: 35000.0,
          elevationMdpl: 450,
          connectingDistanceKm: 5.0,
          connectingTimeMinutes: 15,
        ),
      ],
    );

    final t3 = TripModel(
      id: 3,
      userId: userId,
      tripName: 'Jelajah Bunker & Lava Tour 2024',
      startDate: '10 Okt 2024',
      participantCount: 2,
      targetBudget: 350000.0,
      totalEstimatedCost: 60000.0,
      totalActualCost: 320000.0,
      status: 'completed',
      completedAt: '2024-10-10 16:30:00',
      reminderEnabled: false,
      isSavedOffline: true,
      bannerImageUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
      createdAt: '2026-10-10',
      items: [
        const TripItemModel(
          id: 5,
          tripId: 3,
          destinationId: 1,
          itemName: 'Bunker Kaliadem',
          itemSubtitle: 'Panorama Puncak & Edukasi Vulkanik',
          visitOrder: 1,
          plannedTime: '08:00 - 10:00',
          durationHours: 2.0,
          estimatedCost: 20000.0,
          isCompleted: true,
          completedAt: '2024-10-10 10:00:00',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCs1bn5sWA_op5eceHeIsQLwaMQVuENkD15MF0xyIocreuPE9u07fCpt91lh4BSXqO7UTrLroxjGGUi7TWMJA_NkuGRx_nxKy-R_sNvzvyYwgMdMvPHcRC2j2O9urQWq2JvofgEte9U1hM-yqiDtfgZiNPV7rcaRuqrjx8b8kbddJv_SWnxMQAJjz12EUhpa3RTVDSZ3o3d0y-XOArN3jcZOGB12ek7JcpeH5X7fGtSM24JM2TObM4',
          elevationMdpl: 1165,
        ),
        const TripItemModel(
          id: 6,
          tripId: 3,
          destinationId: 2,
          itemName: 'Museum Sisa Hartaku',
          itemSubtitle: 'Museum Memori Erupsi 2010',
          visitOrder: 2,
          plannedTime: '10:30 - 12:00',
          durationHours: 1.5,
          estimatedCost: 10000.0,
          isCompleted: true,
          completedAt: '2024-10-10 12:00:00',
          imageUrl:
              'https://lh3.googleusercontent.com/aida-public/AB6AXuCrMdOhkFyi5cCCa57K_dji1aobrBXghl3FRpJRzpB6sn7bo6utRDLky6lzoF0DEGs94zbs_xZrmfkoF8iEb9n95_6toNdhXzL8CVAwPhteTB6vigjJXWqqiy5Fh9hGiLTrKhMACm4HgA9nMeFkfmS-cmlkoZwsu2PksDLjTIv8_-PI39q2JV4WAcBrrDXgM-b6Eef1b5md8zQyfrkKkaRGG6yn_9VtBJcqzFWJ2Ro0NmgIxXchwCQ',
          elevationMdpl: 920,
        ),
      ],
    );

    final all = [t1, t2, t3];
    if (status != null && status.isNotEmpty) {
      return all.where((t) => t.status == status).toList();
    }
    return all;
  }
}
