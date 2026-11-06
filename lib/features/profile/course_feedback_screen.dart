import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/database/database_helper.dart';
import '../auth/auth_provider.dart';

/// Model internal untuk item masukan evaluasi mata kuliah
class _FeedbackItem {
  final int id;
  final int userId;
  final String name;
  final String nim;
  final String kesan;
  final String saran;
  final int rating;
  final String submittedAt;

  const _FeedbackItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.nim,
    required this.kesan,
    required this.saran,
    required this.rating,
    required this.submittedAt,
  });
}

class CourseFeedbackScreen extends StatefulWidget {
  final bool isTab;
  const CourseFeedbackScreen({super.key, this.isTab = false});

  @override
  State<CourseFeedbackScreen> createState() => _CourseFeedbackScreenState();
}

class _CourseFeedbackScreenState extends State<CourseFeedbackScreen> {
  List<_FeedbackItem> _feedbackList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllFeedbacks();
  }

  /// Memuat semua daftar evaluasi dari tabel SQLite `course_feedback`
  Future<void> _loadAllFeedbacks() async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Migrasi data SharedPreferences lama jika database SQLite masih kosong
      final countResult = await db.rawQuery('SELECT COUNT(*) as cnt FROM course_feedback');
      final currentCount = (countResult.first['cnt'] as int?) ?? 0;

      if (currentCount == 0) {
        await _migrateLegacyPreferences(db);
      }

      final rows = await db.query(
        'course_feedback',
        orderBy: 'id DESC',
      );

      final List<_FeedbackItem> items = [];
      for (final row in rows) {
        final id = row['id'] as int? ?? 0;
        final userId = row['user_id'] as int? ?? 0;
        final rawStudentName = row['student_name'] as String? ?? '';
        final rawMessage = row['message'] as String? ?? '';
        final rating = row['rating'] as int? ?? 5;
        final submittedAt = row['submitted_at'] as String? ?? '';

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

        items.add(_FeedbackItem(
          id: id,
          userId: userId,
          name: name,
          nim: nim,
          kesan: kesan,
          saran: saran,
          rating: rating,
          submittedAt: submittedAt,
        ));
      }

      if (mounted) {
        setState(() {
          _feedbackList = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading course feedbacks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Migrasi data evaluasi lama yang tersimpan di SharedPreferences ke SQLite agar tidak hilang
  Future<void> _migrateLegacyPreferences(dynamic db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nowIso = DateTime.now().toIso8601String();

      // Cek mahasiswa 1
      final name1 = prefs.getString('pam_eval_name_1') ?? prefs.getString('pam_eval_name') ?? '';
      final nim1 = prefs.getString('pam_eval_nim_1') ?? prefs.getString('pam_eval_nim') ?? '';
      final kesan1 = prefs.getString('pam_eval_kesan_1') ?? prefs.getString('pam_eval_kesan') ?? '';
      final saran1 = prefs.getString('pam_eval_saran_1') ?? prefs.getString('pam_eval_saran') ?? '';
      final time1 = prefs.getString('pam_eval_time_1') ?? prefs.getString('pam_eval_time') ?? nowIso;

      if (name1.isNotEmpty && kesan1.isNotEmpty) {
        await db.insert('course_feedback', {
          'user_id': 1,
          'student_name': nim1.isNotEmpty ? '$name1 ($nim1)' : name1,
          'rating': 5,
          'message': 'Kesan:\n$kesan1\n\nSaran:\n$saran1',
          'submitted_at': time1,
        });
      }

      // Cek mahasiswa 2
      final name2 = prefs.getString('pam_eval_name_2') ?? '';
      final nim2 = prefs.getString('pam_eval_nim_2') ?? '';
      final kesan2 = prefs.getString('pam_eval_kesan_2') ?? '';
      final saran2 = prefs.getString('pam_eval_saran_2') ?? '';
      final time2 = prefs.getString('pam_eval_time_2') ?? nowIso;

      if (name2.isNotEmpty && kesan2.isNotEmpty) {
        await db.insert('course_feedback', {
          'user_id': 1,
          'student_name': nim2.isNotEmpty ? '$name2 ($nim2)' : name2,
          'rating': 5,
          'message': 'Kesan:\n$kesan2\n\nSaran:\n$saran2',
          'submitted_at': time2,
        });
      }
    } catch (_) {}
  }

  /// Menampilkan form modal (Tambah atau Edit Kesan Pesan)
  void _showFeedbackFormModal({_FeedbackItem? existingItem}) {
    final isEdit = existingItem != null;

    final nameController = TextEditingController(text: isEdit ? existingItem.name : '');
    final nimController = TextEditingController(text: isEdit ? existingItem.nim : '');
    final kesanController = TextEditingController(text: isEdit ? existingItem.kesan : '');
    final saranController = TextEditingController(text: isEdit ? existingItem.saran : '');

    // Jika form tambah baru dan pengguna sedang login, isi default nama
    if (!isEdit && nameController.text.isEmpty) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser?.name.isNotEmpty == true) {
        nameController.text = auth.currentUser!.name;
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        bool isSubmitting = false;
        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(bottomCtx);

        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: AppDimensions.margin,
                right: AppDimensions.margin,
                top: 20,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Header Modal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Kesan & Pesan' : 'Tambah Kesan & Pesan',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.onSurfaceVariant),
                          onPressed: () => Navigator.pop(bottomCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 18),

                    // Input Nama
                    Text(
                      'Nama Mahasiswa',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Nama lengkap mahasiswa...',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.person_outline, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input NIM
                    Text(
                      'NIM (Nomor Induk Mahasiswa)',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nimController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Contoh: 124240xxx',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Input Kesan
                    Text(
                      'Kesan Perkuliahan',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: kesanController,
                      maxLines: 3,
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

                    // Input Saran
                    Text(
                      'Saran Perkuliahan',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: saranController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Tuliskan saran dan masukan untuk materi / dosen perkuliahan...',
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Tombol Submit
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                final nim = nimController.text.trim();
                                final kesan = kesanController.text.trim();
                                final saran = saranController.text.trim();

                                if (name.isEmpty || nim.isEmpty || kesan.isEmpty || saran.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Harap lengkapi semua isian: Nama, NIM, Kesan, dan Saran.'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);

                                final nowIso = DateTime.now().toIso8601String();
                                final studentNameFull = '$name ($nim)';
                                final messageFull = 'Kesan:\n$kesan\n\nSaran:\n$saran';
                                final auth = context.read<AuthProvider>();
                                final userId = auth.currentUser?.id ?? 1;

                                try {
                                  final db = await DatabaseHelper.instance.database;
                                  if (isEdit) {
                                    await db.update(
                                      'course_feedback',
                                      {
                                        'student_name': studentNameFull,
                                        'message': messageFull,
                                        'submitted_at': nowIso,
                                      },
                                      where: 'id = ?',
                                      whereArgs: [existingItem.id],
                                    );
                                  } else {
                                    await db.insert('course_feedback', {
                                      'user_id': userId,
                                      'student_name': studentNameFull,
                                      'rating': 5,
                                      'message': messageFull,
                                      'submitted_at': nowIso,
                                    });
                                  }

                                  navigator.pop();
                                  await _loadAllFeedbacks();
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEdit
                                              ? 'Evaluasi atas nama $name berhasil diperbarui!'
                                              : 'Kesan & pesan $name berhasil ditambahkan!',
                                        ),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal menyimpan evaluasi: $e'),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Icon(isEdit ? Icons.check_circle_outline : Icons.send_rounded),
                        label: Text(
                          isSubmitting
                              ? 'Menyimpan...'
                              : (isEdit ? 'Simpan Perubahan' : 'Kirim Kesan & Pesan'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
              ),
            );
          },
        );
      },
    );
  }

  /// Dialog konfirmasi penghapusan data masukan
  void _confirmDeleteFeedback(_FeedbackItem item) {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
        title: Row(
          children: const [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Hapus Evaluasi?'),
          ],
        ),
        content: Text(
          'Kesan & pesan dari "${item.name}" akan dihapus secara permanen dari database lokal aplikasi.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                final db = await DatabaseHelper.instance.database;
                await db.delete(
                  'course_feedback',
                  where: 'id = ?',
                  whereArgs: [item.id],
                );
                await _loadAllFeedbacks();
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Kesan & pesan "${item.name}" berhasil dihapus.'),
                      backgroundColor: AppColors.onSurface,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus data: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
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

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
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
          : RefreshIndicator(
              onRefresh: _loadAllFeedbacks,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.margin),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),

                  if (_feedbackList.isEmpty)
                    _buildEmptyStateCard()
                  else
                    ..._feedbackList.map((item) => _buildFeedbackCard(item)),

                  const SizedBox(height: 72),
                ],
              ),
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showFeedbackFormModal(),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Isi Kesan Pesan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.school, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kesan & Saran',
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pemrograman Aplikasi Mobile (PAM)',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_feedbackList.length} Masukan',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.rate_review_outlined, color: Color(0xFFB45309), size: 32),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum Ada Kesan & Pesan',
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tekan tombol di pojok kanan bawah untuk menambahkan kesan dan saran perkuliahan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(_FeedbackItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceContainer.withAlpha(150)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Baris Atas: Avatar + Nama + NIM + Tombol Aksi (Edit & Hapus)
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  child: Text(
                    _getInitials(item.name),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (item.nim.isNotEmpty) ...[
                            Text(
                              item.nim,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const Text(' • ', style: TextStyle(color: AppColors.outline, fontSize: 11)),
                          ],
                          Flexible(
                            child: Text(
                              _formatDate(item.submittedAt),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.outline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tombol Edit
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showFeedbackFormModal(existingItem: item),
                ),

                // Tombol Hapus
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDeleteFeedback(item),
                ),
              ],
            ),
            const Divider(height: 16),

            // Konten Kesan
            RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                children: [
                  const TextSpan(
                    text: 'Kesan: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  TextSpan(text: item.kesan.isNotEmpty ? item.kesan : '-'),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Konten Saran
            RichText(
              text: TextSpan(
                style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
                children: [
                  const TextSpan(
                    text: 'Saran: ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  TextSpan(text: item.saran.isNotEmpty ? item.saran : '-'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
