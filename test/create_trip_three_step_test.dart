import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project/data/models/trip_item_model.dart';
import 'package:project/data/models/trip_model.dart';
import 'package:project/data/repositories/trip_repository.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/explore/destination_provider.dart';
import 'package:project/features/trip/create_trip_screen.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:project/features/utility/utility_provider.dart';
import 'package:provider/provider.dart';

class FakeTripRepository extends TripRepository {
  List<TripModel> memoryTrips = [];

  @override
  Future<void> initTrips({bool seedIfEmpty = true}) async {}

  @override
  Future<List<TripModel>> getUserTrips(int userId, {String? status, bool forceOffline = false}) async {
    return memoryTrips;
  }

  @override
  Future<int> createTrip(TripModel trip) async {
    final newId = memoryTrips.length + 1;
    memoryTrips.add(trip.copyWith(id: newId));
    return newId;
  }

  @override
  Future<bool> updateTrip(TripModel trip) async {
    final idx = memoryTrips.indexWhere((t) => t.id == trip.id);
    if (idx != -1) {
      memoryTrips[idx] = trip;
      return true;
    }
    return false;
  }
}

void main() {
  testWidgets('CreateTripScreen displays 3-step wizard and ringkasan trip with notification reminder', (tester) async {
    final fakeRepo = FakeTripRepository();
    final tripProvider = TripProvider(repository: fakeRepo);
    final authProvider = AuthProvider();
    final destProvider = DestinationProvider();
    final utilityProvider = UtilityProvider();

    const sampleTrip = TripModel(
      id: 1,
      userId: 1,
      tripName: 'Exploration Offroad Merapi',
      startDate: '2026-10-25',
      createdAt: '2026-10-22',
      targetBudget: 500000,
      participantCount: 2,
      items: [
        TripItemModel(
          tripId: 1,
          visitOrder: 1,
          itemName: 'Museum Sisa Hartaku',
          estimatedCost: 20000,
          plannedTime: '07:30 - 09:00',
        ),
        TripItemModel(
          tripId: 1,
          visitOrder: 2,
          itemName: 'Bunker Kaliadem',
          estimatedCost: 20000,
          plannedTime: '09:15 - 10:45',
        ),
      ],
    );

    tripProvider.initBuilderTrip(existingTrip: sampleTrip);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TripProvider>.value(value: tripProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<DestinationProvider>.value(value: destProvider),
          ChangeNotifierProvider<UtilityProvider>.value(value: utilityProvider),
        ],
        child: const MaterialApp(
          home: CreateTripScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Verify Step 1: Budget Awal
    expect(find.text('LANGKAH 1 DARI 3: BUDGET AWAL'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget);
    expect(find.text('1. Budget Awal'), findsOneWidget);
    expect(find.text('2. Destinasi & Jam'), findsOneWidget);
    expect(find.text('3. Ringkasan Trip'), findsOneWidget);

    expect(find.text('INFORMASI PERJALANAN'), findsOneWidget);
    expect(find.text('TARGET BUDGET & PERSONALISASI'), findsOneWidget);
    expect(find.text('Pagu Target Anggaran Utama'), findsOneWidget);
    expect(find.text('Zona Waktu Asal Pengguna'), findsOneWidget);

    // 2. Tap button to move to Step 2
    final step1NextBtn = find.text('Lanjut Pilih Destinasi & Jam');
    expect(step1NextBtn, findsOneWidget);
    await tester.tap(step1NextBtn);
    await tester.pumpAndSettle();

    // 3. Verify Step 2: Destinasi & Jam
    expect(find.text('LANGKAH 2 DARI 3: DESTINASI & JAM'), findsOneWidget);
    expect(find.text('66%'), findsOneWidget);
    expect(find.text('Destinasi Terpilih'), findsOneWidget);
    expect(find.text('Museum Sisa Hartaku'), findsOneWidget);
    expect(find.text('Bunker Kaliadem'), findsOneWidget);

    // 4. Tap button to move to Step 3: Ringkasan Trip
    final step2NextBtn = find.text('Lanjut ke Ringkasan Trip');
    expect(step2NextBtn, findsOneWidget);
    await tester.tap(step2NextBtn);
    await tester.pumpAndSettle();

    // 5. Verify Step 3: Ringkasan Trip & Notifikasi
    expect(find.text('LANGKAH 3 DARI 3: RINGKASAN & NOTIF'), findsOneWidget);
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('RINGKASAN ANGGARAN & VALUTA'), findsOneWidget);
    expect(find.text('Target Budget Awal:'), findsOneWidget);
    expect(find.text('Total Biaya Tiket:'), findsOneWidget);
    expect(find.text('Sisa Anggaran:'), findsOneWidget);

    expect(find.text('ATUR PENGINGAT NOTIFIKASI TRIP'), findsOneWidget);
    expect(find.text('Waktu Pengiriman Pengingat:'), findsOneWidget);
    expect(find.text('H-1 Jam Sebelum Perjalanan (06:30 WIB)'), findsOneWidget);

    expect(find.text('Simpan & Buat Trip'), findsOneWidget);
  });
}
