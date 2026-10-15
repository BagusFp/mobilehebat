import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/geo_helper.dart';
import '../../data/mock/mock_destinations.dart';
import '../../data/models/destination_model.dart';
import '../../data/models/offline_pack_model.dart';

class MapProvider extends ChangeNotifier {
  // State Navigasi & Map
  DestinationModel? _selectedDestination;
  String _viewMode = 'map'; // 'map' atau 'list'
  double _userLat = GeoHelper.userDefaultLat;
  double _userLng = GeoHelper.userDefaultLng;
  bool _isBatterySaver = false;
  final bool _isGpsAccurate = true;
  bool _isWifiOnly = true;

  // Real-time GPS Tracking State
  bool _isLocating = false;
  bool _hasLiveGpsFix = false;
  String? _locationStatusMessage;
  double? _gpsAccuracyMeters;
  String _mapStyle = 'standard'; // 'standard', 'topo', 'voyager'

  // OSRM Routing State (FR & User Poin 1)
  bool _isLoadingRoute = false;
  List<LatLng> _routePoints = [];
  double? _routeDistanceKm;
  int? _routeDurationMinutes;
  String? _routeAttribution;
  String? _routeError;

  // OpenStreetMap Online Search State (User Poin 2)
  bool _isSearchingOsm = false;
  List<DestinationModel> _osmSearchResults = [];
  String _searchQuery = '';

  // Paket Data Peta Offline (Sesuai Stitch Screen 9)
  List<OfflinePackModel> _offlinePacks = [
    const OfflinePackModel(
      id: 1,
      name: 'Kaliadem & Cangkringan',
      sizeMb: 18.4,
      downloadedMb: 18.4,
      status: 'downloaded',
      badgeLabel: 'Lengkap',
      iconType: 'terrain',
    ),
    const OfflinePackModel(
      id: 2,
      name: 'Kaliurang & Plunyon',
      sizeMb: 15.8,
      downloadedMb: 15.8,
      status: 'downloaded',
      badgeLabel: 'Lengkap',
      iconType: 'forest',
    ),
    const OfflinePackModel(
      id: 3,
      name: 'Jalur Boyolali & Selo',
      sizeMb: 12.1,
      downloadedMb: 8.2,
      status: 'downloading',
      badgeLabel: 'Mengunduh 68%',
      iconType: 'downloading',
      speedText: '1.4 MB/s • Sisa ~3 dtk',
    ),
    const OfflinePackModel(
      id: 4,
      name: 'Geowisata Bebeng & Klangon',
      sizeMb: 9.5,
      downloadedMb: 0.0,
      status: 'failed',
      badgeLabel: 'Koneksi Terputus',
      iconType: 'cloud_off',
      errorMessage: 'Sinyal seluler tidak stabil saat mengunduh tile peta.',
    ),
  ];

  MapProvider() {
    // Default seleksi: Bunker Kaliadem
    if (MockDestinations.destinations.isNotEmpty) {
      _selectedDestination = MockDestinations.destinations.first;
    }
  }

  // Getters
  DestinationModel? get selectedDestination => _selectedDestination;
  String get viewMode => _viewMode;
  double get userLat => _userLat;
  double get userLng => _userLng;
  bool get isBatterySaver => _isBatterySaver;
  bool get isGpsAccurate => _isGpsAccurate;
  bool get isWifiOnly => _isWifiOnly;
  List<OfflinePackModel> get offlinePacks => _offlinePacks;

  bool get isLocating => _isLocating;
  bool get hasLiveGpsFix => _hasLiveGpsFix;
  String? get locationStatusMessage => _locationStatusMessage;
  double? get gpsAccuracyMeters => _gpsAccuracyMeters;
  String get mapStyle => _mapStyle;

  bool get isLoadingRoute => _isLoadingRoute;
  List<LatLng> get routePoints => _routePoints;
  double? get routeDistanceKm => _routeDistanceKm;
  int? get routeDurationMinutes => _routeDurationMinutes;
  String? get routeAttribution => _routeAttribution;
  String? get routeError => _routeError;

  bool get isSearchingOsm => _isSearchingOsm;
  List<DestinationModel> get osmSearchResults => _osmSearchResults;
  String get searchQuery => _searchQuery;

  double get allocatedStorageMb => 512.0;

  double get totalDownloadedMb {
    double total = 0.0;
    for (final pack in _offlinePacks) {
      if (pack.status == 'downloaded' || pack.status == 'downloading') {
        total += pack.downloadedMb;
      }
    }
    return total;
  }

  double get usagePercent {
    return (totalDownloadedMb / allocatedStorageMb) * 100.0;
  }

  /// Destinasi yang diurutkan berdasarkan kedekatan LBS dengan pengguna
  List<DestinationModel> get destinationsSortedByDistance {
    final list = List<DestinationModel>.from(MockDestinations.destinations);
    list.sort((a, b) {
      final distA = GeoHelper.distanceToUser(a.latitude, a.longitude, userLat: _userLat, userLng: _userLng);
      final distB = GeoHelper.distanceToUser(b.latitude, b.longitude, userLat: _userLat, userLng: _userLng);
      return distA.compareTo(distB);
    });
    return list;
  }

  /// Memilih destinasi aktif di peta (dapat null jika ditutup)
  void selectDestination(DestinationModel? dest) {
    _selectedDestination = dest;
    notifyListeners();
  }

  /// Beralih antara mode tampilan 'map' dan 'list'
  void setViewMode(String mode) {
    _viewMode = mode;
    notifyListeners();
  }

  /// Toggle antara mode 'map' dan 'list'
  void toggleViewMode() {
    _viewMode = _viewMode == 'map' ? 'list' : 'map';
    notifyListeners();
  }

  /// Toggle mode hemat daya GPS
  void toggleBatterySaver() {
    _isBatterySaver = !_isBatterySaver;
    notifyListeners();
  }

  /// Set unduh hanya melalui Wi-Fi
  void setWifiOnly(bool value) {
    _isWifiOnly = value;
    notifyListeners();
  }

  /// Toggle unduh hanya melalui Wi-Fi
  void toggleWifiOnly() {
    _isWifiOnly = !_isWifiOnly;
    notifyListeners();
  }

  /// Mengambil lokasi asli GPS ponsel saat ini secara real-time
  Future<bool> fetchLiveLocation() async {
    _isLocating = true;
    _locationStatusMessage = 'Menghubungkan ke sensor GPS ponsel...';
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _isLocating = false;
        _locationStatusMessage = 'Layanan GPS perangkat belum diaktifkan.';
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _isLocating = false;
          _locationStatusMessage = 'Izin lokasi GPS ditolak oleh pengguna.';
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _isLocating = false;
        _locationStatusMessage = 'Izin lokasi ditolak permanen di setelan HP.';
        notifyListeners();
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _userLat = position.latitude;
      _userLng = position.longitude;
      _hasLiveGpsFix = true;
      _gpsAccuracyMeters = position.accuracy;
      _locationStatusMessage = 'Lokasi asli ponsel aktif: ${_userLat.toStringAsFixed(4)}, ${_userLng.toStringAsFixed(4)} (±${position.accuracy.toStringAsFixed(0)}m)';
      _isLocating = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLocating = false;
      _locationStatusMessage = 'GPS tidak merespons ($e). Memakai titik Kaliurang.';
      notifyListeners();
      return false;
    }
  }

  /// Reset/recenter ke titik acuan Pos Retribusi Kaliurang
  void recenterUserLocation() {
    _userLat = GeoHelper.userDefaultLat;
    _userLng = GeoHelper.userDefaultLng;
    _locationStatusMessage = 'Posisi diatur ke Pos Retribusi Kaliurang.';
    notifyListeners();
  }

  /// Atur lokasi secara manual (berguna untuk simulasi / pengujian)
  void setUserLocationManually(double lat, double lng) {
    _userLat = lat;
    _userLng = lng;
    _hasLiveGpsFix = true;
    notifyListeners();
  }

  /// Beralih gaya tampilan peta OpenStreetMap
  void setMapStyle(String style) {
    _mapStyle = style;
    notifyListeners();
  }

  /// Jeda proses unduhan paket peta
  void pauseDownload(int packId) {
    final index = _offlinePacks.indexWhere((p) => p.id == packId);
    if (index != -1) {
      final pack = _offlinePacks[index];
      _offlinePacks[index] = pack.copyWith(
        status: 'paused',
        badgeLabel: 'Dijeda',
        speedText: 'Unduhan dijeda',
      );
      notifyListeners();
    }
  }

  /// Lanjutkan unduhan paket peta
  void resumeDownload(int packId) {
    final index = _offlinePacks.indexWhere((p) => p.id == packId);
    if (index != -1) {
      final pack = _offlinePacks[index];
      _offlinePacks[index] = pack.copyWith(
        status: 'downloading',
        badgeLabel: 'Mengunduh ${pack.progressPercent}%',
        speedText: '1.4 MB/s • Sisa ~3 dtk',
      );
      notifyListeners();
    }
  }

  /// Coba lagi unduh paket yang gagal
  void retryDownload(int packId) {
    final index = _offlinePacks.indexWhere((p) => p.id == packId);
    if (index != -1) {
      final pack = _offlinePacks[index];
      _offlinePacks[index] = pack.copyWith(
        status: 'downloading',
        downloadedMb: 4.5,
        badgeLabel: 'Mengunduh 47%',
        iconType: 'downloading',
        errorMessage: null,
        speedText: '1.8 MB/s • Sisa ~4 dtk',
      );
      notifyListeners();
    }
  }

  /// Hapus paket data peta offline
  void deletePack(int packId) {
    final index = _offlinePacks.indexWhere((p) => p.id == packId);
    if (index != -1) {
      final pack = _offlinePacks[index];
      _offlinePacks[index] = pack.copyWith(
        status: 'not_downloaded',
        downloadedMb: 0.0,
        badgeLabel: 'Tersedia',
        speedText: null,
      );
      notifyListeners();
    }
  }

  /// Perbarui paket data peta
  void updatePack(int packId) {
    final index = _offlinePacks.indexWhere((p) => p.id == packId);
    if (index != -1) {
      final pack = _offlinePacks[index];
      _offlinePacks[index] = pack.copyWith(
        downloadedMb: pack.sizeMb,
        status: 'downloaded',
        badgeLabel: 'Terbaru',
      );
      notifyListeners();
    }
  }

  /// Bersihkan seluruh cache peta offline
  void cleanCache() {
    _offlinePacks = _offlinePacks.map((pack) {
      if (pack.id == 1 || pack.id == 2) {
        // Pertahankan 1 pack dasar
        return pack;
      }
      return pack.copyWith(
        status: 'not_downloaded',
        downloadedMb: 0.0,
        badgeLabel: 'Tersedia',
        speedText: null,
      );
    }).toList();
    notifyListeners();
  }

  /// Unduh seluruh paket kawasan Merapi
  void downloadAllPacks() {
    _offlinePacks = _offlinePacks.map((pack) {
      return pack.copyWith(
        status: 'downloaded',
        downloadedMb: pack.sizeMb,
        badgeLabel: 'Lengkap',
        iconType: pack.id == 1 ? 'terrain' : (pack.id == 2 ? 'forest' : 'terrain'),
        errorMessage: null,
        speedText: null,
      );
    }).toList();
    notifyListeners();
  }

  /// Mengambil rute mengemudi nyata dari lokasi pengguna ke destinasi via OSRM
  Future<void> fetchRouteToDestination(DestinationModel dest) async {
    _isLoadingRoute = true;
    _routeError = null;
    notifyListeners();

    try {
      final res = await ApiService.getOsrmRoute(
        startLat: _userLat,
        startLng: _userLng,
        endLat: dest.latitude,
        endLng: dest.longitude,
      );

      if (res != null && res['coordinates'] is List && (res['coordinates'] as List).isNotEmpty) {
        _routePoints = List<LatLng>.from(res['coordinates'] as List);
        _routeDistanceKm = res['distance_km'] as double?;
        _routeDurationMinutes = res['duration_minutes'] as int?;
        _routeAttribution = res['attribution'] as String?;
      } else {
        _routePoints = [LatLng(_userLat, _userLng), LatLng(dest.latitude, dest.longitude)];
        _routeDistanceKm = GeoHelper.distanceToUser(dest.latitude, dest.longitude, userLat: _userLat, userLng: _userLng);
        _routeDurationMinutes = (_routeDistanceKm! / 25 * 60).round();
      }
    } catch (e) {
      _routeError = 'Gagal memuat rute OSRM: $e';
      _routePoints = [LatLng(_userLat, _userLng), LatLng(dest.latitude, dest.longitude)];
    } finally {
      _isLoadingRoute = false;
      notifyListeners();
    }
  }

  /// Menghapus rute aktif di peta
  void clearRoute() {
    _routePoints = [];
    _routeDistanceKm = null;
    _routeDurationMinutes = null;
    _routeError = null;
    notifyListeners();
  }

  /// Melakukan pencarian tempat wisata online via OpenStreetMap / Overpass
  Future<void> searchDestinationsOnline(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _osmSearchResults = [];
      _isSearchingOsm = false;
      notifyListeners();
      return;
    }

    _isSearchingOsm = true;
    notifyListeners();

    try {
      final results = await ApiService.searchOsmDestinations(_searchQuery);
      _osmSearchResults = results;
    } catch (e) {
      _osmSearchResults = [];
    } finally {
      _isSearchingOsm = false;
      notifyListeners();
    }
  }

  /// Menghapus hasil pencarian online
  void clearOsmSearch() {
    _searchQuery = '';
    _osmSearchResults = [];
    _isSearchingOsm = false;
    notifyListeners();
  }
}
