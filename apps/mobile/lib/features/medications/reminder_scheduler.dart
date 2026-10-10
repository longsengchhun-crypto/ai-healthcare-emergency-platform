import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Schedules daily local medication reminders on the device.
///
/// Android limits: reminders use inexact, doze-friendly alarms so they may be delayed by several minutes,
/// and are removed if the user force-stops the app or revokes notification permission. Notification text
/// intentionally omits dosage details so it is safe on a lock screen.
class ReminderScheduler {
  ReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _initialised = true;
  }

  /// Returns false when the user has not granted notification permission.
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? false;
  }

  int _idFor(String reminderId) => reminderId.hashCode & 0x7fffffff;

  Future<void> schedule({
    required String reminderId,
    required int hour,
    required int minute,
    required String timezoneName,
  }) async {
    await init();
    final location = tz.getLocation(timezoneName);
    final now = tz.TZDateTime.now(location);
    var first = tz.TZDateTime(
      location,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!first.isAfter(now)) first = first.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _idFor(reminderId),
      title: 'Medication reminder',
      body: 'It is time to take your medication.',
      scheduledDate: first,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'medication_reminders',
          'Medication reminders',
          channelDescription: 'Daily reminders to take your medication',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancel(String reminderId) async {
    await init();
    await _plugin.cancel(id: _idFor(reminderId));
  }
}
