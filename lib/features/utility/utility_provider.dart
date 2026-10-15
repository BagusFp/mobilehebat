import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../core/database/preferences_helper.dart';

class CurrencyInfo {
  final String code;
  final String name;
  final String flag;
  final String symbol;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.flag,
    required this.symbol,
  });
}

class TimezoneInfo {
  final String id;
  final String ianaId;
  final String city;
  final String label;
  final String code;

  const TimezoneInfo({
    required this.id,
    required this.ianaId,
    required this.city,
    required this.label,
    required this.code,
  });

  /// Menghitung selisih jam dari WIB secara dinamis berdasarkan database IANA
  int getOffsetHoursFromWib(DateTime dt) {
    try {
      final wibLoc = tz.getLocation('Asia/Jakarta');
      final targetLoc = tz.getLocation(ianaId);
      final wibTZ = tz.TZDateTime(wibLoc, dt.year, dt.month, dt.day, dt.hour, dt.minute);
      final targetTZ = tz.TZDateTime.from(wibTZ, targetLoc);
      return targetTZ.timeZoneOffset.inHours - wibTZ.timeZoneOffset.inHours;
    } catch (_) {
      return 0;
    }
  }

  /// Backward-compatible getter untuk jam offset acuan
  int get offsetHoursFromWib {
    return getOffsetHoursFromWib(DateTime(2024, 10, 19, 9, 0));
  }
}

class TimezoneComparisonResult {
  final String code; // 'WIB', 'WITA', 'WIT', 'London'
  final String ianaId;
  final String city;
  final tz.TZDateTime dateTime;
  final String formattedTime; // '09:00'
  final String formattedDate; // '19 Okt 2024'
  final String timeZoneName; // 'WIB', 'WITA', 'WIT', 'BST', 'GMT'
  final String utcOffset; // 'UTC+7', 'UTC+1', dll.
  final int dayDiff; // -1, 0, 1
  final String dayDiffBadge; // 'Hari ini', '+1 Hari', '-1 Hari'
  final int offsetHoursFromWib;

  const TimezoneComparisonResult({
    required this.code,
    required this.ianaId,
    required this.city,
    required this.dateTime,
    required this.formattedTime,
    required this.formattedDate,
    required this.timeZoneName,
    required this.utcOffset,
    required this.dayDiff,
    required this.dayDiffBadge,
    required this.offsetHoursFromWib,
  });
}

class UtilityProvider extends ChangeNotifier {
  static bool _timezonesInitialized = false;

  // 1. Currency Converter State
  String _sourceCurrencyCode = 'USD';
  String _targetCurrencyCode = 'IDR';
  double _sourceAmount = 100.0;
  bool _isSyncing = false;
  String? _errorMessage;
  bool _isUsingCachedRates = false;
  String _apiDate = '';
  DateTime? _lastSyncTime;
  String _lastSyncText = '';

  /// Rates map relatif terhadap EUR (base = 'EUR', EUR = 1.0)
  Map<String, double> _rates = {};

  final Map<String, CurrencyInfo> _currencies = const {
    'IDR': CurrencyInfo(code: 'IDR', name: 'Rupiah', flag: '🇮🇩', symbol: 'Rp'),
    'USD': CurrencyInfo(code: 'USD', name: 'Dollar AS', flag: '🇺🇸', symbol: r'$'),
    'EUR': CurrencyInfo(code: 'EUR', name: 'Euro', flag: '🇪🇺', symbol: '€'),
    'JPY': CurrencyInfo(code: 'JPY', name: 'Yen Jepang', flag: '🇯🇵', symbol: '¥'),
    'SGD': CurrencyInfo(code: 'SGD', name: 'Dollar SG', flag: '🇸🇬', symbol: r'S$'),
  };

  // 2. Timezone Converter State
  DateTime _departureDateTime = DateTime(2024, 10, 19, 9, 0);
  String _sourceTimezoneId = 'wib';
  String _selectedTravelerTzId = 'london';

  final List<TimezoneInfo> _timezones = const [
    TimezoneInfo(
      id: 'london',
      ianaId: 'Europe/London',
      city: 'London',
      label: 'London (GMT / BST)',
      code: 'London',
    ),
    TimezoneInfo(
      id: 'wib',
      ianaId: 'Asia/Jakarta',
      city: 'Merapi / Yogyakarta',
      label: 'WIB (Gunung Merapi, UTC+7)',
      code: 'WIB',
    ),
    TimezoneInfo(
      id: 'wita',
      ianaId: 'Asia/Makassar',
      city: 'Bali / Makassar',
      label: 'WITA (Bali/Makassar, UTC+8)',
      code: 'WITA',
    ),
    TimezoneInfo(
      id: 'wit',
      ianaId: 'Asia/Jayapura',
      city: 'Jayapura / Papua',
      label: 'WIT (Maluku/Papua, UTC+9)',
      code: 'WIT',
    ),
    TimezoneInfo(
      id: 'tokyo',
      ianaId: 'Asia/Tokyo',
      city: 'Tokyo',
      label: 'Tokyo (JST / UTC+9)',
      code: 'Tokyo',
    ),
    TimezoneInfo(
      id: 'newyork',
      ianaId: 'America/New_York',
      city: 'New York',
      label: 'New York (EDT / UTC-4)',
      code: 'New York',
    ),
    TimezoneInfo(
      id: 'sydney',
      ianaId: 'Australia/Sydney',
      city: 'Sydney',
      label: 'Sydney (AEST / UTC+10)',
      code: 'Sydney',
    ),
  ];

  UtilityProvider({bool? autoInit}) {
    _ensureTimezonesInitialized();
    final bool shouldInit = autoInit ?? (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST'));
    if (shouldInit) {
      init();
    }
  }

  void _ensureTimezonesInitialized() {
    if (!_timezonesInitialized) {
      try {
        tz.initializeTimeZones();
        _timezonesInitialized = true;
      } catch (_) {}
    }
  }

  /// Inisialisasi awal: Muat cache lokal segera, lalu ambil kurs terbaru dari API
  Future<void> init() async {
    await loadCachedRates();
    await syncRates();
  }

  // ---------------------------------------------------------------------------
  // GETTERS - CURRENCY
  // ---------------------------------------------------------------------------
  String get sourceCurrencyCode => _sourceCurrencyCode;
  String get targetCurrencyCode => _targetCurrencyCode;
  double get sourceAmount => _sourceAmount;
  bool get isLoading => _isSyncing;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  bool get isUsingCachedRates => _isUsingCachedRates;
  String get apiDate => _apiDate;
  DateTime? get lastSyncTime => _lastSyncTime;
  String get lastSyncText => _lastSyncText;
  Map<String, double> get rates => Map.unmodifiable(_rates);

  bool get hasRates =>
      _rates.containsKey('IDR') &&
      _rates.containsKey('USD') &&
      _rates.containsKey('EUR') &&
      _rates.containsKey('JPY');

  List<CurrencyInfo> get availableCurrencies => _currencies.values.toList();
  CurrencyInfo get sourceCurrency => _currencies[_sourceCurrencyCode] ?? _currencies['USD']!;
  CurrencyInfo get targetCurrency => _currencies[_targetCurrencyCode] ?? _currencies['IDR']!;

  /// Format tanggal data kurs dari API (misal: '2026-10-14' -> '14 Okt 2026')
  String get formattedApiDate {
    if (_apiDate.isEmpty) return '-';
    try {
      final parsed = DateTime.parse(_apiDate);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return _apiDate;
    }
  }

  /// Label status sumber kurs
  String get cacheStatusLabel {
    if (_isUsingCachedRates) {
      return 'Kurs terakhir tersimpan';
    }
    return 'Kurs Referensi Frankfurter';
  }

  /// Keterangan ringkas status kurs
  String get cacheStatusSubtitle {
    if (!hasRates) {
      return 'Belum ada data kurs';
    }
    if (_isUsingCachedRates) {
      return 'Tanggal data: $formattedApiDate (Tersimpan lokal)';
    }
    return 'Tanggal data API: $formattedApiDate • Diperbarui: $_lastSyncText';
  }

  /// Menghitung nilai tukar valuta secara presisi dengan kurs silang EUR dari Frankfurter API
  double get convertedAmount {
    return convert(
      amount: _sourceAmount,
      fromCode: _sourceCurrencyCode,
      toCode: _targetCurrencyCode,
    );
  }

  /// Utilitas konversi dua arah berbasis kurs referensi API
  double convert({
    required double amount,
    required String fromCode,
    required String toCode,
  }) {
    if (amount <= 0) return 0.0;
    if (fromCode.toUpperCase() == toCode.toUpperCase()) return amount;
    if (!hasRates) return 0.0;

    final srcRate = _rates[fromCode.toUpperCase()];
    final tgtRate = _rates[toCode.toUpperCase()];
    if (srcRate == null || tgtRate == null || srcRate <= 0 || tgtRate <= 0) {
      return 0.0;
    }

    final amountInEur = amount / srcRate;
    final converted = amountInEur * tgtRate;
    return double.parse(converted.toStringAsPrecision(12));
  }

  /// Konversi nilai dari IDR tanpa mengubah nilai asli
  double convertFromIdr(double amountIdr, String targetCode) {
    return convert(
      amount: amountIdr,
      fromCode: 'IDR',
      toCode: targetCode,
    );
  }

  /// Format angka dan simbol mata uang
  String formatCurrency(double amount, String currencyCode) {
    final code = currencyCode.toUpperCase();
    if (code == 'IDR') {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return formatter.format(amount);
    } else if (code == 'JPY') {
      final formatter = NumberFormat.currency(locale: 'ja_JP', symbol: '¥ ', decimalDigits: 0);
      return formatter.format(amount);
    } else if (code == 'EUR') {
      final formatter = NumberFormat.currency(locale: 'de_DE', symbol: '€ ', decimalDigits: 2);
      return formatter.format(amount);
    } else {
      final sym = _currencies[code]?.symbol ?? '$code ';
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: '$sym ', decimalDigits: 2);
      return formatter.format(amount);
    }
  }

  /// Format hasil konversi saat ini
  String get formattedConvertedResult {
    if (!hasRates) {
      return 'Kurs belum tersedia';
    }
    final result = convertedAmount;
    if (_targetCurrencyCode == 'IDR') {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return '${formatter.format(result)} IDR';
    } else {
      final sym = targetCurrency.symbol;
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: '$sym ', decimalDigits: 2);
      return '${formatter.format(result)} $_targetCurrencyCode';
    }
  }

  /// Teks referensi kurs per 1 unit
  String get exchangeRateReferenceText {
    if (!hasRates) {
      return 'Memuat kurs referensi...';
    }
    final oneUnitConverted = convert(
      amount: 1.0,
      fromCode: _sourceCurrencyCode,
      toCode: _targetCurrencyCode,
    );

    if (_targetCurrencyCode == 'IDR') {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return '1 $_sourceCurrencyCode = ${formatter.format(oneUnitConverted)} IDR';
    } else {
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: '${targetCurrency.symbol} ', decimalDigits: 4);
      return '1 $_sourceCurrencyCode = ${formatter.format(oneUnitConverted)} $_targetCurrencyCode';
    }
  }

  // ---------------------------------------------------------------------------
  // SETTERS & ACTIONS - CURRENCY
  // ---------------------------------------------------------------------------
  void setSourceAmount(double amount) {
    _sourceAmount = amount.clamp(0.0, 9999999999.0);
    notifyListeners();
  }

  void setSourceCurrency(String code) {
    if (_currencies.containsKey(code)) {
      _sourceCurrencyCode = code;
      notifyListeners();
    }
  }

  void setTargetCurrency(String code) {
    if (_currencies.containsKey(code)) {
      _targetCurrencyCode = code;
      notifyListeners();
    }
  }

  void swapCurrencies() {
    final temp = _sourceCurrencyCode;
    _sourceCurrencyCode = _targetCurrencyCode;
    _targetCurrencyCode = temp;
    notifyListeners();
  }

  /// Memuat cache kurs tersimpan dari SharedPreferences lokal
  Future<bool> loadCachedRates() async {
    try {
      final helper = await PreferencesHelper.instance;
      final cached = helper.getCachedCurrencyData();
      if (cached != null) {
        final ratesMap = (cached['rates'] as Map).cast<String, double>();
        if (ratesMap.containsKey('IDR') &&
            ratesMap.containsKey('USD') &&
            ratesMap.containsKey('EUR') &&
            ratesMap.containsKey('JPY')) {
          _rates = ratesMap;
          _apiDate = cached['api_date'] as String? ?? '';
          final syncTimeStr = cached['sync_time'] as String?;
          if (syncTimeStr != null && syncTimeStr.isNotEmpty) {
            _lastSyncTime = DateTime.tryParse(syncTimeStr);
            if (_lastSyncTime != null) {
              _lastSyncText = '${DateFormat('dd MMM yyyy, HH:mm').format(_lastSyncTime!)} WIB';
            }
          }
          if (_lastSyncText.isEmpty) {
            _lastSyncText = 'Tersimpan lokal';
          }
          _isUsingCachedRates = true;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint('UtilityProvider.loadCachedRates error: $e');
    }
    return false;
  }

  /// Sinkronisasi kurs terbaru dari Frankfurter API online
  Future<bool> syncRates({http.Client? client}) async {
    _isSyncing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final httpClient = client ?? http.Client();
      final url = Uri.parse('https://api.frankfurter.dev/v1/latest?base=EUR&symbols=IDR,USD,JPY,SGD');
      final response = await httpClient.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final date = data['date'] as String? ?? '';
        final rawRates = data['rates'] as Map<String, dynamic>? ?? {};

        final Map<String, double> parsedRates = {'EUR': 1.0};
        rawRates.forEach((key, val) {
          if (val is num) {
            parsedRates[key.toUpperCase()] = val.toDouble();
          }
        });

        if (parsedRates.containsKey('IDR') &&
            parsedRates.containsKey('USD') &&
            parsedRates.containsKey('EUR') &&
            parsedRates.containsKey('JPY')) {
          _rates = parsedRates;
          _apiDate = date;
          final now = DateTime.now();
          _lastSyncTime = now;
          _lastSyncText = 'Hari ini, ${DateFormat('HH:mm').format(now)} WIB';
          _isUsingCachedRates = false;
          _errorMessage = null;

          // Simpan ke cache lokal
          try {
            final helper = await PreferencesHelper.instance;
            await helper.saveCurrencyCache(
              apiDate: date,
              syncTimeIso: now.toIso8601String(),
              rates: parsedRates,
            );
          } catch (_) {}

          _isSyncing = false;
          notifyListeners();
          return true;
        } else {
          throw const FormatException('Respons API tidak memuat mata uang wajib (IDR, USD, EUR, JPY).');
        }
      } else {
        throw HttpException('Status server API: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('UtilityProvider.syncRates failed: $e');
      // Jika API gagal, coba gunakan cache yang sudah ada
      final hasCache = await loadCachedRates();
      if (hasCache) {
        _isUsingCachedRates = true;
        _errorMessage = 'Gagal memperbarui kurs dari server. Menggunakan kurs terakhir tersimpan.';
      } else {
        _errorMessage = 'Gagal mengambil data kurs dari server dan belum ada data tersimpan. Periksa koneksi internet Anda.';
        _isUsingCachedRates = false;
        // JANGAN membuat kurs pengganti acak jika belum ada cache
      }
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Helper untuk pengujian (menyetel rates dan state pengujian)
  void setRatesForTesting({
    required Map<String, double> rates,
    required String apiDate,
    bool isCache = false,
    String? lastSyncText,
    String? errorMessage,
  }) {
    _rates = Map.from(rates);
    _apiDate = apiDate;
    _isUsingCachedRates = isCache;
    _lastSyncText = lastSyncText ?? 'Hari ini, 08:30 WIB';
    _errorMessage = errorMessage;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // GETTERS & METHODS - TIMEZONE
  // ---------------------------------------------------------------------------
  DateTime get departureDateTime => _departureDateTime;
  String get sourceTimezoneId => _sourceTimezoneId;
  String get selectedTravelerTzId => _selectedTravelerTzId;
  List<TimezoneInfo> get timezones => _timezones;

  TimezoneInfo get selectedTravelerTz {
    return _timezones.firstWhere(
      (tz) => tz.id == _selectedTravelerTzId,
      orElse: () => _timezones.first,
    );
  }

  TimezoneInfo get sourceTimezone {
    return _timezones.firstWhere(
      (tz) => tz.id == _sourceTimezoneId,
      orElse: () => _timezones.firstWhere((tz) => tz.id == 'wib'),
    );
  }

  tz.Location get _wibLocation => tz.getLocation('Asia/Jakarta');

  /// Waktu acuan rencana berangkat di Merapi sebagai TZDateTime
  tz.TZDateTime get departureWibTZ {
    _ensureTimezonesInitialized();
    return tz.TZDateTime(
      _wibLocation,
      _departureDateTime.year,
      _departureDateTime.month,
      _departureDateTime.day,
      _departureDateTime.hour,
      _departureDateTime.minute,
    );
  }

  /// Waktu di zona traveler yang dikonversi dari departureDateTime (WIB) menggunakan IANA
  tz.TZDateTime get travelerTime {
    _ensureTimezonesInitialized();
    final targetLoc = tz.getLocation(selectedTravelerTz.ianaId);
    return tz.TZDateTime.from(departureWibTZ, targetLoc);
  }

  /// Format rencana waktu berangkat di Merapi (misal: "19 Okt 2024, 09:00 WIB")
  String get formattedDepartureWib {
    return DateFormat('dd MMM yyyy, HH:mm').format(_departureDateTime);
  }

  /// Jam waktu Merapi (HH:mm)
  String get formattedMerapiTime {
    return DateFormat('HH:mm').format(_departureDateTime);
  }

  /// Jam waktu asal traveler (HH:mm)
  String get formattedTravelerTime {
    return DateFormat('HH:mm').format(travelerTime);
  }

  /// Tanggal waktu traveler (dd MMM yyyy)
  String get formattedTravelerDate {
    return DateFormat('dd MMM yyyy').format(travelerTime);
  }

  /// Nama zona waktu IANA traveler saat ini (misal: 'GMT', 'BST', 'JST', 'WIB')
  String get travelerTimezoneAbbr {
    return travelerTime.timeZoneName;
  }

  /// Selisih hari antara waktu traveler dan waktu Merapi
  int get dayDifferenceFromMerapi {
    final merapiDateOnly = DateTime(
      _departureDateTime.year,
      _departureDateTime.month,
      _departureDateTime.day,
    );
    final travelerDateOnly = DateTime(
      travelerTime.year,
      travelerTime.month,
      travelerTime.day,
    );
    return travelerDateOnly.difference(merapiDateOnly).inDays;
  }

  /// Badge teks perbedaan tanggal (Hari yang sama / Hari sebelumnya / Hari berikutnya)
  String get dayDifferenceBadgeText {
    final diff = dayDifferenceFromMerapi;
    if (diff == 0) return 'Hari yang sama';
    if (diff > 0) return 'Hari berikutnya (+$diff hari)';
    return 'Hari sebelumnya ($diff hari)';
  }

  /// Deskripsi waktu asal (Pagi hari, Siang, Sore, Malam)
  String get travelerTimeOfDayDescription {
    final hour = travelerTime.hour;
    if (hour >= 3 && hour < 11) return 'Pagi hari';
    if (hour >= 11 && hour < 15) return 'Siang hari';
    if (hour >= 15 && hour < 18) return 'Sore hari';
    return 'Malam hari';
  }

  /// Selisih jam menuju Merapi (misal "+6 Jam" atau "-2 Jam")
  String get timeLagBadgeText {
    final offsetFromWib = selectedTravelerTz.getOffsetHoursFromWib(_departureDateTime);
    final diff = -offsetFromWib;
    if (diff > 0) return '+$diff Jam';
    if (diff < 0) return '$diff Jam';
    return 'Zona Sama';
  }

  // Setters - Timezone
  void setDepartureDateTime(DateTime dt) {
    _departureDateTime = dt;
    notifyListeners();
  }

  void setSourceTimezone(String id) {
    _sourceTimezoneId = id;
    notifyListeners();
  }

  void setSelectedTravelerTz(String id) {
    _selectedTravelerTzId = id;
    notifyListeners();
  }

  /// Konversi waktu antar zona pilihan mana pun secara bebas
  tz.TZDateTime convertTimeBetweenZones({
    required DateTime inputDateTime,
    required String fromIanaId,
    required String toIanaId,
  }) {
    _ensureTimezonesInitialized();
    final fromLoc = tz.getLocation(fromIanaId);
    final toLoc = tz.getLocation(toIanaId);
    final fromTZ = tz.TZDateTime(
      fromLoc,
      inputDateTime.year,
      inputDateTime.month,
      inputDateTime.day,
      inputDateTime.hour,
      inputDateTime.minute,
    );
    return tz.TZDateTime.from(fromTZ, toLoc);
  }

  /// Menghasilkan perbandingan waktu lengkap di 4 zona utama:
  /// WIB (Asia/Jakarta), WITA (Asia/Makassar), WIT (Asia/Jayapura), London (Europe/London)
  List<TimezoneComparisonResult> getPrimaryZoneComparisons({DateTime? customDateTime}) {
    _ensureTimezonesInitialized();
    final baseDt = customDateTime ?? _departureDateTime;
    final wibLoc = tz.getLocation('Asia/Jakarta');
    final wibTZ = tz.TZDateTime(
      wibLoc,
      baseDt.year,
      baseDt.month,
      baseDt.day,
      baseDt.hour,
      baseDt.minute,
    );
    final wibDateOnly = DateTime(wibTZ.year, wibTZ.month, wibTZ.day);

    const targetZones = [
      {'code': 'WIB', 'iana': 'Asia/Jakarta', 'city': 'Gunung Merapi (Waktu Lokal)'},
      {'code': 'WITA', 'iana': 'Asia/Makassar', 'city': 'Bali / Makassar'},
      {'code': 'WIT', 'iana': 'Asia/Jayapura', 'city': 'Jayapura / Papua'},
      {'code': 'London', 'iana': 'Europe/London', 'city': 'London (UK)'},
    ];

    return targetZones.map((z) {
      final loc = tz.getLocation(z['iana']!);
      final convertedTZ = tz.TZDateTime.from(wibTZ, loc);
      final dateOnly = DateTime(convertedTZ.year, convertedTZ.month, convertedTZ.day);
      final dayDiff = dateOnly.difference(wibDateOnly).inDays;

      String dayBadge = 'Hari ini';
      if (dayDiff > 0) {
        dayBadge = '+$dayDiff Hari';
      } else if (dayDiff < 0) {
        dayBadge = '$dayDiff Hari';
      }

      final offsetHours = convertedTZ.timeZoneOffset.inHours - wibTZ.timeZoneOffset.inHours;
      final sign = convertedTZ.timeZoneOffset.isNegative ? '-' : '+';
      final offsetAbs = convertedTZ.timeZoneOffset.inHours.abs();
      final offsetText = 'UTC$sign$offsetAbs';

      return TimezoneComparisonResult(
        code: z['code']!,
        ianaId: z['iana']!,
        city: z['city']!,
        dateTime: convertedTZ,
        formattedTime: DateFormat('HH:mm').format(convertedTZ),
        formattedDate: DateFormat('dd MMM yyyy').format(convertedTZ),
        timeZoneName: convertedTZ.timeZoneName,
        utcOffset: offsetText,
        dayDiff: dayDiff,
        dayDiffBadge: dayBadge,
        offsetHoursFromWib: offsetHours,
      );
    }).toList();
  }

  /// Mendapatkan string jam (HH:mm) untuk offset jam tertentu
  String getTimeForZone(int offsetHours) {
    final dt = _departureDateTime.add(Duration(hours: offsetHours));
    return DateFormat('HH:mm').format(dt);
  }
}
