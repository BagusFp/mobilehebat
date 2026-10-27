import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../core/services/blockchain_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/blockchain_proof_helper.dart';
import '../../data/models/trip_model.dart';
import '../../data/models/trip_proof_model.dart';
import '../auth/auth_provider.dart';
import '../trip/trip_provider.dart';
import 'blockchain_model.dart';
import 'blockchain_provider.dart';

class BlockchainScreen extends StatefulWidget {
  final int? initialTripId;

  const BlockchainScreen({super.key, this.initialTripId});

  @override
  State<BlockchainScreen> createState() => _BlockchainScreenState();
}

class _BlockchainScreenState extends State<BlockchainScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProofs();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadProofs() {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id ?? 1;
    context.read<BlockchainProvider>().loadUserProofs(userId);
  }

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
          'Catatan Bukti Blockchain',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondaryContainer,
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
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
                const SizedBox(width: 6),
                Text(
                  'Sepolia Testnet',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          labelStyle: AppTypography.titleSm.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.verified_outlined, size: 20),
              text: 'Proof of Visit',
            ),
            Tab(
              icon: Icon(Icons.account_tree_outlined, size: 20),
              text: 'Ledger Konservasi',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProofOfVisitTab(context, chain),
          _buildConservationLedgerTab(context, chain, isChainValid),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: BUKTI PERJALANAN (PROOF OF VISIT - ETHEREUM SEPOLIA)
  // ===========================================================================
  Widget _buildProofOfVisitTab(BuildContext context, BlockchainProvider chain) {
    final tripProvider = context.watch<TripProvider>();
    final auth = context.watch<AuthProvider>();
    final userId = auth.currentUser?.id ?? 1;

    // Filter trip berstatus selesai ('completed')
    final completedTrips = tripProvider.allTrips
        .where((t) => t.status == 'completed')
        .toList();

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        _loadProofs();
        await tripProvider.loadUserTrips(userId);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.margin,
          AppDimensions.spaceMd,
          AppDimensions.margin,
          AppDimensions.spaceXl,
        ),
        children: [
          // 1. Kartu Info Network & Smart Contract
          _buildNetworkInfoCard(),

          const SizedBox(height: AppDimensions.spaceMd),

          // Header section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bukti Perjalanan Saya',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  '${completedTrips.length} Trip Selesai',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sertifikat perjalanan digital yang di-hash SHA-256 dan diverifikasi pada smart contract Ethereum Sepolia.',
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spaceMd),

          // List Completed Trips with Proof Status
          if (completedTrips.isEmpty)
            _buildEmptyStateCard()
          else
            ...completedTrips.map((trip) {
              final proof = chain.getProofForTrip(trip.id ?? -1);
              return _buildTripProofCard(context, trip, proof, chain, userId);
            }),

          const SizedBox(height: AppDimensions.spaceMd),

          // Disclaimer Privasi & Kejujuran
          _buildPrivacyAndFraudDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildNetworkInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.hub_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  BlockchainService.networkName,
                  style: AppTypography.titleSm.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Chain ID 11155111',
                  style: AppTypography.labelSm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Smart Contract:',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(
                      text: BlockchainService.defaultContractAddress,
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alamat kontrak disalin ke clipboard!'),
                    ),
                  );
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      BlockchainProofHelper.formatShortHash(
                        BlockchainService.defaultContractAddress,
                      ),
                      style: AppTypography.bodySm.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.copy, size: 14, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Block Explorer:',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                'sepolia.etherscan.io',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 48,
            color: AppColors.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada bukti perjalanan.',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selesaikan trip untuk membuat bukti perjalanan di blockchain.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripProofCard(
    BuildContext context,
    TripModel trip,
    TripProofModel? proof,
    BlockchainProvider chain,
    int userId,
  ) {
    final status = proof?.status ?? 'uncreated';
    final hasProof = proof != null;

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'confirmed':
        statusColor = const Color(0xFF1B5E20);
        statusBgColor = const Color(0xFFE8F5E9);
        statusIcon = Icons.verified;
        statusText = 'Bukti tercatat di blockchain';
        break;
      case 'simulated':
      case 'dry_run':
        statusColor = const Color(0xFF00695C);
        statusBgColor = const Color(0xFFE0F2F1);
        statusIcon = Icons.science_outlined;
        statusText = 'Simulasi Valid (Dry-Run)';
        break;
      case 'pending':
        statusColor = const Color(0xFFE65100);
        statusBgColor = const Color(0xFFFFF3E0);
        statusIcon = Icons.hourglass_top_rounded;
        statusText = 'Bukti sedang diproses';
        break;
      case 'failed':
        statusColor = AppColors.error;
        statusBgColor = AppColors.errorContainer;
        statusIcon = Icons.error_outline;
        statusText = 'Gagal mencatat bukti. Coba lagi';
        break;
      case 'needs_review':
        statusColor = Colors.deepOrange;
        statusBgColor = Colors.deepOrange.withAlpha(30);
        statusIcon = Icons.help_outline;
        statusText = 'Perlu pemeriksaan';
        break;
      case 'uncreated':
      default:
        statusColor = AppColors.onSurfaceVariant;
        statusBgColor = AppColors.surfaceContainerHigh;
        statusIcon = Icons.pending_actions;
        statusText = 'Belum dibuat';
        break;
    }

    final visitedCount = trip.items.where((i) => i.isCompleted).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
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
          // 1. Header Kartu: Judul Trip & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BUKTI PERJALANAN',
                      style: AppTypography.labelSm.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trip.tripName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelSm.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Ringkasan Destinasi & Tanggal
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$visitedCount/${trip.items.length} Destinasi Tercatat',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trip.startDate,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (hasProof) ...[
            const Divider(height: 20),
            // Proof Hash
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Hash Bukti (SHA-256):',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: proof.proofHash));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proof Hash disalin!')),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        BlockchainProofHelper.formatShortHash(proof.proofHash),
                        style: AppTypography.bodySm.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurface,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.copy,
                        size: 12,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // TX Hash
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'TX Hash:',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (proof.txHash != null && proof.txHash!.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: proof.txHash!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('TX Hash disalin!')),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          BlockchainProofHelper.formatShortHash(proof.txHash),
                          style: AppTypography.bodySm.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.copy,
                          size: 12,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  )
                else if (proof.isSimulated)
                  Flexible(
                    child: Text(
                      'Simulasi off-chain (Mode Dry-Run)',
                      style: AppTypography.bodySm.copyWith(
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF00695C),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      'Menunggu penambangan blok',
                      style: AppTypography.bodySm.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons
          if (!hasProof)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: chain.isGeneratingProof
                    ? null
                    : () async {
                        final session = SupabaseService().currentSession;
                        await chain.generateProofForTrip(
                          trip: trip,
                          userId: userId,
                          userJwtToken: session?.accessToken,
                        );
                        if (context.mounted) {
                          if (chain.proofError != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal: ${chain.proofError}'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bukti perjalanan berhasil dibuat dan dicatat!',
                                ),
                              ),
                            );
                          }
                        }
                      },
                icon: chain.isGeneratingProof
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.verified_outlined, size: 18),
                label: Text(
                  chain.isGeneratingProof
                      ? 'Memproses Bukti...'
                      : 'Buat Bukti Perjalanan',
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
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    // Tombol Lihat di Blockchain
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: proof.blockExplorerUrl != null
                            ? () async {
                                final urlString = proof.blockExplorerUrl!;
                                final uri = Uri.parse(urlString);
                                bool launched = false;
                                try {
                                  launched = await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } catch (_) {}

                                if (!launched) {
                                  try {
                                    launched = await launchUrl(
                                      uri,
                                      mode: LaunchMode.platformDefault,
                                    );
                                  } catch (_) {}
                                }

                                if (!launched) {
                                  await Clipboard.setData(
                                    ClipboardData(text: urlString),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Tautan Etherscan disalin ke clipboard:\n$urlString',
                                        ),
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              }
                            : (proof.isSimulated
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Mode Dry-Run: Transaksi tidak disiarkan on-chain, sehingga tidak ada data di Sepolia Explorer.',
                                        ),
                                      ),
                                    );
                                  }
                                : null),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text(
                          'Lihat di Explorer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Tombol Verifikasi Bukti
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: chain.isVerifying
                            ? null
                            : () => _showVerificationBottomSheet(
                                context,
                                proof,
                                chain,
                              ),
                        icon: const Icon(Icons.fact_check_outlined, size: 16),
                        label: const Text(
                          'Verifikasi Bukti',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondaryContainer,
                          foregroundColor: AppColors.onSecondaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (proof.isPending || proof.isFailed) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: chain.isGeneratingProof
                          ? null
                          : () async {
                              final session = SupabaseService().currentSession;
                              await chain.generateProofForTrip(
                                trip: trip,
                                userId: userId,
                                userJwtToken: session?.accessToken,
                              );
                              if (context.mounted) {
                                if (chain.proofError != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Gagal: ${chain.proofError}'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Bukti perjalanan berhasil disinkronkan ke server!',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: chain.isGeneratingProof
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 16),
                      label: Text(
                        chain.isGeneratingProof
                            ? 'Menyinkronkan...'
                            : 'Sinkronkan / Perbarui Bukti (Dry-Run)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusMd,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  void _showVerificationBottomSheet(
    BuildContext context,
    TripProofModel proof,
    BlockchainProvider chain,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return FutureBuilder<Map<String, dynamic>>(
          future: chain.verifyProof(proof),
          builder: (ctx, snapshot) {
            final isWaiting =
                snapshot.connectionState == ConnectionState.waiting;
            final result = snapshot.data;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Audit Verifikasi Bukti Digital',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verifikasi kriptografis deterministik antara snapshot lokal dan kondisi on-chain.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isWaiting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Memverifikasi hash dan state Ethereum Sepolia...',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (result != null) ...[
                    // Item 1: Hash Snapshot Lokal
                    _buildVerificationRow(
                      title: 'Hash Snapshot Lokal (SHA-256)',
                      isValid: result['isLocalHashValid'] == true,
                      description: result['isLocalHashValid'] == true
                          ? 'Snapshot kanonis trip cocok 100% dengan hash bukti.'
                          : 'Peringatan: Snapshot lokal tidak cocok dengan hash!',
                    ),
                    const SizedBox(height: 12),

                    // Item 2: Status Transaksi / Simulasi
                    _buildVerificationRow(
                      title: proof.isSimulated
                          ? 'Status Simulasi Eksekusi'
                          : 'Status Transaksi di Sepolia',
                      isValid: proof.isSimulated
                          ? true
                          : result['isTxReceiptValid'] == true,
                      description: proof.isSimulated
                          ? 'Mode Dry-Run: Simulasi staticCall smart contract Sepolia berhasil tanpa revert (on-chain broadcast dinonaktifkan secara aman).'
                          : (result['isTxReceiptValid'] == true
                                ? 'Receipt transaksi terkonfirmasi status 0x1 pada node Sepolia.'
                                : (proof.isPending
                                      ? 'Transaksi sedang menunggu mining di mempool testnet.'
                                      : 'Receipt transaksi on-chain belum ditemukan.')),
                    ),
                    const SizedBox(height: 12),

                    // Item 3: Catatan Keberadaan Fisik & Fraud
                    _buildVerificationRow(
                      title: 'Stempel Waktu Digital (Proof of Visit)',
                      isValid: true,
                      description:
                          'Tervalidasi sebagai catatan perjalanan pengguna. Blockchain mencatat hash secara imutabel; bukan verifikasi sensor hardware anti-fraud mutlak.',
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                      child: Text(
                        result['details'] ?? '',
                        style: AppTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetCtx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusMd,
                            ),
                          ),
                        ),
                        child: const Text('Tutup Verifikasi'),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerificationRow({
    required String title,
    required bool isValid,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.warning_rounded,
          color: isValid ? const Color(0xFF1B5E20) : AppColors.error,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrivacyAndFraudDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withAlpha(120),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Privasi & Kejujuran Sistem',
                style: AppTypography.titleSm.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• Nol Data Pribadi (Zero PII): Nama asli, email, nomor HP, detail anggaran, dan catatan pribadi TIDAK pernah disimpan di blockchain.\n'
            '• Nilai Trip ID disamarkan menggunakan Salt 32-byte berkekuatan kriptografis.\n'
            '• Pencatatan blockchain menjamin keaslian stempel waktu dan integritas ringkasan trip, bukan pembuktian lokasi absolut anti-fraud.',
            style: AppTypography.bodySm.copyWith(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: LEDGER KONSERVASI MERAPI (EDUKASI - PRD FR-14)
  // ===========================================================================
  Widget _buildConservationLedgerTab(
    BuildContext context,
    BlockchainProvider chain,
    bool isChainValid,
  ) {
    return ListView(
      key: const Key('conservation_ledger_list'),
      padding: const EdgeInsets.only(bottom: 40),
      children: [
        // Live Status Banner
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

        // Hero Header Section
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isChainValid
                          ? AppColors.surfaceContainerHigh
                          : AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isChainValid ? Icons.verified : Icons.error,
                          size: 14,
                          color: isChainValid
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isChainValid ? 'Rantai Valid' : 'Rantai Rusak!',
                          style: AppTypography.labelSm.copyWith(
                            color: isChainValid
                                ? AppColors.primary
                                : AppColors.error,
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
            ],
          ),
        ),

        // Connected Blockchain Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
          child: Column(
            children: chain.blocks.reversed.map((block) {
              return _buildBlockCard(context, block, chain);
            }).toList(),
          ),
        ),

        // Card Cek Integritas Rantai & Tamper Test Action
        _buildAuditActionSection(context, chain),
      ],
    );
  }

  Widget _buildBlockCard(
    BuildContext context,
    BlockModel block,
    BlockchainProvider chain,
  ) {
    final isGenesis = block.index == 1;
    final isTampered = block.isTampered;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: isTampered
            ? AppColors.errorContainer.withAlpha(50)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: isTampered
            ? Border.all(color: AppColors.error, width: 1.5)
            : null,
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
                      : (isGenesis
                            ? AppColors.surfaceContainerHighest
                            : AppColors.primary),
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
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isGenesis
                                  ? AppColors.surfaceContainer
                                  : AppColors.secondaryContainer,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSm,
                              ),
                            ),
                            child: Text(
                              isGenesis ? 'Genesis Block' : 'Blok Riwayat Sah',
                              style: AppTypography.labelSm.copyWith(
                                color: isGenesis
                                    ? AppColors.onSurfaceVariant
                                    : AppColors.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                        color: isTampered
                            ? AppColors.error
                            : AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            block.dataPayload,
            style: AppTypography.bodySm.copyWith(
              color: isTampered ? AppColors.error : AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hash: ${block.hash}',
            style: AppTypography.bodySm.copyWith(
              fontFamily: 'monospace',
              fontSize: 10,
              color: isTampered ? AppColors.error : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditActionSection(
    BuildContext context,
    BlockchainProvider chain,
  ) {
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
                Expanded(
                  child: Text(
                    'Cek Integritas Rantai',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMd.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Audit integritas memeriksa kesinambungan signature hash dari Blok Genesis hingga transaksi mutakhir.',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: chain.isAuditing
                    ? null
                    : () => chain.runChainAudit(),
                icon: chain.isAuditing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.fact_check, size: 18),
                label: Text(
                  chain.isAuditing
                      ? 'Mengaudit SHA-256 Rantai...'
                      : 'Validasi Seluruh Rantai Blok',
                  style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: chain.isChainValid
                    ? AppColors.surfaceContainerLow
                    : AppColors.errorContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              ),
              child: Row(
                children: [
                  Icon(
                    chain.isChainValid ? Icons.check_circle : Icons.warning,
                    color: chain.isChainValid
                        ? AppColors.primary
                        : AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chain.auditStatus,
                      style: AppTypography.bodySm.copyWith(
                        color: chain.isChainValid
                            ? AppColors.primary
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: chain.isTamperedState
                        ? () => chain.restoreChain()
                        : () => chain.simulateTamper(3),
                    icon: Icon(
                      chain.isTamperedState
                          ? Icons.restart_alt
                          : Icons.bug_report,
                      size: 16,
                      color: chain.isTamperedState
                          ? AppColors.primary
                          : AppColors.error,
                    ),
                    label: Text(
                      chain.isTamperedState
                          ? 'Pulihkan Rantai Asli'
                          : 'Simulasi Manipulasi (Tamper Test)',
                      style: TextStyle(
                        color: chain.isTamperedState
                            ? AppColors.primary
                            : AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: chain.isTamperedState
                            ? AppColors.primary
                            : AppColors.error,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
