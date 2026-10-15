import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/database/database_helper.dart';
import 'package:project/core/services/supabase_service.dart';
import 'package:project/data/models/destination_model.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/repositories/destination_repository.dart';
import 'package:project/data/repositories/trip_repository.dart';
import 'package:project/features/explore/destination_provider.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseHelper dbHelper;
  late DestinationRepository destRepo;
  late TripRepository tripRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // Buka database in-memory baru untuk setiap test case
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.setDatabaseForTesting(db);
    dbHelper = DatabaseHelper.instance;

    // Inisialisasi schema tabel
    await db.execute('''
      CREATE TABLE destinations (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        category_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        elevation_mdpl INTEGER DEFAULT 800,
        ticket_price REAL DEFAULT 0,
        ticket_price_label TEXT,
        opening_hours TEXT,
        estimated_duration TEXT,
        temperature_range TEXT,
        address TEXT NOT NULL,
        image_url TEXT,
        is_saved_offline INTEGER DEFAULT 1,
        rating REAL DEFAULT 4.8,
        review_count INTEGER DEFAULT 100,
        facilities TEXT,
        distance_km REAL DEFAULT 0.0,
        best_visiting_time TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE trips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        trip_name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        participant_count INTEGER DEFAULT 1,
        target_budget REAL DEFAULT 0,
        total_estimated_cost REAL DEFAULT 0,
        total_actual_cost REAL DEFAULT 0,
        status TEXT DEFAULT 'upcoming',
        started_at TEXT,
        completed_at TEXT,
        origin_city TEXT,
        origin_timezone TEXT,
        destination_city TEXT,
        destination_timezone TEXT,
        currency_source TEXT,
        currency_target TEXT,
        reminder_enabled INTEGER DEFAULT 1,
        is_saved_offline INTEGER DEFAULT 1,
        banner_image_url TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE trip_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        destination_id INTEGER,
        item_name TEXT NOT NULL,
        item_subtitle TEXT,
        visit_order INTEGER NOT NULL,
        planned_time TEXT,
        duration_hours REAL DEFAULT 1.5,
        estimated_cost REAL DEFAULT 0,
        notes TEXT,
        image_url TEXT,
        elevation_mdpl INTEGER DEFAULT 900,
        connecting_distance_km REAL DEFAULT 3.5,
        connecting_time_minutes INTEGER DEFAULT 15,
        is_completed INTEGER DEFAULT 0,
        completed_at TEXT,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE trip_expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        trip_id INTEGER NOT NULL,
        user_id INTEGER,
        destination_id INTEGER,
        destination_name TEXT,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        spent_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (trip_id) REFERENCES trips (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        destination_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(user_id, destination_id)
      )
    ''');

    destRepo = DestinationRepository(dbHelper: dbHelper);
    tripRepo = TripRepository(dbHelper: dbHelper);
    SupabaseService.mockIsInitialized = false;
  });

  tearDown(() async {
    SupabaseService.mockIsInitialized = null;
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  group('Kondisi 1: Online - Destinasi dan Itinerary Berhasil Dimuat dan Disimpan ke SQLite', () {
    test('Menyimpan destinasi dari data online ke cache lokal SQLite', () async {
      final sampleDests = <DestinationModel>[
        const DestinationModel(
          id: 101,
          name: 'Bunker Kaliadem Online',
          description: 'Saksi bisu erupsi Merapi dengan view megah',
          categoryId: 1,
          categoryName: 'Wisata Alam',
          latitude: -7.5833,
          longitude: 110.4456,
          elevationMdpl: 1165,
          ticketPrice: 15000.0,
          ticketPriceLabel: 'Rp 15.000',
          address: 'Kinahrejo, Hargobinangun, Pakem, Sleman',
        ),
        const DestinationModel(
          id: 102,
          name: 'Plunyon Kalikuning Online',
          description: 'Jembatan gantung berlatar pinus dan puncak Merapi',
          categoryId: 1,
          categoryName: 'Wisata Alam',
          latitude: -7.6012,
          longitude: 110.4321,
          elevationMdpl: 850,
          ticketPrice: 12000.0,
          ticketPriceLabel: 'Rp 12.000',
          address: 'Umbulharjo, Cangkringan, Sleman',
        ),
      ];

      // Simpan ke SQLite
      await dbHelper.saveDestinations(sampleDests);

      // Verifikasi di SQLite
      final cached = await dbHelper.getCachedDestinations();
      expect(cached.length, 2);
      expect(cached.first.id, 101);
      expect(cached.first.name, 'Bunker Kaliadem Online');
      expect(cached.last.id, 102);
      expect(cached.last.name, 'Plunyon Kalikuning Online');
    });

    test('Menyimpan itinerary trip dan trip items dari online ke cache lokal SQLite', () async {
      const userId = 10;
      final onlineTrips = <TripModel>[
        TripModel(
          id: 50,
          userId: userId,
          tripName: 'Eksplorasi Lereng Merapi',
          startDate: 'Sabtu, 20 Des 2025',
          participantCount: 2,
          targetBudget: 500000.0,
          totalEstimatedCost: 150000.0,
          status: 'upcoming',
          createdAt: DateTime.now().toIso8601String(),
          items: const [
            TripItemModel(
              id: 501,
              tripId: 50,
              destinationId: 101,
              itemName: 'Bunker Kaliadem Online',
              visitOrder: 1,
              plannedTime: '08:00 - 10:00',
              estimatedCost: 30000.0,
            ),
            TripItemModel(
              id: 502,
              tripId: 50,
              destinationId: 102,
              itemName: 'Plunyon Kalikuning Online',
              visitOrder: 2,
              plannedTime: '10:30 - 12:00',
              estimatedCost: 24000.0,
            ),
          ],
        ),
      ];

      // Simpan ke SQLite
      await dbHelper.saveUserTrips(userId, onlineTrips);

      // Verifikasi tersimpan di SQLite lengkap dengan item
      final cachedTrips = await dbHelper.getCachedUserTrips(userId);
      expect(cachedTrips.length, 1);
      expect(cachedTrips.first.id, 50);
      expect(cachedTrips.first.tripName, 'Eksplorasi Lereng Merapi');
      expect(cachedTrips.first.items.length, 2);
      expect(cachedTrips.first.items.first.itemName, 'Bunker Kaliadem Online');
      expect(cachedTrips.first.items.last.itemName, 'Plunyon Kalikuning Online');
    });
  });

  group('Kondisi 2: Offline - Data yang Tersimpan Tetap Dapat Dibuka dan Dilihat Detailnya', () {
    test('Mengambil destinasi offline dari SQLite dengan detail lengkap saat offline', () async {
      const sample = DestinationModel(
        id: 201,
        name: 'Museum Gunung Merapi',
        description: 'Pusat edukasi vulkanologi dan sejarah kegempaan',
        categoryId: 3,
        categoryName: 'Budaya & Edukasi',
        latitude: -7.6167,
        longitude: 110.4244,
        ticketPrice: 10000.0,
        ticketPriceLabel: 'Rp 10.000',
        openingHours: '08:00 - 15:30 WIB',
        temperatureRange: '20°C - 26°C',
        elevationMdpl: 850,
        address: 'Jl. Kaliurang KM 22, Hargobinangun, Pakem, Sleman',
        rating: 4.7,
        reviewCount: 350,
        facilities: ['Area Parkir', 'Toilet', 'Mushola', 'Teater Mini'],
      );

      await dbHelper.saveDestinations([sample]);

      // Ambil data dalam mode offline
      final offlineDests = await destRepo.getAllDestinations(forceOffline: true);
      expect(destRepo.isUsingCachedData, isTrue);
      expect(offlineDests.length, 1);

      // Verifikasi detail destinasi yang dibuka dari SQLite
      final detail = await destRepo.getDestinationById(201);
      expect(detail, isNotNull);
      expect(detail!.id, 201);
      expect(detail.name, 'Museum Gunung Merapi');
      expect(detail.openingHours, '08:00 - 15:30 WIB');
      expect(detail.ticketPrice, 10000.0);
      expect(detail.temperatureRange, '20°C - 26°C');
      expect(detail.elevationMdpl, 850);
      expect(detail.facilities, contains('Teater Mini'));
    });

    test('Mengambil itinerary trip offline dari SQLite beserta item-item perjalanannya', () async {
      const userId = 20;
      final trip = TripModel(
        id: 70,
        userId: userId,
        tripName: 'Trip Santai Merapi Akhir Pekan',
        startDate: 'Minggu, 12 Jan 2025',
        participantCount: 3,
        targetBudget: 300000.0,
        totalEstimatedCost: 85000.0,
        status: 'upcoming',
        createdAt: DateTime.now().toIso8601String(),
        items: const [
          TripItemModel(
            id: 701,
            tripId: 70,
            destinationId: 201,
            itemName: 'Museum Gunung Merapi',
            itemSubtitle: 'Edukasi dan Teater Kegempaan',
            visitOrder: 1,
            plannedTime: '09:00 - 11:00',
            durationHours: 2.0,
            estimatedCost: 30000.0,
            notes: 'Menonton film dokumenter erupsi di teater',
          ),
        ],
      );

      await dbHelper.saveUserTrips(userId, [trip]);

      // Load trips saat offline
      final offlineTrips = await tripRepo.getUserTrips(userId, forceOffline: true);
      expect(tripRepo.isUsingCachedData, isTrue);
      expect(offlineTrips.length, 1);
      expect(offlineTrips.first.tripName, 'Trip Santai Merapi Akhir Pekan');

      // Ambil detail trip utuh
      final detailTrip = await tripRepo.getTripWithItems(70);
      expect(detailTrip, isNotNull);
      expect(detailTrip!.items.length, 1);
      expect(detailTrip.items.first.itemName, 'Museum Gunung Merapi');
      expect(detailTrip.items.first.notes, 'Menonton film dokumenter erupsi di teater');
    });

    test('Destinasi favorit offline tersimpan dan dapat diakses', () async {
      const userId = 25;
      await dbHelper.toggleFavorite(userId, 201);

      final favorites = await dbHelper.getFavoriteIds(userId);
      expect(favorites.contains(201), isTrue);

      // Toggle off
      await dbHelper.toggleFavorite(userId, 201);
      final favoritesAfter = await dbHelper.getFavoriteIds(userId);
      expect(favoritesAfter.contains(201), isFalse);
    });
  });

  group('Kondisi 3: Cache Kosong - Menampilkan Pesan Membutuhkan Koneksi Internet', () {
    test('DestinationProvider menampilkan offlineNotice saat cache kosong dan offline', () async {
      // Pastikan cache SQLite kosong
      await dbHelper.clearDestinations();

      final provider = DestinationProvider(repository: destRepo);
      await provider.loadDestinations(forceOffline: true, seedIfEmpty: false);

      expect(provider.allDestinations, isEmpty);
      expect(provider.isUsingCachedData, isTrue);
      expect(provider.offlineNotice, isNotNull);
      expect(
        provider.offlineNotice,
        contains('Data destinasi belum tersedia dalam penyimpanan lokal'),
      );
    });

    test('TripProvider menampilkan emptyCacheMessage saat cache trip kosong dan offline', () async {
      const userId = 30;
      await dbHelper.clearUserTrips(userId);

      final provider = TripProvider(repository: tripRepo);
      await provider.loadUserTrips(userId, forceOffline: true, seedIfEmpty: false);

      expect(provider.allTrips, isEmpty);
      expect(provider.isUsingCachedData, isTrue);
      expect(provider.emptyCacheMessage, isNotNull);
      expect(
        provider.emptyCacheMessage,
        contains('Belum ada itinerary tersimpan secara offline'),
      );
    });
  });

  group('Kondisi 4: Online Kembali - Data Dapat Diperbarui Tanpa Duplikasi', () {
    test('Update destinasi dengan ID sama menggantikan data lama tanpa duplikasi', () async {
      const initialDest = DestinationModel(
        id: 300,
        name: 'Bukit Klangon Awal',
        description: 'Gardu pandang Merapi',
        categoryId: 1,
        categoryName: 'Wisata Alam',
        latitude: -7.5500,
        longitude: 110.4500,
        elevationMdpl: 1200,
        ticketPrice: 5000.0,
        address: 'Glanten, Kalitengah Lor, Cangkringan',
      );

      await dbHelper.saveDestinations([initialDest]);
      var cached = await dbHelper.getCachedDestinations();
      expect(cached.length, 1);
      expect(cached.first.name, 'Bukit Klangon Awal');
      expect(cached.first.ticketPrice, 5000.0);

      // Pembaruan data saat online kembali dengan ID yang sama
      const updatedDest = DestinationModel(
        id: 300,
        name: 'Bukit Klangon Baru & Camping Ground',
        description: 'Spot camping dengan pemandangan sunrise puncak Merapi',
        categoryId: 1,
        categoryName: 'Wisata Alam',
        latitude: -7.5500,
        longitude: 110.4500,
        elevationMdpl: 1200,
        ticketPrice: 10000.0,
        address: 'Glanten, Kalitengah Lor, Cangkringan, Sleman',
      );

      await dbHelper.saveDestinations([updatedDest]);

      // Verifikasi tidak ada duplikasi record (jumlah tetap 1) dan data terupdate
      cached = await dbHelper.getCachedDestinations();
      expect(cached.length, 1);
      expect(cached.first.id, 300);
      expect(cached.first.name, 'Bukit Klangon Baru & Camping Ground');
      expect(cached.first.ticketPrice, 10000.0);
    });

    test('Update itinerary dengan ID sama memperbarui trip dan items tanpa duplikasi', () async {
      const userId = 40;
      final initialTrip = TripModel(
        id: 88,
        userId: userId,
        tripName: 'Itinerary Versi 1',
        startDate: 'Sabtu, 1 Nov 2025',
        participantCount: 1,
        targetBudget: 200000.0,
        totalEstimatedCost: 50000.0,
        status: 'upcoming',
        createdAt: DateTime.now().toIso8601String(),
        items: const [
          TripItemModel(
            id: 881,
            tripId: 88,
            destinationId: 300,
            itemName: 'Kunjungan Singkat',
            visitOrder: 1,
          ),
        ],
      );

      await dbHelper.saveUserTrips(userId, [initialTrip]);
      var trips = await dbHelper.getCachedUserTrips(userId);
      expect(trips.length, 1);
      expect(trips.first.tripName, 'Itinerary Versi 1');
      expect(trips.first.items.length, 1);

      // Online kembali: Trip diperbarui dengan nama baru dan 2 items
      final updatedTrip = TripModel(
        id: 88,
        userId: userId,
        tripName: 'Itinerary Versi 2 Lengkap',
        startDate: 'Sabtu, 1 Nov 2025',
        participantCount: 2,
        targetBudget: 350000.0,
        totalEstimatedCost: 120000.0,
        status: 'upcoming',
        createdAt: DateTime.now().toIso8601String(),
        items: const [
          TripItemModel(
            id: 881,
            tripId: 88,
            destinationId: 300,
            itemName: 'Kunjungan Pagi',
            visitOrder: 1,
          ),
          TripItemModel(
            id: 882,
            tripId: 88,
            destinationId: 300,
            itemName: 'Spot Sunset',
            visitOrder: 2,
          ),
        ],
      );

      await dbHelper.saveUserTrips(userId, [updatedTrip]);

      // Verifikasi tidak ada duplikasi ID trip dan items diperbarui
      trips = await dbHelper.getCachedUserTrips(userId);
      expect(trips.length, 1);
      expect(trips.first.id, 88);
      expect(trips.first.tripName, 'Itinerary Versi 2 Lengkap');
      expect(trips.first.participantCount, 2);
      expect(trips.first.items.length, 2);
      expect(trips.first.items.first.itemName, 'Kunjungan Pagi');
      expect(trips.first.items.last.itemName, 'Spot Sunset');
    });
  });

  group('Kondisi 5: Logout dan Pergantian Akun - Data Privat Tidak Bocor ke Akun Lain', () {
    test('Pemisahan data privat antar user di SQLite dan pembersihan memory saat logout', () async {
      const userAId = 100;
      const userBId = 200;

      // 1. User A menyimpan trip privat dan destinasi favorit
      final tripUserA = TripModel(
        id: 901,
        userId: userAId,
        tripName: 'Trip Rahasia User A',
        startDate: 'Senin, 10 Nov 2025',
        status: 'upcoming',
        createdAt: DateTime.now().toIso8601String(),
        items: const [
          TripItemModel(
            id: 9011,
            tripId: 901,
            destinationId: 1,
            itemName: 'Destinasi Rahasia A',
            visitOrder: 1,
          ),
        ],
      );
      await dbHelper.saveUserTrips(userAId, [tripUserA]);
      await dbHelper.toggleFavorite(userAId, 1);

      // 2. User B menyimpan trip miliknya sendiri
      final tripUserB = TripModel(
        id: 902,
        userId: userBId,
        tripName: 'Trip Publik User B',
        startDate: 'Selasa, 11 Nov 2025',
        status: 'upcoming',
        createdAt: DateTime.now().toIso8601String(),
        items: const [
          TripItemModel(
            id: 9021,
            tripId: 902,
            destinationId: 2,
            itemName: 'Destinasi Favorit B',
            visitOrder: 1,
          ),
        ],
      );
      await dbHelper.saveUserTrips(userBId, [tripUserB]);
      await dbHelper.toggleFavorite(userBId, 2);

      // 3. Simulasi User A sedang menggunakan aplikasi
      final tripProvider = TripProvider(repository: tripRepo);
      await tripProvider.loadUserTrips(userAId, forceOffline: true, seedIfEmpty: false);
      expect(tripProvider.allTrips.length, 1);
      expect(tripProvider.allTrips.first.tripName, 'Trip Rahasia User A');

      // 4. User A Logout: clearSession() dipanggil
      tripProvider.clearSession();
      expect(tripProvider.allTrips, isEmpty, reason: 'Memori trip harus bersih seketika setelah logout');

      // 5. User B Login pada perangkat yang sama
      await tripProvider.loadUserTrips(userBId, forceOffline: true, seedIfEmpty: false);
      expect(tripProvider.allTrips.length, 1);
      expect(tripProvider.allTrips.first.tripName, 'Trip Publik User B');
      expect(
        tripProvider.allTrips.any((t) => t.tripName.contains('User A')),
        isFalse,
        reason: 'Data privat User A tidak boleh bocor ke User B',
      );

      // Verifikasi favorit juga terisolasi
      final favoritesUserB = await dbHelper.getFavoriteIds(userBId);
      expect(favoritesUserB.contains(2), isTrue);
      expect(favoritesUserB.contains(1), isFalse, reason: 'Favorit User A tidak boleh bocor ke User B');

      // 6. User B Logout, Pengguna Tamu / Tanpa Akun membuka aplikasi
      tripProvider.clearSession();
      await tripProvider.loadUserTrips(null, forceOffline: true, seedIfEmpty: false);
      expect(tripProvider.allTrips, isEmpty, reason: 'Pengguna tanpa akun tidak boleh melihat trip pengguna lain');

      // 7. User A Login Kembali: Data User A tidak terhapus dari SQLite
      await tripProvider.loadUserTrips(userAId, forceOffline: true, seedIfEmpty: false);
      expect(tripProvider.allTrips.length, 1);
      expect(tripProvider.allTrips.first.tripName, 'Trip Rahasia User A');
      final favoritesUserA = await dbHelper.getFavoriteIds(userAId);
      expect(favoritesUserA.contains(1), isTrue);
    });
  });
}
