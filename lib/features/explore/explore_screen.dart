import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';
import '../../data/models/destination_model.dart';
import '../auth/auth_provider.dart';
import 'destination_detail_screen.dart';
import 'destination_provider.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<DestinationProvider>().loadDestinations(userId: auth.currentUser?.id);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatCurrency(double price) {
    if (price <= 0) return 'Gratis';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }

  void _showSortModal(BuildContext context) {
    final provider = context.read<DestinationProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.margin,
              vertical: AppDimensions.spaceMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Text(
                  'Urutkan Destinasi Berdasarkan',
                  style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                ...[
                  'Destinasi Populer',
                  'Biaya Terendah',
                  'Terdekat',
                ].map((option) {
                  final isSelected = provider.sortOption == option;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      option,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? AppColors.primary : AppColors.onSurface,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      provider.setSortOption(option);
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.margin,
              vertical: AppDimensions.spaceMd,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filter Destinasi',
                      style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<DestinationProvider>().setSelectedCategory('Semua');
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  'Kawasan Lereng',
                  style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      selected: true,
                      label: const Text('Cangkringan'),
                      onSelected: (_) {},
                      selectedColor: AppColors.secondaryContainer,
                    ),
                    FilterChip(
                      selected: false,
                      label: const Text('Pakem / Kaliurang'),
                      onSelected: (_) {},
                    ),
                    FilterChip(
                      selected: false,
                      label: const Text('Klaten & Selo'),
                      onSelected: (_) {},
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceLg),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppDimensions.roundedLg,
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Terapkan Filter'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DestinationProvider>();
    final auth = context.watch<AuthProvider>();
    final destinations = provider.displayedDestinations;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await provider.loadDestinations(userId: auth.currentUser?.id);
          },
          child: CustomScrollView(
            slivers: [
              // 3. Search & Filter Bar Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.margin,
                    vertical: AppDimensions.spaceSm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppDimensions.roundedXl,
                            border: Border.all(color: AppColors.surfaceContainer),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) => provider.setSearchQuery(val),
                            decoration: InputDecoration(
                              hintText: 'Cari destinasi, lokasi, atau kategori...',
                              hintStyle: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.onSurfaceVariant,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        provider.clearSearch();
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spaceSm),
                      // Filter Button with Badge
                      Stack(
                        children: [
                          InkWell(
                            onTap: () => _showFilterModal(context),
                            borderRadius: AppDimensions.roundedXl,
                            child: Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: AppDimensions.roundedXl,
                                border: Border.all(color: AppColors.surfaceContainer),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tune, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text('Filter', style: AppTypography.labelMd),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: const BoxDecoration(
                                color: AppColors.primaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '2',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onPrimary,
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
                  ),
                ),
              ),

              // 4. Horizontal Category Chips
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                    scrollDirection: Axis.horizontal,
                    itemCount: provider.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (ctx, idx) {
                      final cat = provider.categories[idx];
                      final isSelected = provider.selectedCategory == cat.name;

                      return InkWell(
                        onTap: () => provider.setSelectedCategory(cat.name),
                        borderRadius: AppDimensions.roundedFull,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryContainer
                                : AppColors.surfaceContainerLowest,
                            borderRadius: AppDimensions.roundedFull,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryContainer
                                  : AppColors.surfaceContainer,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getCategoryIcon(cat.iconName),
                                size: 16,
                                color: isSelected
                                    ? AppColors.onPrimary
                                    : AppColors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.name,
                                style: AppTypography.labelMd.copyWith(
                                  color: isSelected
                                      ? AppColors.onPrimary
                                      : AppColors.onSurfaceVariant,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 5. Sort & View Controls Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: AppDimensions.margin,
                    right: AppDimensions.margin,
                    top: AppDimensions.spaceSm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => _showSortModal(context),
                        borderRadius: AppDimensions.roundedFull,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: AppDimensions.roundedFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.swap_vert,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Urutkan: ${provider.sortOption}',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, size: 16),
                            ],
                          ),
                        ),
                      ),
                      // View Mode Toggle (List / Grid)
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: AppDimensions.roundedLg,
                          border: Border.all(color: AppColors.surfaceContainer),
                        ),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () => provider.setViewMode(false),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: !provider.isGridView
                                      ? AppColors.surfaceContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.format_list_bulleted,
                                  size: 18,
                                  color: !provider.isGridView
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => provider.setViewMode(true),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: provider.isGridView
                                      ? AppColors.surfaceContainer
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.grid_view,
                                  size: 18,
                                  color: provider.isGridView
                                      ? AppColors.primary
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Result Counter & Offline Mode Status
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.margin,
                    vertical: AppDimensions.spaceSm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Menampilkan ${destinations.length} destinasi terverifikasi',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (provider.isUsingCachedData)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off_rounded,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Mode Offline Aktif',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // 7. Destinations Feed (Single Column or Grid)
              if (destinations.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.margin,
                      vertical: AppDimensions.spaceXl,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            provider.offlineNotice != null
                                ? Icons.cloud_off_rounded
                                : Icons.search_off,
                            size: 56,
                            color: provider.offlineNotice != null
                                ? AppColors.secondary
                                : AppColors.outlineVariant,
                          ),
                          const SizedBox(height: AppDimensions.spaceSm),
                          Text(
                            provider.offlineNotice != null
                                ? 'Data Butuh Koneksi Internet'
                                : 'Tidak ada destinasi ditemukan',
                            style: AppTypography.titleMd.copyWith(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.offlineNotice ??
                                'Coba ganti kata kunci atau pilih kategori lain.',
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!provider.isGridView)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final dest = destinations[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
                          child: _buildListCard(context, dest, provider, auth),
                        );
                      },
                      childCount: destinations.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.margin),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppDimensions.spaceSm,
                      mainAxisSpacing: AppDimensions.spaceSm,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        final dest = destinations[idx];
                        return _buildGridCard(context, dest, provider, auth);
                      },
                      childCount: destinations.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context,
    DestinationModel dest,
    DestinationProvider provider,
    AuthProvider auth,
  ) {
    final isFav = provider.isFavorite(dest.id);
    final isOffline = provider.isSavedOffline(dest.id);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppDimensions.roundedXl,
        border: Border.all(color: AppColors.surfaceContainer),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Area
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppDimensions.radiusXl),
                ),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  color: AppColors.primaryContainer,
                  child: dest.imageUrl != null && dest.imageUrl!.startsWith('http')
                      ? Image.network(
                          dest.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),
              // Gradient Scrim
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusXl),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(50),
                        Colors.transparent,
                        Colors.black.withAlpha(120),
                      ],
                    ),
                  ),
                ),
              ),
              // Top Badges
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    if (isOffline)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(220),
                          borderRadius: AppDimensions.roundedFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.offline_pin,
                              size: 13,
                              color: AppColors.onPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tersimpan Offline',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onPrimary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest.withAlpha(230),
                        borderRadius: AppDimensions.roundedFull,
                      ),
                      child: Text(
                        dest.categoryName,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurface,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Top Right Micro Buttons
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => provider.toggleFavorite(dest.id, userId: auth.currentUser?.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withAlpha(230),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: isFav ? AppColors.error : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => provider.toggleOfflineSave(dest.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withAlpha(230),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOffline ? Icons.download_done : Icons.download,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Distance & Elevation Overlay
              Positioned(
                bottom: 10,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.landscape,
                          size: 14,
                          color: AppColors.secondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dest.elevationMdpl} mdpl',
                          style: AppTypography.labelSm.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me,
                          size: 14,
                          color: AppColors.secondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${dest.distanceKm} km dari Pos',
                          style: AppTypography.labelSm.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dest.name,
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  dest.address,
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Tiket Masuk',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          dest.ticketPrice > 0 ? _formatCurrency(dest.ticketPrice) : 'Gratis',
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spaceSm),
                Text(
                  dest.description,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spaceMd),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: AppDimensions.roundedLg,
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DestinationDetailScreen(destination: dest),
                              ),
                            );
                          },
                          icon: Text('Lihat Detail', style: AppTypography.labelLg),
                          label: const Icon(Icons.arrow_forward, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spaceSm),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DestinationDetailScreen(destination: dest),
                          ),
                        );
                      },
                      borderRadius: AppDimensions.roundedLg,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: AppDimensions.roundedLg,
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: AppColors.primary,
                          size: 20,
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
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    DestinationModel dest,
    DestinationProvider provider,
    AuthProvider auth,
  ) {
    final isFav = provider.isFavorite(dest.id);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(destination: dest),
          ),
        );
      },
      borderRadius: AppDimensions.roundedLg,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppDimensions.roundedLg,
          border: Border.all(color: AppColors.surfaceContainer),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.radiusLg),
                    ),
                    child: dest.imageUrl != null && dest.imageUrl!.startsWith('http')
                        ? Image.network(
                            dest.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: () => provider.toggleFavorite(dest.id, userId: auth.currentUser?.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest.withAlpha(230),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isFav ? AppColors.error : AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(160),
                        borderRadius: AppDimensions.roundedSm,
                      ),
                      child: Text(
                        '${dest.elevationMdpl} mdpl',
                        style: AppTypography.labelSm.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dest.name,
                    style: AppTypography.titleMd.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dest.ticketPrice > 0 ? _formatCurrency(dest.ticketPrice) : 'Gratis',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'park':
        return Icons.park;
      case 'history_edu':
        return Icons.history_edu;
      case 'school':
        return Icons.school;
      case 'hiking':
        return Icons.hiking;
      case 'directions_car':
        return Icons.directions_car;
      case 'travel_explore':
      default:
        return Icons.travel_explore;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryContainer,
      child: const Center(
        child: Icon(
          Icons.landscape,
          color: AppColors.onPrimary,
          size: 40,
        ),
      ),
    );
  }
}
