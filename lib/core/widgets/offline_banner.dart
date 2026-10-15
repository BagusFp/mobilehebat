import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onManageOfflineTap;

  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.onManageOfflineTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: AppColors.offlineBg,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: AppColors.offline),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mode Offline Aktif • Menggunakan data lokal lereng Merapi',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.offline,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
          if (onManageOfflineTap != null)
            InkWell(
              onTap: onManageOfflineTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  'Kelola',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
