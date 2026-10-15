import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

enum VolcanicStatusType { waspada, safeRadius, offline, verified }

class StatusBadge extends StatelessWidget {
  final String label;
  final VolcanicStatusType type;
  final IconData? customIcon;
  final VoidCallback? onTap;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = VolcanicStatusType.waspada,
    this.customIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData iconData;

    switch (type) {
      case VolcanicStatusType.waspada:
        bgColor = AppColors.volcanoStatusWaspadaBg;
        textColor = AppColors.volcanoStatusWaspada;
        iconData = Icons.warning_amber_rounded;
        break;
      case VolcanicStatusType.safeRadius:
        bgColor = AppColors.safeRadiusBg;
        textColor = AppColors.safeRadius;
        iconData = Icons.verified_user_rounded;
        break;
      case VolcanicStatusType.offline:
        bgColor = AppColors.offlineBg;
        textColor = AppColors.offline;
        iconData = Icons.wifi_off_rounded;
        break;
      case VolcanicStatusType.verified:
        bgColor = AppColors.surfaceContainer;
        textColor = AppColors.primary;
        iconData = Icons.check_circle_rounded;
        break;
    }

    final effectiveIcon = customIcon ?? iconData;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppDimensions.roundedFull,
        border: Border.all(color: textColor.withAlpha(40), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(effectiveIcon, size: 14, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: AppDimensions.roundedFull,
        child: badge,
      );
    }

    return badge;
  }
}
