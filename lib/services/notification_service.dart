import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class AppNotificationService {
  AppNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int checkInId = 1001;
  static const int checkOutId = 1002;
  static const String defaultCheckIn = '08:00';
  static const String defaultCheckOut = '17:00';
  static const int hrAttendanceId = 2001;
  static const int leaveStatusId = 3001;

  static bool _initialized = false;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static Future<void> initialize() async {
    if (_initialized || !_supported) return;

    try {
      await _initializePlatform();
    } catch (e) {
      debugPrint('Notifikasi lokal tidak tersedia: $e');
    }
  }

  static Future<void> _initializePlatform() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    if (!_supported || !_initialized) return false;
    try {
      return await _requestPermissionPlatform();
    } catch (e) {
      debugPrint('Gagal meminta izin notifikasi: $e');
      return false;
    }
  }

  static Future<bool> _requestPermissionPlatform() async {
    if (!Platform.isAndroid) {
      final bool? granted = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }

    final AndroidFlutterLocalNotificationsPlugin? android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final bool? granted = await android?.requestNotificationsPermission();
    if (granted == true) return true;

    final PermissionStatus status = await Permission.notification.request();
    return status.isGranted;
  }

  static NotificationDetails _details({
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    return NotificationDetails(android: android, iOS: ios);
  }

  static NotificationDetails get _attendanceDetails => _details(
        channelId: 'attendance_reminder',
        channelName: 'Pengingat Absensi',
        channelDescription: 'Pengingat absen masuk dan absen pulang',
      );

  static NotificationDetails get _hrDetails => _details(
        channelId: 'hr_attendance',
        channelName: 'Absensi Karyawan',
        channelDescription: 'Notifikasi absen masuk karyawan untuk HR',
      );

  static NotificationDetails get _leaveDetails => _details(
        channelId: 'leave_status',
        channelName: 'Status Pengajuan Cuti',
        channelDescription: 'Pemberitahuan hasil persetujuan cuti',
      );

  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
    required NotificationDetails details,
    String? payload,
  }) async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    final bool allowed = await requestPermission();
    if (!allowed) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Gagal menampilkan notifikasi: $e');
    }
  }

  static Future<void> showAttendanceReminderNow({
    required String title,
    required String body,
    int id = checkInId,
  }) =>
      showNow(
        id: id,
        title: title,
        body: body,
        details: _attendanceDetails,
        payload: 'attendance_reminder',
      );

  static Future<void> showHrAttendance({
    required String employeeName,
    required String time,
  }) =>
      showNow(
        id: hrAttendanceId,
        title: 'Absen Masuk Karyawan',
        body: '$employeeName melakukan absen masuk pukul $time',
        details: _hrDetails,
        payload: 'hr_attendance',
      );

  static Future<void> showLeaveStatus({
    required String title,
    required String body,
  }) =>
      showNow(
        id: leaveStatusId,
        title: title,
        body: body,
        details: _leaveDetails,
        payload: 'leave_status',
      );

  static Future<void> scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    final bool allowed = await requestPermission();
    if (!allowed) return;

    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _attendanceDetails,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: id == checkOutId ? 'check_out' : 'check_in',
      );
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi: $e');
    }
  }

  static Future<void> scheduleAttendanceReminders({
    required String checkIn,
    required String checkOut,
  }) async {
    final int? checkInMinutes = _parseClock(checkIn);
    final int? checkOutMinutes = _parseClock(checkOut);
    if (checkInMinutes == null || checkOutMinutes == null) return;

    await scheduleDaily(
      id: checkInId,
      hour: checkInMinutes ~/ 60,
      minute: checkInMinutes % 60,
      title: 'Waktunya Absen Masuk',
      body: 'Jangan lupa melakukan absen masuk hari ini.',
    );
    await scheduleDaily(
      id: checkOutId,
      hour: checkOutMinutes ~/ 60,
      minute: checkOutMinutes % 60,
      title: 'Waktunya Absen Pulang',
      body: 'Jangan lupa melakukan absen pulang sebelum pulang kerja.',
    );
  }

  static Future<void> scheduleDefaultReminders() =>
      scheduleAttendanceReminders(
        checkIn: defaultCheckIn,
        checkOut: defaultCheckOut,
      );

  static int? _parseClock(String value) {
    final RegExp regex = RegExp(r'^(\d{1,2}):(\d{2})');
    final RegExpMatch? match = regex.firstMatch(value.trim());
    if (match == null) return null;
    final int hour = int.tryParse(match.group(1) ?? '') ?? -1;
    final int minute = int.tryParse(match.group(2) ?? '') ?? -1;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  static Future<void> cancelReminders() async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.cancel(checkInId);
      await _plugin.cancel(checkOutId);
    } catch (e) {
      debugPrint('Gagal membatalkan notifikasi: $e');
    }
  }

  static Future<void> cancelAll() async {
    if (!_supported) return;
    await initialize();
    if (!_initialized) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Gagal membersihkan notifikasi: $e');
    }
  }
}
