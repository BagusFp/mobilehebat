import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:project/features/auth/auth_provider.dart';
import 'package:project/features/explore/destination_provider.dart';
import 'package:project/features/home/home_screen.dart';
import 'package:project/features/nature_scanner/models/detected_nature_object.dart';
import 'package:project/features/nature_scanner/presentation/scanner_result_screen.dart';
import 'package:project/features/nature_scanner/presentation/widgets/nature_bounding_box_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<DestinationProvider>(create: (_) => DestinationProvider()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('AI Nature Scanner Widget Tests', () {
    testWidgets('1. HomeScreen renders both AI Nature Scanner and AI Assistant side-by-side without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(380, 800));

      await tester.pumpWidget(createTestWidget(const HomeScreen()));
      await tester.pump();

      // Verifikasi kedua kartu AI tersedia berdampingan di Home
      expect(find.text('AI Nature Scanner'), findsOneWidget);
      expect(find.text('Pindai Objek Alam'), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('Tanya Jagawana AI'), findsOneWidget);

      // Verifikasi utilitas navigasi sebelumnya tetap utuh
      expect(find.text('Peta Merapi'), findsOneWidget);
      expect(find.text('Kompas'), findsOneWidget);

      // Verifikasi ikon
      expect(find.byIcon(Icons.document_scanner_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    testWidgets('2. ScannerResultScreen renders detected objects, confidence score, and safety disclaimer', (tester) async {
      const mockObj = DetectedNatureObject(
        id: 'mtn_1',
        category: NatureCategory.mountain,
        label: 'Gunung',
        englishLabel: 'Mountain',
        educationalDetail: 'Morfologi lereng vulkanik dan kontur puncak.',
        confidence: 0.89,
        boundingBox: Rect.fromLTWH(0.1, 0.2, 0.8, 0.4),
      );

      final result = NatureScanResult(
        objects: const [mockObj],
        scanTime: DateTime.now(),
        inferenceTimeMs: 48,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScannerResultScreen(result: result),
        ),
      );
      await tester.pump();

      // Cek judul dan konten
      expect(find.text('Hasil Analisis Objek Alam'), findsOneWidget);
      expect(find.text('Gunung'), findsOneWidget);
      expect(find.text('89.0%'), findsOneWidget);
      expect(find.text('Morfologi lereng vulkanik dan kontur puncak.'), findsOneWidget);

      // Cek banner keselamatan & privasi
      expect(find.textContaining('BUKAN penentu kelayakan jalur pendakian'), findsOneWidget);

      // Cek tombol aksi
      expect(find.text('Scan Objek Lain'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
    });

    testWidgets('3. ScannerResultScreen displays empty state message when no objects detected', (tester) async {
      final emptyResult = NatureScanResult(
        objects: const [],
        scanTime: DateTime.now(),
        inferenceTimeMs: 35,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ScannerResultScreen(result: emptyResult),
        ),
      );
      await tester.pump();

      expect(find.text('Tidak Ada Objek Terdeteksi'), findsOneWidget);
      expect(
        find.textContaining('Belum ada objek yang dapat dikenali. Coba arahkan kamera ke objek lain'),
        findsOneWidget,
      );
    });

    testWidgets('4. NatureBoundingBoxPainter paints bounding box without throwing', (tester) async {
      const mockDetections = [
        DetectedNatureObject(
          id: '1',
          category: NatureCategory.vegetation,
          label: 'Pohon / Vegetasi',
          englishLabel: 'Tree / Vegetation',
          educationalDetail: 'Vegetasi hutan alami.',
          confidence: 0.78,
          boundingBox: Rect.fromLTWH(0.1, 0.2, 0.5, 0.4),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              size: const Size(400, 600),
              painter: NatureBoundingBoxPainter(detections: mockDetections),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}
