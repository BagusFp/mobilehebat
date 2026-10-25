import 'package:flutter/foundation.dart';
import '../../core/database/preferences_helper.dart';
import '../../core/services/notification_service.dart';
import 'notification_model.dart';

class NotificationProvider extends ChangeNotifier {
  String _activeFilter = 'all'; // 'all', 'trip', 'volcano', 'system'
  bool _isAlarmEnabled = true;
  String _alarmTiming = 'H-2 Jam'; // 'H-1 Hari', 'H-2 Jam', 'H-1 Jam', atau Kustom

  int _reminderDays = 0;
  int _reminderHours = 2;
  int _reminderMinutes = 0;

  // Hanya memuat notifikasi yang betulan dikirimkan oleh APK ke HP user
  List<NotificationModel> _notifications = [];

  NotificationProvider({List<NotificationModel>? initialNotifications}) {
    if (initialNotifications != null) {
      _notifications = List.from(initialNotifications);
    } else {
      _loadSentNotifications();
    }

    // Dengarkan setiap notifikasi yang betulan dikirim oleh NotificationService ke bilah status HP
    NotificationService.onNotificationSent = (item) {
      addNotification(item);
    };
  }

  Future<void> _loadSentNotifications() async {
    try {
      final prefs = await PreferencesHelper.instance;
      final saved = prefs.getSentNotifications();
      if (saved.isNotEmpty) {
        _notifications = saved;
        notifyListeners();
      }
    } catch (_) {}
  }

  void setNotificationsForTesting(List<NotificationModel> items) {
    _notifications = List.from(items);
    notifyListeners();
  }

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
  }

  void markAllAsRead() {
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    PreferencesHelper.instance.then((prefs) => prefs.saveSentNotifications(_notifications));
    notifyListeners();
  }

  void markAsRead(int id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      PreferencesHelper.instance.then((prefs) => prefs.saveSentNotifications(_notifications));
      notifyListeners();
    }
  }

  void deleteNotification(int id) {
    _notifications.removeWhere((n) => n.id == id);
    PreferencesHelper.instance.then((prefs) => prefs.saveSentNotifications(_notifications));
    notifyListeners();
  }

  void addNotification(NotificationModel item) {
    _notifications.removeWhere((n) => n.id == item.id && n.title == item.title);
    _notifications.insert(0, item);
    PreferencesHelper.instance.then((prefs) => prefs.saveSentNotifications(_notifications));
    notifyListeners();
  }
}
