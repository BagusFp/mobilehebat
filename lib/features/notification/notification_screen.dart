import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';

import '../map/map_screen.dart';
import '../trip/my_trip_screen.dart';
import 'notification_model.dart';
import 'notification_provider.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = context.watch<NotificationProvider>();
    final notifications = notifProvider.filteredNotifications;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest.withAlpha(230),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Notifikasi & Pengingat',
          style: AppTypography.titleMd.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: AppColors.primary),
            tooltip: 'Tandai Semua Dibaca',
            onPressed: () {
              notifProvider.markAllAsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Semua notifikasi ditandai sudah dibaca.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.margin,
            AppDimensions.spaceSm,
            AppDimensions.margin,
            AppDimensions.spaceXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Interactive Filter Chips
              _buildFilterChips(notifProvider),
              const SizedBox(height: AppDimensions.spaceMd),

              // 2. Active Scheduled Alarm Banner Card
              _buildAlarmBannerCard(context, notifProvider),
              const SizedBox(height: AppDimensions.spaceLg),

              // 3. Notification Feed Header & Mark All Read
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Aktivitas Terbaru',
                            style: AppTypography.headlineSm.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (notifProvider.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text(
                              '${notifProvider.unreadCount} Baru',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: () => notifProvider.markAllAsRead(),
                      icon: const Icon(Icons.done_all, size: 16, color: AppColors.primary),
                      label: Text(
                        'Tandai Dibaca',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spaceSm),

              // 4. Notification List or Empty State
              if (notifications.isEmpty)
                _buildEmptyState()
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final item = notifications[idx];
                    return _buildNotificationCard(context, item, notifProvider);
                  },
                ),

              const SizedBox(height: AppDimensions.spaceLg),

              // 5. Footer Push Notification Settings Link
              _buildFooterSettings(context),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Filter Chips
  Widget _buildFilterChips(NotificationProvider provider) {
    final active = provider.activeFilter;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            label: 'Semua',
            icon: Icons.all_inbox,
            isSelected: active == 'all',
            hasDot: true,
            dotColor: AppColors.secondary,
            onTap: () => provider.setFilter('all'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Pengingat Trip',
            icon: Icons.hiking,
            isSelected: active == 'trip',
            badgeText: '1',
            onTap: () => provider.setFilter('trip'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Info Vulkanik',
            icon: Icons.volcano,
            isSelected: active == 'volcano',
            hasDot: true,
            dotColor: AppColors.error,
            onTap: () => provider.setFilter('volcano'),
          ),
          const SizedBox(width: 8),
          _buildChip(
            label: 'Sistem & Notifikasi',
            icon: Icons.notifications_active_outlined,
            isSelected: active == 'system',
            onTap: () => provider.setFilter('system'),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool hasDot = false,
    Color? dotColor,
    String? badgeText,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            if (hasDot && dotColor != null) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
            ],
            if (badgeText != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.onPrimary.withAlpha(50)
                      : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text(
                  badgeText,
                  style: AppTypography.labelSm.copyWith(
                    color: isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 2. Active Alarm Banner Card
  Widget _buildAlarmBannerCard(BuildContext context, NotificationProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.alarm_on, size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PENJADWALAN LOKAL AKTIF',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Eksplorasi Merapi 1 Hari',
                            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: provider.isAlarmEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (val) {
                  provider.toggleAlarm(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(val
                          ? 'Pengingat alarm offline diaktifkan.'
                          : 'Pengingat alarm offline dinonaktifkan.'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pin_drop, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                      children: const [
                        TextSpan(text: 'Pukul '),
                        TextSpan(
                          text: '06:00 WIB ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        TextSpan(
                          text:
                              'tujuan Plunyon Kalikuning. Alarm bersuara lembut otomatis terpicu tanpa butuh koneksi internet.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Timing Chips
          Text(
            'Pilih Waktu Bunyi Alarm:',
            style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: ['H-1 Hari', 'H-2 Jam', 'H-1 Jam'].map((timing) {
              final isSel = provider.alarmTiming == timing;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: provider.isAlarmEnabled
                        ? () => provider.setAlarmTiming(timing)
                        : null,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.primary : AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Text(
                        timing,
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSm.copyWith(
                          color: isSel ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // 3. Notification Card
  Widget _buildNotificationCard(
    BuildContext context,
    NotificationModel notif,
    NotificationProvider provider,
  ) {
    Color stripColor = AppColors.outlineVariant;
    Color iconBg = AppColors.surfaceContainerHigh;
    Color iconColor = AppColors.onSurfaceVariant;
    IconData icon = Icons.notifications;

    if (notif.category == 'volcano') {
      stripColor = AppColors.error;
      iconBg = AppColors.errorContainer;
      iconColor = AppColors.error;
      icon = Icons.warning;
    } else if (notif.category == 'trip') {
      stripColor = AppColors.secondary;
      iconBg = AppColors.secondaryContainer;
      iconColor = AppColors.onSecondaryContainer;
      icon = Icons.departure_board;
    } else if (notif.category == 'system') {
      stripColor = AppColors.primary;
      iconBg = AppColors.surfaceContainer;
      iconColor = AppColors.primary;
      icon = notif.title.contains('Unduhan') ? Icons.cloud_download : Icons.military_tech;
    }

    return InkWell(
      onTap: () => provider.markAsRead(notif.id),
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        decoration: BoxDecoration(
          color: notif.isRead
              ? AppColors.surfaceContainerLowest.withAlpha(200)
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category Color Strip
              Container(
                width: 5,
                color: notif.isRead ? stripColor.withAlpha(80) : stripColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spaceMd),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                        child: Icon(icon, size: 20, color: iconColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: stripColor.withAlpha(25),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      notif.tag,
                                      style: AppTypography.labelSm.copyWith(
                                        color: stripColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  notif.timeAgo,
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif.title,
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif.body,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            if (notif.actionText != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (notif.category == 'volcano') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const MapScreen()),
                                        );
                                      } else if (notif.category == 'trip') {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const MyTripScreen()),
                                        );
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          notif.actionText!,
                                          style: AppTypography.labelMd.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                  if (!notif.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Empty State
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spaceXl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_paused, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            'Belum Ada Notifikasi Baru',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua info pembaruan trip dan peringatan vulkanik untuk kategori ini sudah terpantau rapi.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // 5. Footer Settings Link
  Widget _buildFooterSettings(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pengaturan Notifikasi Push',
                        style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Suara sirine darurat & update cuaca',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: AppColors.onSurfaceVariant),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preferensi notifikasi push lokal tersimpan.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
