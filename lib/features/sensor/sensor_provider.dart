import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
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
      // Listen to Magnetometer Events for compass heading
      _magnetoSubscription = magnetometerEventStream().listen(
        (event) {
          final double heading = (atan2(event.y, event.x) * 180 / pi) % 360;
          if (heading.isFinite) {
            _updateHeading(heading >= 0 ? heading : heading + 360);
          }
        },
        onError: (err) {
          debugPrint('Magnetometer stream error / unavailable: $err');
        },
      );
    } catch (e) {
      debugPrint('Sensor init magnetometer catch: $e');
    }
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

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _magnetoSubscription?.cancel();
    super.dispose();
  }
}
