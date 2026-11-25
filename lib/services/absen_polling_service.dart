import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/laporan_excel_service.dart';
import '../services/notification_service.dart';

class AbsenPollingService {
  AbsenPollingService._();

  static const String _seenKey = 'hr_absen_masuk_seen_ids';
  static Set<int> _seen = <int>{};
  static bool _running = false;

  static Future<void> loadSeen() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList(_seenKey);
    if (saved != null) {
      _seen = saved.map(int.tryParse).whereType<int>().toSet();
    }
  }

  static Future<void> pollOnce({http.Client? client}) async {
    if (_running) return;
    final String? role = await AppSession.resolveRole();
    if (!AppSession.isHrRole(role)) return;

    _running = true;
    try {
      final String? token = await AppSession.resolveToken();
      final http.Client httpClient = client ?? http.Client();
      final Uri uri = ApiConfig.uri('laporan_absensi.php').replace(
        queryParameters: <String, String>{
          'date': LaporanExcelService.tanggalHariIni(),
        },
      );
      final http.Response response = await httpClient
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 15));

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
          .where((_AbsenRow row) => !_seen.contains(row.id))
          .toList();
      if (baru.isEmpty) return;

      _seen.addAll(baru.map((_AbsenRow row) => row.id));
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _seenKey,
        _seen.map((int id) => id.toString()).toList(),
      );

      for (final _AbsenRow row in baru) {
        await AppNotificationService.showHrAttendance(
          employeeName: row.name,
          time: row.clockIn,
        );
      }
    } catch (_) {
      // Polling gagal tidak boleh mengganggu aplikasi.
    } finally {
      _running = false;
    }
  }

  static List<dynamic> _extractRows(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final dynamic raw = decoded['data'] ??
          decoded['absensi'] ??
          decoded['result'] ??
          decoded['list'];
      if (raw is List) return raw;
    }
    return const <dynamic>[];
  }

  static Future<void> resetSeen() async {
    _seen = <int>{};
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenKey);
  }
}

class _AbsenRow {
  const _AbsenRow({
    required this.id,
    required this.name,
    required this.clockIn,
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
    );
  }

  final int id;
  final String name;
  final String clockIn;
}
