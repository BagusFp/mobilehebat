import 'package:flutter/foundation.dart';
import '../../core/services/notification_service.dart';
import 'notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  String _activeFilter = 'all'; // 'all', 'trip', 'volcano', 'system'
  bool _isAlarmEnabled = true;
  String _alarmTiming = 'H-2 Jam'; // 'H-1 Hari', 'H-2 Jam', 'H-1 Jam', atau Kustom

  int _reminderDays = 0;
  int _reminderHours = 2;
  int _reminderMinutes = 0;

  int get reminderDays => _reminderDays;
  int get reminderHours => _reminderHours;
  int get reminderMinutes => _reminderMinutes;

  String get reminderTimingSummary {
    if (_reminderDays == 1 && _reminderHours == 0 && _reminderMinutes == 0) return 'H-1 Hari';
    if (_reminderDays == 0 && _reminderHours == 2 && _reminderMinutes == 0) return 'H-2 Jam';
    if (_reminderDays == 0 && _reminderHours == 1 && _reminderMinutes == 0) return 'H-1 Jam';
    if (_reminderDays == 0 && _reminderHours == 0 && _reminderMinutes == 30) return 'H-30 Menit';
    final parts = <String>[];
    if (_reminderDays > 0) parts.add('$_reminderDays Hari');
    if (_reminderHours > 0) parts.add('$_reminderHours Jam');
    if (_reminderMinutes > 0) parts.add('$_reminderMinutes Menit');
    if (parts.isEmpty) return 'Tepat Waktu';
    return 'H-${parts.join(" ")}';
  }

  List<NotificationModel> _notifications = [
    const NotificationModel(
      id: 1,
      title: 'Siaga Level II (Waspada)',
      body:
          'Radius aman wisata di luar 3 km dari puncak kawah. Bunker Kaliadem & Plunyon aman dikunjungi dengan pemantauan reguler BPPTKG.',
      category: 'volcano',
      timeAgo: '10 mnt lalu',
      tag: 'Penting • Status Merapi',
      isRead: false,
      actionText: 'Peta Titik Pantau',
      actionRoute: '/map',
    ),
    const NotificationModel(
      id: 2,
      title: 'Eksplorasi Merapi 1 Hari',
      body:
          'Perjalanan dimulai besok pukul 07:30 WIB dari meeting point. Jangan lupa jaket hangat, kacamata debu pasir, dan baterai cadangan.',
      category: 'trip',
      timeAgo: '1 jam lalu',
      tag: 'Pengingat Berangkat',
      isRead: false,
      actionText: 'Cek Daftar Bawaan',
      actionRoute: '/trip',
    ),
    const NotificationModel(
      id: 3,
      title: 'Pembaruan Data Rute Berhasil',
      body:
          'Data rute navigasi Bunker Kaliadem & Plunyon siap diakses dengan lancar di kawasan lereng Merapi.',
      category: 'system',
      timeAgo: 'Kemarin',
      tag: 'Sistem & Notifikasi',
      isRead: true,
      actionText: null,
      actionRoute: '/map',
    ),
    const NotificationModel(
      id: 4,
      title: 'Skor Kamu Masuk 10 Besar!',
      body:
          'Selamat! Kamu mengumpulkan 850 poin pada Mini Game Flora & Batuan Vulkanik Merapi.',
      category: 'system',
      timeAgo: '2 hari lalu',
      tag: 'Komunitas & Kuis',
      isRead: true,
      actionText: 'Lihat Papan Peringkat Mingguan',
      actionRoute: '/quiz',
    ),
  ];

  // Getters
  String get activeFilter => _activeFilter;
  bool get isAlarmEnabled => _isAlarmEnabled;
  String get alarmTiming => _alarmTiming;
  List<NotificationModel> get allNotifications => _notifications;

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  int countByCategory(String category) {
    if (category == 'all') return _notifications.length;
    return _notifications.where((n) => n.category == category).length;
  }

  List<NotificationModel> get filteredNotifications {
    if (_activeFilter == 'all') return _notifications;
    return _notifications.where((n) => n.category == _activeFilter).toList();
  }

  // Actions
  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void toggleAlarm(bool value) {
    _isAlarmEnabled = value;
    notifyListeners();
  }

  void setAlarmTiming(String timing) {
    _alarmTiming = timing;
    if (timing == 'H-1 Hari') {
      _reminderDays = 1;
      _reminderHours = 0;
      _reminderMinutes = 0;
    } else if (timing == 'H-2 Jam') {
      _reminderDays = 0;
      _reminderHours = 2;
      _reminderMinutes = 0;
    } else if (timing == 'H-1 Jam') {
      _reminderDays = 0;
      _reminderHours = 1;
      _reminderMinutes = 0;
    } else if (timing == 'H-30 Menit') {
      _reminderDays = 0;
      _reminderHours = 0;
      _reminderMinutes = 30;
    }
    notifyListeners();
  }

  /// Mengatur kustom waktu pengingat trip (bebas berapa hari, jam, menit)
  void setCustomTiming({
    required int days,
    required int hours,
    required int minutes,
  }) {
    _reminderDays = days.clamp(0, 30);
    _reminderHours = hours.clamp(0, 23);
    _reminderMinutes = minutes.clamp(0, 59);
    _alarmTiming = reminderTimingSummary;
    notifyListeners();
  }

  /// Mengirimkan notifikasi uji coba langsung ke status bar HP
  Future<void> sendTestNotificationToDevice() async {
    await NotificationService().showTestNotification();
    addNotification(
      NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'Uji Coba Notifikasi Sistem',
        body:
            'Notifikasi berhasil muncul di bilah status ponsel Anda dengan getaran dan suara.',
        category: 'system',
        timeAgo: 'Baru saja',
        tag: 'Uji Sistem',
        isRead: false,
        actionText: null,
      ),
    );
  }

  void markAllAsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    notifyListeners();
  }

  void markAsRead(int id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void deleteNotification(int id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void addNotification(NotificationModel item) {
    _notifications.insert(0, item);
    notifyListeners();
  }
}
