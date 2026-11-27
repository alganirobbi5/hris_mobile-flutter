import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/notification_service.dart';

class AbsenPollingService {
  AbsenPollingService._();

  static const String _seenKey = 'hr_absen_masuk_seen_ids';
  static const String _seenNotifKey = 'hr_notification_seen_ids';
  static Set<String> _seen = <String>{};
  static Set<int> _seenNotif = <int>{};
  static bool _running = false;
  static bool _loaded = false;

  static Future<void> loadSeen() async {
    if (_loaded) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList(_seenKey);
    if (saved != null) {
      _seen = saved.toSet();
    }
    final List<String>? savedNotif = prefs.getStringList(_seenNotifKey);
    if (savedNotif != null) {
      _seenNotif = savedNotif.map(int.tryParse).whereType<int>().toSet();
    }
    _loaded = true;
  }

  static Future<void> pollOnce({http.Client? client}) async {
    if (_running) return;
    final String? role = await AppSession.resolveRole();
    if (role == null || role.isEmpty) return;

    _running = true;
    final http.Client httpClient = client ?? http.Client();
    try {
      await loadSeen();
      final String? token = await AppSession.resolveToken();
      final Map<String, String> headers = ApiConfig.authHeaders(token);

      await _pollNotifications(httpClient, headers, role);
      if (AppSession.isHrRole(role)) {
        await _pollAttendance(httpClient, headers);
      }
    } catch (_) {
      // Polling gagal tidak boleh mengganggu aplikasi.
    } finally {
      _running = false;
    }
  }

  static Future<void> _pollNotifications(
    http.Client client,
    Map<String, String> headers,
    String role,
  ) async {
    final http.Response response = await client
        .get(
          ApiConfig.uri('notifications.php'),
          headers: headers,
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return;

    final dynamic decoded = jsonDecode(response.body);
    final dynamic raw = decoded is Map<String, dynamic>
        ? (decoded['data'] ?? decoded['notifications'])
        : decoded;
    if (raw is! List) return;

    final List<_NotifRow> baru = raw
        .whereType<Map<String, dynamic>>()
        .map(_NotifRow.fromJson)
        .where((_NotifRow row) =>
            row.id > 0 && !_seenNotif.contains(row.id))
        .toList();
    if (baru.isEmpty) return;

    for (final _NotifRow row in baru) {
      _seenNotif.add(row.id);
      await _tampilkanNotifikasi(row, role);
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seenNotifKey,
      _seenNotif.map((int id) => id.toString()).toList(),
    );
  }

  static Future<void> _tampilkanNotifikasi(_NotifRow row, String role) async {
    final String type = row.type;
    if (type == 'attendance' && !AppSession.isHrRole(role)) return;
    if (type == 'leave_request' && role == 'super_admin') return;
    if (type == 'attendance_self') {
      await AppNotificationService.showAttendanceReminderNow(
        id: 1000 + row.id,
        title: row.title,
        body: row.message,
      );
      return;
    }
    if (type == 'announcement') {
      await AppNotificationService.showAnnouncement(
        title: row.title,
        body: row.message,
      );
      return;
    }
    if (type == 'leave_request') {
      await AppNotificationService.showLeaveStatus(
        title: row.title,
        body: row.message,
      );
      return;
    }
    await AppNotificationService.showHrAttendance(
      employeeName: row.title,
      time: row.message,
    );
  }

  static Future<void> _pollAttendance(
    http.Client client,
    Map<String, String> headers,
  ) async {
    final Uri uri = ApiConfig.uri('laporan_absensi.php').replace(
      queryParameters: <String, String>{
        'date': LaporanTanggal.hariIni(),
      },
    );
    final http.Response response = await client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return;

    final dynamic decoded = jsonDecode(response.body);
    final List<dynamic> rows = _extractRows(decoded);
    if (rows.isEmpty) return;

    final List<_AbsenRow> masukHariIni = rows
        .whereType<Map<String, dynamic>>()
        .map(_AbsenRow.fromJson)
        .where((_AbsenRow row) => row.id > 0 && row.clockIn.isNotEmpty)
        .toList();

    final List<_AbsenRow> baru = masukHariIni
        .where((_AbsenRow row) => !_seen.contains(_kunciAbsen(row)))
        .toList();
    if (baru.isEmpty) return;

    for (final _AbsenRow row in baru) {
      _seen.add(_kunciAbsen(row));
      await AppNotificationService.showHrAttendance(
        employeeName: row.name,
        time: row.clockIn,
      );
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _seenKey,
      _seen.map((String key) => key).toList(),
    );
  }

  static String _kunciAbsen(_AbsenRow row) =>
      '${row.recordType}:${row.id}:${row.name}:${row.clockIn}';

  static List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final dynamic raw = decoded['data'] ??
          decoded['absensi'] ??
          decoded['result'] ??
          decoded['list'];
      if (raw is List) return raw;
      if (raw is Map<String, dynamic>) {
        final dynamic nested = raw['data'] ?? raw['rows'];
        if (nested is List) return nested;
      }
    }
    return const <dynamic>[];
  }

  static Future<void> resetSeen() async {
    _seen = <String>{};
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
  }
}

class LaporanTanggal {
  static String hariIni() {
    final DateTime now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}

class _NotifRow {
  const _NotifRow({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
  });

  factory _NotifRow.fromJson(Map<String, dynamic> json) {
    return _NotifRow(
      id: int.tryParse((json['id'] ?? json['notification_id'])?.toString() ?? '') ?? 0,
      title: (json['title'] ?? 'Notifikasi').toString().trim(),
      message: (json['message'] ?? '').toString().trim(),
      type: (json['type'] ?? 'general').toString().trim(),
    );
  }

  final int id;
  final String title;
  final String message;
  final String type;
}

class _AbsenRow {
  const _AbsenRow({
    required this.id,
    required this.name,
    required this.clockIn,
    this.recordType = 'employee',
  });

  factory _AbsenRow.fromJson(Map<String, dynamic> json) {
    final String firstName = (json['first_name'] ?? '').toString().trim();
    final String lastName = (json['last_name'] ?? '').toString().trim();
    final String fallbackName = '$firstName $lastName'.trim();
    return _AbsenRow(
      id: int.tryParse(
            (json['id'] ?? json['absen_id'] ?? json['attendance_id'])
                ?.toString() ?? '',
          ) ??
          0,
      name: (json['nama_lengkap'] ??
              json['nama_karyawan'] ??
              json['employee_name'] ??
              json['name'] ??
              fallbackName)
          .toString()
          .trim(),
      clockIn: (json['clock_in'] ??
              json['jam_masuk'] ??
              json['check_in'] ??
              json['masuk'])
          .toString()
          .trim(),
      recordType: (json['record_type'] ?? 'employee').toString().trim(),
    );
  }

  final int id;
  final String name;
  final String clockIn;
  final String recordType;
}
