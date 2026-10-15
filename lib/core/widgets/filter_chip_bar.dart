import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

class FilterCategoryItem {
  final String id;
  final String label;
  final IconData icon;

  const FilterCategoryItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

class FilterChipBar extends StatelessWidget {
  final List<FilterCategoryItem> categories;
  final String selectedCategoryId;
  final ValueChanged<String> onSelected;

  const FilterChipBar({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  static const List<FilterCategoryItem> defaultCategories = [
    FilterCategoryItem(id: 'all', label: 'Semua', icon: Icons.travel_explore_rounded),
    FilterCategoryItem(id: 'alam', label: 'Alam', icon: Icons.park_rounded),
    FilterCategoryItem(id: 'sejarah', label: 'Sejarah', icon: Icons.history_edu_rounded),
    FilterCategoryItem(id: 'edukasi', label: 'Edukasi', icon: Icons.school_rounded),
    FilterCategoryItem(id: 'petualangan', label: 'Petualangan', icon: Icons.hiking_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = categories[index];
          final isSelected = item.id == selectedCategoryId;

          return InkWell(
            onTap: () => onSelected(item.id),
            borderRadius: AppDimensions.roundedFull,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
                borderRadius: AppDimensions.roundedFull,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 15,
                    color: isSelected ? AppColors.onPrimary : AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: AppTypography.labelMedium.copyWith(
                      color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
