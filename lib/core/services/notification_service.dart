import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static const String channelId = 'meratrip_trip_channel';
  static const String channelName = 'MeraTrip Pengingat & Eksplorasi';
  static const String channelDescription =
      'Notifikasi pengingat perjalanan, destinasi berikutnya, dan peringatan vulkanik Merapi';

  Function(String? payload)? onNotificationClick;

  /// Inisialisasi awal notifikasi lokal Android & iOS
  Future<void> init({Function(String? payload)? onClick}) async {
    if (_isInitialized) return;
    onNotificationClick = onClick;

    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTest) {
      _isInitialized = true;
      return;
    }

    try {
      // 1. Inisialisasi Database Zona Waktu
      tz.initializeTimeZones();

      // 2. Pengaturan Inisialisasi Android & iOS
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
          onNotificationClick?.call(response.payload);
        },
      );

      // 3. Buat Android Notification Channel dengan Prioritas Tertinggi (Heads-up pop up)
      final androidPlugin = _localNotifPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(channel);

        // Minta izin runtime notifikasi (khususnya Android 13+)
        await androidPlugin.requestNotificationsPermission();
      }

      _isInitialized = true;
      debugPrint('NotificationService: Inisialisasi berhasil.');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Meminta izin notifikasi ke pengguna
  Future<bool> requestPermission() async {
    try {
      final androidPlugin = _localNotifPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? true;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Detail Notifikasi Android & iOS dengan Prioritas Maksimal
  NotificationDetails _buildNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  bool get _isTestEnv {
    try {
      final binding = WidgetsBinding.instance;
      return binding.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Menampilkan Notifikasi Instan di Status Bar / Bilah Notifikasi HP
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (_isTestEnv) return;
    try {
      await _localNotifPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _buildNotificationDetails(),
        payload: payload,
      );
      debugPrint('NotificationService: Notifikasi #$id terkirim ke bilah HP.');
    } catch (e) {
      debugPrint('NotificationService.showInstantNotification warning: $e');
    }
  }

  /// Menjadwalkan Pengingat Trip Berdasarkan Setting Custom (Hari, Jam, Menit sebelum mulai)
  Future<void> scheduleTripReminder({
    required int tripId,
    required String tripTitle,
    required DateTime tripStartTime,
    required int beforeDays,
    required int beforeHours,
    required int beforeMinutes,
    String? startDestinationName,
  }) async {
    if (_isTestEnv) return;
    try {
      final totalBeforeDuration = Duration(
        days: beforeDays,
        hours: beforeHours,
        minutes: beforeMinutes,
      );

      // Waktu alarm berbunyi = Waktu mulai trip dikurangi durasi pengingat
      final triggerTime = tripStartTime.subtract(totalBeforeDuration);
      final now = DateTime.now();

      // Jika waktu pemicu alarm sudah lewat dari sekarang, jangan jadwalkan alarm masa lampau
      if (triggerTime.isBefore(now)) {
        debugPrint(
            'NotificationService: Waktu pengingat $triggerTime sudah lewat, tidak dijadwalkan.');
        return;
      }

      final tzTrigger = tz.TZDateTime.from(triggerTime, tz.local);

      // Format teks timing yang informatif
      final List<String> timingParts = [];
      if (beforeDays > 0) timingParts.add('$beforeDays hari');
      if (beforeHours > 0) timingParts.add('$beforeHours jam');
      if (beforeMinutes > 0) timingParts.add('$beforeMinutes menit');
      final timingString = timingParts.isEmpty ? 'segera' : timingParts.join(' ');

      final bodyText = startDestinationName != null
          ? 'Perjalanan menuju $startDestinationName dimulai dalam $timingString. Siapkan ransel & perlengkapan Anda!'
          : 'Trip "$tripTitle" akan dimulai dalam $timingString. Ketuk untuk membuka rute!';

      await _localNotifPlugin.zonedSchedule(
        id: tripId,
        title: '🔔 Pengingat Trip: $tripTitle',
        body: bodyText,
        scheduledDate: tzTrigger,
        notificationDetails: _buildNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: '/trip/$tripId',
      );

      debugPrint(
          'NotificationService: Alarm trip #$tripId dijadwalkan pada $triggerTime ($timingString sebelum start)');
    } catch (e) {
      debugPrint('NotificationService.scheduleTripReminder warning: $e');
    }
  }

  /// Membatalkan alarm trip tertentu
  Future<void> cancelTripReminder(int tripId) async {
    if (_isTestEnv) return;
    try {
      await _localNotifPlugin.cancel(id: tripId);
      debugPrint('NotificationService: Alarm trip #$tripId dibatalkan.');
    } catch (e) {
      debugPrint('NotificationService.cancelTripReminder warning: $e');
    }
  }

  /// Menampilkan Notifikasi Destinasi Selanjutnya saat Eksplorasi Aktif
  Future<void> showNextDestinationNotification({
    required String destinationName,
    required int visitOrder,
    String? plannedTime,
    int? elevationMdpl,
  }) async {
    final title = '📍 Tujuan Selanjutnya: $destinationName';
    final buffer = StringBuffer('Perjalanan berlanjut ke tujuan ke-$visitOrder.');
    if (plannedTime != null && plannedTime.isNotEmpty) {
      buffer.write(' Jadwal: $plannedTime.');
    }
    if (elevationMdpl != null && elevationMdpl > 0) {
      buffer.write(' Ketinggian: $elevationMdpl mdpl.');
    }
    buffer.write(' Ketuk untuk melihat petunjuk navigasi!');

    await showInstantNotification(
      id: 888,
      title: title,
      body: buffer.toString(),
      payload: '/active_trip',
    );
  }

  /// Notifikasi Peringatan Bahaya / Status Merapi
  Future<void> showVolcanoAlertNotification({
    required String title,
    required String message,
  }) async {
    await showInstantNotification(
      id: 777,
      title: '🌋 $title',
      body: message,
      payload: '/map',
    );
  }

  /// Notifikasi Uji Coba untuk Pengguna
  Future<void> showTestNotification({
    String? title,
    String? body,
  }) async {
    await showInstantNotification(
      id: 9999,
      title: title ?? '🔔 MeraTrip: Notifikasi Ponsel Berhasil!',
      body: body ??
          'Notifikasi ini benar-benar muncul di bilah status ponsel Anda. Sistem pengingat siap digunakan untuk trip Merapi.',
      payload: '/notification',
    );
  }
}
