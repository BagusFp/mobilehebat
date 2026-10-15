import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

class BudgetSummaryCard extends StatelessWidget {
  final double targetBudget;
  final double ticketCost;
  final double transportCost;
  final double otherCost;

  const BudgetSummaryCard({
    super.key,
    required this.targetBudget,
    required this.ticketCost,
    required this.transportCost,
    required this.otherCost,
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
    final totalSpent = ticketCost + transportCost + otherCost;
    final remaining = targetBudget - totalSpent;
    final progress = targetBudget > 0 ? (totalSpent / targetBudget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = remaining < 0;

    return Container(
      padding: AppDimensions.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedLg,
        border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Kalkulator Rencana Budget',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOverBudget ? AppColors.errorContainer : AppColors.surfaceContainer,
                  borderRadius: AppDimensions.roundedFull,
                ),
                child: Text(
                  isOverBudget ? 'Melebihi Budget' : 'Anggaran Aman',
                  style: AppTypography.labelSmall.copyWith(
                    color: isOverBudget ? AppColors.error : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Total & Target
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Estimasi', style: AppTypography.bodySmall),
                  Text(
                    _formatCurrency(totalSpent),
                    style: AppTypography.headlineSmall.copyWith(
                      color: isOverBudget ? AppColors.error : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Target Anggaran', style: AppTypography.bodySmall),
                  Text(
                    _formatCurrency(targetBudget),
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          ClipRRect(
            borderRadius: AppDimensions.roundedFull,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(
                isOverBudget ? AppColors.error : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Rincian Baris
          _buildBreakdownRow('Tiket Destinasi Terpilih', ticketCost),
          const SizedBox(height: 4),
          _buildBreakdownRow('Transportasi & BBM Lereng', transportCost),
          const SizedBox(height: 4),
          _buildBreakdownRow('Logistik & Tak Terduga', otherCost),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sisa Anggaran Cadangan',
                style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                _formatCurrency(remaining.abs()),
                style: AppTypography.titleSmall.copyWith(
                  color: isOverBudget ? AppColors.error : AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySmall),
        Text(
          _formatCurrency(amount),
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
