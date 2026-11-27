import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class EmployeeServiceException implements Exception {
  const EmployeeServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class EmployeeService {
  const EmployeeService._();

  static Future<String> update({
    required int id,
    required int employeeId,
    required int userId,
    required String namaLengkap,
    required String username,
    required String email,
    required String mobileNo,
    required bool statusAktif,
    String password = '',
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final Map<String, dynamic> body = <String, dynamic>{
      'action': 'update',
      'id': id,
      'employee_id': employeeId,
      'user_id': userId,
      'nama_lengkap': namaLengkap.trim(),
      'username': username.trim(),
      'user_name': username.trim(),
      'email': email.trim(),
      'mobile_no': mobileNo.trim(),
      'status': statusAktif ? '1' : '0',
      if (password.trim().isNotEmpty) 'password': password,
    };
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .post(
            ApiConfig.uri('employees.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

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
        throw EmployeeServiceException(
          serverMessage != null && serverMessage.isNotEmpty
              ? serverMessage
              : 'Gagal memperbarui karyawan (HTTP ${response.statusCode}).',
        );
      }
      return serverMessage != null && serverMessage.isNotEmpty
          ? serverMessage
          : 'Data karyawan berhasil diperbarui.';
    } on EmployeeServiceException {
      rethrow;
    } catch (_) {
      throw const EmployeeServiceException('Gagal terhubung ke server.');
    }
  }
}
