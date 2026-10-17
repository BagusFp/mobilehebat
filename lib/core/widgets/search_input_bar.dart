import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

class SearchInputBar extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onFilterTap;
  final VoidCallback? onClear;
  final String hintText;
  final bool showFilterButton;
  final int activeFilterCount;
  final bool readOnly;
  final VoidCallback? onTap;

  const SearchInputBar({
    super.key,
    this.controller,
    this.onChanged,
    this.onFilterTap,
    this.onClear,
    this.hintText = 'Cari destinasi, bunker, plunyon...',
    this.showFilterButton = true,
    this.activeFilterCount = 0,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final effectiveHeight = (AppDimensions.inputHeight * textScale).clamp(AppDimensions.inputHeight, 68.0);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: effectiveHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              borderRadius: AppDimensions.roundedMd,
              border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
            ),
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              readOnly: readOnly,
              onTap: onTap,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.onSurfaceVariant.withAlpha(160),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                suffixIcon: (controller != null && controller!.text.isNotEmpty)
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: AppColors.onSurfaceVariant,
                        onPressed: () {
                          controller!.clear();
                          if (onChanged != null) onChanged!('');
                          if (onClear != null) onClear!();
                        },
                      )
                    : null,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (showFilterButton) ...[
          const SizedBox(width: 8),
          Stack(
            children: [
              Container(
                height: effectiveHeight,
                width: effectiveHeight,
                decoration: BoxDecoration(
                  color: activeFilterCount > 0 ? AppColors.primary : AppColors.surfaceContainer,
                  borderRadius: AppDimensions.roundedMd,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: activeFilterCount > 0 ? AppColors.onPrimary : AppColors.primary,
                    size: 22,
                  ),
                  onPressed: onFilterTap,
                ),
              ),
              if (activeFilterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.volcanoStatusWaspada,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        '$activeFilterCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
