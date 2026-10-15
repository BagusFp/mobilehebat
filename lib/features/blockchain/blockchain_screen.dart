import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import 'blockchain_model.dart';
import 'blockchain_provider.dart';

class BlockchainScreen extends StatelessWidget {
  const BlockchainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chain = context.watch<BlockchainProvider>();
    final isChainValid = chain.isChainValid;

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
          'Riwayat Integritas Blockchain',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isChainValid ? Icons.verified : Icons.warning_amber_rounded,
              color: isChainValid ? AppColors.primary : AppColors.error,
            ),
            tooltip: isChainValid ? 'Rantai Valid' : 'Rantai Terlanggar',
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // 1. Live Status Banner
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.margin,
              AppDimensions.spaceSm,
              AppDimensions.margin,
              AppDimensions.spaceXs,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'NODE MERAPI TNGM LIVE',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Aktif Terhubung',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Hero Header Section
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.margin,
              AppDimensions.spaceMd,
              AppDimensions.margin,
              AppDimensions.spaceSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'BUKU BESAR KONSERVASI',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isChainValid ? AppColors.surfaceContainerHigh : AppColors.errorContainer,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isChainValid ? Icons.verified : Icons.error,
                            size: 14,
                            color: isChainValid ? AppColors.primary : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isChainValid ? 'Rantai Valid' : 'Rantai Rusak!',
                            style: AppTypography.labelSm.copyWith(
                              color: isChainValid ? AppColors.primary : AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Riwayat Blok Integritas Data',
                  style: AppTypography.headlineMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pencatatan data perjalanan dan izin konservasi Taman Nasional Gunung Merapi (TNGM) berbasis struktur hash berantai anti-manipulasi.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),

                // Metrics Card
                Container(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Terdaftar', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            Text('4 Blok', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Text('Imutabel', style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sinkronisasi', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            Text(isChainValid ? 'Konsisten' : 'Anomali', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: isChainValid ? AppColors.secondary : AppColors.error)),
                            Text('Semua Node', style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Algoritma', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            Text('SHA-256', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Text('Kriptografis', style: AppTypography.bodySm.copyWith(fontSize: 10, color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Section Struktur Rantai Hash Terbuka
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Struktur Rantai Hash Terbuka',
                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Kronologis Naik',
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Vertical Connected Blockchain Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
            child: Column(
              children: chain.blocks.reversed.map((block) {
                return _buildBlockCard(context, block, chain);
              }).toList(),
            ),
          ),

          // 5. Card Cek Integritas Rantai & Tamper Test Action
          _buildAuditActionSection(context, chain),
        ],
      ),
    );
  }

  Widget _buildBlockCard(BuildContext context, BlockModel block, BlockchainProvider chain) {
    final isGenesis = block.index == 1;
    final isTampered = block.isTampered;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: isTampered ? AppColors.errorContainer.withAlpha(50) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: isTampered ? Border.all(color: AppColors.error, width: 1.5) : null,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isTampered
                      ? AppColors.error
                      : (isGenesis ? AppColors.surfaceContainerHighest : AppColors.primary),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '#0${block.index}',
                  style: TextStyle(
                    color: isGenesis ? AppColors.onSurface : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: isGenesis ? AppColors.surfaceContainer : AppColors.secondaryContainer,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          ),
                          child: Text(
                            isGenesis ? 'Genesis Block' : 'Blok Riwayat Sah',
                            style: AppTypography.labelSm.copyWith(
                              color: isGenesis ? AppColors.onSurfaceVariant : AppColors.onSecondaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        Text(
                          block.referenceId,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      block.title,
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isTampered ? AppColors.error : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          block.timestamp,
                          style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Payload Info
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Muatan Data (Payload):',
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                ),
                const SizedBox(height: 2),
                Text(
                  block.dataPayload,
                  style: AppTypography.bodySm.copyWith(
                    fontWeight: isTampered ? FontWeight.bold : FontWeight.normal,
                    color: isTampered ? AppColors.error : AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Previous Hash
                Text(
                  'Parent Hash:',
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                ),
                Text(
                  block.previousHash,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Current Hash SHA-256
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hash Blok Ini (SHA-256):',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isTampered ? AppColors.error : AppColors.primary,
                        fontSize: 10,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: block.hash));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Hash SHA-256 berhasil disalin ke clipboard!'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: const [
                            Icon(Icons.content_copy, size: 12, color: AppColors.primary),
                            SizedBox(width: 2),
                            Text('Salin', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    block.hash,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isTampered ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Authority Signer
          Row(
            children: [
              Icon(
                isTampered ? Icons.error_outline : Icons.check_circle_outline,
                size: 14,
                color: isTampered ? AppColors.error : AppColors.secondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isTampered
                      ? 'Integritas Rusak: Hash tidak sesuai kalkulasi SHA-256'
                      : 'Tervalidasi Sah oleh ${block.authoritySigner}',
                  style: AppTypography.labelSm.copyWith(
                    color: isTampered ? AppColors.error : AppColors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: isTampered ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditActionSection(BuildContext context, BlockchainProvider chain) {
    return Padding(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Cek Integritas Rantai',
                  style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Audit integritas otomatis memeriksa kesinambungan signature hash dari Blok Genesis hingga transaksi mutakhir.',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),

            // Button 1: Validasi Seluruh Rantai Blok
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: chain.isAuditing ? null : () => chain.runChainAudit(),
                icon: chain.isAuditing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.fact_check, size: 18),
                label: Text(
                  chain.isAuditing ? 'Mengaudit SHA-256 Rantai...' : 'Validasi Seluruh Rantai Blok',
                  style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Audit Feedback Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: chain.isChainValid ? AppColors.surfaceContainerLow : AppColors.errorContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    chain.isChainValid ? Icons.check_circle : Icons.warning,
                    color: chain.isChainValid ? AppColors.primary : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chain.auditStatus,
                      style: AppTypography.bodySm.copyWith(
                        color: chain.isChainValid ? AppColors.primary : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Button 2: Tamper Simulation Test
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: chain.isTamperedState
                        ? () => chain.restoreChain()
                        : () => chain.simulateTamper(3),
                    icon: Icon(
                      chain.isTamperedState ? Icons.restart_alt : Icons.bug_report,
                      size: 16,
                      color: chain.isTamperedState ? AppColors.primary : AppColors.error,
                    ),
                    label: Text(
                      chain.isTamperedState ? 'Pulihkan Rantai Asli' : 'Simulasi Manipulasi (Tamper Test)',
                      style: TextStyle(
                        color: chain.isTamperedState ? AppColors.primary : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: chain.isTamperedState ? AppColors.primary : AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Educational note
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withAlpha(150),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan Transparansi: Sistem ini memastikan sertifikat pendakian ramah lingkungan dan izin masuk bebas duplikasi tanpa melibatkan transaksi kripto spekulatif.',
                      style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.onSurfaceVariant),
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
}
