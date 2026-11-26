import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';
import 'employee_request.dart';

class RiwayatCutiException implements Exception {
  const RiwayatCutiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RiwayatCutiItem {
  const RiwayatCutiItem({
    required this.id,
    required this.type,
    required this.leavFrom,
    required this.leavTo,
    required this.status,
    this.alasan = '',
    this.komentar = '',
    this.targetLeaderName = '',
    this.approvedByName = '',
    this.catatanLeader = '',
    this.createdAt = '',
  });

  final int id;
  final String type;
  final String leavFrom;
  final String leavTo;
  final String status;
  final String alasan;
  final String komentar;
  final String targetLeaderName;
  final String approvedByName;
  final String catatanLeader;
  final String createdAt;

  factory RiwayatCutiItem.fromJson(Map<String, dynamic> json) {
    return RiwayatCutiItem(
      id: _int(json['id'] ?? json['leave_id']),
      type: _text(json['type'] ?? json['reason'] ?? json['keterangan'], '-'),
      leavFrom: _text(
        json['leav_from'] ?? json['leave_from'] ?? json['start_date'],
        '-',
      ),
      leavTo: _text(json['leav_to'] ?? json['leave_to'] ?? json['end_date'], '-'),
      status: _text(json['staus'] ?? json['status'], '-'),
      alasan: _text(json['alasan'] ?? json['reason'], ''),
      komentar: _text(json['komentar'] ?? json['comment'], ''),
      targetLeaderName: _text(json['target_leader_name'], ''),
      approvedByName: _text(json['approved_by_name'], ''),
      catatanLeader: _text(json['catatan_leader'], ''),
      createdAt: _text(
        json['created_at'] ?? json['tanggal_pengajuan'],
        '',
      ),
    );
  }

  static String _text(dynamic value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return fallback;
    return text;
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class RiwayatCutiService {
  const RiwayatCutiService._();

  static Future<List<RiwayatCutiItem>> fetch({http.Client? client}) async {
    final String? token = await AppSession.resolveToken();
    final int? employeeId = await AppSession.currentEmployeeId();
    final String? role = await AppSession.resolveRole();
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .get(
            EmployeeRequest.leaveHistory(employeeId, role: role),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.requestTimeout);
    } finally {
      if (ownsClient) httpClient.close();
    }

    if (response.statusCode != 200) {
      throw RiwayatCutiException(
        'Gagal memuat riwayat cuti (HTTP ${response.statusCode}).',
      );
    }
    return parse(response.body);
  }

  static List<RiwayatCutiItem> parse(String body) {
    if (body.trim().isEmpty) return const <RiwayatCutiItem>[];
    final dynamic decoded = jsonDecode(body);
    dynamic raw = decoded;
    if (decoded is Map<String, dynamic>) {
      raw = decoded['data'] ??
          decoded['riwayat'] ??
          decoded['result'] ??
          decoded['riwayat_cuti'];
    }
    if (raw is! List) return const <RiwayatCutiItem>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RiwayatCutiItem.fromJson)
        .toList();
  }
}
