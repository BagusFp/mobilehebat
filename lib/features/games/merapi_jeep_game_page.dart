import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model Data Kendaraan Permainan
class GameVehicle {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final String assetPath;
  final double width;
  final double height;
  final double bottomOffset; // Offset agar roda menempel persis di atas tanah
  final Color themeColor;

  const GameVehicle({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.bottomOffset,
    required this.themeColor,
  });
}

/// Model Data Rintangan Permainan
class GameObstacle {
  final String id;
  final String name;
  final String assetPath;
  final double width;
  final double height;
  final double bottomOffset; // Offset agar rintangan menempel persis di atas tanah
  final double hitboxWidth;
  final double hitboxHeight;

  const GameObstacle({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.bottomOffset,
    required this.hitboxWidth,
    required this.hitboxHeight,
  });
}

class MerapiJeepGamePage extends StatefulWidget {
  const MerapiJeepGamePage({super.key});

  @override
  State<MerapiJeepGamePage> createState() => _MerapiJeepGamePageState();
}

class _MerapiJeepGamePageState extends State<MerapiJeepGamePage> {
  // Asset Latar Belakang Baru
  static const String backgroundAssetPath = 'lib/img/game/baground.png';

  // Daftar Pilihan Mobil (Jeep, Kopdes, SPPG)
  static const List<GameVehicle> vehicles = [
    GameVehicle(
      id: 'jeep',
      name: 'Jeep Willys',
      subtitle: 'Off-Road 4x4',
      description: 'Mobil off-road legendaris wisata Lava Tour Merapi.',
      assetPath: 'lib/img/game/jeep.png',
      width: 86.0,
      height: 60.0,
      bottomOffset: 12.0,
      themeColor: Color(0xFF2E7D32),
    ),
    GameVehicle(
      id: 'kopdes',
      name: 'Truk Kopdes',
      subtitle: 'Koperasi Desa',
      description: 'Truk logistik Kopdes Kel Merah Putih yang kokoh.',
      assetPath: 'lib/img/game/kopdes.png',
      width: 94.0,
      height: 62.0,
      bottomOffset: 11.0,
      themeColor: Color(0xFFC62828),
    ),
    GameVehicle(
      id: 'sppg',
      name: 'Mobil SPPG',
      subtitle: 'Pelayanan Gizi',
      description: 'Mobil Satuan Pelayanan Pemenuhan Gizi yang gesit.',
      assetPath: 'lib/img/game/sppg.png',
      width: 92.0,
      height: 50.0,
      bottomOffset: 8.5,
      themeColor: Color(0xFF1565C0),
    ),
  ];

  // Daftar Rintangan (Batu, Papan !AWAS, Pohon Sawit)
  static const List<GameObstacle> obstacles = [
    GameObstacle(
      id: 'batu',
      name: 'Batu Merapi',
      assetPath: 'lib/img/game/batu.png',
      width: 44.0,
      height: 44.0,
      bottomOffset: 4.5,
      hitboxWidth: 32.0,
      hitboxHeight: 32.0,
    ),
    GameObstacle(
      id: 'papan',
      name: 'Papan Awas',
      assetPath: 'lib/img/game/papan.png',
      width: 40.0,
      height: 52.0,
      bottomOffset: 3.0,
      hitboxWidth: 28.0,
      hitboxHeight: 42.0,
    ),
    GameObstacle(
      id: 'sawit',
      name: 'Pohon Sawit',
      assetPath: 'lib/img/game/sawit.png',
      width: 62.0,
      height: 62.0,
      bottomOffset: 11.0,
      hitboxWidth: 40.0,
      hitboxHeight: 44.0,
    ),
  ];

  // Status Mobil Terpilih & Arah
  GameVehicle selectedVehicle = vehicles[0];
  bool faceRight = true; // Fungsi membalik gambar yang aslinya menghadap kiri menjadi menghadap kanan

  // Status Permainan
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int highScore = 0;
  int frameCount = 0;

  // Fisika Lompatan
  final double groundLevel = 48.0;
  final double jeepLeftPosition = 45.0; // Posisi X tetap
  double jeepBottomOffset = 0.0; // 0 = menapak di atas tanah
  double velocityY = 0.0;
  final double jumpPower = 13.5;
  final double gravity = 0.60;
  bool isJumping = false;

  // Rintangan
  double obstacleX = 500.0;
  double gameSpeed = 4.5;
  GameObstacle currentObstacle = obstacles[0];

  // Partikel Abu & Awan Hiasan
  double cloudDecorationX = 300.0;

  // Sensor & Optimasi Performa
  bool enableSensorJump = true;
  double accValue = 0.0;
  final ValueNotifier<double> _gyroNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<String> _sensorTextNotifier = ValueNotifier<String>('Acc: 0.0 | Gyro: 0.0');
  int _lastSensorTextUpdate = 0;
  bool _isModalOpen = false;
  bool _assetsPrecached = false;

  Timer? gameTimer;
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _initSensors();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_assetsPrecached) {
      _assetsPrecached = true;
      // Precache lazy loading semua asset agar saat menu dibuka tidak ada lag / freeze decoding
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        precacheImage(const AssetImage(backgroundAssetPath), context);
        for (final v in vehicles) {
          precacheImage(AssetImage(v.assetPath), context);
        }
        for (final o in obstacles) {
          precacheImage(AssetImage(o.assetPath), context);
        }
      });
    }
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCarId = prefs.getString('game_car_id');
      final savedHighScore = prefs.getInt('game_high_score') ?? 0;
      final savedFaceRight = prefs.getBool('game_car_face_right') ?? true;

      if (mounted) {
        setState(() {
          if (savedCarId != null) {
            selectedVehicle = vehicles.firstWhere(
              (v) => v.id == savedCarId,
              orElse: () => vehicles[0],
            );
          }
          highScore = savedHighScore;
          faceRight = savedFaceRight;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCarPreference(String carId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('game_car_id', carId);
    } catch (_) {}
  }

  Future<void> _saveDirectionPreference(bool isRight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('game_car_face_right', isRight);
    } catch (_) {}
  }

  Future<void> _saveHighScore(int newHighScore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('game_high_score', newHighScore);
    } catch (_) {}
  }

  void _initSensors() {
    // Tunda listener sensor setelah frame awal selesai dirender agar transisi menu sangat enteng
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startSensorStreams();
    });
  }

  void _startSensorStreams() {
    // Sensor 1: Accelerometer (Hanya picu jump saat main, tanpa setState global)
    _accSub = accelerometerEventStream().listen((event) {
      if (_isModalOpen) return;
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      accValue = magnitude;

      if (enableSensorJump && isPlaying && !isJumping && magnitude > 15.5) {
        _jump();
      }

      _updateSensorTextThrottled();
    });

    // Sensor 2: Gyroscope (Parallax terisolasi via ValueNotifier, tidak rebuild seluruh halaman)
    _gyroSub = gyroscopeEventStream().listen((event) {
      if (_isModalOpen) return;
      final current = _gyroNotifier.value;
      final newOffset = (current + event.y * 2.2).clamp(-25.0, 25.0);
      if ((newOffset - current).abs() > 0.08) {
        _gyroNotifier.value = newOffset;
        _updateSensorTextThrottled();
      }
    });
  }

  void _updateSensorTextThrottled() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSensorTextUpdate > 250) {
      _lastSensorTextUpdate = now;
      _sensorTextNotifier.value =
          'Acc: ${accValue.toStringAsFixed(1)} | Gyro: ${_gyroNotifier.value.toStringAsFixed(1)}';
    }
  }

  void _startGame() {
    final double initialX = MediaQuery.sizeOf(context).width > 0
        ? MediaQuery.sizeOf(context).width + 60.0
        : 450.0;

    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      frameCount = 0;
      jeepBottomOffset = 0.0;
      velocityY = 0.0;
      isJumping = false;
      obstacleX = initialX;
      gameSpeed = 4.6;
      currentObstacle = obstacles[Random().nextInt(obstacles.length)];
    });

    HapticFeedback.lightImpact();

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _updateGame();
    });
  }

  void _jump() {
    if (!isJumping && isPlaying) {
      setState(() {
        isJumping = true;
        velocityY = jumpPower;
      });
      HapticFeedback.selectionClick();
    }
  }

  void _updateGame() {
    setState(() {
      frameCount++;

      // 1. Tambah skor otomatis seiring jarak tempuh
      if (frameCount % 6 == 0) {
        score++;
        if (gameSpeed < 8.8) {
          gameSpeed += 0.003;
        }
      }

      // 2. Fisika Lompatan Mobil
      if (isJumping) {
        jeepBottomOffset += velocityY;
        velocityY -= gravity;

        if (jeepBottomOffset <= 0.0) {
          jeepBottomOffset = 0.0;
          velocityY = 0.0;
          isJumping = false;
        }
      }

      // 3. Gerakkan Rintangan dari Kanan ke Kiri
      obstacleX -= gameSpeed;
      cloudDecorationX -= 1.0;

      if (cloudDecorationX < -80.0) {
        final screenW = MediaQuery.sizeOf(context).width;
        cloudDecorationX = screenW > 0 ? screenW + 50.0 : 400.0;
      }

      // Munculkan rintangan baru secara acak (Batu, Papan, atau Sawit)
      if (obstacleX < -80.0) {
        final screenW = MediaQuery.sizeOf(context).width;
        obstacleX = (screenW > 0 ? screenW : 360.0) + 40.0 + Random().nextInt(150);
        currentObstacle = obstacles[Random().nextInt(obstacles.length)];
      }

      // 4. Deteksi Tabrakan Presisi & Adil
      final double carHitboxLeft = jeepLeftPosition + 12.0;
      final double carHitboxRight = jeepLeftPosition + selectedVehicle.width - 12.0;

      final double obsPaddingH = (currentObstacle.width - currentObstacle.hitboxWidth) / 2;
      final double obsHitboxLeft = obstacleX + obsPaddingH;
      final double obsHitboxRight = obsHitboxLeft + currentObstacle.hitboxWidth;

      final bool isHorizontalHit = (carHitboxRight > obsHitboxLeft) && (carHitboxLeft < obsHitboxRight);
      final bool isVerticalHit = jeepBottomOffset < currentObstacle.hitboxHeight;

      if (isHorizontalHit && isVerticalHit) {
        _triggerGameOver();
      }
    });
  }

  void _triggerGameOver() {
    gameTimer?.cancel();
    isPlaying = false;
    isGameOver = true;
    HapticFeedback.heavyImpact();

    if (score > highScore) {
      highScore = score;
      _saveHighScore(highScore);
    }
  }

  void _selectVehicle(GameVehicle vehicle) {
    setState(() {
      selectedVehicle = vehicle;
    });
    _saveCarPreference(vehicle.id);
    HapticFeedback.selectionClick();
  }

  void _toggleDirection() {
    setState(() {
      faceRight = !faceRight;
    });
    _saveDirectionPreference(faceRight);
    HapticFeedback.selectionClick();
  }

  void _showCarSelectionModal() {
    _isModalOpen = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return RepaintBoundary(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E1F24),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: const Text(
                              'PILIH KENDARAAN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          // Tombol Arah Hadap Kanan
                          InkWell(
                            onTap: () {
                              _toggleDirection();
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: faceRight
                                    ? Colors.orangeAccent.withValues(alpha: 0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: faceRight ? Colors.orangeAccent : Colors.white24,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    faceRight ? Icons.arrow_forward : Icons.arrow_back,
                                    color: faceRight ? Colors.orangeAccent : Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    faceRight ? 'Hadap Kanan' : 'Hadap Kiri',
                                    style: TextStyle(
                                      color: faceRight ? Colors.orangeAccent : Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pilih armada yang ingin dikemudikan di lereng Merapi.',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 18),

                      // List Mobil
                      ...vehicles.map((v) {
                        final bool isSelected = selectedVehicle.id == v.id;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: InkWell(
                            onTap: () {
                              _selectVehicle(v);
                              setModalState(() {});
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? v.themeColor.withValues(alpha: 0.22)
                                    : const Color(0xFF282A31),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? Colors.orangeAccent : Colors.white12,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Thumbnail Mobil dengan Fungsi Arah Hadap
                                  Container(
                                    width: 80,
                                    height: 54,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black26,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Transform.flip(
                                        flipX: faceRight,
                                        child: Image.asset(
                                          v.assetPath,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                          filterQuality: FilterQuality.low,
                                          cacheWidth: 160,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                v.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: v.themeColor.withValues(alpha: 0.3),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                v.subtitle,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          v.description,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.orangeAccent,
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Selesai',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        _isModalOpen = false;
      }
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _accSub?.cancel();
    _gyroSub?.cancel();
    _gyroNotifier.dispose();
    _sensorTextNotifier.dispose();
    super.dispose();
  }

  String _formatScore(int val) {
    return val.toString().padLeft(5, '0');
  }

  @override
  Widget build(BuildContext context) {
    final double jumpTilt = isJumping
        ? (velocityY > 0 ? (faceRight ? -0.10 : 0.10) : (faceRight ? 0.08 : -0.08))
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF191A1E),
      appBar: AppBar(
        title: const Text('Merapi Jeep Run', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2A1C16),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Kembali',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        elevation: 0,
        actions: [
          // Tombol Buka Menu Ganti Mobil
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.orangeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: const Icon(Icons.directions_car, size: 20),
            label: Text(
              selectedVehicle.name.split(' ').first,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: _showCarSelectionModal,
          ),
          // Toggle Sensor Accelerometer
          IconButton(
            tooltip: enableSensorJump ? 'Sensor Lompat: Aktif' : 'Sensor Lompat: Mati',
            icon: Icon(
              enableSensorJump ? Icons.sensors : Icons.sensors_off,
              color: enableSensorJump ? Colors.orangeAccent : Colors.white38,
            ),
            onPressed: () {
              setState(() => enableSensorJump = !enableSensorJump);
            },
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (!isPlaying) {
            _startGame();
          } else {
            _jump();
          }
        },
        child: Column(
          children: [
            // ==========================================
            // AREA GAME UTAMA
            // ==========================================
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. BACKGROUND GAMBAR DARI ASSET (baground.png) - Terisolasi dengan RepaintBoundary & ValueListenable
                  RepaintBoundary(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _gyroNotifier,
                      builder: (context, offset, child) {
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: Transform.scale(
                        scale: 1.15, // Skala halus untuk mencegah celah saat parallax sensor
                        child: Image.asset(
                          backgroundAssetPath,
                          fit: BoxFit.cover,
                          alignment: Alignment.bottomCenter,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.low,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Color(0xFF8D6E63), Color(0xFF261C18)],
                                ),
                              ),
                              child: const Center(
                                child: Text('🌋', style: TextStyle(fontSize: 100)),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // 2. AWAN HIASAN DI LANGIT
                  Positioned(
                    top: 40,
                    left: cloudDecorationX,
                    child: Opacity(
                      opacity: 0.65,
                      child: const Text('☁️', style: TextStyle(fontSize: 34)),
                    ),
                  ),

                  // 3. PAPAN SKOR RETRO (Pojok Kanan Atas)
                  Positioned(
                    top: 14,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'HI ${_formatScore(highScore)}   ${_formatScore(score)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. INDIKATOR SENSOR & MOBIL (Pojok Kiri Atas)
                  Positioned(
                    top: 14,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: selectedVehicle.themeColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedVehicle.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          ValueListenableBuilder<String>(
                            valueListenable: _sensorTextNotifier,
                            builder: (context, text, _) {
                              return Text(
                                text,
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 5. GARIS TANAH HIJAU
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: groundLevel,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E342E), // Tanah cokelat
                        border: Border(
                          top: BorderSide(
                            color: Colors.green.shade800, // Rumput hijau
                            width: 6,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. KENDARAAN (JEEP / KOPDES / SPPG)
                  // FUNGSI MEMBALIK KE KANAN MENGGUNAKAN Transform.flip(flipX: faceRight)
                  Positioned(
                    left: jeepLeftPosition,
                    bottom: groundLevel - selectedVehicle.bottomOffset + jeepBottomOffset,
                    child: RepaintBoundary(
                      child: Transform.rotate(
                        angle: jumpTilt,
                        child: Transform.flip(
                          flipX: faceRight, // Membalik gambar dari kiri menjadi kanan
                          child: Image.asset(
                            selectedVehicle.assetPath,
                            width: selectedVehicle.width,
                            height: selectedVehicle.height,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            filterQuality: FilterQuality.low,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 7. RINTANGAN ASSET (BATU / PAPAN AWAS / POHON SAWIT)
                  Positioned(
                    left: obstacleX,
                    bottom: groundLevel - currentObstacle.bottomOffset,
                    child: RepaintBoundary(
                      child: Image.asset(
                        currentObstacle.assetPath,
                        width: currentObstacle.width,
                        height: currentObstacle.height,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),

                  // 8. OVERLAY MENU SAAT BELUM MAIN ATAU GAME OVER - Diisolasi dengan RepaintBoundary agar enteng
                  if (!isPlaying)
                    RepaintBoundary(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B1D22).withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isGameOver ? Colors.redAccent : Colors.orangeAccent,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Judul Status
                                Text(
                                  isGameOver ? 'G A M E   O V E R' : 'MERAPI JEEP RUN',
                                  style: TextStyle(
                                    color: isGameOver ? const Color(0xFFFF5252) : Colors.orangeAccent,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isGameOver
                                      ? 'Skor Akhir: $score'
                                      : 'Lompati rintangan batu, papan, dan sawit!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // PILIH MOBIL CEPAT
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black38,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'PILIH MOBIL:',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          // Tombol Ubah Arah Hadap Kanan / Kiri
                                          InkWell(
                                            onTap: _toggleDirection,
                                            borderRadius: BorderRadius.circular(6),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    faceRight ? Icons.arrow_forward : Icons.arrow_back,
                                                    color: Colors.orangeAccent,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    faceRight ? 'Arah Kanan' : 'Arah Kiri',
                                                    style: const TextStyle(
                                                      color: Colors.orangeAccent,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // 3 Pilihan Mobil Horizontal
                                      Row(
                                        children: vehicles.map((v) {
                                          final bool isCur = selectedVehicle.id == v.id;
                                          return Expanded(
                                            child: GestureDetector(
                                              onTap: () => _selectVehicle(v),
                                              child: Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                                padding: const EdgeInsets.symmetric(vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: isCur
                                                      ? v.themeColor.withValues(alpha: 0.3)
                                                      : Colors.white.withValues(alpha: 0.05),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: isCur ? Colors.orangeAccent : Colors.white12,
                                                    width: isCur ? 1.8 : 1.0,
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    SizedBox(
                                                      height: 38,
                                                      child: Transform.flip(
                                                        flipX: faceRight,
                                                        child: Image.asset(
                                                          v.assetPath,
                                                          fit: BoxFit.contain,
                                                          gaplessPlayback: true,
                                                          filterQuality: FilterQuality.low,
                                                          cacheHeight: 80,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      v.name.split(' ').first,
                                                      style: TextStyle(
                                                        color: isCur ? Colors.orangeAccent : Colors.white70,
                                                        fontSize: 11,
                                                        fontWeight: isCur ? FontWeight.bold : FontWeight.normal,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Tombol Mulai / Main Lagi
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orangeAccent,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 4,
                                    ),
                                    onPressed: _startGame,
                                    icon: Icon(
                                      isGameOver ? Icons.replay : Icons.play_arrow_rounded,
                                      size: 26,
                                    ),
                                    label: Text(
                                      isGameOver ? 'MAIN LAGI' : 'MULAI MAIN',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Sentuh layar di mana saja untuk LOMPAT',
                                  style: TextStyle(color: Colors.white54, fontSize: 11.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ==========================================
            // KETERANGAN & KONTROL DI BAGIAN BAWAH
            // ==========================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF1E2026),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mobil: ${selectedVehicle.name} • Latar: Gunung Merapi • Rintangan: Batu, Papan, Sawit',
                      style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orangeAccent,
                      side: const BorderSide(color: Colors.orangeAccent, width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Menu Mobil', style: TextStyle(fontSize: 11.5)),
                    onPressed: _showCarSelectionModal,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
