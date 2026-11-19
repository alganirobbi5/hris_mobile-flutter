import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AppSession {
  static int? userId;
  static int? employeeId;
  static String? username;
  static String? name;
  static String? role;

  static bool get isHr => role == 'hr';

  static int? _cachedEmployeeId;

  /// Hapus cache saat login/logout.
  static void invalidateEmployeeId() => _cachedEmployeeId = null;

  /// ID karyawan yang dipakai backend (employees.id).
  /// Urutan prioritas: employee_id tersimpan -> resolusi otomatis -> fallback 2.
  static Future<int> currentEmployeeId() async {
    final int? cached = _cachedEmployeeId;
    if (cached != null) return cached;

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final int? employeeId = prefs.getInt('employee_id');
    if (employeeId != null && await _isValidEmployeeId(prefs, employeeId)) {
      _cachedEmployeeId = employeeId;
      return employeeId;
    }

    final int? resolved = await _resolveEmployeeId(prefs);
    if (resolved != null) {
      await prefs.setInt('employee_id', resolved);
      _cachedEmployeeId = resolved;
      return resolved;
    }

    return 2;
  }

  static Future<bool> _isValidEmployeeId(
    SharedPreferences prefs,
    int employeeId,
  ) async {
    final String? username = prefs.getString('username')?.trim().toLowerCase();
    if (username == null || username.isEmpty) return true;

    try {
      final http.Response response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/profil.php?employee_id=$employeeId'),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return false;

      final dynamic decoded = jsonDecode(response.body);
      final dynamic data = decoded is Map<String, dynamic>
          ? (decoded['data'] is Map<String, dynamic>
              ? decoded['data']
              : decoded)
          : null;
      if (data is! Map<String, dynamic>) return false;

      final String profilUsername =
          (data['username'] ?? '').toString().trim().toLowerCase();
      return profilUsername == username;
    } catch (_) {
      // Saat jaringan bermasalah, pakai nilai tersimpan agar tetap bisa dipakai.
      return true;
    }
  }

  /// Endpoint login lama tidak mengirim employee_id, sehingga yang tersimpan
  /// adalah user_id (id tabel users) yang belum tentu sama dengan employees.id.
  /// Cari employees.id yang username-nya cocok dengan akun yang login.
  static Future<int?> _resolveEmployeeId(SharedPreferences prefs) async {
    final String? username = prefs.getString('username')?.trim().toLowerCase();
    if (username == null || username.isEmpty) return null;

    final int? userId = prefs.getInt('user_id');
    final List<int> candidates = <int>[if (userId != null) userId];
    for (int i = 1; i <= 50; i++) {
      if (!candidates.contains(i)) candidates.add(i);
    }

    final http.Client client = http.Client();
    try {
      for (final int id in candidates) {
        try {
          final http.Response response = await client
              .get(
                Uri.parse('${ApiConfig.baseUrl}/profil.php?employee_id=$id'),
              )
              .timeout(const Duration(seconds: 5));
          if (response.statusCode != 200) continue;

          final dynamic decoded = jsonDecode(response.body);
          final dynamic data = decoded is Map<String, dynamic>
              ? (decoded['data'] is Map<String, dynamic>
                  ? decoded['data']
                  : decoded)
              : null;
          if (data is! Map<String, dynamic>) continue;

          final String profilUsername =
              (data['username'] ?? '').toString().trim().toLowerCase();
          if (profilUsername == username) return id;
        } catch (_) {
          // Lanjut ke kandidat berikutnya.
        }
      }
    } finally {
      client.close();
    }
    return null;
  }

  static void setFromLogin(Map<String, dynamic> data) {
    userId = _asInt(data['user_id']);
    employeeId = _asInt(data['employee_id']);
    username = data['username'] as String?;
    name = data['nama_lengkap'] as String?;
    role = data['role'] as String?;
  }

  static void clear() {
    userId = null;
    employeeId = null;
    username = null;
    name = null;
    role = null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
