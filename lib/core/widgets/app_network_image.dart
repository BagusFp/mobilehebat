import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widget gambar jaringan teroptimasi untuk menghemat RAM dan mencegah lag saat scrolling.
/// Menggunakan `cacheWidth` untuk mendecode bitmap sesuai ukuran tampilan kartu.
class AppNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int cacheWidth;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.cacheWidth = 600,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || !imageUrl!.startsWith('http')) {
      return errorWidget ?? _defaultPlaceholder();
    }

    return Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      cacheWidth: cacheWidth,
      filterQuality: FilterQuality.low, // Lebih hemat CPU & GPU saat scrolling cepat
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ??
            Container(
              width: width,
              height: height,
              color: AppColors.surfaceContainerHigh,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: AppColors.primary,
                  ),
                ),
              ),
            );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _defaultPlaceholder();
      },
    );
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryContainer,
      child: const Center(
        child: Icon(
          Icons.landscape,
          color: AppColors.onPrimary,
          size: 32,
        ),
      ),
    );
  }
}
