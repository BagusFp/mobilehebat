import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/destination_model.dart';
import '../ai_assistant/ai_assistant_screen.dart';
import '../explore/destination_detail_screen.dart';
import '../explore/destination_provider.dart';
import '../games/merapi_jeep_game_page.dart';
import '../map/map_screen.dart';
import '../sensor/sensor_compass_screen.dart';
import '../trip/create_trip_screen.dart';
import '../utility/currency_time_screen.dart';

class HomeScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;

  const HomeScreen({
    super.key,
    this.onNavigateTab,
  });

  String _formatCurrency(double price) {
    if (price <= 0) return 'Sukarela';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    final destProvider = context.watch<DestinationProvider>();
    final verifiedDestinations = destProvider.allDestinations.take(4).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3. Header Greeting Section
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  top: AppDimensions.spaceSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mau menjelajah Merapi?',
                            style: AppTypography.headlineLg.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Rencanakan petualangan wisatamu dengan cerdas',
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.landscape,
                        color: AppColors.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Search Bar with Quick Filter Trigger
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.margin,
                  vertical: AppDimensions.spaceMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => onNavigateTab?.call(1), // Pindah ke tab Explore
                        borderRadius: AppDimensions.roundedXl,
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppDimensions.roundedXl,
                            border: Border.all(color: AppColors.surfaceContainer),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: AppColors.outline,
                                size: 22,
                              ),
                              const SizedBox(width: AppDimensions.spaceSm),
                              Expanded(
                                child: Text(
                                  'Cari destinasi di sekitar Merapi...',
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.outline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    InkWell(
                      onTap: () => onNavigateTab?.call(1),
                      borderRadius: AppDimensions.roundedXl,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppDimensions.roundedXl,
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),



              // 5. Quick Actions Grid (4 round tactile buttons)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.margin,
                  vertical: AppDimensions.spaceLg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildQuickAction(
                      icon: Icons.explore,
                      label: 'Jelajah',
                      onTap: () => onNavigateTab?.call(1), // Tab Explore
                    ),
                    _buildQuickAction(
                      icon: Icons.edit_calendar,
                      label: 'Buat Trip',
                      onTap: () => onNavigateTab?.call(2), // Tab My Trip
                    ),
                    _buildQuickAction(
                      icon: Icons.map,
                      label: 'Peta Merapi',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapScreen()),
                        );
                      },
                    ),
                    _buildQuickAction(
                      icon: Icons.auto_awesome,
                      label: 'Tanya AI',
                      isSpecialHighlight: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AiAssistantScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 5b. Utilitas Lapangan & Sensor Quick Bar
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SensorCompassScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            border: Border.all(color: AppColors.surfaceContainer),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppColors.secondaryContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.explore, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kompas & Sensor',
                                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Goyang HP & Arah',
                                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CurrencyTimeScreen()),
                          );
                        },
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            border: Border.all(color: AppColors.surfaceContainer),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.currency_exchange, size: 16, color: AppColors.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Kurs & Waktu',
                                      style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Konversi Valuta',
                                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 5c. Merapi Jeep 2D Run Game Banner (Sensors: Accelerometer & Gyroscope)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceMd,
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
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
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
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('🚙', style: TextStyle(fontSize: 24)),
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
                                        'Minigame',
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
                                        color: Colors.amberAccent,
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                                      ),
                                      child: const Text(
                                        'SENSOR',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Goyang & miringkan HP untuk kemudikan Jeep Lava Tour',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.play_arrow_rounded, color: Color(0xFF1B5E20), size: 16),
                                SizedBox(width: 2),
                                Text(
                                  'Main',
                                  style: TextStyle(
                                    color: Color(0xFF1B5E20),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
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

              // 6. Featured Destination Hero Card
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceLg,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppDimensions.roundedXl,
                    border: Border.all(color: AppColors.surfaceContainer),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.onSurface.withAlpha(10),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Hero visual
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppDimensions.radiusXl),
                            ),
                            child: Container(
                              height: 200,
                              width: double.infinity,
                              color: AppColors.primaryContainer,
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
                          ),
                          // Scrim
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppDimensions.radiusXl),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withAlpha(40),
                                    Colors.transparent,
                                    AppColors.primary.withAlpha(220),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Top Badges
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest.withAlpha(230),
                                borderRadius: AppDimensions.roundedFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.landscape, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Alam & Panorama',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(200),
                                borderRadius: AppDimensions.roundedFull,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.visibility, size: 14, color: AppColors.onPrimary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Spot Utama',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Hero info text
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kawasan Wisata Kaliadem & Merapi View',
                                  style: AppTypography.headlineSm.copyWith(
                                    color: AppColors.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Pemandangan lanskap megah puncak Merapi dengan udara sejuk pegunungan.',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onPrimary.withAlpha(220),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Card Footer Action
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.spaceMd),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.straighten,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '1.100 mdpl • Cangkringan',
                                      style: AppTypography.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.onPrimary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppDimensions.roundedLg,
                                ),
                                elevation: 0,
                              ),
                              onPressed: () {
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
                              icon: Text('Jelajahi', style: AppTypography.labelLg),
                              label: const Icon(Icons.arrow_forward, size: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 7. Trip Planner Quick Configurator Card
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
                    borderRadius: AppDimensions.roundedXl,
                    border: Border.all(color: AppColors.surfaceContainer),
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
                                const Icon(Icons.route, color: AppColors.primary, size: 22),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rencana Perjalanan Cepat',
                                    style: AppTypography.titleMd.copyWith(
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
                              color: AppColors.surfaceContainer,
                              borderRadius: AppDimensions.roundedSm,
                            ),
                            child: Text(
                              'Personalisasi',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sesuaikan rencana petualangan harimu di lereng selatan Merapi.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      // 2x2 Grid of Quick Parameters
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: AppDimensions.spaceSm,
                        mainAxisSpacing: AppDimensions.spaceSm,
                        childAspectRatio: 2.1,
                        children: [
                          _buildConfigTile(
                            icon: Icons.calendar_today,
                            label: 'Tanggal',
                            value: '14 Okt 2024',
                          ),
                          _buildConfigTile(
                            icon: Icons.schedule,
                            label: 'Durasi',
                            value: '1 Hari Penuh',
                          ),
                          _buildConfigTile(
                            icon: Icons.group,
                            label: 'Wisatawan',
                            value: '2 Orang (Dewasa)',
                          ),
                          _buildConfigTile(
                            icon: Icons.payments,
                            label: 'Est. Budget',
                            value: 'Rp 350.000/org',
                            isHighlight: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spaceMd),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDimensions.roundedXl,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateTripScreen()),
                            );
                          },
                          icon: const Icon(Icons.schedule, size: 20),
                          label: Text('Buat Itinerary', style: AppTypography.labelLg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 9. Verified Destinations Section
              Padding(
                padding: const EdgeInsets.only(
                  left: AppDimensions.margin,
                  right: AppDimensions.margin,
                  bottom: AppDimensions.spaceSm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destinasi Terverifikasi',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Informasi tiket & rute akurat dari pengelola',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => onNavigateTab?.call(1),
                      child: Text(
                        'Lihat Semua',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // List of 4 Verified Destinations
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: verifiedDestinations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.spaceSm),
                  itemBuilder: (ctx, idx) {
                    final dest = verifiedDestinations[idx];
                    return _buildVerifiedTile(context, dest, destProvider);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSpecialHighlight = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isSpecialHighlight
                  ? AppColors.secondaryContainer
                  : AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigTile({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppDimensions.roundedLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.outline),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.labelMd.copyWith(
              color: isHighlight ? AppColors.primary : AppColors.onSurface,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedTile(
    BuildContext context,
    DestinationModel dest,
    DestinationProvider provider,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(destination: dest),
          ),
        );
      },
      borderRadius: AppDimensions.roundedXl,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppDimensions.roundedXl,
          border: Border.all(color: AppColors.surfaceContainer),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: AppDimensions.roundedLg,
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.primaryContainer,
                child: dest.imageUrl != null && dest.imageUrl!.startsWith('http')
                    ? Image.network(
                        dest.imageUrl!,
                        fit: BoxFit.cover,
                        cacheWidth: 200,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.landscape,
                          color: AppColors.onPrimary,
                        ),
                      )
                    : const Icon(
                        Icons.landscape,
                        color: AppColors.onPrimary,
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: AppDimensions.roundedSm,
                        ),
                        child: Text(
                          dest.categoryName,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      Icon(
                        provider.isFavorite(dest.id)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: 20,
                        color: provider.isFavorite(dest.id)
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dest.name,
                    style: AppTypography.titleMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.secondary),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          dest.address,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _formatCurrency(dest.ticketPrice),
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withAlpha(100),
                          borderRadius: AppDimensions.roundedSm,
                        ),
                        child: Text(
                          'Terverifikasi',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }
}
