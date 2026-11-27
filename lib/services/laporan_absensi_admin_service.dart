import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/laporan_excel_service.dart';

class LaporanAbsensiAdminException implements Exception {
  const LaporanAbsensiAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LaporanAbsensiAdminService {
  LaporanAbsensiAdminService._();

  static const String endpoint = 'laporan_absensi_admin.php';

  static Future<List<LaporanAbsensiRow>> fetchHariIni({
    http.Client? client,
  }) async {
    final String tanggal = _tanggalHariIni();
    final http.Client httpClient = client ?? http.Client();
    final String? token = await AppSession.resolveToken();

    final Uri uri = ApiConfig.uri(endpoint).replace(
      queryParameters: <String, String>{'date': tanggal},
    );
    final http.Response response = await httpClient
        .get(uri, headers: ApiConfig.authHeaders(token))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404 || response.statusCode == 405) {
      return const <LaporanAbsensiRow>[];
    }
    if (response.statusCode != 200) {
      throw LaporanAbsensiAdminException(
        'Gagal memuat absensi admin (HTTP ${response.statusCode}).',
      );
    }

    return parse(response.body);
  }

  static Future<List<LaporanAbsensiRow>> fetchRentang({
    required String? startDate,
    required String? endDate,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final String? token = await AppSession.resolveToken();
    final Map<String, String> query = <String, String>{};
    if (startDate != null && startDate.isNotEmpty) {
      query['start_date'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) {
      query['end_date'] = endDate;
    }

    final Uri uri = ApiConfig.uri(endpoint).replace(queryParameters: query);
    final http.Response response = await httpClient
        .get(uri, headers: ApiConfig.authHeaders(token))
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 404 || response.statusCode == 405) {
      return const <LaporanAbsensiRow>[];
    }
    if (response.statusCode != 200) {
      throw LaporanAbsensiAdminException(
        'Gagal memuat absensi admin (HTTP ${response.statusCode}).',
      );
    }
    return parse(response.body);
  }

  static String _tanggalHariIni() {
    final DateTime now = DateTime.now().toUtc().add(const Duration(hours: 7));
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static List<LaporanAbsensiRow> parse(String body) {
    if (body.trim().isEmpty) return const <LaporanAbsensiRow>[];

    final dynamic decoded = jsonDecode(body);
    dynamic raw = decoded;
    if (decoded is Map<String, dynamic>) {
      raw = decoded['data'] ??
          decoded['absensi'] ??
          decoded['result'] ??
          decoded['list'] ??
          decoded['admin'];
    }
    if (raw is! List) return const <LaporanAbsensiRow>[];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(LaporanAbsensiRow.fromJson)
        .where(
          (LaporanAbsensiRow row) =>
              !row.isLibur && (row.id > 0 || row.nama.isNotEmpty),
        )
        .toList();
  }
}
