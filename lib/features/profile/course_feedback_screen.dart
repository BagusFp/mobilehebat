import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/database_helper.dart';
import '../auth/auth_provider.dart';

class CourseFeedbackScreen extends StatefulWidget {
  final bool isTab;
  const CourseFeedbackScreen({super.key, this.isTab = false});

  @override
  State<CourseFeedbackScreen> createState() => _CourseFeedbackScreenState();
}

class _CourseFeedbackScreenState extends State<CourseFeedbackScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nimController = TextEditingController();
  final TextEditingController _kesanController = TextEditingController();
  final TextEditingController _saranController = TextEditingController();

  // Snapshot controller untuk membatalkan perubahan saat mode edit dibatalkan
  String _backupName = '';
  String _backupNim = '';
  String _backupKesan = '';
  String _backupSaran = '';

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasSavedData = false;
  bool _isEditing = false;
  String? _savedAt;
  int? _savedDbId;

  @override
  void initState() {
    super.initState();
    _loadSavedFeedback();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nimController.dispose();
    _kesanController.dispose();
    _saranController.dispose();
    super.dispose();
  }

  /// Memuat evaluasi yang pernah disimpan dari SharedPreferences dan/atau SQLite
  Future<void> _loadSavedFeedback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSaved = prefs.getBool('pam_eval_saved') ?? false;

      if (hasSaved) {
        final name = prefs.getString('pam_eval_name') ?? '';
        final nim = prefs.getString('pam_eval_nim') ?? '';
        final kesan = prefs.getString('pam_eval_kesan') ?? '';
        final saran = prefs.getString('pam_eval_saran') ?? '';
        final time = prefs.getString('pam_eval_time');
        final dbId = prefs.getInt('pam_eval_db_id');

        _nameController.text = name;
        _nimController.text = nim;
        _kesanController.text = kesan;
        _saranController.text = saran;

        _backupName = name;
        _backupNim = nim;
        _backupKesan = kesan;
        _backupSaran = saran;

        _savedAt = time;
        _savedDbId = dbId;

        if (mounted) {
          setState(() {
            _hasSavedData = true;
            _isEditing = false;
            _isLoading = false;
          });
        }
        return;
      }

      // Fallback: periksa tabel course_feedback di SQLite
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'course_feedback',
        orderBy: 'id DESC',
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final row = rows.first;
        final rawStudentName = row['student_name'] as String? ?? '';
        final rawMessage = row['message'] as String? ?? '';
        final submittedAt = row['submitted_at'] as String? ?? '';
        final dbId = row['id'] as int?;

        String name = rawStudentName;
        String nim = '';
        if (rawStudentName.contains('(') && rawStudentName.endsWith(')')) {
          final parts = rawStudentName.split('(');
          name = parts[0].trim();
          nim = parts[1].replaceAll(')', '').trim();
        }

        String kesan = '';
        String saran = '';
        if (rawMessage.contains('Kesan:') && rawMessage.contains('Saran:')) {
          final parts = rawMessage.split('Saran:');
          kesan = parts[0].replaceAll('Kesan:', '').trim();
          saran = parts.length > 1 ? parts[1].trim() : '';
        } else {
          kesan = rawMessage;
        }

        _nameController.text = name;
        _nimController.text = nim;
        _kesanController.text = kesan;
        _saranController.text = saran;

        _backupName = name;
        _backupNim = nim;
        _backupKesan = kesan;
        _backupSaran = saran;

        _savedAt = submittedAt;
        _savedDbId = dbId;

        // Sinkronisasi ke SharedPreferences untuk akses instan & aman saat logout
        await prefs.setBool('pam_eval_saved', true);
        await prefs.setString('pam_eval_name', name);
        await prefs.setString('pam_eval_nim', nim);
        await prefs.setString('pam_eval_kesan', kesan);
        await prefs.setString('pam_eval_saran', saran);
        await prefs.setString('pam_eval_time', submittedAt);
        if (dbId != null) {
          await prefs.setInt('pam_eval_db_id', dbId);
        }

        if (mounted) {
          setState(() {
            _hasSavedData = true;
            _isEditing = false;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error loading saved feedback: $e');
    }

    // Default jika belum pernah mengisi: gunakan nama pengguna jika login
    if (mounted) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.name.isNotEmpty == true && _nameController.text.isEmpty) {
        _nameController.text = auth.currentUser!.name;
      }

      setState(() {
        _hasSavedData = false;
        _isEditing = true;
        _isLoading = false;
      });
    }
  }

  /// Menyimpan atau memperbarui data evaluasi ke SQLite & SharedPreferences
  Future<void> _submitFeedback() async {
    final name = _nameController.text.trim();
    final nim = _nimController.text.trim();
    final kesan = _kesanController.text.trim();
    final saran = _saranController.text.trim();

    if (name.isEmpty || nim.isEmpty || kesan.isEmpty || saran.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi seluruh isian: Nama, NIM, Kesan, dan Saran.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final nowIso = DateTime.now().toIso8601String();
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 0;
    final studentNameFull = '$name ($nim)';
    final messageFull = 'Kesan:\n$kesan\n\nSaran:\n$saran';

    // 1. Simpan ke SQLite
    try {
      final db = await DatabaseHelper.instance.database;
      if (_savedDbId != null) {
        await db.update(
          'course_feedback',
          {
            'user_id': userId,
            'student_name': studentNameFull,
            'rating': 5,
            'message': messageFull,
            'submitted_at': nowIso,
          },
          where: 'id = ?',
          whereArgs: [_savedDbId],
        );
      } else {
        _savedDbId = await db.insert('course_feedback', {
          'user_id': userId,
          'student_name': studentNameFull,
          'rating': 5,
          'message': messageFull,
          'submitted_at': nowIso,
        });
      }
    } catch (e) {
      debugPrint('Error writing to SQLite: $e');
    }

    // 2. Simpan ke SharedPreferences (Bertahan meskipun logout / ganti akun)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pam_eval_saved', true);
      await prefs.setString('pam_eval_name', name);
      await prefs.setString('pam_eval_nim', nim);
      await prefs.setString('pam_eval_kesan', kesan);
      await prefs.setString('pam_eval_saran', saran);
      await prefs.setString('pam_eval_time', nowIso);
      if (_savedDbId != null) {
        await prefs.setInt('pam_eval_db_id', _savedDbId!);
      }
    } catch (e) {
      debugPrint('Error writing to SharedPreferences: $e');
    }

    if (!mounted) return;

    // Perbarui state lokal & backup
    _backupName = name;
    _backupNim = nim;
    _backupKesan = kesan;
    _backupSaran = saran;

    setState(() {
      _isSubmitting = false;
      _hasSavedData = true;
      _isEditing = false;
      _savedAt = nowIso;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.primary, size: 28),
            SizedBox(width: 8),
            Expanded(child: Text('Evaluasi Tersimpan!')),
          ],
        ),
        content: Text(
          'Terima kasih telah mengisi evaluasi mata kuliah Pemrograman Aplikasi Mobile ^^',
          style: AppTypography.bodyMd,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              if (!widget.isTab) {
                Navigator.of(context).maybePop();
              }
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

  void _startEditing() {
    _backupName = _nameController.text;
    _backupNim = _nimController.text;
    _backupKesan = _kesanController.text;
    _backupSaran = _saranController.text;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _nameController.text = _backupName;
    _nimController.text = _backupNim;
    _kesanController.text = _backupKesan;
    _saranController.text = _backupSaran;
    setState(() => _isEditing = false);
  }

  String _formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day $month $year, $hour:$minute WIB';
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: widget.isTab
          ? null
          : AppBar(
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.margin),
              children: [
                // 1. Header Card
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
                              'Kesan & Saran Mata Kuliah',
                              style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Pemrograman Aplikasi Mobile (PAM)',
                              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Konten Tampilan: Tampilan Tersimpan vs Mode Edit/Input
                if (_hasSavedData && !_isEditing)
                  _buildSavedView()
                else
                  _buildFormView(),
              ],
            ),
    );
  }

  /// Tampilan saat data evaluasi telah disimpan (dengan tombol Edit Inputan)
  Widget _buildSavedView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge Tersimpan
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFD1FAE5),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: Color(0xFF047857), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evaluasi Anda Telah Tersimpan',
                      style: TextStyle(
                        color: Color(0xFF065F46),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (_savedAt != null)
                      Text(
                        'Terakhir diperbarui: ${_formatDate(_savedAt)}',
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kartu Identitas Mahasiswa
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_pin, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Identitas Mahasiswa',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),
              _buildSavedInfoRow(label: 'Nama Mahasiswa', value: _nameController.text),
              const SizedBox(height: 10),
              _buildSavedInfoRow(label: 'NIM', value: _nimController.text),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Kartu Catatan Evaluasi (Kesan & Saran)
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Catatan Evaluasi',
                    style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Kesan
              Text(
                'Kesan Perkuliahan:',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Text(
                  _kesanController.text.isNotEmpty ? _kesanController.text : '-',
                  style: AppTypography.bodyMedium,
                ),
              ),
              const SizedBox(height: 14),

              // Saran
              Text(
                'Saran Perkuliahan:',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Text(
                  _saranController.text.isNotEmpty ? _saranController.text : '-',
                  style: AppTypography.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Tombol Edit Inputan Evaluasi
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _startEditing,
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text(
              'Edit Evaluasi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
    );
  }

  Widget _buildSavedInfoRow({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : '-',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  /// Tampilan Form Input / Edit Evaluasi
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasSavedData)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: const [
                Icon(Icons.edit_note, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mode Edit: Anda dapat memperbarui data nama, NIM, kesan, dan saran di bawah ini.',
                    style: TextStyle(
                      color: Color(0xFF92400E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Input Identitas Mahasiswa (Nama & NIM)
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nama Mahasiswa / Evaluator',
                style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
              ),
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
              Text(
                'NIM',
                style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nimController,
                decoration: InputDecoration(
                  hintText: 'Contoh: 124240xxx',
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

        // Input Catatan Evaluasi (Kesan & Saran)
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Catatan Evaluasi',
                style: AppTypography.labelMd.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),

              // Tempat Input Kesan
              Text(
                'Kesan Perkuliahan',
                style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _kesanController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tuliskan kesan Anda selama mengikuti perkuliahan PAM...',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Tempat Input Saran
              Text(
                'Saran Perkuliahan',
                style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _saranController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Tuliskan saran dan masukan untuk perkuliahan PAM...',
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

        // Tombol Aksi (Simpan / Simpan Perubahan & Batal)
        if (_hasSavedData)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isSubmitting ? null : _cancelEditing,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _isSubmitting ? 'Menyimpan...' : 'Simpan Perubahan',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
              ),
            ],
          )
        else
          SizedBox(
            width: double.infinity,
            height: 48,
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
                _isSubmitting ? 'Menyimpan...' : 'Simpan',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
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
    );
  }
}
