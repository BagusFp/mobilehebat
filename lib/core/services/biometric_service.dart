import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  /// Status apakah dialog biometrik OS saat ini sedang aktif ditampilkan
  bool get isAuthenticating => _isAuthenticating;

  @visibleForTesting
  static bool? mockAuthenticationResult;
  @visibleForTesting
  static bool? mockIsSupported;
  @visibleForTesting
  static bool? mockHasEnrolled;

  /// Memeriksa apakah hardware perangkat mendukung sensor biometrik
  Future<bool> isDeviceSupported() async {
    if (mockIsSupported != null) return mockIsSupported!;
    try {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isTest) return false;

      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Memperoleh daftar biometrik yang terdaftar (fingerprint, face, dll)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isTest) return <BiometricType>[];

      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    } catch (_) {
      return <BiometricType>[];
    }
  }

  /// Memeriksa apakah pengguna sudah mendaftarkan setidaknya satu sidik jari / face di perangkat
  Future<bool> hasEnrolledBiometrics() async {
    if (mockHasEnrolled != null) return mockHasEnrolled!;
    try {
      final biometrics = await getAvailableBiometrics();
      return biometrics.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Memeriksa apakah biometrik siap digunakan (didukung hardware DAN sudah terdaftar)
  Future<bool> canAuthenticate() async {
    final supported = await isDeviceSupported();
    if (!supported) return false;
    final enrolled = await hasEnrolledBiometrics();
    return enrolled;
  }

  /// Menjalankan prompt autentikasi biometrik OS
  Future<bool> authenticate({String? localizedReason}) async {
    if (mockAuthenticationResult != null) return mockAuthenticationResult!;
    try {
      final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
      if (isTest) return false;

      final canAuth = await canAuthenticate();
      if (!canAuth) return false;

      _isAuthenticating = true;
      final result = await _auth.authenticate(
        localizedReason: localizedReason ??
            'Pindai sidik jari atau gunakan Face ID untuk membuka MeraTrip',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return result;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Menghentikan proses autentikasi biometrik jika sedang berjalan
  Future<void> cancelAuthentication() async {
    try {
      _isAuthenticating = false;
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
