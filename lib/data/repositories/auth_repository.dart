import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../core/database/database_helper.dart';
import '../../core/database/preferences_helper.dart';
import '../../core/services/biometric_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/crypto_helper.dart';

class AuthResult {
  final bool isSuccess;
  final String message;
  final UserModel? user;

  const AuthResult({
    required this.isSuccess,
    required this.message,
    this.user,
  });
}

class AuthRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final BiometricService _biometricService = BiometricService();
  final SupabaseService _supabaseService = SupabaseService();

  /// Pendaftaran akun baru petualang Merapi ke Supabase Cloud & Lokal
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim();

    try {
      // 1. Pendaftaran Utama ke Supabase Auth
      AuthResponse? supabaseRes;
      String? supabaseUserId;

      try {
        supabaseRes = await _supabaseService.signUp(
          email: cleanEmail,
          password: password,
          name: cleanName,
        );
        supabaseUserId = supabaseRes.user?.id;
        debugPrint('Supabase Auth register sukses: User ID = $supabaseUserId');
      } on AuthException catch (e) {
        debugPrint('Supabase AuthException register: ${e.message}');
        if (e.message.toLowerCase().contains('already registered') ||
            e.message.toLowerCase().contains('user already exists')) {
          return const AuthResult(
            isSuccess: false,
            message: 'Email sudah terdaftar di Supabase. Silakan langsung masuk.',
          );
        }
        if (e.message.toLowerCase().contains('invalid') && e.message.toLowerCase().contains('email')) {
          return const AuthResult(
            isSuccess: false,
            message: 'Format email tidak diterima oleh Supabase. Gunakan email valid (misal @gmail.com).',
          );
        }
        return AuthResult(
          isSuccess: false,
          message: 'Gagal mendaftar di Supabase: ${e.message}',
        );
      } catch (e) {
        debugPrint('Supabase signUp network/unknown error: $e');
        // Jaringan bermasalah, lanjut simpan lokal
      }

      // 2. Simpan atau perbarui akun di SQLite lokal untuk cache offline
      final db = await _dbHelper.database;
      final passwordHash = CryptoHelper.hashPassword(password);
      final now = DateTime.now().toIso8601String();

      int localUserId;
      final existing = await db.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
      );

      if (existing.isNotEmpty) {
        localUserId = existing.first['id'] as int;
        final updateData = <String, Object?>{
          'name': cleanName,
          'password_hash': passwordHash,
        };
        if (supabaseUserId != null) {
          updateData['supabase_id'] = supabaseUserId;
        }
        await db.update(
          'users',
          updateData,
          where: 'id = ?',
          whereArgs: [localUserId],
        );
      } else {
        localUserId = await db.insert('users', {
          'name': cleanName,
          'email': cleanEmail,
          'password_hash': passwordHash,
          'supabase_id': supabaseUserId,
          'is_biometric_enabled': 0,
          'created_at': now,
        });
      }

      final newUser = UserModel(
        id: localUserId,
        supabaseId: supabaseUserId,
        name: cleanName,
        email: cleanEmail,
        passwordHash: passwordHash,
        isBiometricEnabled: false,
        createdAt: now,
      );

      // 3. Simpan sesi aktif ke Preferences
      final prefs = await PreferencesHelper.instance;
      await prefs.saveUserSession(
        userId: localUserId,
        supabaseId: supabaseUserId,
        email: cleanEmail,
        name: cleanName,
        token: supabaseRes?.session?.accessToken ?? 'token_$localUserId',
      );

      return AuthResult(
        isSuccess: true,
        message: 'Registrasi berhasil! Akun Anda telah terdaftar di Supabase.',
        user: newUser,
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Gagal melakukan pendaftaran: $e',
      );
    }
  }

  /// Login dengan email dan password menggunakan Supabase Auth
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final inputPasswordHash = CryptoHelper.hashPassword(password);

    try {
      // 1. Autentikasi ke Supabase Cloud
      AuthResponse? supabaseRes;
      String? supabaseUserId;
      String? userName;

      try {
        supabaseRes = await _supabaseService.signIn(
          email: cleanEmail,
          password: password,
        );
        supabaseUserId = supabaseRes.user?.id;
        userName = supabaseRes.user?.userMetadata?['name'] as String?;
        debugPrint('Supabase Auth login sukses: User ID = $supabaseUserId');
      } on AuthException catch (e) {
        debugPrint('Supabase AuthException login: ${e.message}');
        if (e.message.toLowerCase().contains('email not confirmed')) {
          return const AuthResult(
            isSuccess: false,
            message: 'Email belum dikonfirmasi di Supabase. Silakan periksa inbox email Anda, atau matikan "Confirm email" di Dashboard Supabase (Authentication -> Email).',
          );
        }
        if (e.message.toLowerCase().contains('invalid login credentials') ||
            e.message.toLowerCase().contains('invalid credentials')) {
          return const AuthResult(
            isSuccess: false,
            message: 'Email atau kata sandi tidak sesuai. Silakan periksa kembali.',
          );
        }
        return AuthResult(
          isSuccess: false,
          message: 'Supabase Auth: ${e.message}',
        );
      } catch (e) {
        debugPrint('Supabase network unreachable, trying offline login: $e');
      }

      // 2. Sinkronisasi sesi lokal ke SQLite
      final db = await _dbHelper.database;
      final result = await db.query(
        'users',
        where: 'LOWER(email) = ?',
        whereArgs: [cleanEmail],
      );

      int localUserId = 1;
      if (result.isNotEmpty) {
        final userData = result.first;
        localUserId = userData['id'] as int;
        final storedHash = userData['password_hash'] as String;

        // Jika offline & Supabase tidak merespons, verifikasi hash lokal
        if (supabaseRes == null && storedHash != inputPasswordHash) {
          return const AuthResult(
            isSuccess: false,
            message: 'Kata sandi tidak sesuai (mode offline).',
          );
        }
        userName = userName ?? (userData['name'] as String?);
      } else {
        // User login berhasil dari Supabase tapi baru pertama kali di HP ini
        final now = DateTime.now().toIso8601String();
        userName = userName ?? 'Wisatawan Merapi';
        localUserId = await db.insert('users', {
          'name': userName,
          'email': cleanEmail,
          'password_hash': inputPasswordHash,
          'supabase_id': supabaseUserId,
          'is_biometric_enabled': 0,
          'created_at': now,
        });
      }

      final user = UserModel(
        id: localUserId,
        supabaseId: supabaseUserId,
        name: userName ?? 'Wisatawan Merapi',
        email: cleanEmail,
        passwordHash: inputPasswordHash,
        isBiometricEnabled: false,
        createdAt: DateTime.now().toIso8601String(),
      );

      final prefs = await PreferencesHelper.instance;
      await prefs.saveUserSession(
        userId: localUserId,
        supabaseId: supabaseUserId,
        email: cleanEmail,
        name: user.name,
        token: supabaseRes?.session?.accessToken ?? 'token_$localUserId',
      );

      return AuthResult(
        isSuccess: true,
        message: 'Berhasil masuk ke MeraTrip!',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Terjadi kesalahan saat masuk: $e',
      );
    }
  }

  /// Autentikasi biometrik OS
  Future<AuthResult> loginWithBiometrics() async {
    try {
      final isSupported = await _biometricService.isDeviceSupported();
      if (!isSupported) {
        return const AuthResult(
          isSuccess: false,
          message: 'Sensor biometrik tidak tersedia pada perangkat ini.',
        );
      }

      final authenticated = await _biometricService.authenticate();
      if (!authenticated) {
        return const AuthResult(
          isSuccess: false,
          message: 'Autentikasi biometrik dibatalkan atau ditolak.',
        );
      }

      final prefs = await PreferencesHelper.instance;
      final lastUserId = prefs.getUserId();

      if (lastUserId == null) {
        return const AuthResult(
          isSuccess: false,
          message: 'Data sesi belum tersedia. Silakan masuk dengan email dan kata sandi terlebih dahulu.',
        );
      }

      final db = await _dbHelper.database;
      final result = await db.query(
        'users',
        where: 'id = ?',
        whereArgs: [lastUserId],
      );

      if (result.isEmpty) {
        return const AuthResult(
          isSuccess: false,
          message: 'Sesi akun tidak ditemukan. Silakan masuk manual.',
        );
      }

      final user = UserModel.fromMap(result.first);
      await prefs.saveUserSession(
        userId: user.id ?? 1,
        supabaseId: user.supabaseId,
        email: user.email,
        name: user.name,
        token: 'token_${user.id}',
      );

      return AuthResult(
        isSuccess: true,
        message: 'Login biometrik berhasil!',
        user: user,
      );
    } catch (e) {
      return AuthResult(
        isSuccess: false,
        message: 'Kendala biometrik: $e',
      );
    }
  }

  /// Memperoleh data profil user saat ini
  Future<UserModel?> getCurrentUser() async {
    final prefs = await PreferencesHelper.instance;
    final userId = prefs.getUserId();
    if (userId == null) return null;

    final db = await _dbHelper.database;
    final result = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (result.isEmpty) return null;
    return UserModel.fromMap(result.first);
  }

  /// Mengubah status biometrik user
  Future<bool> setBiometricEnabled(int userId, bool enabled) async {
    try {
      final db = await _dbHelper.database;
      await db.update(
        'users',
        {'is_biometric_enabled': enabled ? 1 : 0},
        where: 'id = ?',
        whereArgs: [userId],
      );
      final prefs = await PreferencesHelper.instance;
      await prefs.setBiometricEnabled(enabled);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Logout dan hapus sesi di lokal dan Supabase
  Future<void> logout() async {
    final prefs = await PreferencesHelper.instance;
    await prefs.clearSession();
    try {
      await _supabaseService.signOut();
    } catch (_) {}
  }
}
