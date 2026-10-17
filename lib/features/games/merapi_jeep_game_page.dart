import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class MerapiJeepGamePage extends StatefulWidget {
  const MerapiJeepGamePage({super.key});

  @override
  State<MerapiJeepGamePage> createState() => _MerapiJeepGamePageState();
}

class _MerapiJeepGamePageState extends State<MerapiJeepGamePage> {
  // URL Foto Gunung Merapi (Otomatis di-cache oleh Flutter)
  static const String merapiImageUrl =
      'https://images.unsplash.com/photo-1588668214407-6ea9a6d8c272?auto=format&fit=crop&w=1000&q=80';

  // Status Permainan
  bool isPlaying = false;
  bool isGameOver = false;
  int score = 0;
  int highScore = 0;
  int frameCount = 0;

  // Fisika Lompatan (Persis Chrome Dino menggunakan Piksel)
  final double jeepLeftPosition = 45.0; // Posisi X dikunci (tidak maju-mundur)
  double jeepBottomOffset = 0.0; // 0 = menapak tanah
  double velocityY = 0.0;
  final double jumpPower = 13.0; // Kekuatan lompat tinggi & ringan
  final double gravity = 0.58; // Gravitasi nyaman seperti Dino Chrome
  bool isJumping = false;

  // Rintangan (1 antrean agar tidak pernah menumpuk mustahil)
  double obstacleX = 450.0;
  double gameSpeed = 4.5; // Kecepatan awal santai
  String currentObstacleEmoji = '🪨';
  final List<String> obstacleTypes = ['🪨', '🌵', '🪵'];

  // Awan hiasan di langit
  double cloudDecorationX = 300.0;

  // Sensor (Untuk memenuhi syarat wajib dosen tanpa mengganggu kontrol mobil)
  bool enableSensorJump = true;
  double accValue = 0.0;
  double gyroParallaxOffset = 0.0; // Hanya menggeser halus gambar background

  Timer? gameTimer;
  StreamSubscription<AccelerometerEvent>? _accSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  @override
  void initState() {
    super.initState();
    _initSensors();
  }

  void _initSensors() {
    // Sensor 1: Accelerometer (Bisa lompat dengan sentak HP sedikit)
    _accSub = accelerometerEventStream().listen((event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (mounted) {
        setState(() => accValue = magnitude);
      }
      if (enableSensorJump && isPlaying && !isJumping && magnitude > 15.0) {
        _jump();
      }
    });

    // Sensor 2: Gyroscope (Efek Parallax halus pada foto Gunung Merapi)
    _gyroSub = gyroscopeEventStream().listen((event) {
      if (mounted) {
        setState(() {
          gyroParallaxOffset = (gyroParallaxOffset + event.y * 2.5).clamp(
            -25.0,
            25.0,
          );
        });
      }
    });
  }

  void _startGame() {
    setState(() {
      isPlaying = true;
      isGameOver = false;
      score = 0;
      frameCount = 0;
      jeepBottomOffset = 0.0;
      velocityY = 0.0;
      isJumping = false;
      obstacleX = 420.0; // Muncul dari luar kanan layar
      gameSpeed = 4.5; // Mulai dengan kecepatan santai
      currentObstacleEmoji = '🪨';
    });

    gameTimer?.cancel();
    // Loop 60 FPS (setiap 16 milidetik)
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
    }
  }

  void _updateGame() {
    setState(() {
      frameCount++;

      // 1. Skor berjalan otomatis seperti Dino Chrome
      if (frameCount % 6 == 0) {
        score++;
        // Kecepatan bertambah sangat halus seiring skor naik
        if (gameSpeed < 8.5) {
          gameSpeed += 0.003;
        }
      }

      // 2. Fisika Lompat (Atas - Bawah)
      if (isJumping) {
        jeepBottomOffset += velocityY;
        velocityY -= gravity;

        // Kembali menapak tanah
        if (jeepBottomOffset <= 0.0) {
          jeepBottomOffset = 0.0;
          velocityY = 0.0;
          isJumping = false;
        }
      }

      // 3. Gerakkan Rintangan dari Kanan ke Kiri
      obstacleX -= gameSpeed;
      cloudDecorationX -= 1.2;

      if (cloudDecorationX < -60) {
        cloudDecorationX = 400.0;
      }

      // Jika rintangan sudah lewat di kiri, munculkan lagi di kanan dengan jarak aman
      if (obstacleX < -50) {
        obstacleX = 380.0 + Random().nextInt(180); // Jarak jeda lega
        currentObstacleEmoji =
            obstacleTypes[Random().nextInt(obstacleTypes.length)];
      }

      // 4. Deteksi Tabrakan yang Toleran (Tidak gampang mati)
      // Jeep berada di X: 45 s/d 85. Kita persempit area tabrak ke X: 52 s/d 75
      final bool isHorizontalHit = obstacleX < 75.0 && obstacleX + 24.0 > 52.0;
      // Hanya tertabrak jika posisi Jeep masih rendah (< 26 piksel dari tanah)
      final bool isVerticalHit = jeepBottomOffset < 26.0;

      if (isHorizontalHit && isVerticalHit) {
        _triggerGameOver();
      }
    });
  }

  void _triggerGameOver() {
    gameTimer?.cancel();
    isPlaying = false;
    isGameOver = true;
    if (score > highScore) {
      highScore = score;
    }
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    _accSub?.cancel();
    _gyroSub?.cancel();
    super.dispose();
  }

  String _formatDinoScore(int val) {
    return val.toString().padLeft(5, '0');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merapi Jeep Run'),
        backgroundColor: const Color(0xFF3E2723),
        foregroundColor: Colors.white,
        actions: [
          Row(
            children: [
              const Text('Lompat Sensor', style: TextStyle(fontSize: 12)),
              Switch(
                value: enableSensorJump,
                activeThumbColor: Colors.orangeAccent,
                onChanged: (v) => setState(() => enableSensorJump = v),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          // Respons instan begitu jari menyentuh layar
          if (!isPlaying) {
            _startGame();
          } else {
            _jump();
          }
        },
        child: Column(
          children: [
            // AREA GAME UTAMA
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. BACKGROUND FOTO GUNUNG MERAPI DARI INTERNET
                  Transform.translate(
                    offset: Offset(gyroParallaxOffset, 0),
                    child: Transform.scale(
                      scale:
                          1.12, // Diperbesar sedikit agar saat parallax tidak bocor
                      child: Image.network(
                        merapiImageUrl,
                        fit: BoxFit.cover,
                        // Fallback jika internet dimatikan dan gambar belum ke-cache
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF90CAF9), Color(0xFFFFF3E0)],
                              ),
                            ),
                            child: const Center(
                              child: Opacity(
                                opacity: 0.25,
                                child: Text(
                                  '⛰️',
                                  style: TextStyle(fontSize: 180),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Lapisan putih tipis agar mobil & batu terlihat kontras jelas
                  Container(color: Colors.white.withValues(alpha: 0.28)),

                  // 2. AWAN HIASAN DI LANGIT
                  Positioned(
                    top: 60,
                    left: cloudDecorationX,
                    child: const Text('☁️', style: TextStyle(fontSize: 36)),
                  ),

                  // 3. PAPAN SKOR ALA DINO CHROME (Pojok Kanan Atas)
                  Positioned(
                    top: 16,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'HI ${_formatDinoScore(highScore)}   ${_formatDinoScore(score)}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),

                  // 4. INDIKATOR SENSOR KECIL (Pojok Kiri Atas untuk bukti ke Dosen)
                  Positioned(
                    top: 18,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Acc: ${accValue.toStringAsFixed(1)} | Gyro: ${gyroParallaxOffset.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                  // 5. GARIS TANAH JALUR JEEP
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF4E342E),
                        border: Border(
                          top: BorderSide(
                            color: Colors.green.shade800,
                            width: 6,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 6. MOBIL JEEP (SUDAH DIBALIK MENGHADAP KE KANAN)
                  Positioned(
                    left: jeepLeftPosition,
                    bottom: 42 + jeepBottomOffset,
                    child: Transform.flip(
                      flipX:
                          true, // Membalik emoji mobil agar menghadap kanan ->
                      child: const Text('🚙', style: TextStyle(fontSize: 44)),
                    ),
                  ),

                  // 7. RINTANGAN (BATU / POHON)
                  Positioned(
                    left: obstacleX,
                    bottom: 44,
                    child: Text(
                      currentObstacleEmoji,
                      style: const TextStyle(fontSize: 34),
                    ),
                  ),

                  // 8. LAYAR MULAI / GAME OVER (Tengah Layar)
                  if (!isPlaying)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isGameOver
                                  ? 'G A M E   O V E R'
                                  : 'MERAPI JEEP RUN',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Ketuk layar di mana saja untuk LOMPAT',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            IconButton.filled(
                              onPressed: _startGame,
                              iconSize: 32,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.orangeAccent,
                                foregroundColor: Colors.black,
                              ),
                              icon: Icon(
                                isGameOver ? Icons.refresh : Icons.play_arrow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // KETERANGAN SINGKAT DI BAWAH
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF3E2723),
              child: const Text(
                'Ketuk layar untuk melompati rintangan seperti Dino Chrome.\n'
                'Sensor Accelerometer (sentak HP) & Gyroscope (efek kamera latar Merapi) aktif otomatis.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
