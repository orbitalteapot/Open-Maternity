import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/calc.dart';
import '../data/models.dart';
import '../l10n/strings.dart';
import 'reminders.dart';

/// Medicine reminders as local notifications, scheduled by the phone itself.
/// Uses inexact daily alarms, so the app needs no exact-alarm permission.
class LocalReminders implements Reminders {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC; reminders may be off by the UTC offset.
    }
    const AndroidInitializationSettings android = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(settings: const InitializationSettings(android: android, iOS: darwin));
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_ready) {
      return false;
    }
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? ios =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, sound: true) ?? false;
    }
    return false;
  }

  @override
  Future<bool> isAllowed() async {
    if (!_ready) {
      return false;
    }
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? true;
    }
    if (Platform.isIOS) {
      final IOSFlutterLocalNotificationsPlugin? ios =
          _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      final NotificationsEnabledOptions? options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return false;
  }

  @override
  Future<void> sync(List<Medicine> meds, S t) async {
    if (!_ready) {
      return;
    }
    // Each reminder carries a key of what it is for. If the phone already has
    // exactly these, leave them alone, so a reminder that is about to fire is
    // never dropped just because the app was opened.
    final List<Medicine> valid = meds.where((Medicine m) => parseClock(m.time) != null).toList();
    final Set<String> wanted = <String>{for (final Medicine m in valid) _key(m, t)};
    final List<PendingNotificationRequest> pending = await _plugin.pendingNotificationRequests();
    final Set<String> existing = <String>{for (final PendingNotificationRequest p in pending) p.payload ?? ''};
    if (existing.length == pending.length && existing.length == wanted.length && existing.containsAll(wanted)) {
      return;
    }
    await _plugin.cancelAllPendingNotifications();
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medicine_reminders',
        t('md_channel'),
        channelDescription: t('md_channel_sub'),
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      ),
      iOS: const DarwinNotificationDetails(),
    );
    int id = 1;
    for (final Medicine m in valid) {
      final ({int hour, int minute}) clock = parseClock(m.time)!;
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      tz.TZDateTime when = tz.TZDateTime(tz.local, now.year, now.month, now.day, clock.hour, clock.minute);
      if (!when.isAfter(now)) {
        when = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, clock.hour, clock.minute);
      }
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: when,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: t('md_notif_title', <String, Object?>{'name': m.name}),
        body: t('md_notif_body'),
        payload: _key(m, t),
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  String _key(Medicine m, S t) => 'med|${m.id}|${m.time}|${t.lang}|${m.name}';
}
