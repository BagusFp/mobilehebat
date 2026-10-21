import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_scaffold.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/biometric_lock_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/ai_assistant/ai_assistant_provider.dart';
import 'features/blockchain/blockchain_provider.dart';
import 'features/explore/destination_provider.dart';
import 'features/explore/explore_screen.dart';
import 'features/home/home_screen.dart';
import 'features/map/map_provider.dart';
import 'features/notification/notification_provider.dart';
import 'features/notification/notification_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/quiz/quiz_provider.dart';
import 'features/sensor/sensor_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'core/config/supabase_config.dart';
import 'core/services/gemini_service.dart';
import 'core/services/notification_service.dart';
import 'features/trip/my_trip_screen.dart';
import 'features/trip/trip_provider.dart';
import 'features/utility/utility_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inisialisasi Database Zona Waktu IANA
  tz.initializeTimeZones();

  // 1. Inisialisasi Supabase Cloud Database & Authentication
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.anonKey,
      );
      debugPrint('Supabase berhasil diinisialisasi.');
    } catch (e) {
      debugPrint('Supabase.initialize error: $e');
    }
  }

  // 2. Muat API Key yang tersimpan dari SharedPreferences saat aplikasi pertama kali dibuka
  await GeminiService().init();

  // 3. Inisialisasi Service Notifikasi Sistem HP (Android / iOS)
  await NotificationService().init();

  runApp(const MeraTripApp());
}

class MeraTripApp extends StatelessWidget {
  final AuthProvider? authProvider;
  final DestinationProvider? destinationProvider;
  final TripProvider? tripProvider;
  final MapProvider? mapProvider;
  final SensorProvider? sensorProvider;
  final UtilityProvider? utilityProvider;
  final NotificationProvider? notificationProvider;
  final AiAssistantProvider? aiAssistantProvider;
  final QuizProvider? quizProvider;
  final BlockchainProvider? blockchainProvider;

  const MeraTripApp({
    super.key,
    this.authProvider,
    this.destinationProvider,
    this.tripProvider,
    this.mapProvider,
    this.sensorProvider,
    this.utilityProvider,
    this.notificationProvider,
    this.aiAssistantProvider,
    this.quizProvider,
    this.blockchainProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authProvider != null)
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider!)
        else
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()..init()),
        if (destinationProvider != null)
          ChangeNotifierProvider<DestinationProvider>.value(value: destinationProvider!)
        else
          ChangeNotifierProvider<DestinationProvider>(create: (_) => DestinationProvider()),
        if (tripProvider != null)
          ChangeNotifierProvider<TripProvider>.value(value: tripProvider!)
        else
          ChangeNotifierProvider<TripProvider>(create: (_) => TripProvider()),
        if (mapProvider != null)
          ChangeNotifierProvider<MapProvider>.value(value: mapProvider!)
        else
          ChangeNotifierProvider<MapProvider>(create: (_) => MapProvider()),
        if (sensorProvider != null)
          ChangeNotifierProvider<SensorProvider>.value(value: sensorProvider!)
        else
          ChangeNotifierProvider<SensorProvider>(create: (_) => SensorProvider()),
        if (utilityProvider != null)
          ChangeNotifierProvider<UtilityProvider>.value(value: utilityProvider!)
        else
          ChangeNotifierProvider<UtilityProvider>(create: (_) => UtilityProvider()),
        if (notificationProvider != null)
          ChangeNotifierProvider<NotificationProvider>.value(value: notificationProvider!)
        else
          ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
        if (aiAssistantProvider != null)
          ChangeNotifierProvider<AiAssistantProvider>.value(value: aiAssistantProvider!)
        else
          ChangeNotifierProvider<AiAssistantProvider>(create: (_) => AiAssistantProvider()),
        if (quizProvider != null)
          ChangeNotifierProvider<QuizProvider>.value(value: quizProvider!)
        else
          ChangeNotifierProvider<QuizProvider>(create: (_) => QuizProvider()),
        if (blockchainProvider != null)
          ChangeNotifierProvider<BlockchainProvider>.value(value: blockchainProvider!)
        else
          ChangeNotifierProvider<BlockchainProvider>(create: (_) => BlockchainProvider()),
      ],
      child: MaterialApp(
        title: 'MeraTrip',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // 1. Splash loading state saat inisialisasi awal
    if (!authProvider.isInitialized) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    // 2. Pengguna belum login atau sesi Supabase telah berakhir/logout
    if (!authProvider.isLoggedIn) {
      return const LoginScreen();
    }

    // 3. Pengguna login, biometrik aktif, dan status aplikasi terkunci
    if (authProvider.isBiometricEnabled && authProvider.isLocked) {
      return const BiometricLockScreen();
    }

    // 4. Pengguna login, sesi valid, dan tidak terkunci -> Buka Home
    return const MeraTripShellScreen();
  }
}

class MeraTripShellScreen extends StatefulWidget {
  const MeraTripShellScreen({super.key});

  @override
  State<MeraTripShellScreen> createState() => _MeraTripShellScreenState();
}

class _MeraTripShellScreenState extends State<MeraTripShellScreen> {
  int _currentTabIndex = 0;

  String? _getTabTitle(int index) {
    switch (index) {
      case 1:
        return 'Explore Merapi';
      case 2:
        return 'My Trip';
      case 3:
        return 'Profil Wisatawan';
      default:
        return null; // Menampilkan logo & nama MeraTrip
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final user = authProvider.currentUser;

    return AppScaffold(
      title: _getTabTitle(_currentTabIndex),
      actions: [
        IconButton(
          icon: Badge(
            isLabelVisible: notifProvider.unreadCount > 0,
            label: Text('${notifProvider.unreadCount}'),
            backgroundColor: AppColors.error,
            child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
          },
        ),
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentTabIndex = 3;
                });
              },
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: (user.profilePhoto != null && user.profilePhoto!.isNotEmpty)
                    ? (user.profilePhoto!.startsWith('http')
                        ? NetworkImage(user.profilePhoto!) as ImageProvider
                        : (File(user.profilePhoto!).existsSync()
                            ? FileImage(File(user.profilePhoto!))
                            : null))
                    : null,
                child: (user.profilePhoto == null || user.profilePhoto!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'P',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      )
                    : null,
              ),
            ),
          ),
      ],
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          HomeScreen(
            onNavigateTab: (idx) {
              setState(() {
                _currentTabIndex = idx;
              });
            },
          ),
          const ExploreScreen(),
          const MyTripScreen(),
          ProfileScreen(
            onNavigateTab: (idx) {
              setState(() {
                _currentTabIndex = idx;
              });
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore_rounded),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.route_outlined),
            activeIcon: Icon(Icons.route_rounded),
            label: 'My Trip',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
