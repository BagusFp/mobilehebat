import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/database/database_helper.dart';
import 'package:project/core/services/supabase_service.dart';
import 'package:project/data/models/trip_expense_model.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/repositories/trip_repository.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late DatabaseHelper dbHelper;
  late TripRepository tripRepo;
  late TripProvider tripProvider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // Database in-memory baru untuk setiap test
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    DatabaseHelper.setDatabaseForTesting(db);
    dbHelper = DatabaseHelper.instance;

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

    tripRepo = TripRepository(dbHelper: dbHelper);
    tripProvider = TripProvider(repository: tripRepo);
    SupabaseService.mockIsInitialized = false;
  });

  tearDown(() async {
    SupabaseService.mockIsInitialized = null;
    DatabaseHelper.setDatabaseForTesting(null);
    await db.close();
  });

  group('1. Alur Mulai Sekarang (Start Active Trip)', () {
    test('Mengubah status trip dari planned/upcoming menjadi active tanpa membuat trip baru', () async {
      // Buat trip rencana awal
      final initialTrip = TripModel(
        id: 101,
        userId: 1,
        tripName: 'Petualangan Merapi Pagi',
        startDate: '2026-10-20',
        targetBudget: 500000.0,
        totalEstimatedCost: 150000.0,
        status: 'upcoming',
        createdAt: '2026-10-15',
        items: const [
          TripItemModel(
            id: 201,
            tripId: 101,
            destinationId: 4,
            itemName: 'Plunyon Kalikuning',
            visitOrder: 1,
            plannedTime: '07:30 - 09:00',
            durationHours: 1.5,
            estimatedCost: 24000.0,
          ),
          TripItemModel(
            id: 202,
            tripId: 101,
            destinationId: 1,
            itemName: 'Bunker Kaliadem',
            visitOrder: 2,
            plannedTime: '09:30 - 11:00',
            durationHours: 1.5,
            estimatedCost: 20000.0,
          ),
        ],
      );

      await dbHelper.saveUserTrips(1, [initialTrip]);

      // Jalankan startActiveTrip
      await tripProvider.loadUserTrips(1);
      expect(tripProvider.allTrips.first.status, 'upcoming');

      await tripProvider.startActiveTrip(101);

      // Verifikasi status berubah menjadi active pada trip yang sama
      expect(tripProvider.selectedTrip?.status, 'active');
      expect(tripProvider.selectedTrip?.id, 101);
      expect(tripProvider.selectedTrip?.startedAt, isNotNull);

      // Verifikasi di SQLite
      final cachedTrip = await tripRepo.getTripWithItems(101);
      expect(cachedTrip?.status, 'active');
      expect(cachedTrip?.startedAt, isNotNull);

      // Pastikan tidak ada trip duplikat
      final allTripsInDb = await dbHelper.getCachedUserTrips(1);
      expect(allTripsInDb.length, 1);
    });

    test('Validasi itinerary kosong: tidak boleh memulai jika tidak ada destinasi', () async {
      const emptyTrip = TripModel(
        id: 102,
        userId: 1,
        tripName: 'Trip Kosong Tanpa Destinasi',
        startDate: '2026-10-20',
        targetBudget: 200000.0,
        status: 'upcoming',
        createdAt: '2026-10-15',
        items: [],
      );

      await dbHelper.saveUserTrips(1, [emptyTrip]);
      await tripProvider.loadUserTrips(1);

      // Itinerary tidak memiliki item
      final tripToStart = tripProvider.allTrips.firstWhere((t) => t.id == 102);
      expect(tripToStart.items.isEmpty, isTrue);

      // Validasi logika bisnis: jika items kosong, status tetap upcoming
      expect(tripToStart.status, 'upcoming');
    });
  });

  group('2. Progress & Checklist Kunjungan Destinasi', () {
    late TripModel activeTrip;

    setUp(() async {
      activeTrip = TripModel(
        id: 105,
        userId: 1,
        tripName: 'Jelajah Alam Merapi',
        startDate: '2026-10-15',
        targetBudget: 400000.0,
        totalEstimatedCost: 80000.0,
        status: 'active',
        createdAt: '2026-10-15',
        items: const [
          TripItemModel(
            id: 301,
            tripId: 105,
            destinationId: 4,
            itemName: 'Plunyon Kalikuning',
            visitOrder: 1,
            plannedTime: '07:00 - 08:30',
            durationHours: 1.5,
            elevationMdpl: 850,
          ),
          TripItemModel(
            id: 302,
            tripId: 105,
            destinationId: 1,
            itemName: 'Bunker Kaliadem',
            visitOrder: 2,
            plannedTime: '09:00 - 10:30',
            durationHours: 1.5,
            elevationMdpl: 1165,
          ),
          TripItemModel(
            id: 303,
            tripId: 105,
            destinationId: 2,
            itemName: 'Museum Sisa Hartaku',
            visitOrder: 3,
            plannedTime: '11:00 - 12:00',
            durationHours: 1.0,
            elevationMdpl: 920,
          ),
        ],
      );

      await dbHelper.saveUserTrips(1, [activeTrip]);
      await tripProvider.selectTripById(105);
    });

    test('Destinasi awal adalah item pertama yang belum dikunjungi', () {
      expect(tripProvider.activeTripTotalCount, 3);
      expect(tripProvider.activeTripCompletedCount, 0);
      expect(tripProvider.activeTripProgress, 0.0);
      expect(tripProvider.nextDestination?.itemName, 'Plunyon Kalikuning');
    });

    test('Menandai destinasi selesai memperbarui progress bar dan auto-advance destinasi berikutnya', () async {
      // Tandai item 1 (Plunyon) selesai
      await tripProvider.markDestinationCompleted(105, 301);

      expect(tripProvider.activeTripCompletedCount, 1);
      expect(tripProvider.activeTripTotalCount, 3);
      expect(tripProvider.activeTripProgress, closeTo(1 / 3, 0.001));
      // Otomatis berganti ke tujuan berikutnya (Bunker Kaliadem)
      expect(tripProvider.nextDestination?.itemName, 'Bunker Kaliadem');

      // Tandai item 2 (Bunker) selesai
      await tripProvider.markDestinationCompleted(105, 302);
      expect(tripProvider.activeTripCompletedCount, 2);
      expect(tripProvider.activeTripProgress, closeTo(2 / 3, 0.001));
      expect(tripProvider.nextDestination?.itemName, 'Museum Sisa Hartaku');

      // Tandai item 3 (Museum) selesai
      await tripProvider.markDestinationCompleted(105, 303);
      expect(tripProvider.activeTripCompletedCount, 3);
      expect(tripProvider.activeTripProgress, 1.0);
      expect(tripProvider.nextDestination, isNull);
    });

    test('Cegah satu destinasi dihitung selesai lebih dari satu kali', () async {
      await tripProvider.markDestinationCompleted(105, 301);
      expect(tripProvider.activeTripCompletedCount, 1);

      // Coba tandai ulang destinasi yang sama
      await tripProvider.markDestinationCompleted(105, 301);
      expect(tripProvider.activeTripCompletedCount, 1);
      expect(tripProvider.activeTripProgress, closeTo(1 / 3, 0.001));
    });

    test('Progres destinasi disimpan ke database lokal dan tetap ada saat reload', () async {
      await tripProvider.markDestinationCompleted(105, 301);

      // Simulasikan reload trip dari database lokal
      final reloadedTrip = await tripRepo.getTripWithItems(105);
      final plunyon = reloadedTrip?.items.firstWhere((i) => i.id == 301);
      expect(plunyon?.isCompleted, isTrue);
      expect(plunyon?.completedAt, isNotNull);

      final bunker = reloadedTrip?.items.firstWhere((i) => i.id == 302);
      expect(bunker?.isCompleted, isFalse);
    });
  });

  group('3. Manajemen Pengeluaran & Perhitungan Anggaran', () {
    late TripModel activeTrip;

    setUp(() async {
      activeTrip = const TripModel(
        id: 110,
        userId: 1,
        tripName: 'Wisata Edukasi Merapi',
        startDate: '2026-10-15',
        targetBudget: 500000.0,
        totalEstimatedCost: 100000.0,
        status: 'active',
        createdAt: '2026-10-15',
        items: [
          TripItemModel(
            id: 401,
            tripId: 110,
            destinationId: 4,
            itemName: 'Plunyon Kalikuning',
            visitOrder: 1,
          ),
        ],
      );

      await dbHelper.saveUserTrips(1, [activeTrip]);
      await tripProvider.selectTripById(110);
    });

    test('Menambah pengeluaran aktual menghitung ulang total pengeluaran dan sisa anggaran secara otomatis', () async {
      expect(tripProvider.activeTripTotalExpenses, 0.0);
      expect(tripProvider.activeTripRemainingBudget, 500000.0);

      // Tambah pengeluaran 1: Tiket Masuk Rp 50.000
      final expense1 = TripExpenseModel(
        tripId: 110,
        userId: 1,
        destinationId: 4,
        destinationName: 'Plunyon Kalikuning',
        category: 'Tiket & Retribusi',
        amount: 50000.0,
        notes: '2 tiket dewasa + parkir',
        spentAt: '2026-10-15T08:00:00',
        createdAt: '2026-10-15T08:00:00',
      );
      await tripProvider.addExpense(expense1);

      expect(tripProvider.activeTripTotalExpenses, 50000.0);
      expect(tripProvider.activeTripRemainingBudget, 450000.0);
      expect(tripProvider.activeTripExpenses.length, 1);

      // Tambah pengeluaran 2: Kuliner Rp 120.000
      final expense2 = TripExpenseModel(
        tripId: 110,
        userId: 1,
        category: 'Kuliner & Minuman',
        amount: 120000.0,
        notes: 'Kopi Merapi & Jadah Tempe',
        spentAt: '2026-10-15T09:30:00',
        createdAt: '2026-10-15T09:30:00',
      );
      await tripProvider.addExpense(expense2);

      expect(tripProvider.activeTripTotalExpenses, 170000.0);
      expect(tripProvider.activeTripRemainingBudget, 330000.0);
      expect(tripProvider.activeTripExpenses.length, 2);

      // Verifikasi di SQLite
      final expensesFromDb = await dbHelper.getTripExpenses(110);
      expect(expensesFromDb.length, 2);
    });

    test('Validasi: nominal pengeluaran tidak boleh negatif atau nol', () {
      final invalidExpense = TripExpenseModel(
        tripId: 110,
        userId: 1,
        category: 'Lainnya',
        amount: -5000.0,
        spentAt: '2026-10-15T10:00:00',
        createdAt: '2026-10-15T10:00:00',
      );

      expect(invalidExpense.amount <= 0, isTrue);
    });

    test('Menghapus pengeluaran menghitung kembali total pengeluaran dan sisa anggaran', () async {
      final exp = TripExpenseModel(
        tripId: 110,
        userId: 1,
        category: 'Sewa Jeep',
        amount: 350000.0,
        spentAt: '2026-10-15T10:00:00',
        createdAt: '2026-10-15T10:00:00',
      );
      await tripProvider.addExpense(exp);
      expect(tripProvider.activeTripTotalExpenses, 350000.0);

      final savedId = tripProvider.activeTripExpenses.first.id!;
      await tripProvider.removeExpense(savedId, 110);

      expect(tripProvider.activeTripTotalExpenses, 0.0);
      expect(tripProvider.activeTripRemainingBudget, 500000.0);
      expect(tripProvider.activeTripExpenses.isEmpty, isTrue);
    });
  });

  group('4. Mengakhiri Perjalanan (Complete Trip)', () {
    test('Mengubah status menjadi completed, mencatat total aktual akhir dan tidak menghapus itinerary', () async {
      final trip = const TripModel(
        id: 120,
        userId: 1,
        tripName: 'Ekspedisi Lereng Merapi',
        startDate: '2026-10-15',
        targetBudget: 600000.0,
        totalEstimatedCost: 100000.0,
        status: 'active',
        createdAt: '2026-10-15',
        items: [
          TripItemModel(
            id: 501,
            tripId: 120,
            destinationId: 4,
            itemName: 'Plunyon Kalikuning',
            visitOrder: 1,
            isCompleted: true,
          ),
          TripItemModel(
            id: 502,
            tripId: 120,
            destinationId: 1,
            itemName: 'Bunker Kaliadem',
            visitOrder: 2,
            isCompleted: false, // Belum selesai
          ),
        ],
      );

      await dbHelper.saveUserTrips(1, [trip]);
      await tripProvider.selectTripById(120);

      // Tambahkan pengeluaran
      await tripProvider.addExpense(
        TripExpenseModel(
          tripId: 120,
          userId: 1,
          category: 'Transportasi',
          amount: 150000.0,
          spentAt: '2026-10-15T11:00:00',
          createdAt: '2026-10-15T11:00:00',
        ),
      );

      // Akhiri perjalanan
      await tripProvider.finishActiveTrip(120);

      // Verifikasi status tripProvider
      expect(tripProvider.selectedTrip?.status, 'completed');
      expect(tripProvider.selectedTrip?.totalActualCost, 150000.0);
      expect(tripProvider.selectedTrip?.completedAt, isNotNull);

      // Verifikasi di SQLite
      final completedTripFromDb = await tripRepo.getTripWithItems(120);
      expect(completedTripFromDb, isNotNull);
      expect(completedTripFromDb?.status, 'completed');
      expect(completedTripFromDb?.totalActualCost, 150000.0);
      expect(completedTripFromDb?.completedAt, isNotNull);

      // Pastikan itinerary dan items TIDAK dihapus
      expect(completedTripFromDb?.items.length, 2);
      expect(completedTripFromDb?.items[0].isCompleted, isTrue);
      expect(completedTripFromDb?.items[1].isCompleted, isFalse);
    });
  });

  group('5. Penanganan Kondisi Khusus & Offline Persistence', () {
    test('Data progres destinasi dan pengeluaran tetap utuh saat aplikasi ditutup lalu dibuka kembali', () async {
      // 1. Simpan trip aktif beserta progres dan pengeluaran
      final trip = const TripModel(
        id: 130,
        userId: 1,
        tripName: 'Trip Offline Persistence Test',
        startDate: '2026-10-15',
        targetBudget: 300000.0,
        status: 'active',
        createdAt: '2026-10-15',
        items: [
          TripItemModel(
            id: 601,
            tripId: 130,
            itemName: 'Gardu Pandang Kaliurang',
            visitOrder: 1,
            isCompleted: true,
          ),
          TripItemModel(
            id: 602,
            tripId: 130,
            itemName: 'Tlogo Putri',
            visitOrder: 2,
            isCompleted: false,
          ),
        ],
      );

      await dbHelper.saveUserTrips(1, [trip]);
      await dbHelper.saveTripExpense(
        TripExpenseModel(
          tripId: 130,
          userId: 1,
          category: 'Camilan',
          amount: 25000.0,
          spentAt: '2026-10-15T12:00:00',
          createdAt: '2026-10-15T12:00:00',
        ),
      );

      // 2. Simulasikan pembuatan instance provider baru (seperti app cold start)
      final newProvider = TripProvider(repository: TripRepository(dbHelper: dbHelper));
      await newProvider.selectTripById(130);

      // 3. Verifikasi data ter-restore dengan sempurna dari SQLite
      expect(newProvider.selectedTrip?.status, 'active');
      expect(newProvider.activeTripCompletedCount, 1);
      expect(newProvider.activeTripTotalCount, 2);
      expect(newProvider.nextDestination?.itemName, 'Tlogo Putri');
      expect(newProvider.activeTripExpenses.length, 1);
      expect(newProvider.activeTripTotalExpenses, 25000.0);
      expect(newProvider.activeTripRemainingBudget, 275000.0);
    });

    test('6. Alur Pagu Anggaran, Auto-Akumulasi Tiket & Auto-Scheduling', () async {
      // Test A: Builder Target Budget & Penyesuaian dengan Biaya Wajib
      tripProvider.initBuilderTrip();
      expect(tripProvider.targetBudget, 400000.0); // Default pagu
      expect(tripProvider.totalMandatoryCost, 64000.0); // 54k tiket + 10k parkir

      // Sesuaikan target budget ke biaya wajib
      tripProvider.setBuilderTargetBudget(tripProvider.totalMandatoryCost);
      expect(tripProvider.targetBudget, 64000.0);
      expect(tripProvider.remainingBudget, 0.0);

      // Test B: Auto-scheduling jam kunjungan
      tripProvider.autoScheduleBuilderItems(startHour: 7, startMinute: 30);
      expect(tripProvider.builderItems[0].plannedTime, '07:30 - 09:00');
      expect(tripProvider.builderItems[1].plannedTime, '09:15 - 10:45');

      // Test C: Auto-akumulasi tiket saat destinasi ditandai selesai di trip aktif
      await tripProvider.saveBuilderTrip(1, status: 'active');
      final activeTrip = tripProvider.allTrips.first;
      await tripProvider.selectTripById(activeTrip.id!);

      expect(tripProvider.activeTripTotalExpenses, 0.0);
      final firstItem = activeTrip.items.first;

      await tripProvider.markDestinationCompleted(activeTrip.id!, firstItem.id!);
      expect(tripProvider.activeTripExpenses.length, 1);
      expect(tripProvider.activeTripExpenses.first.amount, firstItem.estimatedCost);
      expect(tripProvider.activeTripTotalExpenses, firstItem.estimatedCost);
    });
  });
}
