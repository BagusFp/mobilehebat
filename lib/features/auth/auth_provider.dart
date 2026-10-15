import 'package:flutter/foundation.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/services/biometric_service.dart';
import '../../core/database/preferences_helper.dart';

import '../../core/services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  final BiometricService _biometricService = BiometricService();
  final SupabaseService _supabaseService = SupabaseService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBiometricSupported = false;
  bool _isBiometricEnabled = false;
  bool _isInitialized = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBiometricSupported => _isBiometricSupported;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;

  /// Inisialisasi awal saat aplikasi dibuka
  Future<void> init() async {
    try {
      final prefs = await PreferencesHelper.instance;
      _isBiometricSupported = await _biometricService.isDeviceSupported();
      _isBiometricEnabled = prefs.isBiometricEnabled();

      final supabaseUser = _supabaseService.currentUser;
      final supabaseSession = _supabaseService.currentSession;

      // HANYA anggap user logged-in bila ada sesi Supabase aktif atau user yang sah mendaftar
      if (supabaseSession != null && supabaseUser != null) {
        final localUser = await _repository.getCurrentUser();
        _currentUser = localUser ?? UserModel(
          id: prefs.getUserId() ?? 1,
          supabaseId: supabaseUser.id,
          name: supabaseUser.userMetadata?['name'] ?? prefs.getUserName() ?? 'Wisatawan Merapi',
          email: supabaseUser.email ?? prefs.getUserEmail() ?? '',
          passwordHash: '',
          createdAt: supabaseUser.createdAt,
        );
      } else if (prefs.isLoggedIn() && prefs.getUserId() != null && prefs.getUserId() != 1) {
        // User asli yang pernah mendaftar/login di perangkat ini
        _currentUser = await _repository.getCurrentUser();
      } else {
        // Jangan auto-login ke akun mock bawaan database lokal
        _currentUser = null;
        await prefs.clearSession();
      }
    } catch (e) {
      debugPrint('Error init AuthProvider: $e');
      _currentUser = null;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Login email & password
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _repository.login(email: email, password: password);
    _setLoading(false);

    if (result.isSuccess) {
      _currentUser = result.user;
      final prefs = await PreferencesHelper.instance;
      _isBiometricEnabled = prefs.isBiometricEnabled();
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Registrasi akun baru
  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _repository.register(
      name: name,
      email: email,
      password: password,
    );
    _setLoading(false);

    if (result.isSuccess) {
      _currentUser = result.user;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Login via Sensor Biometrik
  Future<bool> loginWithBiometrics() async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _repository.loginWithBiometrics();
    _setLoading(false);

    if (result.isSuccess) {
      _currentUser = result.user;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Toggle aktivasi biometrik oleh user
  Future<void> toggleBiometric(bool enabled) async {
    if (_currentUser == null || _currentUser!.id == null) return;
    final success = await _repository.setBiometricEnabled(_currentUser!.id!, enabled);
    if (success) {
      _isBiometricEnabled = enabled;
      _currentUser = _currentUser!.copyWith(isBiometricEnabled: enabled);
      notifyListeners();
    }
  }

  /// Logout dari sesi
  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @visibleForTesting
  void setUserForTesting(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
