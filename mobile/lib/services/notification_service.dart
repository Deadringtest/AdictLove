import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _enabledKey = 'notifications_enabled';
  static const _reminderHourKey = 'reminder_hour';
  static const _reminderMinuteKey = 'reminder_minute';
  static const _reminderId = 9001;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
    _initialized = true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
    if (enabled) {
      final time = await getReminderTime();
      if (time != null) await scheduleDailyReminder(time.$1, time.$2);
    } else {
      await _plugin.cancel(_reminderId);
    }
  }

  /// Returns (hour, minute) of the configured daily reminder, or null if unset.
  Future<(int, int)?> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt(_reminderHourKey);
    final minute = prefs.getInt(_reminderMinuteKey);
    if (hour == null || minute == null) return null;
    return (hour, minute);
  }

  Future<void> scheduleDailyReminder(int hour, int minute) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reminderHourKey, hour);
    await prefs.setInt(_reminderMinuteKey, minute);

    if (!await isEnabled()) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) scheduled = scheduled.add(const Duration(days: 1));
    final tzScheduled = tz.TZDateTime.from(scheduled.toUtc(), tz.UTC);

    await _plugin.zonedSchedule(
      _reminderId,
      'Tickets are waiting',
      "You've got jackpot spins ready — come see who's out there!",
      tzScheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails('adictlove_reminder', 'Daily reminder', importance: Importance.defaultImportance),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reminderHourKey);
    await prefs.remove(_reminderMinuteKey);
    await _plugin.cancel(_reminderId);
  }

  Future<void> show({required String title, required String body}) async {
    if (!await isEnabled()) return;
    await init();
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'adictlove_default',
          'AdictLove',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
