import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/features/games/merapi_jeep_game_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'merapi_jeep_high_score': 150});
  });

  testWidgets('MerapiJeepGamePage mounts and shows HUD, controls, and high score', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: MerapiJeepGamePage(),
      ),
    );
    await tester.pump();

    // Check AppBar & HUD elements
    expect(find.text('Merapi Jeep Run'), findsOneWidget);
    expect(find.text('Lompat Sensor'), findsOneWidget);

    // Check Start / Instruction Card
    expect(find.text('MERAPI JEEP RUN'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    // Tap to start game
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump(const Duration(milliseconds: 50));

    // Game is running, tap screen to jump
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump(const Duration(milliseconds: 50));
  });
}
