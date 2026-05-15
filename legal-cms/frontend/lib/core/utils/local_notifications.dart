import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;

Future<void> initLocalNotifications() async {
  if (_initialized) return;

  tz_data.initializeTimeZones();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  await _plugin.initialize(
    const InitializationSettings(android: androidSettings, iOS: iosSettings),
  );

  _initialized = true;
}

Future<void> scheduleHearingReminder({
  required int hearingId,
  required String title,
  required String body,
  required DateTime scheduledDate,
}) async {
  await initLocalNotifications();

  final reminderTime = scheduledDate.subtract(const Duration(days: 1));

  if (reminderTime.isBefore(DateTime.now())) return;

  await _plugin.zonedSchedule(
    hearingId,
    title,
    body,
    tz.TZDateTime.from(reminderTime, tz.local),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'hearing_reminders',
        'Hearing Reminders',
        channelDescription: 'Reminders for upcoming court hearings',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}

Future<void> cancelHearingReminder(int hearingId) async {
  await _plugin.cancel(hearingId);
}

Future<void> cancelAllReminders() async {
  await _plugin.cancelAll();
}
