import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Memeriksa apakah perangkat mendukung sensor biometrik
  Future<bool> isDeviceSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Memperoleh daftar biometrik yang tersedia (fingerprint, face, dll)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  /// Menjalankan prompt autentikasi biometrik OS
  Future<bool> authenticate({String? localizedReason}) async {
    try {
      final isSupported = await isDeviceSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason ??
            'Pindai sidik jari atau gunakan Face ID untuk masuk ke MeraTrip',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Menghentikan proses autentikasi biometrik jika sedang berjalan
  Future<void> cancelAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
