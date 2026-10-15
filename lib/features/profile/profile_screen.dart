import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../auth/auth_provider.dart';
import '../blockchain/blockchain_screen.dart';
import '../map/offline_map_screen.dart';
import '../quiz/quiz_provider.dart';
import '../quiz/quiz_screen.dart';
import '../sensor/sensor_compass_screen.dart';
import '../trip/trip_provider.dart';
import '../utility/currency_time_screen.dart';
import 'course_feedback_screen.dart';

class ProfileScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;

  const ProfileScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final quiz = context.watch<QuizProvider>();
    final user = auth.currentUser;

    final displayName = user?.name.isNotEmpty == true ? user!.name : 'Bima Sakti';
    final displayEmail = user?.email.isNotEmpty == true ? user!.email : 'bima.sakti@wisatawan.id';

    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        const SizedBox(height: AppDimensions.spaceSm),
        // 2. Profile Identity Card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Container(
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
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: AppColors.secondaryContainer,
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'B',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
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
                            child: const Icon(Icons.verified, size: 14, color: AppColors.onPrimary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_square, size: 18, color: AppColors.primary),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Buka profil penjelajah...')),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayEmail,
                            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryContainer.withAlpha(150),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined, size: 12, color: AppColors.onSecondaryContainer),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Terverifikasi Sleman & Boyolali',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Quick Eco Carbon Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Jejak Karbon: 14 kg CO₂e Tereduksi',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tingkat 3',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. Travel & Gamification Stats Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Statistik & Pangkat Alam',
                      style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Musim Kemarau 2025',
                    style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatCard(
                    icon: Icons.alt_route,
                    value: '4',
                    label: 'Trip Selesai',
                    iconColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    icon: Icons.bookmark,
                    value: '12',
                    label: 'Disimpan',
                    iconColor: AppColors.secondary,
                  ),
                  const SizedBox(width: 8),
                  _buildStatCard(
                    icon: Icons.military_tech,
                    value: '${quiz.userScore}',
                    label: 'Poin Jagawana',
                    iconColor: const Color(0xFFC58A32),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Gamification Rank Progress Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(6),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.workspace_premium, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Gelar: ${quiz.activeRankTitle}',
                                  style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${quiz.userScore} / 1000 Poin',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            child: LinearProgressIndicator(
                              value: (quiz.userScore / 1000).clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceContainerLow,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 4. Menu List Tiles / Utilitas Lengkap
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigasi Petualang & Utilitas',
                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // 1. Destinasi Favorit
              _buildMenuItem(
                context,
                icon: Icons.favorite,
                title: 'Destinasi Favorit & Tersimpan',
                subtitle: 'Bunker Kaliadem, Selo, Plunyon Kalikuning',
                trailingBadge: '12',
                onTap: () => onNavigateTab?.call(1),
              ),

              // 2. Riwayat & Draft Perjalanan
              _buildMenuItem(
                context,
                icon: Icons.route,
                title: 'Riwayat & Draft Perjalanan',
                subtitle: '4 Berhasil • 1 Draf Rencana Sunrise',
                onTap: () => onNavigateTab?.call(2),
              ),

              // 3. Manajer Data Offline
              _buildMenuItem(
                context,
                icon: Icons.cloud_download,
                title: 'Manajer Data Offline',
                subtitle: 'Peta topografi & jalur darurat tanpa sinyal',
                trailingBadge: '34 MB',
                badgeColor: AppColors.secondaryContainer,
                badgeTextColor: AppColors.onSecondaryContainer,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OfflineMapScreen()),
                  );
                },
              ),

              // 4. Konverter Valuta & Waktu
              _buildMenuItem(
                context,
                icon: Icons.currency_exchange,
                title: 'Konverter Kurs & Zona Waktu',
                subtitle: 'IDR, USD, EUR, JPY & WIB / WITA / WIT / GMT',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CurrencyTimeScreen()),
                  );
                },
              ),

              // 5. Sensor Lapangan (Gyro & Shake)
              _buildMenuItem(
                context,
                icon: Icons.screen_rotation,
                title: 'Eksplorasi Sensor Lapangan',
                subtitle: 'Goyang ponsel untuk rekomendasi rute acak & kompas',
                trailingBadge: 'GYRO',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SensorCompassScreen()),
                  );
                },
              ),

              // 6. Mini Game Kuis Merapi
              _buildMenuItem(
                context,
                icon: Icons.sports_esports,
                title: 'Mini Game Kuis Merapi',
                subtitle: 'Tantangan harian vulkanologi (+50 Poin Jagawana)',
                hasRedDot: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QuizScreen()),
                  );
                },
              ),

              // 7. Catatan Bukti Blockchain
              _buildMenuItem(
                context,
                icon: Icons.token,
                title: 'Catatan Bukti Blockchain',
                subtitle: 'Integritas sertifikat pendakian terverifikasi on-chain',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BlockchainScreen()),
                  );
                },
              ),

              // 8. Refleksi Kuliah & Evaluasi PAM
              _buildMenuItem(
                context,
                icon: Icons.school,
                title: 'Refleksi Kuliah & Evaluasi PAM',
                subtitle: 'Laporan Ujian Praktikum Pemrograman Mobile',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CourseFeedbackScreen()),
                  );
                },
              ),

              // 9. Pengaturan & Biometrik
              _buildMenuItem(
                context,
                icon: Icons.fingerprint,
                title: 'Pengaturan & Biometrik',
                subtitle: 'Fingerprint & Privasi GPS Lapangan',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Autentikasi biometrik aktif untuk akun ini.'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 5. Logout Button Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _showLogoutConfirmation(context, auth),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.errorContainer,
                    foregroundColor: AppColors.onErrorContainer,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'MeraTrip v2.4.0 — Ekowisata Lereng Merapi DIY & Jateng',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.outline,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTypography.headlineSm.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingBadge,
    Color? badgeColor,
    Color? badgeTextColor,
    bool hasRedDot = false,
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
                  width: 36,
                  height: 36,
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasRedDot) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
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
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Text(
                    trailingBadge,
                    style: AppTypography.labelSm.copyWith(
                      color: badgeTextColor ?? AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.outlineVariant),
            ],
          ),
        ),
      ),
    ),
  );
}

  void _showLogoutConfirmation(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(AppDimensions.margin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: AppColors.error, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              'Akhiri Sesi Penjelajahan?',
              style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Data peta offline (34 MB) dan draf rute aman Anda tetap tersimpan di perangkat ini. Anda yakin ingin keluar?',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  context.read<TripProvider>().clearSession();
                  auth.logout();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                child: const Text('Ya, Keluar Akun', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetCtx),
                child: const Text('Tetap di Sini'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
