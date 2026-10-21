import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

class DestinationCard extends StatelessWidget {
  final int id;
  final String name;
  final String category;
  final String address;
  final double ticketPrice;
  final int elevationMdpl;
  final String? imageUrl;
  final double? distanceKm;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onAddToTripTap;

  const DestinationCard({
    super.key,
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.ticketPrice,
    this.elevationMdpl = 800,
    this.imageUrl,
    this.distanceKm,
    this.isFavorite = false,
    this.onTap,
    this.onFavoriteTap,
    this.onAddToTripTap,
  });

  String _formatPrice(double price) {
    if (price <= 0) return 'Gratis';
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(price);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedLg,
        border: Border.all(color: AppColors.surfaceContainer, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDimensions.roundedLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bagian Gambar / Banner
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusLg),
                    ),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      color: AppColors.primaryContainer,
                      child: (imageUrl != null && imageUrl!.startsWith('http'))
                          ? Image.network(
                              imageUrl!,
                              fit: BoxFit.cover,
                              cacheWidth: 600,
                              errorBuilder: (_, _, _) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                  ),

                  // Kategori Tag
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(220),
                        borderRadius: AppDimensions.roundedFull,
                      ),
                      child: Text(
                        category,
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),

                  // Elevasi MDPL Badge
                  Positioned(
                    top: 10,
                    right: 48,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        borderRadius: AppDimensions.roundedFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.terrain_rounded, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '$elevationMdpl mdpl',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tombol Favorit
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white.withAlpha(220),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: onFavoriteTap,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.all(6.0),
                          child: Icon(
                            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 18,
                            color: isFavorite ? Colors.red : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Bagian Konten
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            style: AppTypography.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (distanceKm != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: AppDimensions.roundedSm,
                            ),
                            child: Text(
                              '${distanceKm!.toStringAsFixed(1)} km',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Baris Harga & Aksi
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tiket Masuk',
                                style: AppTypography.bodySmall.copyWith(fontSize: 10),
                              ),
                              Text(
                                _formatPrice(ticketPrice),
                                style: AppTypography.titleMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (onAddToTripTap != null)
                          ElevatedButton.icon(
                            onPressed: onAddToTripTap,
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: const Text('Trip', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainer,
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppDimensions.roundedFull,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.landscape_rounded, size: 36, color: Colors.white70),
            const SizedBox(height: 4),
            Text(
              'Wisata Merapi',
              style: AppTypography.labelSmall.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
