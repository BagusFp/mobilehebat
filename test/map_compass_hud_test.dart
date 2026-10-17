import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/core/utils/geo_helper.dart';
import 'package:project/features/explore/destination_provider.dart';
import 'package:project/features/map/map_provider.dart';
import 'package:project/features/map/map_screen.dart';
import 'package:project/features/sensor/sensor_provider.dart';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('GeoHelper calculateBearing & bearingToMerapiSummit calculate correct angles', (tester) async {
    // Bearing from userDefaultLat (-7.5950, 110.4280) to Puncak Merapi (-7.5407, 110.4461)
    final bearing = GeoHelper.bearingToMerapiSummit(GeoHelper.userDefaultLat, GeoHelper.userDefaultLng);
    expect(bearing, greaterThan(0));
    expect(bearing, lessThan(45)); // General NNE direction (~18°)

    final dist = GeoHelper.distanceFromMerapiSummit(GeoHelper.userDefaultLat, GeoHelper.userDefaultLng);
    expect(dist, greaterThan(5.0)); // > 5 km from summit
  });

  testWidgets('MapScreen Opsi 1: compassBtn toggles Floating Mini Dial Kompas HUD', (tester) async {
    final destProvider = DestinationProvider();
    final mapProvider = MapProvider();
    final sensorProvider = SensorProvider(autoInitSensors: false);
    sensorProvider.setHeadingForTesting(345.0);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DestinationProvider>.value(value: destProvider),
          ChangeNotifierProvider<MapProvider>.value(value: mapProvider),
          ChangeNotifierProvider<SensorProvider>.value(value: sensorProvider),
        ],
        child: const MaterialApp(
          home: MapScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 1. Initial State: HUD should not be visible
    expect(find.text('Mini Kompas'), findsNothing);
    final compassBtnFinder = find.byKey(const ValueKey('compassBtn')).hitTestable(at: Alignment.center).evaluate().isNotEmpty
        ? find.byKey(const ValueKey('compassBtn'))
        : find.byWidgetPredicate((w) => w is FloatingActionButton && w.heroTag == 'compassBtn');

    expect(compassBtnFinder, findsOneWidget);

    // 2. Tap compassBtn -> Opens Floating Mini Dial Kompas HUD
    await tester.tap(compassBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mini Kompas'), findsOneWidget);
    expect(find.textContaining('345°'), findsOneWidget);
    expect(find.textContaining('Puncak:'), findsOneWidget);
    expect(find.text('Kompas Penuh'), findsOneWidget);

    // 3. Dynamic heading update: change heading to 90° (East)
    sensorProvider.setHeadingForTesting(90.0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('90°'), findsOneWidget);

    // 4. Tap close button (X) on HUD -> Dismisses HUD
    final closeFinder = find.byIcon(Icons.close_rounded);
    expect(closeFinder, findsOneWidget);
    await tester.tap(closeFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mini Kompas'), findsNothing);

    // 5. Tap compassBtn again -> Re-opens HUD
    await tester.tap(compassBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mini Kompas'), findsOneWidget);

    // 6. Tap compassBtn while HUD is open -> Toggles off HUD
    await tester.tap(compassBtnFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mini Kompas'), findsNothing);
  });

  test('SensorProvider calculates accurate heading for East (90°), North (0°), South (180°), West (270°)', () {
    final provider = SensorProvider(autoInitSensors: false);
    provider.setHeadingForTesting(0.0);

    // 1. Phone pointing East:
    // Earth magnetic North is to the left (-X): mx = -30, my = 0, mz = -20
    // Phone held flat: ax = 0, ay = 0, az = 9.8
    for (int i = 0; i < 20; i++) {
      provider.calculateHeadingForTesting(
        ax: 0, ay: 0, az: 9.8,
        mx: -30.0, my: 0.0, mz: -20.0,
      );
    }
    expect(provider.headingDegrees, closeTo(90.0, 1.0));
    expect(provider.headingDirection.contains('90°'), true);
    expect(provider.headingDirection.contains('E'), true);

    // 2. Phone pointing North:
    // Earth magnetic North is towards top (+Y): mx = 0, my = 30, mz = -20
    for (int i = 0; i < 20; i++) {
      provider.calculateHeadingForTesting(
        ax: 0, ay: 0, az: 9.8,
        mx: 0.0, my: 30.0, mz: -20.0,
      );
    }
    expect(provider.headingDegrees, closeTo(0.0, 1.0));
    expect(provider.headingDirection.contains('N'), true);

    // 3. Phone pointing South:
    // Earth magnetic North is towards bottom (-Y): mx = 0, my = -30, mz = -20
    for (int i = 0; i < 20; i++) {
      provider.calculateHeadingForTesting(
        ax: 0, ay: 0, az: 9.8,
        mx: 0.0, my: -30.0, mz: -20.0,
      );
    }
    expect(provider.headingDegrees, closeTo(180.0, 1.0));
    expect(provider.headingDirection.contains('180°'), true);
    expect(provider.headingDirection.contains('S'), true);

    // 4. Phone pointing West:
    // Earth magnetic North is towards right (+X): mx = 30, my = 0, mz = -20
    for (int i = 0; i < 20; i++) {
      provider.calculateHeadingForTesting(
        ax: 0, ay: 0, az: 9.8,
        mx: 30.0, my: 0.0, mz: -20.0,
      );
    }
    expect(provider.headingDegrees, closeTo(270.0, 1.0));
    expect(provider.headingDirection.contains('270°'), true);
    expect(provider.headingDirection.contains('W'), true);
  });
}
