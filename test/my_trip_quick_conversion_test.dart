import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/trip/my_trip_screen.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:project/features/utility/utility_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('MyTripScreen quick conversion dropdowns and multi-trip selection test', (tester) async {
    final trip1 = TripModel(
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
        const TripItemModel(
          id: 1,
          tripId: 1,
          itemName: 'Museum Sisa Hartaku',
          visitOrder: 1,
          plannedTime: '07:30 WIB',
          estimatedCost: 20000.0,
        ),
        const TripItemModel(
          id: 2,
          tripId: 1,
          itemName: 'Bunker Kaliadem',
          visitOrder: 2,
          plannedTime: '09:15 WIB',
          estimatedCost: 20000.0,
        ),
      ],
    );

    final trip2 = TripModel(
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
        const TripItemModel(
          id: 7,
          tripId: 5,
          itemName: 'Bunker Kaliadem',
          visitOrder: 1,
          plannedTime: '05:30 WIB',
          estimatedCost: 25000.0,
        ),
      ],
    );

    final tripProvider = TripProvider();
    tripProvider.setTripsForTesting([trip1, trip2]);

    final authProvider = AuthProvider();
    final utilityProvider = UtilityProvider();

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

    // 1. Verify Quick Conversion Card exists and has dropdowns
    expect(find.text('KONVERSI AKSES CEPAT'), findsOneWidget);
    expect(find.text('Zona Waktu:'), findsOneWidget);
    expect(find.text('Mata Uang:'), findsOneWidget);

    // There should be 2 DropdownButton widgets (Timezone and Currency)
    final dropdownFinders = find.byType(DropdownButton<String>);
    expect(dropdownFinders, findsNWidgets(2));

    // Verify initial values
    expect(find.text('WIB (GMT+7)'), findsWidgets);
    expect(find.text('IDR (Rp)'), findsOneWidget);

    // 2. Verify Active Trip Selector displays trip and count indicator
    expect(find.text('PILIH TRIP AKTIF'), findsOneWidget);
    expect(find.text('2 Trip'), findsOneWidget);
    expect(find.textContaining('Exploration Offroad Merapi'), findsWidgets);

    // 3. Tap on PILIH TRIP AKTIF to open the modal bottom sheet
    await tester.tap(find.text('PILIH TRIP AKTIF'));
    await tester.pumpAndSettle();

    // Modal should show "Pilih Trip untuk Dimulai" and both upcoming trips
    expect(find.text('Pilih Trip untuk Dimulai'), findsOneWidget);
    expect(find.text('TRIP MENDATANG TERSEDIA'), findsOneWidget);
    expect(find.text('Lava Tour Sunrise & Jeep Merapi'), findsOneWidget);
    expect(find.text('Pilih Aktif'), findsOneWidget);
    expect(find.text('Mulai Trip Ini'), findsOneWidget);

    // 4. Select the second trip
    await tester.tap(find.text('Pilih Aktif'));
    await tester.pumpAndSettle();

    // Now active trip selector card should show Lava Tour Sunrise & Jeep Merapi
    expect(find.textContaining('Lava Tour Sunrise & Jeep Merapi'), findsWidgets);
  });
}
