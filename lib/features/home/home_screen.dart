import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../auth/auth_provider.dart';
import '../explore/destination_detail_screen.dart';
import '../explore/destination_provider.dart';
import '../games/merapi_jeep_game_page.dart';
import '../map/map_screen.dart';
import '../sensor/sensor_compass_screen.dart';
import '../trip/create_trip_screen.dart';

class HomeScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final destProvider = context.watch<DestinationProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final userName = user != null && user.name.trim().isNotEmpty
        ? user.name.trim().toUpperCase()
        : 'USER';

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Greeting Section
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  top: AppDimensions.spaceMd,
                  bottom: AppDimensions.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HALO, $userName 👋',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mau menjelajah Merapi?',
                      style: AppTypography.headlineLg.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rencanakan petualangan wisatamu dengan cerdas & aman.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Status Aktivitas Merapi Card
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceLg,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE89005),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.warning_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
                                  ),
                                  child: const Text(
                                    'STATUS AKTIVITAS',
                                    style: TextStyle(
                                      color: Color(0xFFB45309),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Merapi Level II (Waspada)',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Jalur wisata Kaliurang & Cangkringan terpantau dalam ',
                                  ),
                                  TextSpan(
                                    text: 'zona aman.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
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
              ),

              // 4. 3 Utilitas Utama Cards Row
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceSm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildUtilityCard(
                        context: context,
                        icon: Icons.map_outlined,
                        iconBgColor: const Color(0xFFD7F5E5),
                        iconColor: const Color(0xFF04432F),
                        title: 'Peta Merapi',
                        subtitle: 'Rute',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MapScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUtilityCard(
                        context: context,
                        icon: Icons.explore_outlined,
                        iconBgColor: const Color(0xFFFEF3C7),
                        iconColor: const Color(0xFFB45309),
                        title: 'Kompas',
                        subtitle: 'Arah & Angin',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SensorCompassScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildUtilityCard(
                        context: context,
                        icon: Icons.smart_toy_outlined,
                        iconBgColor: const Color(0xFFD6F3EB),
                        iconColor: const Color(0xFF04432F),
                        title: 'Jagawana AI',
                        subtitle: 'Tanya Asisten',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // 5. Mini Game Banner: Merapi Jeep Run
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceLg,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MerapiJeepGamePage()),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF042B1D),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF042B1D).withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.directions_car_filled_rounded,
                                color: Color(0xFF4EE39D),
                                size: 24,
                              ),
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
                                        'Merapi Jeep Run',
                                        style: AppTypography.titleMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFB74D),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'MINI GAME',
                                        style: TextStyle(
                                          color: Color(0xFF3E2723),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Simulasi offroad lereng gunung',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withAlpha(180),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4EE39D),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.play_arrow_rounded, color: Color(0xFF042B1D), size: 16),
                                SizedBox(width: 2),
                                Text(
                                  'Main',
                                  style: TextStyle(
                                    color: Color(0xFF042B1D),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 6. Perencana Trip Instan Card
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceLg,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceContainer.withAlpha(120)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withAlpha(6),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD7F5E5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_motion_rounded,
                                    color: Color(0xFF04432F),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Perencana Trip Instan',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD7F5E5),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              'Smart Planner',
                              style: AppTypography.labelSmall.copyWith(
                                color: const Color(0xFF04432F),
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buat rencana trip terstruktur dengan personalisasi budget awal, konversi valuta & zona waktu.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.add, size: 20),
                          label: Text(
                            'Buat Perencanaan Trip Baru',
                            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Section Header: Rekomendasi Utama
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REKOMENDASI UTAMA',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.outline,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    InkWell(
                      onTap: () => onNavigateTab?.call(1),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          'Lihat Semua',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 8. Hero Destination Card (Kaliadem & Merapi View)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceLg,
                ),
                child: InkWell(
                  onTap: () {
                    if (destProvider.allDestinations.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DestinationDetailScreen(
                            destination: destProvider.allDestinations.first,
                          ),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuD__JTBQcN2VsrNHKnYZ3FxiZdpsu2-fckBgW-YFTPB2_IwRsWRTY0ZzPK3EY0nOTR9Jaut-9xVIAY7bJ0r5GeR5Bp6WKDYOBF8nqbDwSw2iRpvqT-lu6DRI-DJ3fgMNSdprlLU4CPEld1KWrAocN1GBaG6J3iyYnlEw9_cvpKjcZAeSyY_sWN4k8zIzEvVJH4PvHj12yNDoQ4qetdwZJVqvmwcvyYcl_Kf_2lp-GWVsts1KsPJGgk',
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                              errorBuilder: (_, _, _) => Container(
                                color: AppColors.primaryContainer,
                                child: const Center(
                                  child: Icon(Icons.landscape, size: 60, color: AppColors.onPrimary),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withAlpha(20),
                                    Colors.black.withAlpha(70),
                                    Colors.black.withAlpha(200),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14,
                            left: 14,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C853),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                  ),
                                  child: const Text(
                                    'SPOT UTAMA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(120),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.terrain_rounded, size: 12, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        '1.100 mdpl',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            left: 14,
                            right: 14,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kawasan Wisata Kaliadem & Merapi View',
                                  style: AppTypography.headlineSm.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pemandangan lanskap megah puncak Merapi dengan rute jeep menantang.',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withAlpha(220),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Tiket: Rp 10.000 / org',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: const Color(0xFF69F0AE),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Detail',
                                            style: TextStyle(
                                              color: Color(0xFF04432F),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          SizedBox(width: 2),
                                          Icon(Icons.chevron_right, size: 14, color: Color(0xFF04432F)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildUtilityCard({
    required BuildContext context,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceContainer.withAlpha(120)),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withAlpha(6),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
