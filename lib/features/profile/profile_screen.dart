import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/utils/image_compress_helper.dart';
import '../../data/models/user_model.dart';
import '../auth/auth_provider.dart';
import '../blockchain/blockchain_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;

  const ProfileScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Bima Sakti';
    final displayEmail = user?.email.isNotEmpty == true ? user!.email : 'bima.sakti@wisatawan.id';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.margin,
        AppDimensions.spaceSm,
        AppDimensions.margin,
        32,
      ),
      children: [
        // 1. Kartu Profil Wisatawan Ringkas & Rapi
        Container(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Foto / Avatar Pengguna
              Stack(
                children: [
                  _buildUserAvatar(user, radius: 34),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        size: 14,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),

              // Identitas Nama & Email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayEmail,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Edit Profil dengan Ikon Pensil
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerLow,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.all(10),
                ),
                tooltip: 'Edit Profil',
                onPressed: () => _showEditProfileDialog(context, auth),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppDimensions.spaceLg),

        // 2. Bagian Navigasi & Pengaturan (Ringkas - Hanya 3 Menu)
        Text(
          'Navigasi & Pengaturan',
          style: AppTypography.titleMd.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: AppDimensions.spaceSm),

        // Menu 1: Catatan Bukti Blockchain
        _buildMenuItem(
          context,
          icon: Icons.shield_outlined,
          title: 'Catatan Bukti Blockchain',
          subtitle: 'Bukti perjalanan digital terdesentralisasi (Sepolia Testnet)',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockchainScreen()),
            );
          },
        ),

        // Menu 2: Kunci Biometrik Aplikasi
        _buildBiometricSettingTile(context, auth),

        const SizedBox(height: AppDimensions.spaceXl),

      ],
    );
  }

  /// Avatar Widget yang mendukung URL Supabase, File Lokal, dan Inisial Nama
  Widget _buildUserAvatar(UserModel? user, {required double radius}) {
    final photo = user?.profilePhoto;
    final name = user?.name.isNotEmpty == true ? user!.name : 'User';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    if (photo != null && photo.isNotEmpty) {
      if (photo.startsWith('http')) {
        return CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.secondaryContainer,
          backgroundImage: NetworkImage(photo),
          onBackgroundImageError: (exception, stackTrace) {},
        );
      } else {
        final localFile = File(photo);
        if (localFile.existsSync()) {
          return CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.secondaryContainer,
            backgroundImage: FileImage(localFile),
          );
        }
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.secondaryContainer,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: radius * 0.9,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  /// Dialog / Modal Sheet Edit Profil Pengguna
  void _showEditProfileDialog(BuildContext context, AuthProvider auth) {
    final user = auth.currentUser;
    final nameController = TextEditingController(text: user?.name ?? 'User');
    Uint8List? selectedImageBytes;
    bool isCompressing = false;
    String? compressionStats;
    bool isSaving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppDimensions.margin,
                right: AppDimensions.margin,
                top: 16,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profil',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Area Ubah Foto Profil
                    Center(
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              if (isCompressing)
                                const CircleAvatar(
                                  radius: 46,
                                  backgroundColor: AppColors.secondaryContainer,
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                )
                              else if (selectedImageBytes != null)
                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor: AppColors.secondaryContainer,
                                  backgroundImage: MemoryImage(selectedImageBytes!),
                                )
                              else
                                _buildUserAvatar(user, radius: 46),
                              Container(
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                  onPressed: isCompressing || isSaving
                                      ? null
                                      : () async {
                                          try {
                                            final picker = ImagePicker();
                                            final picked = await picker.pickImage(
                                              source: ImageSource.gallery,
                                            );

                                            if (picked != null) {
                                              setSheetState(() {
                                                isCompressing = true;
                                                errorText = null;
                                              });

                                              final rawBytes = await picked.readAsBytes();
                                              // Otomatis decode format apapun & kompres ke WebP resolusi tajam 512x512
                                              final compressResult = await ImageCompressHelper.compressToWebP(
                                                rawBytes,
                                                quality: 80,
                                                maxDimension: 512,
                                              );

                                              setSheetState(() {
                                                isCompressing = false;
                                                selectedImageBytes = compressResult.bytes;
                                                compressionStats = compressResult.summaryText;
                                                errorText = null;
                                              });
                                            }
                                          } catch (e) {
                                            setSheetState(() {
                                              isCompressing = false;
                                              errorText = 'Gagal memproses gambar: $e';
                                            });
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                          if (compressionStats != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withAlpha(60),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primary.withAlpha(120)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    'WebP: $compressionStats',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Text(
                              'Pilih foto (JPG/PNG)',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Field Nama Lengkap
                    Text(
                      'Nama Lengkap',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Masukkan nama lengkap Anda',
                        prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Info Email (Read-only)
                    Text(
                      'Email Akun',
                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: TextEditingController(text: user?.email ?? ''),
                      readOnly: true,
                      enabled: false,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.outline),
                        filled: true,
                        fillColor: AppColors.surfaceContainerHigh,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorText!,
                                style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Tombol Simpan Perubahan
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (isSaving || isCompressing)
                            ? null
                            : () async {
                                final newName = nameController.text.trim();
                                if (newName.isEmpty) {
                                  setSheetState(() => errorText = 'Nama tidak boleh kosong.');
                                  return;
                                }

                                setSheetState(() {
                                  isSaving = true;
                                  errorText = null;
                                });

                                String? finalPhotoUrl = user?.profilePhoto;

                                // Jika pengguna memilih foto baru: upload ke Supabase Storage (format WebP)
                                if (selectedImageBytes != null) {
                                  final uploadedUrl = await auth.uploadAvatarBytes(
                                    selectedImageBytes!,
                                    'webp',
                                  );

                                  if (uploadedUrl == null) {
                                    setSheetState(() {
                                      isSaving = false;
                                      errorText = auth.errorMessage ??
                                          "Gagal mengunggah foto ke Supabase Storage. Pastikan bucket 'avatars' sudah dibuat di Supabase.";
                                    });
                                    return;
                                  }
                                  finalPhotoUrl = uploadedUrl;
                                }

                                final success = await auth.updateProfile(
                                  name: newName,
                                  profilePhoto: finalPhotoUrl,
                                );

                                if (context.mounted) {
                                  if (success) {
                                    Navigator.pop(sheetCtx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Profil dan foto berhasil diperbarui'),
                                        backgroundColor: AppColors.secondary,
                                      ),
                                    );
                                  } else {
                                    setSheetState(() {
                                      isSaving = false;
                                      errorText = auth.errorMessage ?? 'Gagal memperbarui profil.';
                                    });
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(fontWeight: FontWeight.bold),
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

  /// Tile Menu Navigasi
  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        elevation: 0.5,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleMd.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTypography.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.outlineVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tile Pengaturan Kunci Biometrik dengan Toggle Switch
  Widget _buildBiometricSettingTile(BuildContext context, AuthProvider auth) {
    final isSupported = auth.isBiometricSupported;
    final hasEnrolled = auth.hasEnrolledBiometrics;
    final isEnabled = auth.isBiometricEnabled;
    final canToggle = isSupported && hasEnrolled;

    String statusText;
    Color statusColor;
    Color statusBgColor;

    if (!isSupported) {
      statusText = 'Tidak Didukung';
      statusColor = AppColors.onSurfaceVariant;
      statusBgColor = AppColors.surfaceContainerHigh;
    } else if (!hasEnrolled) {
      statusText = 'Belum Terdaftar';
      statusColor = AppColors.volcanoStatusWaspada;
      statusBgColor = AppColors.volcanoStatusWaspadaBg;
    } else if (isEnabled) {
      statusText = 'Aktif';
      statusColor = AppColors.secondary;
      statusBgColor = AppColors.secondaryContainer;
    } else {
      statusText = 'Tidak Aktif';
      statusColor = AppColors.onSurfaceVariant;
      statusBgColor = AppColors.surfaceContainerHigh;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        elevation: 0.5,
        child: InkWell(
          onTap: () => _showBiometricDetailsSheet(context, auth),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Kunci Biometrik Aplikasi',
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        !isSupported
                            ? 'Sensor biometrik tidak tersedia di perangkat ini'
                            : !hasEnrolled
                                ? 'Daftarkan sidik jari di pengaturan HP Anda'
                                : isEnabled
                                    ? 'Aplikasi terkunci saat dibuka kembali'
                                    : 'Sentuh untuk mengaktifkan kunci biometrik',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled && canToggle,
                  activeTrackColor: AppColors.primaryContainer,
                  activeThumbColor: AppColors.primary,
                  onChanged: !canToggle
                      ? (_) {
                          _showBiometricDetailsSheet(context, auth);
                        }
                      : (val) async {
                          if (val) {
                            final success = await auth.unlockWithBiometrics();
                            if (success) {
                              await auth.setBiometricEnabled(true);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Kunci biometrik berhasil diaktifkan.'),
                                    backgroundColor: AppColors.secondary,
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Verifikasi biometrik dibatalkan. Kunci belum diaktifkan.',
                                    ),
                                    backgroundColor: AppColors.volcanoStatusWaspada,
                                  ),
                                );
                              }
                            }
                          } else {
                            await auth.setBiometricEnabled(false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Kunci biometrik dinonaktifkan.'),
                                ),
                              );
                            }
                          }
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lembar Detail Informasi & Penjelasan Kunci Biometrik
  void _showBiometricDetailsSheet(BuildContext context, AuthProvider auth) {
    final isSupported = auth.isBiometricSupported;
    final hasEnrolled = auth.hasEnrolledBiometrics;
    final isEnabled = auth.isBiometricEnabled;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.margin),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keamanan & Kunci Biometrik',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Perlindungan data petualangan MeraTrip',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Hardware Sensor', style: AppTypography.labelMd),
                        Text(
                          isSupported ? 'Tersedia' : 'Tidak Didukung',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSupported ? AppColors.secondary : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Biometrik Terdaftar', style: AppTypography.labelMd),
                        Text(
                          hasEnrolled ? 'Terdaftar' : 'Belum Terdaftar di HP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasEnrolled
                                ? AppColors.secondary
                                : AppColors.volcanoStatusWaspada,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kunci Aplikasi', style: AppTypography.labelMd),
                        Text(
                          isEnabled ? 'Aktif' : 'Nonaktif',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isEnabled
                                ? AppColors.secondary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Info Point Fallback Password
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Jika biometrik gagal, sensor rusak, atau tidak tersedia, Anda dapat membuka aplikasi menggunakan kata sandi akun Supabase.',
                      style: AppTypography.bodySm.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.secondary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tidak ada kata sandi atau data biometrik yang disimpan dalam penyimpanan lokal. Autentikasi dikelola aman oleh hardware OS & Supabase.',
                      style: AppTypography.bodySm.copyWith(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (!isSupported)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Text(
                    'Perangkat ini tidak memiliki sensor biometrik yang kompatibel. Akses aplikasi Anda tetap aman dengan kata sandi akun Supabase.',
                    style: AppTypography.bodySm.copyWith(fontSize: 12),
                  ),
                )
              else if (!hasEnrolled)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.volcanoStatusWaspadaBg,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Text(
                    'Silakan daftarkan sidik jari atau Face ID pada Pengaturan Keamanan perangkat HP Anda terlebih dahulu.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.volcanoStatusWaspada,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheetCtx);
                      if (!isEnabled) {
                        final success = await auth.unlockWithBiometrics();
                        if (success) {
                          await auth.setBiometricEnabled(true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kunci biometrik berhasil diaktifkan.'),
                                backgroundColor: AppColors.secondary,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verifikasi biometrik dibatalkan.'),
                                backgroundColor: AppColors.volcanoStatusWaspada,
                              ),
                            );
                          }
                        }
                      } else {
                        await auth.setBiometricEnabled(false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Kunci biometrik dinonaktifkan.')),
                          );
                        }
                      }
                    },
                    icon: Icon(
                      isEnabled ? Icons.lock_open_rounded : Icons.lock_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isEnabled
                          ? 'Nonaktifkan Kunci Biometrik'
                          : 'Aktifkan Kunci Biometrik Sekarang',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isEnabled ? AppColors.surfaceContainerHigh : AppColors.primary,
                      foregroundColor: isEnabled ? AppColors.onSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

}
