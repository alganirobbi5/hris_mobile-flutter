import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/company_config.dart';
import 'app_session.dart';

class CompanyProfileData {
  const CompanyProfileData({required this.name, required this.code});

  final String name;
  final String code;
}

/// Data profil perusahaan yang dipakai halaman profil dan validasi login.
/// Nilai lokal dipakai sebagai fallback bila endpoint belum tersedia.
class CompanyProfile {
  const CompanyProfile._();

  static const String nameKey = 'company_name';
  static const String codeKey = 'company_code';

  static CompanyProfileData current = const CompanyProfileData(
    name: CompanyConfig.namaPerusahaan,
    code: CompanyConfig.kodePerusahaan,
  );

  static Future<CompanyProfileData> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String name = _text(prefs.getString(nameKey)) ?? current.name;
    final String code = _text(prefs.getString(codeKey)) ?? current.code;
    current = CompanyProfileData(name: name, code: code);
    return current;
  }

  static Future<void> save(CompanyProfileData data) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(nameKey, data.name);
    await prefs.setString(codeKey, data.code);
    current = data;
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
      if (decoded is Map<String, dynamic> &&
          !_isSuccessStatus(decoded['status'])) {
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
      final CompanyProfileData result = CompanyProfileData(
        name: name ?? base.name,
        code: code ?? base.code,
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
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final String cleanedName = name.trim();
    final String cleanedCode = code.trim();
    if (cleanedName.isEmpty || cleanedCode.isEmpty) return false;

    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .post(
            ApiConfig.uri('update_company.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, String>{
              'nama_perusahaan': cleanedName,
              'kode_perusahaan': cleanedCode,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          !_isSuccessStatus(decoded['status'])) {
        return false;
      }
      await save(
        CompanyProfileData(name: cleanedName, code: cleanedCode),
      );
      return true;
    } catch (_) {
      return false;
    }
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
