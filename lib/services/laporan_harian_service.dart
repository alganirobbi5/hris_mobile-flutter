import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class LaporanHarianException implements Exception {
  const LaporanHarianException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Mengambil ringkasan absensi karyawan untuk satu hari tertentu
/// dari API baru (attendances.php) yang memakai autentikasi token.
class LaporanHarianService {
  LaporanHarianService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const String _endpoint = 'attendances.php';

  static String tanggalHariIni() {
    final DateTime now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<String?> _token() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(ApiConfig.tokenPrefKey);
  }

  Future<List<Map<String, dynamic>>> fetchHariIni() async {
    final String? token = await _token();
    if (token == null || token.trim().isEmpty) {
      throw const LaporanHarianException(
        'Sesi login berakhir. Silakan login kembali.',
      );
    }

    final Uri url = ApiConfig.uri(_endpoint).replace(
      queryParameters: <String, String>{
        'scope': 'all',
        'date': tanggalHariIni(),
      },
    );

    final http.Response response;
    try {
      response = await _client
          .get(
            url,
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.requestTimeout);
    } catch (_) {
      throw const LaporanHarianException(
        'Gagal terhubung ke server. Periksa koneksi internet.',
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const LaporanHarianException(
        'Sesi login berakhir atau Anda tidak memiliki izin HR.',
      );
    }

    if (response.statusCode != 200) {
      throw LaporanHarianException(
        'Server mengembalikan kode ${response.statusCode}.',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const LaporanHarianException('Format data laporan tidak valid.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw const LaporanHarianException('Data laporan tidak ditemukan.');
    }

    final dynamic payload = decoded['data'];
    final List<dynamic> items;
    if (payload is Map<String, dynamic> && payload['items'] is List) {
      items = payload['items'] as List<dynamic>;
    } else if (payload is List) {
      items = payload;
    } else {
      throw const LaporanHarianException('Data absensi tidak ditemukan.');
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
