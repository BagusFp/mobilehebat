import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/offline_pack_model.dart';

import 'map_provider.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _showCleanCacheDialog(BuildContext context, MapProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
          title: Text('Bersihkan Cache Peta?', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
          content: Text(
            'Cache rute peta sementara akan dibersihkan untuk menghemat ruang penyimpanan. Paket data kawasan utama tetap tersimpan.',
            style: AppTypography.bodyMd,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.pop(ctx);
                provider.cleanCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache peta offline berhasil dibersihkan.')),
                );
              },
              child: const Text('Bersihkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();


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
          'Manajer Peta Offline',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Volcanic Trail Status & Storage Readiness Pill
                _buildStorageCard(context, mapProvider),

                // 2. Informative Notice Banner
                _buildInfoBanner(),

                // 3. Destination Data Packs Section
                _buildDataPacksHeader(mapProvider),
                ...mapProvider.offlinePacks.map((pack) => _buildPackItemCard(context, pack, mapProvider)),

                // 4. Micro Guide / Database Info Card
                _buildDbInfoCard(),
              ],
            ),
          ),

          // 5. Pinned Sticky Bottom Controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildStickyBottomControls(context, mapProvider),
          ),
        ],
      ),
    );
  }

  // 1. Storage Progress Card
  Widget _buildStorageCard(BuildContext context, MapProvider provider) {
    final downloaded = provider.totalDownloadedMb.toStringAsFixed(1);
    final usagePercentStr = provider.usagePercent.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.margin),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withAlpha(6),
              blurRadius: 6,
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
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Mode Offline Siap Digunakan',
                      style: AppTypography.labelLg.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done, size: 13, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        'Tersinkron',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Storage Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$downloaded MB',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '/ 512 MB Dialokasikan',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
                Text(
                  '$usagePercentStr% Terpakai',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Segmented Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              child: SizedBox(
                height: 10,
                child: Stack(
                  children: [
                    Container(color: AppColors.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: (provider.usagePercent / 100).clamp(0.01, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryContainer,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Footer Timestamp & Clean Cache Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history, size: 14, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text(
                      'Pembaruan: 18 Okt 2024, 14:20 WIB',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => _showCleanCacheDialog(context, provider),
                  child: Row(
                    children: [
                      const Icon(Icons.cleaning_services, size: 14, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        'Bersihkan Cache',
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
          ],
        ),
      ),
    );
  }

  // 2. Informative Notice Banner
  Widget _buildInfoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.offline_bolt, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informasi Data Lokal Merapi',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Detail destinasi, elevasi kontur, koordinat GPS rute utama, dan kontak pos darurat tersimpan aman secara offline. Fitur asisten AI dan rekomendasi cuaca real-time tetap membutuhkan sinyal internet.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Header Section Paket Data
  Widget _buildDataPacksHeader(MapProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.margin,
        AppDimensions.spaceLg,
        AppDimensions.margin,
        AppDimensions.spaceSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paket Data Kawasan',
                style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                'Peta topografi, jalur evakuasi, dan POI lokal',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Text(
              '${provider.offlinePacks.length} Wilayah',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pack Item Card
  Widget _buildPackItemCard(
    BuildContext context,
    OfflinePackModel pack,
    MapProvider provider,
  ) {
    final isDownloaded = pack.status == 'downloaded';
    final isDownloading = pack.status == 'downloading';
    final isFailed = pack.status == 'failed';
    final isPaused = pack.status == 'paused';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.margin,
        vertical: 6,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isFailed
                        ? AppColors.errorContainer
                        : (isDownloaded
                            ? AppColors.secondaryContainer
                            : AppColors.surfaceContainer),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isDownloading
                      ? RotationTransition(
                          turns: _spinController,
                          child: const Icon(Icons.downloading, color: AppColors.secondary, size: 22),
                        )
                      : Icon(
                          pack.iconType == 'terrain'
                              ? Icons.terrain
                              : (pack.iconType == 'forest'
                                  ? Icons.forest
                                  : (isFailed ? Icons.cloud_off : Icons.downloading)),
                          color: isFailed
                              ? AppColors.error
                              : (isDownloaded ? AppColors.primary : AppColors.secondary),
                          size: 22,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.name,
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            '${pack.sizeMb} MB',
                            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.outlineVariant)),
                          const SizedBox(width: 6),
                          Row(
                            children: [
                              Icon(
                                isDownloaded
                                    ? Icons.check_circle
                                    : (isFailed ? Icons.error : (isPaused ? Icons.pause_circle : Icons.download)),
                                size: 12,
                                color: isDownloaded
                                    ? AppColors.primary
                                    : (isFailed ? AppColors.error : AppColors.secondary),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isDownloaded
                                    ? 'Tersimpan'
                                    : (isFailed ? 'Unduhan Gagal' : (isPaused ? 'Dijeda' : pack.badgeLabel)),
                                style: AppTypography.labelSm.copyWith(
                                  color: isDownloaded
                                      ? AppColors.primary
                                      : (isFailed ? AppColors.error : AppColors.secondary),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isDownloading || isPaused)
                  IconButton(
                    icon: Icon(
                      isPaused ? Icons.play_arrow : Icons.pause,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      if (isPaused) {
                        provider.resumeDownload(pack.id);
                      } else {
                        provider.pauseDownload(pack.id);
                      }
                    },
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFailed
                          ? AppColors.errorContainer
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      pack.badgeLabel,
                      style: AppTypography.labelSm.copyWith(
                        color: isFailed ? AppColors.onErrorContainer : AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),

            // Active Downloading Progress Bar
            if (isDownloading || isPaused) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: LinearProgressIndicator(
                  value: pack.progress,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPaused ? AppColors.outline : AppColors.primary,
                  ),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${pack.downloadedMb} MB dari ${pack.sizeMb} MB',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    pack.speedText ?? '',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],

            // Failed Error Notice & Retry Button
            if (isFailed) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        pack.errorMessage ?? 'Sinyal seluler tidak stabil saat mengunduh tile peta.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () => provider.retryDownload(pack.id),
                      icon: const Icon(Icons.replay, size: 14),
                      label: const Text('Coba Lagi', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons for Downloaded Items
            if (isDownloaded) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 34),
                      side: BorderSide.none,
                      backgroundColor: AppColors.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      provider.updatePack(pack.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Peta "${pack.name}" berhasil diperbarui.')),
                      );
                    },
                    icon: const Icon(Icons.sync, size: 14, color: AppColors.onSurface),
                    label: Text('Perbarui', style: AppTypography.labelSm.copyWith(color: AppColors.onSurface)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(60, 34),
                      side: BorderSide.none,
                      backgroundColor: AppColors.surfaceContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      provider.deletePack(pack.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Paket "${pack.name}" dihapus dari penyimpanan.')),
                      );
                    },
                    icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.error),
                    label: Text('Hapus', style: AppTypography.labelSm.copyWith(color: AppColors.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 4. Micro Guide / Database Info Card
  Widget _buildDbInfoCard() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.margin),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storage, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Database Enkripsi SQLite & Hive',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rute geojson diverifikasi berkala oleh Balai TN Merapi.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 5. Pinned Sticky Bottom Controls
  Widget _buildStickyBottomControls(BuildContext context, MapProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.margin,
        12,
        AppDimensions.margin,
        AppDimensions.spaceMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withAlpha(245),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.wifi, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Hanya Unduh via Wi-Fi',
                    style: AppTypography.labelLg.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              Switch(
                value: provider.isWifiOnly,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  provider.setWifiOnly(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                elevation: 2,
              ),
              onPressed: () {
                provider.downloadAllPacks();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mengunduh seluruh 4 paket kawasan Merapi (55 MB)...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.cloud_download, size: 22),
              label: Text(
                'Unduh Semua Data Kawasan Merapi (55 MB)',
                style: AppTypography.labelLg.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
