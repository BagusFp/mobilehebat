import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/core/utils/crypto_helper.dart';
import 'package:project/data/mock/mock_destinations.dart';
import 'package:project/core/utils/geo_helper.dart';
import 'package:project/data/models/destination_model.dart';
import 'package:project/data/models/offline_pack_model.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/models/user_model.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/core/widgets/app_scaffold.dart';
import 'package:project/features/explore/destination_detail_screen.dart';
import 'package:project/features/explore/destination_provider.dart';
import 'package:project/features/explore/explore_screen.dart';
import 'package:project/features/map/map_provider.dart';
import 'package:project/features/map/map_screen.dart';
import 'package:project/features/map/offline_map_screen.dart';
import 'package:project/features/ai_assistant/ai_assistant_provider.dart';
import 'package:project/features/ai_assistant/ai_assistant_screen.dart';
import 'package:project/features/notification/notification_model.dart';
import 'package:project/features/notification/notification_provider.dart';
import 'package:project/features/notification/notification_screen.dart';
import 'package:project/features/blockchain/blockchain_model.dart';
import 'package:project/features/blockchain/blockchain_provider.dart';
import 'package:project/features/blockchain/blockchain_screen.dart';
import 'package:project/features/profile/course_feedback_screen.dart';
import 'package:project/features/profile/profile_screen.dart';
import 'package:project/features/quiz/quiz_model.dart';
import 'package:project/features/quiz/quiz_provider.dart';
import 'package:project/features/quiz/quiz_screen.dart';
import 'package:project/features/sensor/sensor_compass_screen.dart';
import 'package:project/features/sensor/sensor_provider.dart';
import 'package:project/features/trip/create_trip_screen.dart';
import 'package:project/features/trip/my_trip_screen.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:project/features/utility/currency_time_screen.dart';
import 'package:project/features/utility/utility_provider.dart';
import 'package:project/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('CryptoHelper hashes password with SHA-256 correctly', () {
    const rawPassword = 'merapiraya2024';
    final hash1 = CryptoHelper.hashPassword(rawPassword);
    final hash2 = CryptoHelper.hashPassword(rawPassword);

    expect(hash1.isNotEmpty, true);
    expect(hash1, equals(hash2));
    expect(CryptoHelper.verifyPassword(rawPassword, hash1), true);
    expect(CryptoHelper.verifyPassword('wrongpassword', hash1), false);
  });

  test('UserModel converts to and from SQLite map correctly', () {
    final user = UserModel(
      id: 1,
      name: 'Danang Baskoro',
      email: 'danang@meratrip.id',
      passwordHash: CryptoHelper.hashPassword('test1234'),
      isBiometricEnabled: true,
      createdAt: '2026-10-12T10:00:00Z',
    );

    final map = user.toMap();
    expect(map['name'], 'Danang Baskoro');
    expect(map['is_biometric_enabled'], 1);

    final reconstructed = UserModel.fromMap(map);
    expect(reconstructed.id, 1);
    expect(reconstructed.name, user.name);
    expect(reconstructed.email, user.email);
    expect(reconstructed.isBiometricEnabled, true);
  });

  test('DestinationModel converts to and from SQLite map correctly', () {
    final dest = MockDestinations.destinations.first;
    final map = dest.toMap();

    expect(map['name'], 'Bunker Kaliadem');
    expect(map['elevation_mdpl'], 1165);
    expect(map['ticket_price'], 10000.0);

    final reconstructed = DestinationModel.fromMap(map);
    expect(reconstructed.name, dest.name);
    expect(reconstructed.elevationMdpl, dest.elevationMdpl);
    expect(reconstructed.ticketPrice, dest.ticketPrice);
    expect(reconstructed.facilities.contains('Area Parkir'), true);
  });

  test('DestinationProvider performs search, filter, and favorites', () async {
    final provider = DestinationProvider();
    await provider.loadDestinations(userId: 1);

    expect(provider.allDestinations.isNotEmpty, true);

    // Filter kategori 'Sejarah'
    provider.setSelectedCategory('Sejarah');
    expect(provider.displayedDestinations.every((d) => d.categoryName == 'Sejarah'), true);

    // Reset kategori dan pencarian keyword
    provider.setSelectedCategory('Semua');
    provider.setSearchQuery('Bunker');
    expect(provider.displayedDestinations.length, 1);
    expect(provider.displayedDestinations.first.name, 'Bunker Kaliadem');

    // Toggle favorit
    final destId = provider.displayedDestinations.first.id;
    final wasFav = provider.isFavorite(destId);
    await provider.toggleFavorite(destId, userId: 1);
    expect(provider.isFavorite(destId), !wasFav);
  });

  testWidgets('MeraTrip app mounts with LoginScreen when not logged in', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MeraTripApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MeraTrip'), findsWidgets);
    expect(find.text('Jelajahi Pesona Merapi dengan Cerdas'), findsOneWidget);
    expect(find.text('Masuk ke MeraTrip'), findsOneWidget);
    expect(find.text('Masuk Biometrik'), findsOneWidget);
  });

  testWidgets('Navigasi dari Layar Masuk ke Layar Registrasi Pengguna', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MeraTripApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final daftarTab = find.text('Daftar Akun');
    expect(daftarTab, findsOneWidget);
    await tester.tap(daftarTab);
    await tester.pumpAndSettle();

    expect(find.text('Registrasi Pengguna'), findsOneWidget);
    expect(find.text('Daftar Akun Penjelajah'), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Daftar Akun MeraTrip'), findsOneWidget);
  });

  testWidgets('State AuthProvider berpindah ke HomeScreen & Shell saat login', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    final destProvider = DestinationProvider();
    await tester.runAsync(() async {
      await destProvider.loadDestinations(userId: 1);
    });

    await tester.pumpWidget(
      MeraTripApp(
        authProvider: fakeAuth,
        destinationProvider: destProvider,
      ),
    );
    await tester.pump();

    expect(find.text('Masuk ke MeraTrip'), findsOneWidget);

    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );
    await tester.pump();

    // Verifikasi Tab bar
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Jelajah'), findsWidgets);
    expect(find.text('Kesan/Saran'), findsWidgets);
    expect(find.text('Profil'), findsWidgets);
    expect(find.text('Logout'), findsWidgets);

    // Verifikasi elemen Home Stitch Layar 3 (Status Merapi di top app bar)
    expect(find.text('Merapi Level II (Waspada)'), findsOneWidget);
    expect(find.text('Mau menjelajah Merapi?'), findsOneWidget);
    expect(find.text('Peta Merapi'), findsOneWidget);
    expect(find.text('Kompas'), findsOneWidget);
    expect(find.text('Jagawana AI'), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('Layar Explore menampilkan search bar, category chips, dan card destinasi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final destProvider = DestinationProvider();
    await tester.runAsync(() async {
      await destProvider.loadDestinations(userId: 1);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<DestinationProvider>.value(value: destProvider),
          ChangeNotifierProvider<TripProvider>.value(value: TripProvider()),
        ],
        child: const MaterialApp(
          home: AppScaffold(
            title: 'Explore Merapi',
            body: ExploreScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // Verifikasi elemen Explore Stitch Layar 4
    expect(find.text('Merapi Level II (Waspada)'), findsWidgets);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Alam'), findsWidgets);
    expect(find.text('Sejarah'), findsWidgets);
    expect(find.text('Bunker Kaliadem'), findsWidgets);
  });

  testWidgets('DestinationDetailScreen merender hero visual, 2x2 info ringkas, dan sticky CTA', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final destProvider = DestinationProvider();
    await tester.runAsync(() async {
      await destProvider.loadDestinations(userId: 1);
    });

    final destination = MockDestinations.destinations.first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<DestinationProvider>.value(value: destProvider),
          ChangeNotifierProvider<TripProvider>.value(value: TripProvider()),
        ],
        child: MaterialApp(
          home: DestinationDetailScreen(destination: destination),
        ),
      ),
    );
    await tester.pump();

    // Verifikasi elemen Stitch Layar 5
    expect(find.text('Trail Detail'), findsOneWidget);
    expect(find.text('Bunker Kaliadem'), findsWidgets);
    expect(find.text('Informasi Ringkas'), findsOneWidget);
    expect(find.text('Tiket Masuk'), findsWidgets);
    expect(find.text('Deskripsi Lengkap'), findsOneWidget);
    expect(find.text('Fasilitas Tersedia'), findsOneWidget);
    expect(find.text('Peta Lokasi & Akses'), findsOneWidget);
    expect(find.text('Tambahkan ke Itinerary'), findsOneWidget);
  });

  test('TripModel and TripItemModel convert to and from SQLite map correctly', () {
    const item = TripItemModel(
      id: 1,
      tripId: 10,
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
      imageUrl: 'https://example.com/plunyon.jpg',
    );

    final itemMap = item.toMap();
    expect(itemMap['item_name'], 'Plunyon Kalikuning');
    expect(itemMap['duration_hours'], 1.5);
    expect(itemMap['elevation_mdpl'], 850);

    final restoredItem = TripItemModel.fromMap(itemMap);
    expect(restoredItem.itemName, item.itemName);
    expect(restoredItem.estimatedCost, 24000.0);
    expect(restoredItem.connectingDistanceKm, 4.2);

    final trip = TripModel(
      id: 10,
      userId: 1,
      tripName: 'Eksplorasi Merapi 1 Hari',
      startDate: 'Sabtu, 19 Okt 2024',
      participantCount: 2,
      targetBudget: 400000.0,
      totalEstimatedCost: 64000.0,
      status: 'upcoming',
      reminderEnabled: true,
      isSavedOffline: true,
      createdAt: '2026-10-12',
      items: [item],
    );

    final tripMap = trip.toMap();
    expect(tripMap['trip_name'], 'Eksplorasi Merapi 1 Hari');
    expect(tripMap['target_budget'], 400000.0);

    final restoredTrip = TripModel.fromMap(tripMap, items: [restoredItem]);
    expect(restoredTrip.id, 10);
    expect(restoredTrip.tripName, trip.tripName);
    expect(restoredTrip.items.length, 1);
  });

  test('TripProvider calculates budget and manages builder items', () {
    final provider = TripProvider();
    provider.initBuilderTrip(empty: false);

    expect(provider.builderTrip != null, true);
    expect(provider.builderItems.length, 3);

    // Initial total ticket cost (Plunyon 24.000 + Kaliadem 20.000 + Museum 10.000 = 54.000)
    expect(provider.totalTicketCost, 54000.0);
    expect(provider.totalMandatoryCost, 64000.0); // 54.000 + 10.000 parkir
    expect(provider.remainingBudget, 336000.0); // 400.000 - 64.000

    // Reorder items (dalam ReorderableListView, pindah item 0 ke bawah item 1 menggunakan newIndex: 2)
    final firstItemName = provider.builderItems[0].itemName;
    provider.reorderBuilderItems(0, 2);
    expect(provider.builderItems[1].itemName, firstItemName);
    expect(provider.builderItems[0].visitOrder, 1);
    expect(provider.builderItems[1].visitOrder, 2);

    // Remove item
    final countBefore = provider.builderItems.length;
    provider.removeBuilderItem(0);
    expect(provider.builderItems.length, countBefore - 1);
  });

  testWidgets('MyTripScreen displays active trip hero, volcanic indicator, timeline, budget estimation, and elevation profile', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final tripProvider = TripProvider();
    await tester.runAsync(() async {
      await tripProvider.loadUserTrips(1);
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
        ],
        child: const MaterialApp(
          home: MyTripScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi Header My Trip
    expect(find.text('My Trip'), findsOneWidget);
    expect(find.text('Perjalanan'), findsOneWidget);
    expect(find.text('+ Trip Baru'), findsOneWidget);

    // Verifikasi Segmented Tabs
    expect(find.textContaining('Mendatang'), findsOneWidget);
    expect(find.textContaining('Draft'), findsWidgets);
    expect(find.textContaining('Selesai'), findsOneWidget);

    // Verifikasi Cards
    expect(find.text('PILIH TRIP AKTIF'), findsOneWidget);
    expect(find.text('TERKONFIRMASI'), findsOneWidget);
    expect(find.text('KONVERSI'), findsOneWidget);
    expect(find.text('BUDGET'), findsOneWidget);
    expect(find.text('TIMELINE RUTE'), findsOneWidget);
  });

  testWidgets('CreateTripScreen renders step progress, volcanic status, interactive drag items, and budget calculator', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final destProvider = DestinationProvider();
    await tester.runAsync(() async {
      await destProvider.loadDestinations(userId: 1);
    });

    final tripProvider = TripProvider();
    tripProvider.initBuilderTrip();

    final utilityProvider = UtilityProvider(autoInit: false);
    utilityProvider.setRatesForTesting(
      rates: {'EUR': 1.0, 'IDR': 20000.0, 'USD': 1.0, 'JPY': 100.0},
      apiDate: '2026-10-14',
      lastSyncText: '15 Okt 2026',
      isCache: false,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<DestinationProvider>.value(value: destProvider),
          ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
          ChangeNotifierProvider<UtilityProvider>.value(value: utilityProvider),
        ],
        child: const MaterialApp(
          home: CreateTripScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Berpindah ke Langkah 2 (Destinasi & Jadwal)
    await tester.tap(find.text('2. Destinasi & Jadwal'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi Stepper & Metadata
    expect(find.text('Trip Baru'), findsOneWidget);
    expect(find.text('LANGKAH 2 DARI 3: DESTINASI & JADWAL'), findsOneWidget);

    // Verifikasi Kondisi Default Kosong & Tombol Tambah
    expect(find.text('Belum ada destinasi'), findsOneWidget);
    expect(find.text('Pilih Destinasi'), findsOneWidget);

    // Tambahkan destinasi ke builder
    final plunyon = destProvider.allDestinations.firstWhere(
      (d) => d.name.contains('Plunyon'),
      orElse: () => destProvider.allDestinations.first,
    );
    tripProvider.addDestinationToBuilder(plunyon);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi Item Perjalanan setelah ditambahkan
    expect(find.text(plunyon.name), findsOneWidget);
    expect(find.text('Lanjut ke Ringkasan'), findsOneWidget);
  });

  // ==================== TAHAP E: PETA MERAPI & OFFLINE MANAGER TESTS ====================

  test('GeoHelper calculates Haversine distance, formats duration, and checks KRB zones', () {
    // Jarak dari titik acuan pengguna ke Bunker Kaliadem (-7.5562, 110.4502)
    final dist = GeoHelper.distanceToUser(-7.5562, 110.4502);
    expect(dist > 0, true);
    expect(dist < 10.0, true);

    // Jarak dari puncak Gunung Merapi ke puncak itu sendiri mendekati 0 km
    final summitDist = GeoHelper.distanceFromMerapiSummit(
      GeoHelper.merapiSummitLat,
      GeoHelper.merapiSummitLng,
    );
    expect(summitDist, closeTo(0.0, 0.01));

    // Zona KRB III (< 3 km dari puncak)
    final krbSummit = GeoHelper.getKrbZone(
      GeoHelper.merapiSummitLat,
      GeoHelper.merapiSummitLng,
    );
    expect(krbSummit.contains('KRB III'), true);
    expect(
      GeoHelper.isSafeTourismZone(
        GeoHelper.merapiSummitLat,
        GeoHelper.merapiSummitLng,
      ),
      false,
    );

    // Zona KRB I (> 5 km dari puncak, posisi Kaliurang)
    final krbKaliurang = GeoHelper.getKrbZone(
      GeoHelper.userDefaultLat,
      GeoHelper.userDefaultLng,
    );
    expect(krbKaliurang.contains('KRB I'), true);
    expect(
      GeoHelper.isSafeTourismZone(
        GeoHelper.userDefaultLat,
        GeoHelper.userDefaultLng,
      ),
      true,
    );

    // Format jarak dan estimasi durasi berkendara
    final formatted = GeoHelper.formatDistanceAndDuration(4.2);
    expect(formatted.contains('4.2 km'), true);
    expect(formatted.contains('mnt'), true);
  });

  test('OfflinePackModel calculates progress and serializes to and from Map', () {
    const pack = OfflinePackModel(
      id: 10,
      name: 'Kawasan Lereng Selatan',
      sizeMb: 20.0,
      downloadedMb: 10.0,
      status: 'downloading',
      badgeLabel: 'Mengunduh 50%',
      iconType: 'terrain',
    );

    expect(pack.progress, 0.5);
    expect(pack.progressPercent, 50);

    final map = pack.toMap();
    expect(map['name'], 'Kawasan Lereng Selatan');
    expect(map['size_mb'], 20.0);

    final reconstructed = OfflinePackModel.fromMap(map);
    expect(reconstructed.id, 10);
    expect(reconstructed.name, pack.name);
    expect(reconstructed.status, pack.status);

    final updated = pack.copyWith(status: 'downloaded', downloadedMb: 20.0);
    expect(updated.progress, 1.0);
    expect(updated.progressPercent, 100);
  });

  test('MapProvider manages offline map packs, storage allocation, and view mode toggle', () {
    final provider = MapProvider();

    // Verifikasi initial state
    expect(provider.viewMode, 'map');
    expect(provider.offlinePacks.length, 4);
    expect(provider.allocatedStorageMb, 512.0);
    expect(provider.totalDownloadedMb > 0, true);
    expect(provider.usagePercent > 0, true);
    expect(provider.selectedDestination != null, true);

    // Toggle view mode (Peta -> Daftar -> Peta)
    provider.toggleViewMode();
    expect(provider.viewMode, 'list');
    provider.setViewMode('map');
    expect(provider.viewMode, 'map');

    // Toggle Wi-Fi only
    final initialWifi = provider.isWifiOnly;
    provider.toggleWifiOnly();
    expect(provider.isWifiOnly, !initialWifi);

    // Retry unduhan yang gagal (pack id 4: Geowisata Bebeng & Klangon)
    provider.retryDownload(4);
    final pack4 = provider.offlinePacks.firstWhere((p) => p.id == 4);
    expect(pack4.status, 'downloading');

    // Pause unduhan
    provider.pauseDownload(4);
    final pausedPack = provider.offlinePacks.firstWhere((p) => p.id == 4);
    expect(pausedPack.status, 'paused');

    // Resume unduhan
    provider.resumeDownload(4);
    final resumedPack = provider.offlinePacks.firstWhere((p) => p.id == 4);
    expect(resumedPack.status, 'downloading');

    // Pembersihan cache
    provider.cleanCache();
    expect(provider.offlinePacks.isNotEmpty, true);
  });

  testWidgets('MapScreen renders GPS safety banner, POI markers, and switches between map and proximity list', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final destProvider = DestinationProvider();
    await destProvider.loadDestinations(userId: 1);

    final mapProvider = MapProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<DestinationProvider>.value(value: destProvider),
          ChangeNotifierProvider<MapProvider>.value(value: mapProvider),
        ],
        child: const MaterialApp(
          home: MapScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi AppBar & Hapus tulisan GPS Akurat & Hemat Daya
    expect(find.text('Peta Merapi Navigasi'), findsOneWidget);
    expect(find.textContaining('GPS Akurat'), findsNothing);
    expect(find.text('Hemat Daya'), findsNothing);

    // Verifikasi Label Puncak Merapi & Penghapusan Zona Wisata Aman
    expect(find.text('PUNCAK MERAPI (2.930 MDPL)'), findsOneWidget);
    expect(find.textContaining('Zona Wisata Aman'), findsNothing);

    // Verifikasi Kontrol Toggle Tampilan
    expect(find.text('Peta'), findsOneWidget);
    expect(find.text('Daftar'), findsOneWidget);

    // Verifikasi Bottom Sheet Destinasi Terpilih (Bunker Kaliadem)
    expect(find.text('Bunker Kaliadem'), findsWidgets);
    expect(find.text('Petunjuk Arah'), findsOneWidget);
    expect(find.text('Detail'), findsWidgets);

    // Beralih ke Mode Daftar
    await tester.tap(find.text('Daftar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(mapProvider.viewMode, 'list');

    // Beralih kembali ke Mode Peta
    await tester.tap(find.text('Peta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(mapProvider.viewMode, 'map');
  });

  testWidgets('OfflineMapScreen renders storage info, 4 regional packs, Wi-Fi toggle, and download all CTA', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final mapProvider = MapProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<MapProvider>.value(value: mapProvider),
        ],
        child: const MaterialApp(
          home: OfflineMapScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi Judul & Storage Readiness Card
    expect(find.text('Manajer Peta Offline'), findsOneWidget);
    expect(find.text('Mode Offline Siap Digunakan'), findsOneWidget);
    expect(find.text('Tersinkron'), findsOneWidget);
    expect(find.textContaining('/ 512 MB Dialokasikan'), findsOneWidget);

    // Verifikasi 4 Paket Kawasan Lereng Merapi
    expect(find.text('Kaliadem & Cangkringan'), findsOneWidget);
    expect(find.text('Kaliurang & Plunyon'), findsOneWidget);
    expect(find.text('Jalur Boyolali & Selo'), findsOneWidget);
    expect(find.text('Geowisata Bebeng & Klangon'), findsOneWidget);

    // Verifikasi Toggle Wi-Fi dan Tombol Unduh Semua
    expect(find.text('Hanya Unduh via Wi-Fi'), findsOneWidget);
    expect(find.text('Unduh Semua Data Kawasan Merapi (55 MB)'), findsOneWidget);
  });

  // ==================== TAHAP F: SENSOR & UTILITAS TESTS ====================

  test('SensorProvider manages accelerometer shake detection, random destinations, and compass bearing', () async {
    final provider = SensorProvider(autoInitSensors: false);

    // Verifikasi initial state
    expect(provider.isShakeEnabled, true);
    expect(provider.randomDestination != null, true);
    expect(provider.selectedTargetId, 'puncak');
    expect(provider.currentTarget.bearingDegrees, 345.0);
    expect(provider.headingDirection.contains('345°'), true);
    expect(provider.targets.length, 4);

    // Toggle shake
    provider.toggleShake(false);
    expect(provider.isShakeEnabled, false);
    expect(provider.sensorStatusLabel.contains('dinonaktifkan'), true);
    provider.toggleShake(true);
    expect(provider.isShakeEnabled, true);

    // Trigger acak destinasi
    provider.triggerRandomDestination();
    expect(provider.randomDestination != null, true);

    // Pilih target kompas Bunker Kaliadem
    provider.setCompassTarget('kaliadem');
    expect(provider.selectedTargetId, 'kaliadem');
    expect(provider.currentTarget.bearingDegrees, 10.0);
    expect(provider.headingDirection.contains('10°'), true);

    // Kalibrasi kompas
    await provider.calibrateCompass();
    expect(provider.accuracyText.contains('Tinggi (Terkalibrasi)'), true);
  });

  test('UtilityProvider calculates accurate currency conversions and traveler timezone offsets', () async {
    final provider = UtilityProvider(autoInit: false);
    provider.setRatesForTesting(
      rates: {
        'EUR': 1.0,
        'USD': 17200.0 / 15850.0,
        'IDR': 17200.0,
        'JPY': 106.0,
      },
      apiDate: '2026-10-14',
    );

    // Verifikasi default state kurs
    expect(provider.sourceCurrencyCode, 'USD');
    expect(provider.targetCurrencyCode, 'IDR');
    expect(provider.sourceAmount, 100.0);
    expect(provider.convertedAmount, 1585000.0);
    expect(provider.formattedConvertedResult.contains('1.585.000 IDR'), true);
    expect(provider.exchangeRateReferenceText.contains('15.850 IDR'), true);

    // Swap currency
    provider.swapCurrencies();
    expect(provider.sourceCurrencyCode, 'IDR');
    expect(provider.targetCurrencyCode, 'USD');

    // Ubah nominal
    provider.setSourceCurrency('EUR');
    provider.setTargetCurrency('IDR');
    provider.setSourceAmount(50.0);
    expect(provider.convertedAmount, 50.0 * 17200.0);

    // Verifikasi sinkronisasi
    await provider.syncRates();
    expect(provider.lastSyncText.contains('WIB'), true);

    // Verifikasi zona waktu
    expect(provider.selectedTravelerTzId, 'london');
    expect(provider.selectedTravelerTz.offsetHoursFromWib, -6);
    expect(provider.timeLagBadgeText, '+6 Jam');
    expect(provider.formattedMerapiTime, '09:00');
    expect(provider.formattedTravelerTime, '03:00');
    expect(provider.travelerTimeOfDayDescription, 'Pagi hari');

    // Ubah ke Tokyo (UTC+9 / +2 dari WIB)
    provider.setSelectedTravelerTz('tokyo');
    expect(provider.selectedTravelerTz.offsetHoursFromWib, 2);
    expect(provider.timeLagBadgeText, '-2 Jam');
    expect(provider.formattedTravelerTime, '11:00');
  });

  testWidgets('SensorCompassScreen renders shake detector, random destination card, and compass dial with Merapi needle', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final sensorProvider = SensorProvider(autoInitSensors: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<SensorProvider>.value(value: sensorProvider),
        ],
        child: const MaterialApp(
          home: SensorCompassScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi Header & Status Banner
    expect(find.text('Eksplorasi Sensor & Kompas'), findsOneWidget);
    expect(find.text('STATUS SENSOR PERANGKAT'), findsOneWidget);
    expect(find.text('2 Sensor Aktif'), findsOneWidget);

    // Verifikasi Mode Switcher
    expect(find.text('Goyang Ponsel'), findsOneWidget);
    expect(find.text('Kompas Lapangan'), findsOneWidget);

    // Verifikasi Tab Goyang Ponsel
    expect(find.text('Eksplorasi Goyang Ponsel'), findsOneWidget);
    expect(find.text('Pilihan Acak Hari Ini'), findsOneWidget);
    expect(find.text('Lihat Detail Destinasi'), findsOneWidget);
    expect(find.text('Goyang Lagi (Acak Ulang)'), findsOneWidget);
    expect(find.text('Perangkat tanpa sensor getar?'), findsOneWidget);

    // Tap Goyang Lagi
    await tester.tap(find.text('Goyang Lagi (Acak Ulang)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Beralih ke Tab Kompas Lapangan
    await tester.tap(find.text('Kompas Lapangan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Kompas Arah Menuju Puncak & Destinasi'), findsOneWidget);
    expect(find.text('Pilih Titik Target Orientasi:'), findsOneWidget);
    expect(find.text('Azimuth Puncak'), findsOneWidget);
    expect(find.text('MERAPI'), findsOneWidget);
    expect(find.text('Akurasi Sensor: Tinggi (Terkalibrasi)'), findsOneWidget);
    expect(find.text('Buka di Peta Navigasi Lengkap'), findsOneWidget);
  });

  testWidgets('CurrencyTimeScreen renders currency calculator, swap action, timezone comparison, and operational guide', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuth = AuthProvider();
    fakeAuth.setUserForTesting(
      const UserModel(
        id: 1,
        name: 'Bima Sakti',
        email: 'bima@wisatawan.id',
        passwordHash: 'hash',
        createdAt: '2026-10-12',
      ),
    );

    final utilityProvider = UtilityProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: fakeAuth),
          ChangeNotifierProvider<UtilityProvider>.value(value: utilityProvider),
        ],
        child: const MaterialApp(
          home: CurrencyTimeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verifikasi AppBar & Context Bar
    expect(find.text('Konversi Mata Uang & Waktu'), findsOneWidget);
    expect(find.text('Merapi Hub Utility'), findsOneWidget);
    expect(find.text('Mode Lapangan'), findsOneWidget);

    // Verifikasi Segmented Tabs
    expect(find.text('Kurs Valuta'), findsOneWidget);
    expect(find.text('Zona Waktu'), findsOneWidget);

    // Verifikasi Konten Tab Kurs Valuta
    expect(find.text('Tersimpan (Offline Cache)'), findsOneWidget);
    expect(find.text('MATA UANG ASAL'), findsOneWidget);
    expect(find.text('MATA UANG TUJUAN'), findsOneWidget);
    expect(find.text('HASIL KONVERSI SAAT INI'), findsOneWidget);
    expect(find.text('Terapkan ke Estimasi Anggaran Trip'), findsOneWidget);
    expect(find.text('Dukungan Kurs Wisman Merapi:'), findsOneWidget);

    // Beralih ke Tab Zona Waktu
    await tester.tap(find.text('Zona Waktu'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Konverter Zona Waktu Perjalanan'), findsOneWidget);
    expect(find.text('WAKTU ACUAN RENCANA BERANGKAT'), findsOneWidget);
    expect(find.text('Zona Asal Traveler'), findsOneWidget);
    expect(find.text('WIB (Gunung Merapi, UTC+7)'), findsOneWidget);
    expect(find.text('Tujuan Utama Tur'), findsOneWidget);
    expect(find.text('Referensi Cepat Zona Waktu:'), findsOneWidget);
    expect(find.text('Rencana Trip'), findsOneWidget);
    expect(find.text('Peta Navigasi'), findsOneWidget);
  });

  test('NotificationModel and NotificationProvider manage offline alarms, categories, and read states', () {
    final provider = NotificationProvider();

    // Inisialisasi awal
    expect(provider.isAlarmEnabled, true);
    expect(provider.alarmTiming, 'H-2 Jam');
    expect(provider.allNotifications.isNotEmpty, true);
    expect(provider.unreadCount > 0, true);

    // Toggle alarm
    provider.toggleAlarm(false);
    expect(provider.isAlarmEnabled, false);
    provider.toggleAlarm(true);
    expect(provider.isAlarmEnabled, true);

    // Ubah timing alarm
    provider.setAlarmTiming('H-1 Jam');
    expect(provider.alarmTiming, 'H-1 Jam');

    // Filter kategori
    provider.setFilter('volcano');
    expect(provider.activeFilter, 'volcano');
    expect(provider.filteredNotifications.every((n) => n.category == 'volcano'), true);

    provider.setFilter('trip');
    expect(provider.filteredNotifications.every((n) => n.category == 'trip'), true);

    provider.setFilter('all');
    expect(provider.filteredNotifications.length, provider.allNotifications.length);

    // Mark as read per item
    final unreadItem = provider.allNotifications.firstWhere((n) => !n.isRead);
    provider.markAsRead(unreadItem.id);
    final readItem = provider.allNotifications.firstWhere((n) => n.id == unreadItem.id);
    expect(readItem.isRead, true);

    // Mark all as read
    provider.markAllAsRead();
    expect(provider.unreadCount, 0);
    expect(provider.allNotifications.every((n) => n.isRead), true);

    // Tambah notifikasi baru
    provider.addNotification(
      const NotificationModel(
        id: 99,
        title: 'Tes Notifikasi Baru',
        body: 'Pesan pengingat baru diuji.',
        category: 'system',
        timeAgo: 'Baru saja',
        tag: 'Tes Sistem',
        isRead: false,
      ),
    );
    expect(provider.unreadCount, 1);
    expect(provider.allNotifications.any((n) => n.title == 'Tes Notifikasi Baru'), true);
  });

  test('AiChatModel and AiAssistantProvider handle interactive chat, quick prompts, and itinerary adoption', () async {
    final aiProvider = AiAssistantProvider();
    final tripProvider = TripProvider();

    expect(aiProvider.messages.isNotEmpty, true);
    expect(aiProvider.isTyping, false);
    expect(aiProvider.quickPrompts.length, 4);

    // Quick prompt trigger
    await aiProvider.selectQuickPrompt('Wisata ramah keluarga');
    expect(aiProvider.selectedQuickPrompt, 'Wisata ramah keluarga');
    expect(aiProvider.messages.any((m) => m.text.contains('keluarga')), true);

    // Send custom message
    await aiProvider.sendMessage('Bagaimana kondisi jalur menuju Bunker?');
    expect(aiProvider.messages.any((m) => m.text.contains('Bunker')), true);
    expect(aiProvider.isTyping, false);

    // Itinerary recommendation validation
    final rec = aiProvider.defaultRecommendation;
    expect(rec.stops.length, 3);
    expect(rec.estimatedTicket, 'Rp 22.000/org');

    // Adopsi itinerary ke My Trip SQLite
    final adoptSuccess = await aiProvider.adoptItineraryToMyTrip(tripProvider, userId: 1);
    expect(adoptSuccess, true);
    expect(tripProvider.allTrips.any((t) => t.tripName == rec.title), true);
  });

  testWidgets('NotificationScreen renders filter pills, local alarm card, notification feed, and mark all read',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authProvider = AuthProvider();
    final notifProvider = NotificationProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<NotificationProvider>.value(value: notifProvider),
        ],
        child: const MaterialApp(
          home: NotificationScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Header & App Bar
    expect(find.text('Notifikasi & Pengingat'), findsOneWidget);

    // Validasi Banner Alarm Lokal
    expect(find.text('PENJADWALAN LOKAL AKTIF'), findsOneWidget);
    expect(find.textContaining('06:00 WIB'), findsOneWidget);
    expect(find.text('H-1 Hari'), findsOneWidget);
    expect(find.text('H-2 Jam'), findsOneWidget);

    // Validasi Filter Pills
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Pengingat Trip'), findsOneWidget);
    expect(find.text('Info Vulkanik'), findsOneWidget);
    expect(find.text('Sistem & Notifikasi'), findsWidgets);

    // Validasi Feed Notifikasi
    expect(find.text('Aktivitas Terbaru'), findsOneWidget);
    expect(find.text('Tandai Dibaca'), findsOneWidget);

    // Tap 'Tandai Dibaca'
    await tester.tap(find.text('Tandai Dibaca'));
    await tester.pump();
    expect(notifProvider.unreadCount, 0);
  });

  testWidgets('AiAssistantScreen renders status bar, greeting chat bubble, quick prompt chips, and itinerary recommendation card',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authProvider = AuthProvider();
    final tripProvider = TripProvider();
    final aiProvider = AiAssistantProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
          ChangeNotifierProvider<AiAssistantProvider>.value(value: aiProvider),
        ],
        child: const MaterialApp(
          home: AiAssistantScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Title & Companion Status
    expect(find.text('Ai Assistant'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('MeraTrip AI'), findsWidgets);

    // Validasi Quick Prompts
    expect(find.textContaining('Buat itinerary 1 hari'), findsWidgets);
    expect(find.textContaining('Wisata ramah keluarga'), findsWidgets);

    // Validasi Kartu Rekomendasi Itinerary
    expect(find.text('Rute Pine & Heritage Merapi'), findsOneWidget);
    expect(find.textContaining('Plunyon Kalikuning'), findsWidgets);
    expect(find.textContaining('Bunker Kaliadem'), findsWidgets);
    expect(find.textContaining('Museum Mini Sisa Hartaku'), findsWidgets);
    expect(find.text('Simpan ke My Trip'), findsOneWidget);
    expect(find.text('Kustomisasi Rute'), findsOneWidget);

    // Validasi Floating Input Field
    expect(find.byType(TextField), findsOneWidget);
  });

  test('QuizProvider and QuizModel manage score, questions, active Jagawana rank, and navigation correctly', () {
    final provider = QuizProvider();

    // Verifikasi Kondisi Awal
    expect(provider.totalQuestions, 5);
    expect(provider.currentQuestionIndex, 0);
    expect(provider.userScore, 850);
    expect(provider.activeRankTitle, 'Jagawana Merapi Tingkat 3');
    expect(provider.isAnswered, false);
    expect(provider.sessionEarnedPoints, 0);
    expect(provider.sessionCorrectCount, 0);
    expect(provider.leaderboard.length, 5);

    final QuizQuestionModel q1 = provider.currentQuestion;
    expect(q1.id, 1);
    expect(q1.options.length, 4);

    // Jawab dengan Jawaban yang Benar
    provider.answerQuestion(q1.correctIndex);
    expect(provider.isAnswered, true);
    expect(provider.isCurrentAnswerCorrect, true);
    expect(provider.sessionEarnedPoints, 50);
    expect(provider.sessionCorrectCount, 1);
    expect(provider.userScore, 900);

    // Navigasi ke Pertanyaan Berikutnya
    provider.nextQuestion();
    expect(provider.currentQuestionIndex, 1);
    expect(provider.isAnswered, false);
    expect(provider.selectedOptionIndex, isNull);

    // Jawab Pertanyaan Kedua dengan Jawaban yang Salah
    final q2 = provider.currentQuestion;
    final wrongIndex = (q2.correctIndex + 1) % 4;
    provider.answerQuestion(wrongIndex);
    expect(provider.isAnswered, true);
    expect(provider.isCurrentAnswerCorrect, false);
    expect(provider.sessionCorrectCount, 1); // Tidak bertambah
    expect(provider.sessionEarnedPoints, 50); // Tidak bertambah

    // Reset Quiz
    provider.resetQuiz();
    expect(provider.currentQuestionIndex, 0);
    expect(provider.isAnswered, false);
    expect(provider.sessionEarnedPoints, 0);
    expect(provider.sessionCorrectCount, 0);
  });

  test('BlockchainProvider manages SHA-256 blocks, validates chain, simulates tamper, and restores consensus', () async {
    final provider = BlockchainProvider();

    // 1. Verifikasi 4 Blok Awal
    expect(provider.blocks.length, 4);
    expect(provider.isChainValid, true);
    expect(provider.invalidBlockIndex, isNull);
    expect(provider.isTamperedState, false);

    // Genesis Block
    final BlockModel b0 = provider.blocks[0];
    expect(b0.index, 1);
    expect(b0.previousHash, '00000000000000000000000000000000');
    expect(b0.hash.length, 64); // SHA-256 Hex 64 chars

    // Blok-blok berantai
    for (int i = 1; i < provider.blocks.length; i++) {
      expect(provider.blocks[i].previousHash, provider.blocks[i - 1].hash);
    }

    // 2. Simulasi Manipulasi Data pada Blok 3 (Izin Konservasi & Tiket)
    provider.simulateTamper(3);
    expect(provider.isTamperedState, true);
    expect(provider.isChainValid, false);
    expect(provider.invalidBlockIndex, 3);
    expect(provider.auditStatus, contains('Blok #03'));

    // 3. Pemulihan Konsensus Rantai Asli
    provider.restoreChain();
    expect(provider.isTamperedState, false);
    expect(provider.isChainValid, true);
    expect(provider.invalidBlockIndex, isNull);

    // 4. Jalankan Audit Lengkap
    await provider.runChainAudit();
    expect(provider.isAuditing, false);
    expect(provider.auditStatus, contains('Audit Selesai'));
  });

  testWidgets('QuizScreen renders header, active rank badge, question card, option selection, and answer feedback',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authProvider = AuthProvider();
    final quizProvider = QuizProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<QuizProvider>.value(value: quizProvider),
        ],
        child: const MaterialApp(
          home: QuizScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Header AppBar & Chip Kuis
    expect(find.text('Kuis Jelajah Merapi'), findsOneWidget);
    expect(find.text('Mode Kuis Edukasi Wisata'), findsOneWidget);
    expect(find.textContaining('Jagawana Merapi Tingkat 3'), findsWidgets);

    // Validasi Soal Pertama
    expect(find.textContaining('batu vulkanik besar'), findsWidgets);
    expect(find.text('Batu Alien Cangkringan'), findsOneWidget);
    expect(find.text('Batu Gajah Kaliadem'), findsOneWidget);

    // Tap Jawaban Benar (Batu Alien Cangkringan)
    await tester.tap(find.text('Batu Alien Cangkringan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Feedback Box Jawaban Benar
    expect(find.textContaining('Tepat Sekali! (+50 Poin)'), findsOneWidget);
    expect(find.textContaining('Dusun Jambu'), findsWidgets);
    expect(find.text('Pertanyaan Berikutnya'), findsOneWidget);

    // Validasi Modal Papan Peringkat
    await tester.tap(find.byTooltip('Papan Peringkat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Papan Peringkat Jagawana'), findsOneWidget);
    expect(find.textContaining('Aditya Pratama'), findsWidgets);
    expect(find.textContaining('Bima Sakti'), findsWidgets);

    // Tutup Modal
    await tester.tap(find.text('Tutup'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('BlockchainScreen renders node status banner, 4 connected SHA-256 blocks, and tamper simulation interaction',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authProvider = AuthProvider();
    final chainProvider = BlockchainProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<BlockchainProvider>.value(value: chainProvider),
        ],
        child: const MaterialApp(
          home: BlockchainScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Header AppBar & Live Status
    expect(find.text('Riwayat Integritas Blockchain'), findsOneWidget);
    expect(find.text('NODE MERAPI TNGM LIVE'), findsOneWidget);
    expect(find.text('BUKU BESAR KONSERVASI'), findsOneWidget);
    expect(find.text('Riwayat Blok Integritas Data'), findsOneWidget);
    expect(find.text('4 Blok'), findsOneWidget);
    expect(find.text('SHA-256'), findsOneWidget);

    // Validasi Blok-blok Riwayat
    expect(find.textContaining('Pendaftaran Akun Penjelajah'), findsWidgets);
    expect(find.textContaining('Itinerary Eksplorasi Merapi'), findsWidgets);
    expect(find.textContaining('Izin Konservasi & Tiket Plunyon'), findsWidgets);
    expect(find.textContaining('Sertifikat Gelar Jagawana'), findsWidgets);

    // Scroll ke bagian bawah ListView untuk menjangkau Action Card Audit & Tamper Test
    await tester.scrollUntilVisible(find.text('Simulasi Manipulasi (Tamper Test)'), 300);
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();

    // Validasi Tombol Audit & Tamper Test
    expect(find.text('Validasi Seluruh Rantai Blok'), findsOneWidget);
    expect(find.text('Simulasi Manipulasi (Tamper Test)'), findsOneWidget);

    // Tap 'Simulasi Manipulasi (Tamper Test)'
    await tester.tap(find.text('Simulasi Manipulasi (Tamper Test)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi State Tampered
    expect(chainProvider.isChainValid, false);
    expect(find.text('Pulihkan Rantai Asli'), findsOneWidget);
    expect(find.textContaining('Integritas Rantai Terlanggar'), findsWidgets);

    // Tap 'Pulihkan Rantai Asli'
    await tester.tap(find.text('Pulihkan Rantai Asli'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Rantai Pulih
    expect(chainProvider.isChainValid, true);
    expect(find.text('Simulasi Manipulasi (Tamper Test)'), findsOneWidget);
  });

  testWidgets('ProfileScreen renders traveler identity, Jagawana stats, menu tiles, and navigates to CourseFeedbackScreen',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final authProvider = AuthProvider();
    final quizProvider = QuizProvider();
    final chainProvider = BlockchainProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<QuizProvider>.value(value: quizProvider),
          ChangeNotifierProvider<BlockchainProvider>.value(value: chainProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Validasi Identitas Penjelajah
    expect(find.text('Bima Sakti'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    // Validasi Bagian Navigasi & Pengaturan (Hanya 3 Menu)
    expect(find.text('Navigasi & Pengaturan'), findsOneWidget);
    expect(find.text('Mini Game Kuis Merapi'), findsOneWidget);
    expect(find.text('Refleksi Kuliah & Evaluasi PAM'), findsOneWidget);
    expect(find.text('Kunci Biometrik Aplikasi'), findsOneWidget);
    expect(find.text('Keluar dari Akun'), findsOneWidget);

    // Scroll ke item menu Refleksi Kuliah & Evaluasi PAM
    await tester.scrollUntilVisible(find.text('Refleksi Kuliah & Evaluasi PAM'), 200);
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.text('Refleksi Kuliah & Evaluasi PAM'), findsOneWidget);

    // Tap 'Refleksi Kuliah & Evaluasi PAM' untuk navigasi ke CourseFeedbackScreen
    await tester.tap(find.text('Refleksi Kuliah & Evaluasi PAM'));
    await tester.pumpAndSettle();

    // Validasi Halaman Evaluasi Mata Kuliah PAM
    expect(find.byType(CourseFeedbackScreen), findsOneWidget);
    expect(find.text('Evaluasi Mata Kuliah PAM'), findsOneWidget);
    expect(find.text('Refleksi & Penilaian Praktikum'), findsOneWidget);
    expect(find.text('Nama Mahasiswa / Evaluator'), findsOneWidget);
    expect(find.text('Rating Kepuasan Arsitektur & UI/UX Aplikasi'), findsOneWidget);
    expect(find.text('Modul yang Telah Diuji & Divalidasi:'), findsOneWidget);

    // Scroll ke tombol submit
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Kirim Evaluasi & Simpan'), findsOneWidget);

    // Tap 'Kirim Evaluasi & Simpan'
    await tester.tap(find.text('Kirim Evaluasi & Simpan'));
    await tester.pump();
    await tester.runAsync(() async {
      await Future.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Validasi Dialog Berhasil
    expect(find.text('Evaluasi Terkirim!'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);

    // Tutup Dialog
    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    // Kembali ke Halaman Profil
    expect(find.text('Bima Sakti'), findsOneWidget);
  });
}

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration? connectionTimeout;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  int? maxConnectionsPerHost;
  @override
  String? userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) {}

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) {}

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) {}

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) {}

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) {}

  @override
  set findProxy(String Function(Uri url)? f) {}

  @override
  void close({bool force = false}) {}

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _handleUrl(url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _handleUrl(url);

  Future<HttpClientRequest> _handleUrl(Uri url) async {
    if (url.host.contains('supabase') ||
        url.host.contains('generativelanguage') ||
        url.host.contains('frankfurter')) {
      throw const SocketException('Simulated offline network in widget tests');
    }
    return _MockHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  @override
  void add(List<int> data) {}

  @override
  void write(Object? obj) {}

  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override
  final HttpHeaders headers = _MockHttpHeaders();

  static final Uint8List _kTransparentImage = Uint8List.fromList(<int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
    0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
    0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
    0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
    0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
    0x60, 0x82,
  ]);

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
