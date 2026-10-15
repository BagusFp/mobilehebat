import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

class TripCard extends StatelessWidget {
  final int id;
  final String title;
  final String date;
  final int participants;
  final double budget;
  final double totalEstimatedCost;
  final String status; // 'upcoming', 'draft', 'completed'
  final bool isOfflineSaved;
  final String? timeUntilTrip;
  final VoidCallback? onTap;

  const TripCard({
    super.key,
    required this.id,
    required this.title,
    required this.date,
    required this.participants,
    required this.budget,
    required this.totalEstimatedCost,
    this.status = 'upcoming',
    this.isOfflineSaved = true,
    this.timeUntilTrip,
    this.onTap,
  });

  String _formatCurrency(double val) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(val);
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (status == 'upcoming') {
      statusColor = AppColors.primary;
      statusLabel = 'Terkonfirmasi • Siap Jalan';
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'completed') {
      statusColor = AppColors.outline;
      statusLabel = 'Selesai';
      statusIcon = Icons.done_all_rounded;
    } else {
      statusColor = AppColors.volcanoStatusWaspada;
      statusLabel = 'Rencana Draft';
      statusIcon = Icons.edit_note_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedLg,
        border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimensions.roundedLg,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Baris Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(20),
                        borderRadius: AppDimensions.roundedFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 13, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: AppTypography.labelSmall.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOfflineSaved)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: AppDimensions.roundedFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_done_rounded, size: 12, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              'Offline Siap',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Judul Trip
                Text(
                  title,
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 6),

                // Info Tanggal & Partisipan
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(date, style: AppTypography.bodySmall),
                    const SizedBox(width: 10),
                    const Icon(Icons.group_rounded, size: 14, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('$participants Orang', style: AppTypography.bodySmall),
                  ],
                ),

                if (timeUntilTrip != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppDimensions.roundedSm,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          timeUntilTrip!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Estimasi Biaya
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estimasi Biaya', style: AppTypography.bodySmall.copyWith(fontSize: 10)),
                        Text(
                          _formatCurrency(totalEstimatedCost),
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Lihat Timeline',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
