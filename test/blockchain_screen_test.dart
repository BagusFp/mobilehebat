import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/models/user_model.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/blockchain/blockchain_provider.dart';
import 'package:project/features/blockchain/blockchain_screen.dart';
import 'package:project/features/trip/trip_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required TripProvider tripProvider,
    required BlockchainProvider blockchainProvider,
  }) {
    final auth = AuthProvider();
    auth.setUserForTesting(
      const UserModel(
        id: 1,
        email: 'bima.sakti@wisatawan.id',
        name: 'Bima Sakti',
        passwordHash: 'dummy',
        profilePhoto: null,
        createdAt: '2026-10-23',
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
        ChangeNotifierProvider<BlockchainProvider>.value(value: blockchainProvider),
      ],
      child: const MaterialApp(
        home: BlockchainScreen(),
      ),
    );
  }

  testWidgets('BlockchainScreen renders header, testnet badge, and 2 tabs', (tester) async {
    final tripProvider = TripProvider();
    final blockchainProvider = BlockchainProvider();

    await tester.pumpWidget(createTestWidget(
      tripProvider: tripProvider,
      blockchainProvider: blockchainProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Catatan Bukti Blockchain'), findsOneWidget);
    expect(find.text('Sepolia Testnet'), findsOneWidget);
    expect(find.text('Proof of Visit'), findsOneWidget);
    expect(find.text('Ledger Konservasi'), findsOneWidget);
  });

  testWidgets('Proof of Visit tab displays empty state when no completed trips exist', (tester) async {
    final tripProvider = TripProvider();
    tripProvider.setTripsForTesting([
      const TripModel(
        id: 1,
        userId: 1,
        tripName: 'Trip Mendatang',
        startDate: '2026-10-25',
        status: 'upcoming',
        createdAt: '2026-10-23',
      ),
    ]);

    final blockchainProvider = BlockchainProvider();

    await tester.pumpWidget(createTestWidget(
      tripProvider: tripProvider,
      blockchainProvider: blockchainProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Tidak ada bukti perjalanan.'), findsOneWidget);
    expect(
      find.text('Selesaikan trip untuk membuat bukti perjalanan di blockchain.'),
      findsOneWidget,
    );
  });

  testWidgets('Proof of Visit tab displays completed trip with action button', (tester) async {
    final tripProvider = TripProvider();
    tripProvider.setTripsForTesting([
      TripModel(
        id: 10,
        userId: 1,
        tripName: 'Eksplorasi Merapi Selesai',
        startDate: '2026-10-23',
        status: 'completed',
        completedAt: '2026-10-23T16:00:00Z',
        createdAt: '2026-10-23',
        items: const [
          TripItemModel(
            id: 101,
            tripId: 10,
            itemName: 'Bunker Kaliadem',
            visitOrder: 1,
            isCompleted: true,
          ),
        ],
      ),
    ]);

    final blockchainProvider = BlockchainProvider();

    await tester.pumpWidget(createTestWidget(
      tripProvider: tripProvider,
      blockchainProvider: blockchainProvider,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Eksplorasi Merapi Selesai'), findsOneWidget);
    expect(find.text('Belum dibuat'), findsOneWidget);
    expect(find.text('Buat Bukti Perjalanan'), findsOneWidget);
  });

  testWidgets('Ledger Konservasi tab renders blocks and runs tamper test', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final tripProvider = TripProvider();
    final blockchainProvider = BlockchainProvider();

    await tester.pumpWidget(createTestWidget(
      tripProvider: tripProvider,
      blockchainProvider: blockchainProvider,
    ));
    await tester.pumpAndSettle();

    // Switch to tab 2: Ledger Konservasi
    await tester.tap(find.text('Ledger Konservasi'));
    await tester.pumpAndSettle();

    expect(find.text('BUKU BESAR KONSERVASI'), findsOneWidget);
    expect(find.text('Rantai Valid'), findsOneWidget);

    final tamperButtonFinder = find.text('Simulasi Manipulasi (Tamper Test)');
    expect(tamperButtonFinder, findsOneWidget);

    await tester.tap(tamperButtonFinder);
    await tester.pumpAndSettle();

    expect(blockchainProvider.isTamperedState, isTrue);
    expect(find.text('Pulihkan Rantai Asli'), findsOneWidget);

    // Tap Pulihkan Rantai Asli
    await tester.tap(find.text('Pulihkan Rantai Asli'));
    await tester.pumpAndSettle();

    expect(blockchainProvider.isTamperedState, isFalse);
    expect(find.text('Simulasi Manipulasi (Tamper Test)'), findsOneWidget);
  });
}
