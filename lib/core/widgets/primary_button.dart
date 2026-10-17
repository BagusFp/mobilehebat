import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

enum ButtonVariant { primary, secondary, outline }

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final ButtonVariant variant;
  final double? height;
  final double? width;

  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final baseHeight = height ?? AppDimensions.buttonHeight;
    final effectiveHeight = height != null ? height! : (baseHeight * textScale).clamp(baseHeight, 72.0);

    if (variant == ButtonVariant.outline) {
      return SizedBox(
        width: width,
        height: effectiveHeight,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            shape: RoundedRectangleBorder(borderRadius: AppDimensions.roundedMd),
          ),
          child: _buildChild(AppColors.primary),
        ),
      );
    }

    final bgColor = variant == ButtonVariant.secondary
        ? AppColors.surfaceContainer
        : AppColors.primary;
    final fgColor = variant == ButtonVariant.secondary
        ? AppColors.primary
        : AppColors.onPrimary;

    return SizedBox(
      width: width,
      height: effectiveHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14.0),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.roundedMd),
        ),
        child: _buildChild(fgColor),
      ),
    );
  }

  Widget _buildChild(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTypography.labelLarge.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Text(
      text,
      style: AppTypography.labelLarge.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
