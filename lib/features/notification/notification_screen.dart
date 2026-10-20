import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_typography.dart';

import '../map/map_screen.dart';
import '../trip/my_trip_screen.dart';
import '../trip/trip_provider.dart';
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

  Widget _buildAlarmBannerCard(BuildContext context, NotificationProvider provider) {
    TripProvider? tripProvider;
    try {
      tripProvider = Provider.of<TripProvider>(context);
    } catch (_) {
      tripProvider = null;
    }
    final activeTrip = tripProvider?.activeOrUpcomingTrip ??
        ((tripProvider?.allTrips.isNotEmpty ?? false) ? tripProvider!.allTrips.first : null);

    final tripTitle = (activeTrip != null && activeTrip.tripName.isNotEmpty)
        ? activeTrip.tripName
        : 'Eksplorasi Merapi 1 Hari';
    final firstItemTime = (activeTrip != null && activeTrip.items.isNotEmpty)
        ? activeTrip.items.first.plannedTime.split('-').first.trim()
        : null;
    final startTimeText = (firstItemTime != null && firstItemTime.isNotEmpty)
        ? '$firstItemTime WIB '
        : '06:00 WIB ';
    final destName = (activeTrip != null && activeTrip.items.isNotEmpty)
        ? activeTrip.items.first.itemName
        : 'Plunyon Kalikuning';

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
                            tripTitle,
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
                  if (activeTrip?.id != null) {
                    if (val) {
                      tripProvider?.scheduleCustomTripReminder(
                        tripId: activeTrip!.id!,
                        beforeDays: provider.reminderDays,
                        beforeHours: provider.reminderHours,
                        beforeMinutes: provider.reminderMinutes,
                      );
                    } else {
                      tripProvider?.toggleReminder(activeTrip!.id!);
                    }
                  }
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
                      children: [
                        const TextSpan(text: 'Pukul '),
                        TextSpan(
                          text: startTimeText,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        TextSpan(
                          text:
                              'tujuan $destName. Alarm bersuara lembut otomatis terpicu tanpa butuh koneksi internet.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Header Timing & Tombol Atur Sendiri
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waktu Pengingat Alarm:',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              InkWell(
                onTap: provider.isAlarmEnabled
                    ? () => _showCustomTimingSheet(context, provider, tripProvider)
                    : null,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Atur Sendiri ⏱️',
                    style: AppTypography.labelSm.copyWith(
                      color: provider.isAlarmEnabled ? AppColors.primary : AppColors.outline,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Quick Timing Chips
          Row(
            children: ['H-1 Hari', 'H-2 Jam', 'H-1 Jam'].map((timing) {
              final isSel = provider.alarmTiming == timing;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: provider.isAlarmEnabled
                        ? () {
                            provider.setAlarmTiming(timing);
                            if (activeTrip?.id != null) {
                              tripProvider?.scheduleCustomTripReminder(
                                tripId: activeTrip!.id!,
                                beforeDays: provider.reminderDays,
                                beforeHours: provider.reminderHours,
                                beforeMinutes: provider.reminderMinutes,
                              );
                            }
                          }
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

          // Kustom Info Tag jika user setting sendiri
          if (provider.alarmTiming != 'H-1 Hari' &&
              provider.alarmTiming != 'H-2 Jam' &&
              provider.alarmTiming != 'H-1 Jam') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withAlpha(200),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.onSecondaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    'Pengingat Kustom Aktif: ${provider.alarmTiming}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Tombol Uji Coba Notifikasi Sistem Langsung ke Bilah HP
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await provider.sendTestNotificationToDevice();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notifikasi uji coba berhasil dikirim ke bilah status HP!'),
                      backgroundColor: AppColors.secondary,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.notifications_active_rounded, size: 16),
              label: const Text(
                'Kirim Notifikasi Uji Coba ke HP',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Modal Pengaturan Waktu Pengingat Trip Kustom (Bebas Hari, Jam, Menit)
  void _showCustomTimingSheet(
    BuildContext context,
    NotificationProvider notifProvider,
    TripProvider? tripProvider,
  ) {
    int days = notifProvider.reminderDays;
    int hours = notifProvider.reminderHours;
    int minutes = notifProvider.reminderMinutes;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (dialogCtx, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.margin),
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
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.timer_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atur Waktu Pengingat Trip',
                              style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Tentukan berapa hari, jam, atau menit sebelum trip dimulai',
                              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Steppers 3 Kolom: Hari, Jam, Menit
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeStepper(
                          label: 'Hari',
                          value: days,
                          min: 0,
                          max: 30,
                          onChanged: (val) => setSheetState(() => days = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTimeStepper(
                          label: 'Jam',
                          value: hours,
                          min: 0,
                          max: 23,
                          onChanged: (val) => setSheetState(() => hours = val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTimeStepper(
                          label: 'Menit',
                          value: minutes,
                          min: 0,
                          max: 59,
                          step: 5,
                          onChanged: (val) => setSheetState(() => minutes = val),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Kalimat Rangkuman
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Text(
                      (days == 0 && hours == 0 && minutes == 0)
                          ? 'Notifikasi akan berbunyi tepat saat trip dimulai.'
                          : 'Notifikasi akan muncul di bilah status HP $days hari $hours jam $minutes menit sebelum waktu keberangkatan.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tombol Simpan
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        notifProvider.setCustomTiming(
                          days: days,
                          hours: hours,
                          minutes: minutes,
                        );

                        final active = tripProvider?.activeOrUpcomingTrip ??
                            ((tripProvider?.allTrips.isNotEmpty ?? false) ? tripProvider!.allTrips.first : null);
                        if (active?.id != null && notifProvider.isAlarmEnabled) {
                          tripProvider?.scheduleCustomTripReminder(
                            tripId: active!.id!,
                            beforeDays: days,
                            beforeHours: hours,
                            beforeMinutes: minutes,
                          );
                        }

                        Navigator.pop(sheetCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Pengingat trip diatur: $days Hari $hours Jam $minutes Menit sebelum keberangkatan.',
                            ),
                            backgroundColor: AppColors.secondary,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                      ),
                      child: const Text('Simpan Pengingat', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildTimeStepper({
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.surfaceContainer),
      ),
      child: Column(
        children: [
          Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('$value', style: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              InkWell(
                onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: value > min ? AppColors.surfaceContainerHigh : AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.remove, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: value < max ? AppColors.primary : AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ],
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
