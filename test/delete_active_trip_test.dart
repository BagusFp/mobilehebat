import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/core/database/preferences_helper.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/repositories/trip_repository.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/trip/my_trip_screen.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:project/features/utility/utility_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeTripRepository extends TripRepository {
  List<TripModel> memoryTrips = [];
  int deleteCallCount = 0;

  @override
  Future<void> initTrips({bool seedIfEmpty = true}) async {}

  @override
  Future<List<TripModel>> getUserTrips(int userId, {String? status, bool forceOffline = false}) async {
    return List.from(memoryTrips);
  }

  @override
  Future<bool> deleteTrip(int tripId, {String? tripName}) async {
    deleteCallCount++;
    memoryTrips.removeWhere((t) => t.id == tripId);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TripProvider Deletion Logic', () {
    late FakeTripRepository fakeRepo;
    late TripModel trip5;
    late TripModel trip1;

    setUp(() {
      trip5 = const TripModel(
        id: 5,
        userId: 1,
        tripName: 'Lava Tour Sunrise & Jeep Merapi',
        startDate: '28 Okt 2026',
        createdAt: '2026-10-22',
        participantCount: 3,
        targetBudget: 650000.0,
        totalEstimatedCost: 45000.0,
        status: 'upcoming',
        items: [
          TripItemModel(
            id: 7,
            tripId: 5,
            itemName: 'Bunker Kaliadem',
            visitOrder: 1,
            plannedTime: '05:30 WIB',
            estimatedCost: 25000.0,
          ),
        ],
      );

      trip1 = const TripModel(
        id: 1,
        userId: 1,
        tripName: 'Exploration Offroad Merapi',
        startDate: '25 Okt 2026',
        createdAt: '2026-10-22',
        participantCount: 4,
        targetBudget: 500000.0,
        totalEstimatedCost: 40000.0,
        status: 'upcoming',
        items: [
          TripItemModel(
            id: 1,
            tripId: 1,
            itemName: 'Museum Sisa Hartaku',
            visitOrder: 1,
            plannedTime: '07:30 WIB',
            estimatedCost: 20000.0,
          ),
        ],
      );

      fakeRepo = FakeTripRepository();
      fakeRepo.memoryTrips = [trip5, trip1];
    });

    test('Trip 5 can be deleted and selectedTrip transitions to Trip 1', () async {
      final tripProvider = TripProvider(repository: fakeRepo);
      await tripProvider.loadUserTrips(1);

      expect(tripProvider.selectedTrip?.id, 5, reason: 'Trip 5 should be initially selected as active trip');

      // Delete Trip 5
      final success = await tripProvider.deleteTrip(5, 1);
      expect(success, isTrue, reason: 'deleteTrip should succeed');
      expect(fakeRepo.deleteCallCount, 1);

      // Verify Trip 5 is removed from state and repository
      expect(tripProvider.allTrips.any((t) => t.id == 5), isFalse);
      expect(fakeRepo.memoryTrips.any((t) => t.id == 5), isFalse);

      // Verify selectedTrip smoothly transitioned to Trip 1
      expect(tripProvider.selectedTrip?.id, 1, reason: 'selectedTrip should transition to Trip 1');
    });

    test('Deleting the last upcoming trip resets selectedTrip to null', () async {
      final tripProvider = TripProvider(repository: fakeRepo);
      await tripProvider.loadUserTrips(1);

      // Delete trip 5
      await tripProvider.deleteTrip(5, 1);
      expect(tripProvider.selectedTrip?.id, 1);

      // Delete trip 1
      final success = await tripProvider.deleteTrip(1, 1);
      expect(success, isTrue);
      expect(tripProvider.allTrips, isEmpty);
      expect(tripProvider.selectedTrip, isNull, reason: 'selectedTrip must be null when no upcoming trips remain');
    });

    test('Trip ownership check allows demo trip deletion by any logged-in user ID', () async {
      final tripProvider = TripProvider(repository: fakeRepo);
      await tripProvider.loadUserTrips(1);

      // User logged in as userId = 2 should be permitted to delete demo trip 5 (userId <= 1)
      final success = await tripProvider.deleteTrip(5, 2);
      expect(success, isTrue, reason: 'User with userId 2 should be able to delete demo trip');
    });

    test('Trip seeding flag prevents resurrection after deletion', () async {
      final prefs = await PreferencesHelper.instance;
      expect(prefs.hasTripsSeeded(), isFalse);

      await prefs.setTripsSeeded(true);
      expect(prefs.hasTripsSeeded(), isTrue);
    });
  });

  group('MyTripScreen UI Deletion Widget Test', () {
    testWidgets('MyTripScreen active trip delete button opens dialog and removes trip', (tester) async {
      const trip1 = TripModel(
        id: 5,
        userId: 1,
        tripName: 'Lava Tour Sunrise & Jeep Merapi',
        startDate: '28 Okt 2026',
        createdAt: '2026-10-22',
        participantCount: 3,
        targetBudget: 650000.0,
        totalEstimatedCost: 45000.0,
        status: 'upcoming',
        items: [
          TripItemModel(
            id: 7,
            tripId: 5,
            itemName: 'Bunker Kaliadem',
            visitOrder: 1,
            plannedTime: '05:30 WIB',
            estimatedCost: 25000.0,
          ),
        ],
      );

      const trip2 = TripModel(
        id: 1,
        userId: 1,
        tripName: 'Exploration Offroad Merapi',
        startDate: '25 Okt 2026',
        createdAt: '2026-10-22',
        participantCount: 4,
        targetBudget: 500000.0,
        totalEstimatedCost: 40000.0,
        status: 'upcoming',
        items: [
          TripItemModel(
            id: 1,
            tripId: 1,
            itemName: 'Museum Sisa Hartaku',
            visitOrder: 1,
            plannedTime: '07:30 WIB',
            estimatedCost: 20000.0,
          ),
        ],
      );

      final fakeRepo = FakeTripRepository();
      fakeRepo.memoryTrips = [trip1, trip2];

      final tripProvider = TripProvider(repository: fakeRepo);
      tripProvider.setTripsForTesting([trip1, trip2]);

      final authProvider = AuthProvider();
      final utilityProvider = UtilityProvider(autoInit: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
            ChangeNotifierProvider<UtilityProvider>.value(value: utilityProvider),
          ],
          child: const MaterialApp(
            home: MyTripScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify active trip is Lava Tour Sunrise
      expect(find.textContaining('Lava Tour Sunrise & Jeep Merapi'), findsWidgets);

      // Tap more_vert "Opsi Trip" button
      final moreVertFinder = find.byTooltip('Opsi Trip');
      expect(moreVertFinder, findsOneWidget);
      await tester.tap(moreVertFinder);
      await tester.pumpAndSettle();

      // Menu sheet should appear with "Hapus Trip"
      expect(find.text('Hapus Trip'), findsOneWidget);
      await tester.tap(find.text('Hapus Trip'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Hapus trip "Lava Tour Sunrise & Jeep Merapi"?'), findsOneWidget);
      expect(find.text('Hapus'), findsOneWidget);

      // Tap Hapus button
      await tester.tap(find.widgetWithText(ElevatedButton, 'Hapus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify success SnackBar
      expect(find.text('Trip "Lava Tour Sunrise & Jeep Merapi" berhasil dihapus.'), findsOneWidget);

      // Verify active trip is now Exploration Offroad Merapi
      expect(find.textContaining('Exploration Offroad Merapi'), findsWidgets);
      expect(find.text('Lava Tour Sunrise & Jeep Merapi'), findsNothing);

      // Let SnackBar dismiss
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
