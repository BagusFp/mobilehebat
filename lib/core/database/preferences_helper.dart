import 'dart:convert';
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
  static const String _keyCurrencyRatesJson = 'currency_rates_json';
  static const String _keyCurrencyApiDate = 'currency_api_date';
  static const String _keyCurrencySyncTime = 'currency_sync_time';

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

  static const String _keyUserPhoto = 'user_photo';

  Future<void> clearSession() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keySupabaseId);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserPhoto);
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

  Future<void> setUserName(String name) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(_keyUserName, name);
  }

  String? getUserPhoto() {
    return _preferences?.getString(_keyUserPhoto);
  }

  Future<void> setUserPhoto(String? photo) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    if (photo == null || photo.isEmpty) {
      await prefs.remove(_keyUserPhoto);
    } else {
      await prefs.setString(_keyUserPhoto, photo);
    }
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

  // Currency Rates Cache
  Future<void> saveCurrencyCache({
    required String apiDate,
    required String syncTimeIso,
    required Map<String, double> rates,
  }) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrencyApiDate, apiDate);
    await prefs.setString(_keyCurrencySyncTime, syncTimeIso);
    await prefs.setString(_keyCurrencyRatesJson, jsonEncode(rates));
  }

  Map<String, dynamic>? getCachedCurrencyData() {
    final prefs = _preferences;
    if (prefs == null) return null;
    final ratesJson = prefs.getString(_keyCurrencyRatesJson);
    final apiDate = prefs.getString(_keyCurrencyApiDate);
    final syncTimeIso = prefs.getString(_keyCurrencySyncTime);

    if (ratesJson == null || apiDate == null) return null;

    try {
      final decoded = jsonDecode(ratesJson) as Map<String, dynamic>;
      final rates = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      return {
        'api_date': apiDate,
        'sync_time': syncTimeIso ?? '',
        'rates': rates,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearCurrencyCache() async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.remove(_keyCurrencyRatesJson);
    await prefs.remove(_keyCurrencyApiDate);
    await prefs.remove(_keyCurrencySyncTime);
  }

  // Initial Trip Seeding Flag
  static const String _keyTripsSeeded = 'has_seeded_trips_initial';

  bool hasTripsSeeded() {
    return _preferences?.getBool(_keyTripsSeeded) ?? false;
  }

  Future<void> setTripsSeeded(bool seeded) async {
    final prefs = _preferences ?? await SharedPreferences.getInstance();
    await prefs.setBool(_keyTripsSeeded, seeded);
  }
}
