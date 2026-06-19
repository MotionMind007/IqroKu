import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/prayer_models.dart';

abstract class PrayerReminderService {
  Future<bool> requestPermissions();
  Future<void> scheduleDailyAdzan(PrayerSchedule schedule);
  Future<void> cancelAdzan();
}

class LocalPrayerReminderService implements PrayerReminderService {
  LocalPrayerReminderService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _regularChannelId = 'iqroku_adzan_regular_v1';
  static const _subuhChannelId = 'iqroku_adzan_subuh_v1';
  static const _channelName = 'Adzan';
  static const _channelDescription = 'Pengingat waktu solat IqroKu';
  static const _notificationIds = <String, int>{
    'Subuh': 701,
    'Dzuhur': 702,
    'Ashar': 703,
    'Maghrib': 704,
    'Isya': 705,
  };

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  @override
  Future<bool> requestPermissions() async {
    await _ensureInitialized();

    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final androidGranted = await android?.requestNotificationsPermission();
    if (androidGranted == false) {
      return false;
    }

    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted == false) {
      return false;
    }

    final macos = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    final macosGranted = await macos?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (macosGranted == false) {
      return false;
    }

    return true;
  }

  @override
  Future<void> scheduleDailyAdzan(PrayerSchedule schedule) async {
    if (kIsWeb) {
      return;
    }
    await _ensureInitialized();
    await cancelAdzan();

    final now = DateTime.now();
    for (final time in schedule.times) {
      final id = _notificationIds[time.name];
      if (id == null) {
        continue;
      }

      final scheduledAt = _nextLocalOccurrence(time.time, now);
      if (scheduledAt == null) {
        continue;
      }

      await _notifications.zonedSchedule(
        id: id,
        title: 'Waktu ${time.name}',
        body: 'Saatnya solat ${time.name}.',
        scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
        notificationDetails: _details(time.name),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'adzan:${time.name}',
      );
    }
  }

  @override
  Future<void> cancelAdzan() async {
    if (kIsWeb) {
      return;
    }
    await _ensureInitialized();
    for (final id in _notificationIds.values) {
      await _notifications.cancel(id: id);
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    const android = AndroidInitializationSettings(
      'ic_stat_iqroku_notification',
    );
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: android,
      iOS: darwin,
      macOS: darwin,
    );

    await _notifications.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> _configureLocalTimezone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(_fallbackLocationForOffset(DateTime.now()));
    }
  }

  tz.Location _fallbackLocationForOffset(DateTime now) {
    final hours = now.timeZoneOffset.inHours;
    final locationName = switch (hours) {
      7 => 'Asia/Jakarta',
      8 => 'Asia/Makassar',
      9 => 'Asia/Jayapura',
      _ => 'UTC',
    };
    return tz.getLocation(locationName);
  }

  DateTime? _nextLocalOccurrence(String value, DateTime now) {
    final parts = value.split(':');
    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23) {
      return null;
    }
    if (minute < 0 || minute > 59) {
      return null;
    }

    var scheduledAt = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduledAt.isAfter(now)) {
      scheduledAt = scheduledAt.add(const Duration(days: 1));
    }
    return scheduledAt;
  }

  NotificationDetails _details(String prayerName) {
    final isSubuh = prayerName == 'Subuh';
    final channelId = isSubuh ? _subuhChannelId : _regularChannelId;
    final soundName = isSubuh ? 'adzan_subuh' : 'adzan';

    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: 'ic_stat_iqroku_notification',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        sound: RawResourceAndroidNotificationSound(soundName),
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
