import 'package:shared_preferences/shared_preferences.dart';

class PreferencesHelper {
  static const String _keyUserId = 'user_id';
  static const String _keySupabaseId = 'supabase_id';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyOfflineMode = 'offline_mode_active';

  static PreferencesHelper? _instance;
  static SharedPreferences? _preferences;

  PreferencesHelper._internal();

  static Future<PreferencesHelper> get instance async {
    _instance ??= PreferencesHelper._internal();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  // Session Management
  Future<void> saveUserSession({
    required int userId,
    String? supabaseId,
    required String email,
    required String name,
    required String token,
  }) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    if (supabaseId != null) {
      await prefs.setString(_keySupabaseId, supabaseId);
    }
    await prefs.setString(_keyUserEmail, email);
    await prefs.setString(_keyUserName, name);
    await prefs.setString(_keyAuthToken, token);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  Future<void> clearSession() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keySupabaseId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyAuthToken);
    await prefs.setBool(_keyIsLoggedIn, false);
  }

  bool isLoggedIn() {
    return _preferences?.getBool(_keyIsLoggedIn) ?? false;
  }

  int? getUserId() {
    return _preferences?.getInt(_keyUserId);
  }

  String? getSupabaseId() {
    return _preferences?.getString(_keySupabaseId);
  }

  String? getUserEmail() {
    return _preferences?.getString(_keyUserEmail);
  }

  String? getUserName() {
    return _preferences?.getString(_keyUserName);
  }

  // Biometric Preference
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  bool isBiometricEnabled() {
    return _preferences?.getBool(_keyBiometricEnabled) ?? false;
  }

  // Offline Mode Toggle
  Future<void> setOfflineModeActive(bool active) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(_keyOfflineMode, active);
  }

  bool isOfflineModeActive() {
    return _preferences?.getBool(_keyOfflineMode) ?? false;
  }
}
