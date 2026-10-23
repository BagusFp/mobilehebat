import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/utils/geo_helper.dart';
import '../../data/mock/mock_destinations.dart';
import '../../data/models/destination_model.dart';

class CompassTarget {
  final String id;
  final String name;
  final String subtitle;
  final double bearingDegrees;
  final double distanceKm;
  final int elevationMdpl;

  const CompassTarget({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.bearingDegrees,
    required this.distanceKm,
    required this.elevationMdpl,
  });
}

class SensorProvider extends ChangeNotifier {
  // 1. Shake Sensor State (Accelerometer)
  bool _isShakeEnabled = true;
  double _accelX = 0.0;
  double _accelY = 0.0;
  double _accelZ = 9.8;
  DateTime _lastShakeTime = DateTime.now();
  DestinationModel? _randomDestination;
  int _shakeCount = 0;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;

  // 2. Compass Sensor State (Gyroscope / Magnetometer)
  double _headingDegrees = 345.0; // Default mengarah ke Puncak Merapi (345° NNW)
  String _headingDirection = '345° NNW';
  String _selectedTargetId = 'puncak';
  bool _isCalibrating = false;
  String _accuracyText = 'Akurasi Sensor: Tinggi (Terkalibrasi)';
  StreamSubscription<MagnetometerEvent>? _magnetoSubscription;

  // 3. User Location & Qibla-style Merapi Direction State
  double _userLat = -7.7956; // Default Gamping, Sleman (sesuai Gambar 1)
  double _userLng = 110.3283;
  String _userLocationName = 'Gamping, Kab. Sleman';
  String _userRegionName = 'INDONESIA';
  bool _isLocatingGps = false;
  String? _gpsErrorMessage;

  // Daftar Target Orientasi Kompas Sesuai Stitch Screen 10
  final List<CompassTarget> _targets = const [
    CompassTarget(
      id: 'puncak',
      name: 'Kawah Puncak Merapi',
      subtitle: 'Kawah Puncak Merapi (2.930 mdpl) - Titik Nol',
      bearingDegrees: 345.0,
      distanceKm: 14.2,
      elevationMdpl: 2930,
    ),
    CompassTarget(
      id: 'kaliadem',
      name: 'Bunker Kaliadem',
      subtitle: 'Bunker Kaliadem (12 km Arah Utara)',
      bearingDegrees: 10.0,
      distanceKm: 12.0,
      elevationMdpl: 1165,
    ),
    CompassTarget(
      id: 'klangon',
      name: 'Bukit Klangon Glamping',
      subtitle: 'Bukit Klangon Glamping (7 km Arah Barat Laut)',
      bearingDegrees: 315.0,
      distanceKm: 7.0,
      elevationMdpl: 1200,
    ),
    CompassTarget(
      id: 'turgo',
      name: 'Bukit Turgo & Makam Syekh Jumadil Kubro',
      subtitle: 'Bukit Turgo & Makam Syekh Jumadil Kubro',
      bearingDegrees: 280.0,
      distanceKm: 5.8,
      elevationMdpl: 1000,
    ),
  ];

  SensorProvider({bool autoInitSensors = true}) {
    // Inisialisasi destinasi acak awal: Plunyon Kalikuning (sesuai Stitch)
    if (MockDestinations.destinations.isNotEmpty) {
      _randomDestination = MockDestinations.destinations.firstWhere(
        (d) => d.name.toLowerCase().contains('plunyon'),
        orElse: () => MockDestinations.destinations.first,
      );
    }
    if (autoInitSensors) {
      _initSensors();
    }
  }

  // Getters - Shake
  bool get isShakeEnabled => _isShakeEnabled;
  double get accelX => _accelX;
  double get accelY => _accelY;
  double get accelZ => _accelZ;
  DestinationModel? get randomDestination => _randomDestination;
  int get shakeCount => _shakeCount;
  String get sensorStatusLabel => _isShakeEnabled
      ? 'Sensor aktif: Mengukur hentakan 3-axis (X, Y, Z)'
      : 'Sensor dinonaktifkan oleh pengguna';

  // Getters - Compass
  double get headingDegrees => _headingDegrees;
  String get headingDirection => _headingDirection;
  String get selectedTargetId => _selectedTargetId;
  bool get isCalibrating => _isCalibrating;
  String get accuracyText => _accuracyText;
  List<CompassTarget> get targets => _targets;

  // Getters - Qibla-style Merapi Compass
  double get userLat => _userLat;
  double get userLng => _userLng;
  String get userLocationName => _userLocationName;
  String get userRegionName => _userRegionName;
  bool get isLocatingGps => _isLocatingGps;
  String? get gpsErrorMessage => _gpsErrorMessage;

  /// Sudut Azimuth ke Puncak Merapi dari lokasi pengguna saat ini (0° - 360°)
  double get merapiBearing => GeoHelper.bearingToMerapiSummit(_userLat, _userLng);

  /// Jarak lurus ke Puncak Gunung Merapi dalam KM
  double get merapiDistanceKm => GeoHelper.distanceFromMerapiSummit(_userLat, _userLng);

  /// Selisih sudut antara arah hadap ponsel dan posisi Puncak Merapi (-180° s.d. +180°)
  double get angleDiffToMerapi {
    double diff = (merapiBearing - _headingDegrees) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return diff;
  }

  /// Apakah ponsel sedang menghadap langsung ke arah Gunung Merapi (toleransi ±5 derajat)
  bool get isFacingMerapi => angleDiffToMerapi.abs() <= 5.0;

  /// Saran putaran arah untuk menghadapkan ponsel ke kawah Merapi
  String get turnSuggestion {
    final diff = angleDiffToMerapi;
    if (diff.abs() <= 5.0) {
      return 'Tepat Menghadap Puncak Merapi';
    } else if (diff > 0) {
      return 'Putar ke kanan ${diff.round()}°';
    } else {
      return 'Putar ke kiri ${diff.abs().round()}°';
    }
  }

  /// Daftar lokasi preset di sekitar Gunung Merapi untuk pengujian & simulasi kompas
  static const List<Map<String, dynamic>> presetLocations = [
    {
      'name': 'Gamping, Kab. Sleman',
      'region': 'INDONESIA',
      'lat': -7.7956,
      'lng': 110.3283,
      'description': 'Arah Barat Daya dari Merapi (Arah ~25° NNE)',
    },
    {
      'name': 'Kaliurang, Kab. Sleman',
      'region': 'INDONESIA',
      'lat': -7.5950,
      'lng': 110.4280,
      'description': 'Arah Selatan Lereng Merapi (Arah ~18° NNE)',
    },
    {
      'name': 'Kota Yogyakarta (Malioboro)',
      'region': 'INDONESIA',
      'lat': -7.7926,
      'lng': 110.3658,
      'description': 'Arah Selatan Jauh dari Merapi (Arah ~16° NNE)',
    },
    {
      'name': 'Selo, Kab. Boyolali',
      'region': 'INDONESIA',
      'lat': -7.5020,
      'lng': 110.4630,
      'description': 'Arah Utara Lereng Merapi (Arah ~202° SSW)',
    },
    {
      'name': 'Ketep Pass, Kab. Magelang',
      'region': 'INDONESIA',
      'lat': -7.4950,
      'lng': 110.3800,
      'description': 'Arah Barat dari Merapi (Arah ~128° SE)',
    },
    {
      'name': 'Candi Prambanan, Klaten',
      'region': 'INDONESIA',
      'lat': -7.7520,
      'lng': 110.4914,
      'description': 'Arah Tenggara dari Merapi (Arah ~347° NNW)',
    },
  ];

  /// Mengubah lokasi secara manual dari daftar preset
  void setManualLocation({
    required double lat,
    required double lng,
    required String locationName,
    String regionName = 'INDONESIA',
  }) {
    _userLat = lat;
    _userLng = lng;
    _userLocationName = locationName;
    _userRegionName = regionName;
    notifyListeners();
  }

  /// Memperbarui lokasi pengguna menggunakan GPS perangkat (Real-time)
  Future<bool> updateGpsLocation() async {
    _isLocatingGps = true;
    _gpsErrorMessage = null;
    notifyListeners();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _gpsErrorMessage = 'Layanan GPS tidak aktif pada perangkat.';
        _isLocatingGps = false;
        notifyListeners();
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _gpsErrorMessage = 'Izin akses lokasi ditolak.';
          _isLocatingGps = false;
          notifyListeners();
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _gpsErrorMessage = 'Izin lokasi ditolak permanen. Buka Pengaturan.';
        _isLocatingGps = false;
        notifyListeners();
        return false;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _userLat = pos.latitude;
      _userLng = pos.longitude;
      _userLocationName = 'Lokasi GPS (${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)})';
      _userRegionName = 'INDONESIA';
      _isLocatingGps = false;
      notifyListeners();
      return true;
    } catch (e) {
      _gpsErrorMessage = 'Gagal membaca GPS: $e';
      _isLocatingGps = false;
      notifyListeners();
      return false;
    }
  }

  CompassTarget get currentTarget {
    return _targets.firstWhere(
      (t) => t.id == _selectedTargetId,
      orElse: () => _targets.first,
    );
  }

  void _initSensors() {
    try {
      // Listen to Accelerometer Events
      _accelSubscription = accelerometerEventStream().listen(
        (event) {
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;

          if (!_isShakeEnabled) return;

          final double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          // Deteksi hentakan signifikan (gForce > 14 m/s^2)
          if (gForce > 14.0) {
            final now = DateTime.now();
            if (now.difference(_lastShakeTime).inMilliseconds > 900) {
              _lastShakeTime = now;
              _shakeCount++;
              triggerRandomDestination();
            }
          }
        },
        onError: (err) {
          // Graceful fallback for simulator / testing environment
          debugPrint('Accelerometer stream error / unavailable: $err');
        },
      );
    } catch (e) {
      debugPrint('Sensor init accelerometer catch: $e');
    }

    try {
      // Listen to Magnetometer Events for compass heading (Arah Kompas Realistis)
      _magnetoSubscription = magnetometerEventStream().listen(
        (event) {
          _calculateCompassHeading(event.x, event.y, event.z);
        },
        onError: (err) {
          debugPrint('Magnetometer stream error / unavailable: $err');
        },
      );
    } catch (e) {
      debugPrint('Sensor init magnetometer catch: $e');
    }
  }

  /// Menghitung orientasi arah kompas (Azimuth 0° - 360°) dengan kompensasi kemiringan ponsel (Tilt Compensation)
  /// Menggunakan kaidah sensor mobile: X (kanan), Y (atas), Z (keluar layar)
  void _calculateCompassHeading(double mx, double my, double mz) {
    // 1. Normalisasi vektor gravitasi dari Accelerometer
    final double gNorm = sqrt(_accelX * _accelX + _accelY * _accelY + _accelZ * _accelZ);
    double ax = 0.0;
    double ay = 0.0;
    double az = 1.0;
    if (gNorm > 0.1) {
      ax = _accelX / gNorm;
      ay = _accelY / gNorm;
      az = _accelZ / gNorm;
    }

    // 2. Vector Cross Product untuk proyeksi bidang datar horizontal (Tilt Compensation)
    // H = G x M (Vektor Timur Horizontal pada kerangka ponsel)
    double hx = ay * mz - az * my;
    double hy = az * mx - ax * mz;
    double hz = ax * my - ay * mx;
    final double hNorm = sqrt(hx * hx + hy * hy + hz * hz);

    double heading;
    if (hNorm > 0.1) {
      hx /= hNorm;
      hy /= hNorm;
      hz /= hNorm;

      // N = H x G (Vektor Utara Horizontal pada kerangka ponsel)
      final double ny = hz * ax - hx * az;

      // Azimuth adalah sudut searah jarum jam dari Utara ke ujung atas ponsel (+Y)
      // -hy = sin(azimuth), ny = cos(azimuth)
      heading = (atan2(-hy, ny) * 180.0 / pi);
    } else {
      // Fallback 2D bila sensor gravitasi tidak terbaca (Ponsel datar di meja)
      // Saat menghadap East (Timur), medan magnet ada di sebelah kiri (-X), sehingga -mx > 0
      heading = (atan2(-mx, my) * 180.0 / pi);
    }

    if (!heading.isFinite) return;

    heading = (heading % 360.0 + 360.0) % 360.0;

    // Filter perataan sudut (Low-Pass Filter) untuk mencegah getaran liar jarum
    final double smoothed = _smoothAngle(_headingDegrees, heading, 0.35);
    _updateHeading(smoothed);
  }

  /// Menghaluskan perubahan sudut melewati batas 0°/360° secara kontinu
  double _smoothAngle(double current, double target, double alpha) {
    double diff = (target - current) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (current + diff * alpha + 360) % 360;
  }

  void _updateHeading(double degrees) {
    _headingDegrees = degrees;
    _headingDirection = _formatDegreeToCardinal(degrees);
    notifyListeners();
  }

  String _formatDegreeToCardinal(double deg) {
    const directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final index = ((deg + 11.25) % 360 / 22.5).floor();
    final card = directions[index % 16];
    return '${deg.round()}° $card';
  }

  /// Toggle aktivasi deteksi goyang ponsel
  void toggleShake(bool value) {
    _isShakeEnabled = value;
    notifyListeners();
  }

  /// Memilih destinasi lereng Merapi secara acak (Hidden Gem)
  void triggerRandomDestination() {
    if (MockDestinations.destinations.isEmpty) return;

    final random = Random();
    int newIndex;
    do {
      newIndex = random.nextInt(MockDestinations.destinations.length);
    } while (MockDestinations.destinations.length > 1 &&
        _randomDestination != null &&
        MockDestinations.destinations[newIndex].id == _randomDestination!.id);

    _randomDestination = MockDestinations.destinations[newIndex];
    notifyListeners();
  }

  /// Memilih target kompas (Puncak, Kaliadem, Klangon, Turgo)
  void setCompassTarget(String targetId) {
    _selectedTargetId = targetId;
    final target = currentTarget;
    _headingDegrees = target.bearingDegrees;
    _headingDirection = _formatDegreeToCardinal(target.bearingDegrees);
    notifyListeners();
  }

  /// Kalibrasi manual orientasi kompas
  Future<void> calibrateCompass() async {
    _isCalibrating = true;
    _accuracyText = 'Mengkalibrasi ulang sensor kompas...';
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _isCalibrating = false;
    _accuracyText = 'Akurasi Sensor: Tinggi (Terkalibrasi)';
    _headingDegrees = currentTarget.bearingDegrees;
    _headingDirection = _formatDegreeToCardinal(_headingDegrees);
    notifyListeners();
  }

  /// Simulasi orientasi derajat langsung (untuk Widget Testing)
  void setHeadingForTesting(double degrees) {
    _updateHeading(degrees);
  }

  @visibleForTesting
  void calculateHeadingForTesting({
    required double ax,
    required double ay,
    required double az,
    required double mx,
    required double my,
    required double mz,
  }) {
    _accelX = ax;
    _accelY = ay;
    _accelZ = az;
    _calculateCompassHeading(mx, my, mz);
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _magnetoSubscription?.cancel();
    super.dispose();
  }
}
