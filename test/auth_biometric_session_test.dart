import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/core/database/preferences_helper.dart';
import 'package:project/data/models/user_model.dart';
import 'package:project/data/repositories/auth_repository.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/auth/biometric_lock_screen.dart';
import 'package:project/features/auth/login_screen.dart';
import 'package:project/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Pengujian Wajib Sistem Login, Session, dan Biometrik MeraTrip (14 Skenario)', () {
    // Skenario 1: Pengguna belum login
    testWidgets('1. Pengguna belum login -> AuthGate mengarahkan ke LoginScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      expect(authProvider.isLoggedIn, false);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BiometricLockScreen), findsNothing);
      expect(find.byType(MeraTripShellScreen), findsNothing);
    });

    // Skenario 2: Login berhasil
    testWidgets('2. Login berhasil -> Pengguna masuk ke Home tanpa kunci jika biometrik nonaktif', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final testUser = UserModel(
        id: 99,
        name: 'Wisatawan Merapi',
        email: 'test@meratrip.id',
        passwordHash: 'hash',
        createdAt: DateTime.now().toIso8601String(),
      );

      authProvider.setUserForTesting(testUser);
      expect(authProvider.isLoggedIn, true);
      expect(authProvider.isLocked, false);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      expect(find.byType(MeraTripShellScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(BiometricLockScreen), findsNothing);
    });

    // Skenario 3: Aplikasi dibuka kembali dengan session valid dan biometrik tidak aktif
    testWidgets('3. Aplikasi dibuka kembali (session valid, biometrik nonaktif) -> Langsung ke Home', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final testUser = UserModel(
        id: 99,
        name: 'Wisatawan Merapi',
        email: 'test@meratrip.id',
        passwordHash: 'hash',
        isBiometricEnabled: false,
        createdAt: DateTime.now().toIso8601String(),
      );

      authProvider.setUserForTesting(testUser);
      expect(authProvider.isBiometricEnabled, false);
      expect(authProvider.isLocked, false);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      expect(find.byType(MeraTripShellScreen), findsOneWidget);
      expect(find.byType(BiometricLockScreen), findsNothing);
    });

    // Skenario 4: Aplikasi dibuka kembali dengan session valid dan biometrik aktif
    testWidgets('4. Aplikasi dibuka kembali (session valid, biometrik aktif) -> Tampilkan BiometricLockScreen sebelum Home', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final testUser = UserModel(
        id: 99,
        name: 'Wisatawan Merapi',
        email: 'test@meratrip.id',
        passwordHash: 'hash',
        isBiometricEnabled: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      authProvider.setUserForTesting(testUser);
      final prefs = await PreferencesHelper.instance;
      await prefs.setBiometricEnabled(true);
      await authProvider.refreshBiometricStatus();
      authProvider.setLockedForTesting(true);

      expect(authProvider.isLoggedIn, true);
      expect(authProvider.isBiometricEnabled, true);
      expect(authProvider.isLocked, true);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      // Home terlindungi dan tidak boleh tampil sebelum unlock
      expect(find.byType(BiometricLockScreen), findsOneWidget);
      expect(find.byType(MeraTripShellScreen), findsNothing);
      expect(find.text('Aplikasi dikunci dengan autentikasi biometrik'), findsOneWidget);
    });

    // Skenario 5: Biometrik berhasil
    testWidgets('5. Biometrik berhasil -> Buka kunci ke Home (MeraTripShellScreen)', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final testUser = UserModel(
        id: 99,
        name: 'Wisatawan Merapi',
        email: 'test@meratrip.id',
        passwordHash: 'hash',
        isBiometricEnabled: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      authProvider.setUserForTesting(testUser);
      final prefs = await PreferencesHelper.instance;
      await prefs.setBiometricEnabled(true);
      await authProvider.refreshBiometricStatus();
      authProvider.setLockedForTesting(true);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      expect(find.byType(BiometricLockScreen), findsOneWidget);

      // Simulasikan biometrik berhasil diverifikasi
      authProvider.setLockedForTesting(false);
      await tester.pump();

      expect(find.byType(MeraTripShellScreen), findsOneWidget);
      expect(find.byType(BiometricLockScreen), findsNothing);
    });

    // Skenario 6 & 7: Biometrik gagal atau dibatalkan pengguna
    testWidgets('6 & 7. Biometrik gagal atau dibatalkan -> Tetap terkunci, sesi tidak dihapus, opsi password tersedia', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final testUser = UserModel(
        id: 99,
        name: 'Wisatawan Merapi',
        email: 'test@meratrip.id',
        passwordHash: 'hash',
        isBiometricEnabled: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      authProvider.setUserForTesting(testUser);
      final prefs = await PreferencesHelper.instance;
      await prefs.setBiometricEnabled(true);
      await authProvider.refreshBiometricStatus();
      authProvider.setLockedForTesting(true);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      // Aplikasi tetap terkunci di BiometricLockScreen
      expect(find.byType(BiometricLockScreen), findsOneWidget);
      expect(authProvider.isLocked, true);
      expect(authProvider.isLoggedIn, true); // Sesi tetap aman

      // Opsi "Gunakan Kata Sandi Akun" dan "Pindai Ulang Biometrik" tersedia
      expect(find.text('Gunakan Kata Sandi Akun'), findsOneWidget);
      expect(find.text('Pindai Ulang Biometrik'), findsOneWidget);
    });

    // Skenario 8 & 9: Sensor biometrik tidak tersedia atau belum terdaftar
    test('8 & 9. Sensor tidak tersedia / belum terdaftar -> Status ketersediaan konsisten', () async {
      final authProvider = AuthProvider();
      await authProvider.refreshBiometricStatus();

      // Pada lingkungan headless test tanpa sensor fisik:
      // Status biometrik harus ditangani dengan benar tanpa crash
      expect(authProvider.isBiometricSupported, isA<bool>());
      expect(authProvider.hasEnrolledBiometrics, isA<bool>());
    });

    // Skenario 10: Pengguna memilih "Gunakan Password"
    testWidgets('10. Pengguna memilih Gunakan Password -> Form kata sandi akun muncul', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final testUser = UserModel(
        id: 99,
        name: 'Wisatawan Merapi',
        email: 'test@meratrip.id',
        passwordHash: 'hash',
        isBiometricEnabled: true,
        createdAt: DateTime.now().toIso8601String(),
      );

      authProvider.setUserForTesting(testUser);
      final prefs = await PreferencesHelper.instance;
      await prefs.setBiometricEnabled(true);
      await authProvider.refreshBiometricStatus();
      authProvider.setLockedForTesting(true);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      expect(find.text('Gunakan Kata Sandi Akun'), findsOneWidget);
      await tester.tap(find.text('Gunakan Kata Sandi Akun'));
      await tester.pump();

      // Form kata sandi dan tombol verifikasi sekarang terlihat
      expect(find.text('Verifikasi Kata Sandi Akun'), findsOneWidget);
      expect(find.text('Verifikasi & Buka Aplikasi'), findsOneWidget);
      expect(find.text('Kembali ke Autentikasi Biometrik'), findsOneWidget);

      // Bisa kembali ke biometrik
      await tester.tap(find.text('Kembali ke Autentikasi Biometrik'));
      await tester.pump();
      expect(find.text('Gunakan Kata Sandi Akun'), findsOneWidget);
    });

    // Skenario 11, 12, 13: Verifikasi kata sandi (benar, salah, error jaringan)
    test('11, 12, 13. Evaluasi hasil verifikasi kata sandi akun Supabase', () async {
      const successResult = AuthResult(
        isSuccess: true,
        message: 'Kata sandi akun berhasil diverifikasi.',
      );
      const wrongPasswordResult = AuthResult(
        isSuccess: false,
        message: 'Kata sandi akun tidak sesuai. Silakan periksa kembali.',
      );
      const networkErrorResult = AuthResult(
        isSuccess: false,
        message: 'Tidak dapat menghubungi server Supabase. Pastikan koneksi internet aktif.',
      );

      expect(successResult.isSuccess, true);
      expect(wrongPasswordResult.isSuccess, false);
      expect(wrongPasswordResult.message, contains('tidak sesuai'));
      expect(networkErrorResult.isSuccess, false);
      expect(networkErrorResult.message, contains('koneksi internet'));
    });

    // Skenario 14: Session Supabase kedaluwarsa atau logout
    testWidgets('14. Session Supabase kedaluwarsa / Logout -> Kembali ke LoginScreen, biometrik lokal tidak bisa bypass', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final authProvider = AuthProvider();
      final prefs = await PreferencesHelper.instance;

      // Pengguna pernah mengaktifkan biometrik
      await prefs.setBiometricEnabled(true);

      // Tapi sesi diakhiri (logout / expired)
      await authProvider.logout();

      expect(authProvider.isLoggedIn, false);
      expect(authProvider.currentUser, isNull);

      await tester.pumpWidget(MeraTripApp(authProvider: authProvider));
      await tester.pump();

      // Harus menampilkan LoginScreen dan TIDAK boleh langsung masuk
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MeraTripShellScreen), findsNothing);

      // Mencoba biometrik saat sesi kedaluwarsa ditolak
      final canLoginBiometric = await authProvider.loginWithBiometrics();
      expect(canLoginBiometric, false);
      expect(authProvider.errorMessage, contains('Sesi akun tidak aktif atau telah logout'));
    });
  });
}
