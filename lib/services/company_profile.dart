import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/company_config.dart';
import 'app_session.dart';

class CompanyProfileData {
  const CompanyProfileData({
    required this.name,
    required this.code,
    this.logo = '',
  });

  final String name;
  final String code;
  final String logo;
}

/// Data profil perusahaan yang dipakai halaman profil dan validasi login.
/// Nilai lokal dipakai sebagai fallback bila endpoint belum tersedia.
class CompanyProfile {
  const CompanyProfile._();

  static const String nameKey = 'company_name';
  static const String codeKey = 'company_code';
  static const String logoKey = 'company_logo';

  /// Pesan error terakhir dari [update], dipakai UI untuk penjelasan spesifik.
  static String? lastError;

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static CompanyProfileData current = const CompanyProfileData(
    name: CompanyConfig.namaPerusahaan,
    code: CompanyConfig.kodePerusahaan,
  );

  static Future<CompanyProfileData> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String name = _text(prefs.getString(nameKey)) ?? current.name;
    final String code = _text(prefs.getString(codeKey)) ?? current.code;
    final String logo = _text(prefs.getString(logoKey)) ?? current.logo;
    current = CompanyProfileData(name: name, code: code, logo: logo);
    return current;
  }

  static Future<void> save(CompanyProfileData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(nameKey, data.name);
    await prefs.setString(codeKey, data.code);
    await prefs.setString(logoKey, data.logo);
    current = data;
    revision.value++;
  }

  static Future<CompanyProfileData?> fetch({http.Client? client}) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .get(
            ApiConfig.uri('get_company.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && !_isSuccess(decoded)) {
        return null;
      }
      final Map<String, dynamic> data = _unwrap(decoded);
      final String? name = _text(
        data['nama_perusahaan'] ?? data['company_name'] ?? data['name'],
      );
      final String? code = _text(
        data['kode_perusahaan'] ?? data['company_code'] ?? data['code'],
      );
      if (name == null && code == null) return null;

      final CompanyProfileData base = await load();
      final String? logo = _text(
        data['logo'] ?? data['company_logo'],
      );
      final CompanyProfileData result = CompanyProfileData(
        name: name ?? base.name,
        code: code ?? base.code,
        logo: logo ?? base.logo,
      );
      await save(result);
      return result;
    } catch (_) {
      return null;
    }
  }

  /// POST ke update_company.php. Mengembalikan true bila server menerima
  /// perubahan; data lokal hanya diperbaharui setelah server berhasil.
  static Future<bool> update({
    required String name,
    required String code,
    String logo = '',
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final String cleanedName = name.trim();
    final String cleanedCode = code.trim();
    lastError = null;
    if (cleanedName.isEmpty || cleanedCode.isEmpty) {
      lastError = 'Nama dan kode perusahaan wajib diisi';
      return false;
    }

    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .post(
            ApiConfig.uri('update_company.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, String>{
              'nama_perusahaan': cleanedName,
              'kode_perusahaan': cleanedCode,
              if (logo.trim().isNotEmpty) 'logo': logo.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      Map<String, dynamic>? body;
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        body = null;
      }

      final bool httpSukses =
          response.statusCode >= 200 && response.statusCode < 300;
      final String? statusTeks = body?['status']?.toString();
      final bool serverTolak =
          body?['success'] == false ||
          (statusTeks != null && !_isSuccessStatus(statusTeks));
      final String? serverMessage = body?['message']?.toString();
      if (!httpSukses || serverTolak) {
        lastError = (serverMessage != null && serverMessage.isNotEmpty)
            ? serverMessage
            : 'Server balas HTTP ${response.statusCode}';
        return false;
      }

      // HTTP 2xx berarti server menerima perubahan. Format balasan boleh
      // berbeda antar versi backend, jadi jangan menggagalkan hanya karena
      // body tidak bisa diparse.
      final Map<String, dynamic>? data = body?['data'] is Map<String, dynamic>
          ? body!['data'] as Map<String, dynamic>
          : null;
      final String? logoDariServer = _text(data?['logo']);
      await save(
        CompanyProfileData(
          name: cleanedName,
          code: cleanedCode,
          logo: logoDariServer ?? (logo.trim().isNotEmpty ? logo.trim() : current.logo),
        ),
      );
      lastError = null;
      return true;
    } catch (e) {
      lastError = 'Gagal terhubung ke server: $e';
      return false;
    }
  }

  static bool _isSuccess(Map<String, dynamic> body) {
    if (body['success'] == false) return false;
    return _isSuccessStatus(body['status']);
  }

  static bool _isSuccessStatus(dynamic value) {
    if (value == null) return true;
    final String text = value.toString().trim().toLowerCase();
    return text.isEmpty || text == 'success' || text == 'ok';
  }

  static Map<String, dynamic> _unwrap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final dynamic nested = decoded['data'];
      if (nested is Map<String, dynamic>) return nested;
      return decoded;
    }
    return <String, dynamic>{};
  }

  static String? _text(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }
}
