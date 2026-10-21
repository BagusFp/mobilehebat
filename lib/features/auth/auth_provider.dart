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
  bool _hasEnrolledBiometrics = false;
  bool _isBiometricEnabled = false;
  bool _isLocked = false;
  bool _isInitialized = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isBiometricSupported => _isBiometricSupported;
  bool get hasEnrolledBiometrics => _hasEnrolledBiometrics;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isLocked => _isLocked;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  bool get isBiometricPromptActive => _biometricService.isAuthenticating;

  /// Inisialisasi awal saat aplikasi dibuka
  Future<void> init() async {
    try {
      final prefs = await PreferencesHelper.instance;
      _isBiometricSupported = await _biometricService.isDeviceSupported();
      _hasEnrolledBiometrics = await _biometricService.hasEnrolledBiometrics();
      _isBiometricEnabled = prefs.isBiometricEnabled();

      final supabaseUser = _supabaseService.currentUser;
      final supabaseSession = _supabaseService.currentSession;

      // HANYA anggap user logged-in bila ada sesi Supabase aktif yang valid
      if (supabaseSession != null && supabaseUser != null) {
        final localUser = await _repository.getCurrentUser();
        // Cek avatar dari metadata atau tabel profiles Supabase
        String? remoteAvatar = supabaseUser.userMetadata?['avatar_url'] as String?;
        if (remoteAvatar == null || remoteAvatar.isEmpty) {
          final profile = await _supabaseService.getProfile(supabaseUser.id);
          remoteAvatar = profile?['avatar_url'] as String?;
        }
        final effectivePhoto = (remoteAvatar != null && remoteAvatar.isNotEmpty)
            ? remoteAvatar
            : (localUser?.profilePhoto ?? prefs.getUserPhoto());

        if (remoteAvatar != null && remoteAvatar.isNotEmpty && remoteAvatar != prefs.getUserPhoto()) {
          await prefs.setUserPhoto(remoteAvatar);
        }

        final baseUser = localUser ?? UserModel(
          id: prefs.getUserId() ?? 1,
          supabaseId: supabaseUser.id,
          name: supabaseUser.userMetadata?['name'] ?? prefs.getUserName() ?? 'Wisatawan Merapi',
          email: supabaseUser.email ?? prefs.getUserEmail() ?? '',
          profilePhoto: effectivePhoto,
          passwordHash: '',
          createdAt: supabaseUser.createdAt,
        );
        _currentUser = baseUser.copyWith(profilePhoto: effectivePhoto);

        // Jika user memiliki sesi valid dan mengaktifkan biometrik: kunci aplikasi
        if (_isBiometricEnabled) {
          _isLocked = true;
        } else {
          _isLocked = false;
        }
      } else {
        // Jangan izinkan bypass tanpa sesi Supabase yang valid
        _currentUser = null;
        _isLocked = false;
        await prefs.clearSession();
      }
    } catch (e) {
      debugPrint('Error init AuthProvider: $e');
      _currentUser = null;
      _isLocked = false;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Memperbarui status ketersediaan & enrollment sensor biometrik perangkat
  Future<void> refreshBiometricStatus() async {
    _isBiometricSupported = await _biometricService.isDeviceSupported();
    _hasEnrolledBiometrics = await _biometricService.hasEnrolledBiometrics();
    final prefs = await PreferencesHelper.instance;
    _isBiometricEnabled = prefs.isBiometricEnabled();
    notifyListeners();
  }

  /// Login email & password via Supabase
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _repository.login(email: email, password: password);
    _setLoading(false);

    if (result.isSuccess) {
      _currentUser = result.user;
      final prefs = await PreferencesHelper.instance;
      _isBiometricEnabled = prefs.isBiometricEnabled();
      // Baru saja login dengan kredensial yang valid -> tidak terkunci
      _isLocked = false;
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
      _isLocked = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return false;
    }
  }

  /// Login via sensor biometrik (hanya diizinkan jika sesi Supabase masih valid)
  Future<bool> loginWithBiometrics() async {
    _setLoading(true);
    _errorMessage = null;

    final supabaseSession = _supabaseService.currentSession;
    final supabaseUser = _supabaseService.currentUser;

    if (supabaseSession == null || supabaseUser == null) {
      _errorMessage = 'Sesi akun tidak aktif atau telah logout. Silakan masuk dengan email dan kata sandi.';
      _setLoading(false);
      notifyListeners();
      return false;
    }

    final success = await unlockWithBiometrics();
    _setLoading(false);
    return success;
  }

  /// Membuka kunci aplikasi via sensor biometrik
  Future<bool> unlockWithBiometrics() async {
    if (!_isBiometricEnabled) {
      _isLocked = false;
      notifyListeners();
      return true;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      final authenticated = await _biometricService.authenticate(
        localizedReason: 'Pindai sidik jari atau Face ID untuk membuka MeraTrip',
      );

      _setLoading(false);

      if (authenticated) {
        _isLocked = false;
        _errorMessage = null;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Autentikasi biometrik dibatalkan atau tidak dikenali.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Kendala sensor biometrik: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Alternatif biometrik: Verifikasi menggunakan kata sandi akun Supabase
  Future<AuthResult> verifyAccountPassword(String password) async {
    if (_currentUser == null) {
      return const AuthResult(
        isSuccess: false,
        message: 'Tidak ada sesi pengguna aktif.',
      );
    }

    _setLoading(true);
    _errorMessage = null;

    final result = await _repository.verifyAccountPassword(
      email: _currentUser!.email,
      password: password,
    );

    _setLoading(false);

    if (result.isSuccess) {
      _isLocked = false;
      _errorMessage = null;
      notifyListeners();
      return result;
    } else {
      _errorMessage = result.message;
      notifyListeners();
      return result;
    }
  }

  /// Mengunci aplikasi secara instan (misal saat aplikasi kembali dari background)
  void lockApp() {
    if (isLoggedIn && _isBiometricEnabled && !_isLocked) {
      _isLocked = true;
      notifyListeners();
    }
  }

  /// Mengubah status aktivasi biometrik (dari halaman Profile / Settings)
  Future<bool> setBiometricEnabled(bool enabled) async {
    if (_currentUser == null) return false;

    final userId = _currentUser!.id ?? 1;
    final success = await _repository.setBiometricEnabled(userId, enabled);
    if (success) {
      _isBiometricEnabled = enabled;
      _currentUser = _currentUser!.copyWith(isBiometricEnabled: enabled);
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Kompatibilitas toggleBiometric
  Future<void> toggleBiometric(bool enabled) async {
    await setBiometricEnabled(enabled);
  }

  /// Logout dari sesi
  Future<void> logout() async {
    await _repository.logout();
    _currentUser = null;
    _isLocked = false;
    notifyListeners();
  }

  /// Memperbarui nama dan/atau foto profil pengguna
  Future<bool> updateProfile({String? name, String? profilePhoto}) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;

    final userId = _currentUser!.id ?? 1;
    final res = await _repository.updateProfile(
      userId: userId,
      name: name,
      profilePhoto: profilePhoto,
    );
    _setLoading(false);

    if (res.isSuccess) {
      if (res.user != null) {
        _currentUser = res.user;
      } else {
        _currentUser = _currentUser!.copyWith(
          name: name,
          profilePhoto: profilePhoto,
        );
      }
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.message;
      notifyListeners();
      return false;
    }
  }

  /// Upload foto avatar ke Supabase Storage (atau null jika offline/gagal)
  Future<String?> uploadAvatarBytes(Uint8List bytes, [String fileExt = 'webp']) async {
    final userId = _currentUser?.supabaseId ??
        _supabaseService.currentUser?.id ??
        (_currentUser?.id != null ? 'user_${_currentUser!.id}' : 'user_1');
    final url = await _supabaseService.uploadAvatar(
      userId: userId,
      bytes: bytes,
      fileExt: fileExt,
    );
    if (url == null) {
      _errorMessage = _supabaseService.lastAvatarUploadError ?? 'Gagal mengunggah foto ke Supabase Storage.';
      notifyListeners();
    }
    return url;
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

  @visibleForTesting
  void setLockedForTesting(bool locked) {
    _isLocked = locked;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
