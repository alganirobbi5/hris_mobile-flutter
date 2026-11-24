import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class LeaveBalanceResult {
  const LeaveBalanceResult({
    required this.employeeId,
    required this.entitlementYear,
    required this.entitledDays,
    required this.remainingDays,
  });

  factory LeaveBalanceResult.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceResult(
      employeeId: (json['employee_id'] is int
          ? json['employee_id'] as int
          : int.tryParse(json['employee_id']?.toString() ?? '') ?? 0),
      entitlementYear: (json['entitlement_year'] is int
          ? json['entitlement_year'] as int
          : int.tryParse(json['entitlement_year']?.toString() ?? '') ?? 0),
      entitledDays: (json['entitled_days'] is num
          ? json['entitled_days'] as num
          : num.tryParse(json['entitled_days']?.toString() ?? '') ?? 0)
          .toDouble(),
      remainingDays: (json['remaining_days'] is num
          ? json['remaining_days'] as num
          : num.tryParse(json['remaining_days']?.toString() ?? '') ?? 0)
          .toDouble(),
    );
  }

  final int employeeId;
  final int entitlementYear;
  final double entitledDays;
  final double remainingDays;
}

class LeaveEmployeeError {
  static String? message;
}

class LeaveBalanceService {
  const LeaveBalanceService._();

  static String? lastError;

  static Future<List<Map<String, dynamic>>> fetchEmployees({
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    lastError = null;
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .get(
            ApiConfig.uri('employees.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        lastError = 'Gagal memuat daftar karyawan (HTTP ${response.statusCode})';
        return const [];
      }
      final dynamic decoded = jsonDecode(response.body);
      dynamic raw = decoded;
      if (decoded is Map<String, dynamic>) raw = decoded['data'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(
            (Map<String, dynamic> item) => <String, dynamic>{
              'id': item['id'],
              'name': (item['name'] ?? '').toString(),
              'nik': (item['nik'] ?? '').toString(),
            },
          )
          .toList();
    } catch (e) {
      lastError = 'Gagal terhubung ke server: $e';
      return const [];
    }
  }

  static Future<LeaveBalanceResult?> addEntitlement({
    required int employeeId,
    required double days,
    required int year,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    lastError = null;
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .post(
            ApiConfig.uri('tambah_kuota_cuti.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'employee_id': employeeId,
              'days': days,
              'entitlement_year': year,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic>? body = decoded is Map<String, dynamic>
          ? decoded
          : null;
      if (response.statusCode != 200 && response.statusCode != 201) {
        lastError = body == null
            ? 'Server balas HTTP ${response.statusCode}'
            : body['message']?.toString();
        return null;
      }
      if (body == null || body['success'] == false) {
        lastError = body == null
            ? 'Balasan server tidak valid'
            : body['message']?.toString();
        return null;
      }
      final dynamic data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      return LeaveBalanceResult.fromJson(data);
    } catch (e) {
      lastError = 'Gagal terhubung ke server: $e';
      return null;
    }
  }
}
