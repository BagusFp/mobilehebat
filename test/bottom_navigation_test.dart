import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/data/models/user_model.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/explore/destination_provider.dart';
import 'package:project/features/notification/notification_provider.dart';
import 'package:project/features/profile/course_feedback_screen.dart';
import 'package:project/features/profile/profile_screen.dart';
import 'package:project/features/trip/trip_provider.dart';
import 'package:project/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createShellWidget({UserModel? user}) {
    final auth = AuthProvider();
    auth.setUserForTesting(
      user ??
          const UserModel(
            id: 1,
            email: 'wisatawan@meratrip.id',
            name: 'Bagus PAM',
            passwordHash: 'dummy',
            profilePhoto: null,
            createdAt: '2026-10-22',
          ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider<DestinationProvider>(
          create: (_) => DestinationProvider(),
        ),
        ChangeNotifierProvider<TripProvider>(
          create: (_) => TripProvider(),
        ),
      ],
      child: const MaterialApp(
        home: MeraTripShellScreen(),
      ),
    );
  }

  testWidgets('BottomNavigationBar renders 6 items: Home, Explore, MyTrip, PAM, Profil, Logout', (tester) async {
    await tester.pumpWidget(createShellWidget());
    await tester.pumpAndSettle();

    // Verify BottomNavigationBar exists
    final bottomNavFinder = find.byType(BottomNavigationBar);
    expect(bottomNavFinder, findsOneWidget);

    // Verify 6 labels are present
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('MyTrip'), findsOneWidget);
    expect(find.text('PAM'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    // Tap on 'PAM'
    await tester.tap(find.text('PAM'));
    await tester.pumpAndSettle();

    // Verify CourseFeedbackScreen is visible
    expect(find.byType(CourseFeedbackScreen), findsOneWidget);

    // Tap on 'Profil'
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();

    // Verify ProfileScreen is visible
    expect(find.byType(ProfileScreen), findsOneWidget);

    // Tap on 'Logout'
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    // Verify Logout confirmation sheet appears
    expect(find.text('Akhiri Sesi Penjelajahan?'), findsOneWidget);
    expect(find.text('Ya, Keluar Akun'), findsOneWidget);
  });
}
