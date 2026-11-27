import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class KaryawanServiceException implements Exception {
  const KaryawanServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class KaryawanItem {
  const KaryawanItem({
    required this.id,
    required this.username,
    required this.namaLengkap,
    required this.email,
    required this.mobileNo,
    required this.statusAktif,
    this.role = '',
    this.isLeader = false,
    this.userId = 0,
  });

  final int id;
  final String username;
  final String namaLengkap;
  final String email;
  final String mobileNo;
  final bool statusAktif;
  final String role;
  final bool isLeader;
  final int userId;

  String get roleLabel {
    final String value = role.trim().toLowerCase();
    if (isLeader || value == 'leader') return 'LEADER';
    if (value == 'hr' || value == 'admin') return 'HR';
    if (value == 'super_admin' || value == 'superadmin') return 'SUPER ADMIN';
    return 'EMPLOYEE';
  }

  static KaryawanItem fromJson(Map<String, dynamic> json) {
    final String firstName = _text(json['first_name']);
    final String lastName = _text(json['last_name']);
    final String fallbackNama = '$firstName $lastName'.trim();
    final String nama = _text(
      json['nama_lengkap'] ?? json['full_name'] ?? json['name'],
    );
    final String statusText = _text(
      json['status_aktif'] ?? json['is_active'] ?? json['active'] ?? json['status'],
    ).toLowerCase();
    final dynamic statusValue =
        json['is_active'] ?? json['active'] ?? json['status_aktif'] ?? json['status'];

    return KaryawanItem(
      id: _int(json['employee_id'] ?? json['id'] ?? json['user_id']) ?? 0,
      username: _text(json['username'] ?? json['user_name']),
      namaLengkap: nama.isNotEmpty
          ? nama
          : (fallbackNama.isNotEmpty ? fallbackNama : _text(json['nama'])),
      email: _text(json['email']),
      mobileNo: _text(
        json['mobile_no'] ?? json['no_hp'] ?? json['phone'] ?? json['whatsapp'],
      ),
      statusAktif: statusValue is bool
          ? statusValue
          : statusText.isEmpty ||
              const <String>['1', 'true', 'active', 'aktif', 'yes']
                  .contains(statusText),
      role: _text(
        json['role'] ??
            json['jabatan'] ??
            json['designation_name'] ??
            json['position'],
      ),
      isLeader: _bool(
        json['is_leader'] ??
            json['is_leave_leader'] ??
            json['leader'] ??
            json['isLeader'],
      ),
      userId: _int(
            json['user_id'] ?? json['employee_id'] ?? json['id'],
          ) ??
          0,
    );
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(_text(value));
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final String text = _text(value).toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }
}

class KaryawanService {
  const KaryawanService._();

  static Future<List<KaryawanItem>> fetchAll({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .get(
            ApiConfig.uri('employees.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw KaryawanServiceException(
          'Gagal memuat daftar karyawan (HTTP ${response.statusCode}).',
        );
      }
      final dynamic decoded = jsonDecode(response.body);
      dynamic raw = decoded;
      if (decoded is Map<String, dynamic>) {
        raw = decoded['data'] ?? decoded['employees'] ?? decoded['result'];
      }
      if (raw is! List) {
        throw const KaryawanServiceException('Format data karyawan tidak valid.');
      }
      return raw
          .whereType<Map<String, dynamic>>()
          .map(KaryawanItem.fromJson)
          .where((KaryawanItem item) => item.id > 0)
          .toList();
    } on KaryawanServiceException {
      rethrow;
    } catch (_) {
      throw const KaryawanServiceException('Gagal terhubung ke server.');
    }
  }

  static Future<String> update({
    required int employeeId,
    required String namaLengkap,
    required String username,
    required String email,
    required String mobileNo,
    required bool statusAktif,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final Map<String, dynamic> body = <String, dynamic>{
      'employee_id': employeeId,
      'nama_lengkap': namaLengkap.trim(),
      'username': username.trim(),
      'user_name': username.trim(),
      'email': email.trim(),
      'mobile_no': mobileNo.trim(),
      'status': statusAktif ? '1' : '0',
    };
    try {
      final String? token = await AppSession.resolveToken();
      http.Response response = await httpClient
          .post(
            ApiConfig.uri('update_karyawan.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await httpClient
            .post(
              ApiConfig.uri('edit_karyawan.php'),
              headers: ApiConfig.authHeaders(token),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 20));
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
      final Map<String, dynamic>? envelope = decoded is Map<String, dynamic>
          ? decoded
          : null;
      final String? serverMessage = envelope?['message']?.toString().trim();
      final String? statusText = envelope?['status']?.toString().toLowerCase();
      final bool rejected = envelope?['success'] == false ||
          (statusText != null &&
              statusText != 'success' &&
              statusText != 'ok' &&
              statusText != '1' &&
              statusText != 'true');
      final bool sukses = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          !rejected;
      if (!sukses) {
        throw KaryawanServiceException(
          serverMessage != null && serverMessage.isNotEmpty
              ? serverMessage
              : 'Gagal memperbarui karyawan (HTTP ${response.statusCode}).',
        );
      }
      return serverMessage != null && serverMessage.isNotEmpty
          ? serverMessage
          : 'Data karyawan berhasil diperbarui.';
    } on KaryawanServiceException {
      rethrow;
    } catch (_) {
      throw const KaryawanServiceException('Gagal terhubung ke server.');
    }
  }
}
