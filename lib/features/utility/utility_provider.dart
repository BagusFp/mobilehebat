import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class CurrencyInfo {
  final String code;
  final String name;
  final String flag;
  final String symbol;
  final double rateToIdr;

  const CurrencyInfo({
    required this.code,
    required this.name,
    required this.flag,
    required this.symbol,
    required this.rateToIdr,
  });
}

class TimezoneInfo {
  final String id;
  final String city;
  final String label;
  final String utcOffset;
  final int offsetHoursFromWib; // WIB is UTC+7

  const TimezoneInfo({
    required this.id,
    required this.city,
    required this.label,
    required this.utcOffset,
    required this.offsetHoursFromWib,
  });
}

class UtilityProvider extends ChangeNotifier {
  // 1. Currency Converter State
  String _sourceCurrencyCode = 'USD';
  String _targetCurrencyCode = 'IDR';
  double _sourceAmount = 100.0;
  String _lastSyncText = 'Hari ini, 08:30 WIB';
  bool _isSyncing = false;

  final Map<String, CurrencyInfo> _currencies = const {
    'IDR': CurrencyInfo(code: 'IDR', name: 'Rupiah', flag: '🇮🇩', symbol: 'Rp', rateToIdr: 1.0),
    'USD': CurrencyInfo(code: 'USD', name: 'Dollar', flag: '🇺🇸', symbol: r'$', rateToIdr: 15850.0),
    'EUR': CurrencyInfo(code: 'EUR', name: 'Euro', flag: '🇪🇺', symbol: '€', rateToIdr: 17200.0),
    'JPY': CurrencyInfo(code: 'JPY', name: 'Yen', flag: '🇯🇵', symbol: '¥', rateToIdr: 106.0),
    'SGD': CurrencyInfo(code: 'SGD', name: 'Dollar SG', flag: '🇸🇬', symbol: r'S$', rateToIdr: 12100.0),
  };

  // 2. Timezone Converter State
  DateTime _departureDateTime = DateTime(2024, 10, 19, 9, 0); // Sesuai Stitch: 19 Okt 2024, 09:00 WIB
  String _selectedTravelerTzId = 'london';

  final List<TimezoneInfo> _timezones = const [
    TimezoneInfo(id: 'london', city: 'London', label: 'London (BST / UTC+1)', utcOffset: 'UTC+1', offsetHoursFromWib: -6),
    TimezoneInfo(id: 'newyork', city: 'New York', label: 'New York (EDT / UTC-4)', utcOffset: 'UTC-4', offsetHoursFromWib: -11),
    TimezoneInfo(id: 'tokyo', city: 'Tokyo', label: 'Tokyo (JST / UTC+9)', utcOffset: 'UTC+9', offsetHoursFromWib: 2),
    TimezoneInfo(id: 'sydney', city: 'Sydney', label: 'Sydney (AEST / UTC+10)', utcOffset: 'UTC+10', offsetHoursFromWib: 3),
    TimezoneInfo(id: 'wita', city: 'Bali / WITA', label: 'WITA (Bali/Makassar, UTC+8)', utcOffset: 'UTC+8', offsetHoursFromWib: 1),
    TimezoneInfo(id: 'wit', city: 'Jayapura / WIT', label: 'WIT (Maluku/Papua, UTC+9)', utcOffset: 'UTC+9', offsetHoursFromWib: 2),
  ];

  // Getters - Currency
  String get sourceCurrencyCode => _sourceCurrencyCode;
  String get targetCurrencyCode => _targetCurrencyCode;
  double get sourceAmount => _sourceAmount;
  String get lastSyncText => _lastSyncText;
  bool get isSyncing => _isSyncing;
  List<CurrencyInfo> get availableCurrencies => _currencies.values.toList();

  CurrencyInfo get sourceCurrency => _currencies[_sourceCurrencyCode] ?? _currencies['USD']!;
  CurrencyInfo get targetCurrency => _currencies[_targetCurrencyCode] ?? _currencies['IDR']!;

  /// Menghitung nilai tukar valuta secara presisi
  double get convertedAmount {
    final srcRate = sourceCurrency.rateToIdr;
    final tgtRate = targetCurrency.rateToIdr;
    if (tgtRate <= 0) return 0.0;
    final idrValue = _sourceAmount * srcRate;
    return idrValue / tgtRate;
  }

  /// Format output hasil konversi (misal: "Rp 1.585.000 IDR")
  String get formattedConvertedResult {
    final result = convertedAmount;
    if (_targetCurrencyCode == 'IDR') {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return '${formatter.format(result)} IDR';
    } else {
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: '${targetCurrency.symbol} ', decimalDigits: 2);
      return '${formatter.format(result)} $_targetCurrencyCode';
    }
  }

  /// Teks referensi kurs per 1 unit mata uang asal (misal: "1 USD = Rp 15.850 IDR")
  String get exchangeRateReferenceText {
    final srcRate = sourceCurrency.rateToIdr;
    final tgtRate = targetCurrency.rateToIdr;
    final oneUnitConverted = srcRate / tgtRate;

    if (_targetCurrencyCode == 'IDR') {
      final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
      return '1 $_sourceCurrencyCode = ${formatter.format(oneUnitConverted)} IDR';
    } else {
      final formatter = NumberFormat.currency(locale: 'en_US', symbol: '${targetCurrency.symbol} ', decimalDigits: 4);
      return '1 $_sourceCurrencyCode = ${formatter.format(oneUnitConverted)} $_targetCurrencyCode';
    }
  }

  // Setters & Actions - Currency
  void setSourceAmount(double amount) {
    _sourceAmount = amount.clamp(0.0, 999999999.0);
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

  /// Menukar posisi mata uang asal dan tujuan (Swap)
  void swapCurrencies() {
    final temp = _sourceCurrencyCode;
    _sourceCurrencyCode = _targetCurrencyCode;
    _targetCurrencyCode = temp;
    notifyListeners();
  }

  /// Sinkronisasi ulang kurs valuta (Simulasi koneksi BI / open exchange)
  Future<void> syncRates() async {
    _isSyncing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final now = DateTime.now();
    _lastSyncText = 'Hari ini, ${DateFormat('HH:mm').format(now)} WIB';
    _isSyncing = false;
    notifyListeners();
  }

  // Getters - Timezone
  DateTime get departureDateTime => _departureDateTime;
  String get selectedTravelerTzId => _selectedTravelerTzId;
  List<TimezoneInfo> get timezones => _timezones;

  TimezoneInfo get selectedTravelerTz {
    return _timezones.firstWhere(
      (tz) => tz.id == _selectedTravelerTzId,
      orElse: () => _timezones.first,
    );
  }

  /// Waktu di zona asal traveler berdasarkan waktu rencana berangkat di Merapi (WIB)
  DateTime get travelerTime {
    return _departureDateTime.add(Duration(hours: selectedTravelerTz.offsetHoursFromWib));
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  /// Teks format rencana waktu berangkat di Merapi (misal: "19 Okt 2024, 09:00")
  String get formattedDepartureWib {
    final d = _departureDateTime.day;
    final m = _months[_departureDateTime.month - 1];
    final y = _departureDateTime.year;
    final hh = _departureDateTime.hour.toString().padLeft(2, '0');
    final mm = _departureDateTime.minute.toString().padLeft(2, '0');
    return '$d $m $y, $hh:$mm';
  }

  /// Jam waktu asal traveler (HH:mm)
  String get formattedTravelerTime {
    return DateFormat('HH:mm').format(travelerTime);
  }

  /// Jam waktu Merapi (HH:mm)
  String get formattedMerapiTime {
    return DateFormat('HH:mm').format(_departureDateTime);
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
    final diff = -selectedTravelerTz.offsetHoursFromWib;
    if (diff > 0) return '+$diff Jam';
    if (diff < 0) return '$diff Jam';
    return 'Zona Sama';
  }

  // Setters - Timezone
  void setDepartureDateTime(DateTime dt) {
    _departureDateTime = dt;
    notifyListeners();
  }

  void setSelectedTravelerTz(String id) {
    _selectedTravelerTzId = id;
    notifyListeners();
  }

  /// Mendapatkan waktu untuk zona tertentu
  String getTimeForZone(int offsetHours) {
    final dt = _departureDateTime.add(Duration(hours: offsetHours));
    return DateFormat('HH:mm').format(dt);
  }
}
