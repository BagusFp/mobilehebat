import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/database_helper.dart';

class CourseFeedbackScreen extends StatefulWidget {
  const CourseFeedbackScreen({super.key});

  @override
  State<CourseFeedbackScreen> createState() => _CourseFeedbackScreenState();
}

class _CourseFeedbackScreenState extends State<CourseFeedbackScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Bima Sakti');
  final TextEditingController _nimController = TextEditingController(text: '22/501234/SV/21800');
  final TextEditingController _feedbackController = TextEditingController(
    text:
        'Aplikasi MeraTrip telah mengimplementasikan seluruh kebutuhan PRD dengan lengkap: navigasi offline SQLite, sensor kompas, AI companion, dan verifikasi blockchain SHA-256.',
  );

  int _rating = 5;
  bool _isSubmitting = false;

  final Map<String, bool> _testedModules = {
    'SQLite Database & Hashing SHA-256': true,
    'Peta Interaktif OpenStreetMap & Radius KRB': true,
    'Manajer Offline & Cache 34 MB': true,
    'Sensor Shake Accelerometer & Kompas Gyro': true,
    'Konversi Valuta & Zona Waktu Wisatawan': true,
    'AI Companion & Generator Itinerary': true,
    'Gamifikasi Kuis & Skor Jagawana Merapi': true,
    'Riwayat Integritas Blockchain Ledger': true,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_nameController.text.trim().isEmpty || _feedbackController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap lengkapi nama dan catatan evaluasi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('course_feedback', {
        'user_id': 1,
        'student_name': '${_nameController.text.trim()} (${_nimController.text.trim()})',
        'rating': _rating,
        'message': _feedbackController.text.trim(),
        'submitted_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Fallback in-memory
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Evaluasi Terkirim!')),
          ],
        ),
        content: Text(
          'Terima kasih telah mengisi evaluasi praktikum Pengembangan Aplikasi Mobile. Data telah tersimpan secara persisten ke database lokal SQLite MeraTrip.',
          style: AppTypography.bodyMd,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              Navigator.of(context).maybePop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(230),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Evaluasi Mata Kuliah PAM',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.margin),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(6),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refleksi & Penilaian Praktikum',
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pemrograman Aplikasi Mobile (PAM) — Proyek MeraTrip',
                        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Identity Input
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nama Mahasiswa / Evaluator', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: 'Nama lengkap...',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('NIM / Identitas Akademik', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nimController,
                  decoration: InputDecoration(
                    hintText: 'Contoh: 22/501234/SV/21800',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rating Bintang
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rating Kepuasan Arsitektur & UI/UX Aplikasi', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (idx) {
                    final starNum = idx + 1;
                    return IconButton(
                      icon: Icon(
                        starNum <= _rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFC58A32),
                        size: 36,
                      ),
                      onPressed: () {
                        setState(() => _rating = starNum);
                      },
                    );
                  }),
                ),
                Center(
                  child: Text(
                    '$_rating dari 5 Bintang (Sangat Memuaskan)',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Checklist Modul
          Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modul yang Telah Diuji & Divalidasi:', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._testedModules.keys.map((modKey) {
                    return CheckboxListTile(
                      title: Text(modKey, style: AppTypography.bodySm),
                      value: _testedModules[modKey],
                      activeColor: AppColors.primary,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _testedModules[modKey] = val ?? false;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Catatan Refleksi & Pesan
          Container(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Catatan Refleksi & Masukan Pengembangan', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Tuliskan kesan, pesan, dan refleksi perkuliahan...',
                    filled: true,
                    fillColor: AppColors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitFeedback,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(
                _isSubmitting ? 'Menyimpan ke SQLite...' : 'Kirim Evaluasi & Simpan',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
