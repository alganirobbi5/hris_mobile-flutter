import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class PerusahaanItem {
  const PerusahaanItem({
    required this.id,
    required this.code,
    required this.name,
    this.address = '',
    this.statusAktif = true,
    this.logo = '',
  });

  final int id;
  final String code;
  final String name;
  final String address;
  final bool statusAktif;
  final String logo;

  String get statusLabel => statusAktif ? 'Aktif' : 'Nonaktif';

  factory PerusahaanItem.fromJson(Map<String, dynamic> json) {
    return PerusahaanItem(
      id: SuperAdminService.intValue(
        json['id'] ?? json['company_id'],
      ),
      code: SuperAdminService.textValue(
        json['company_code'] ?? json['code'] ?? json['kode_perusahaan'],
      ),
      name: SuperAdminService.textValue(
        json['company_name'] ?? json['name'] ?? json['nama_perusahaan'],
      ),
      address: SuperAdminService.textValue(json['address'] ?? json['alamat']),
      statusAktif: SuperAdminService.boolValue(
        json['is_active'] ?? json['status'],
        fallback: true,
      ),
      logo: SuperAdminService.textValue(json['logo']),
    );
  }
}

class HrAdminItem {
  const HrAdminItem({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.companyName,
  });

  final int id;
  final String name;
  final String username;
  final String email;
  final String companyName;

  factory HrAdminItem.fromJson(Map<String, dynamic> json) {
    final String firstName = SuperAdminService.textValue(json['first_name']);
    final String lastName = SuperAdminService.textValue(json['last_name']);
    final String namaLengkap =
        SuperAdminService.textValue(json['nama_lengkap']);
    final String name = namaLengkap.isNotEmpty
        ? namaLengkap
        : '$firstName $lastName'.trim();
    return HrAdminItem(
      id: SuperAdminService.intValue(json['id'] ?? json['user_id']),
      name: name,
      username: SuperAdminService.textValue(
        json['username'] ?? json['user_name'],
      ),
      email: SuperAdminService.textValue(json['email']),
      companyName: SuperAdminService.textValue(
        json['company_name'] ?? json['company'] ?? json['perusahaan'],
      ),
    );
  }
}

class SuperAdminService {
  SuperAdminService._();

  static Future<List<PerusahaanItem>> fetchPerusahaan({
    http.Client? client,
  }) async {
    final List<dynamic> raw = await _fetchList(
      'companies.php',
      const <String>['companies', 'data'],
      client: client,
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PerusahaanItem.fromJson)
        .toList();
  }

  static Future<List<HrAdminItem>> fetchHrAdmin({
    http.Client? client,
  }) async {
    final List<dynamic> raw = await _fetchList(
      'super_admin_hr.php',
      const <String>['hr', 'admins', 'data'],
      client: client,
    );
    return raw
        .whereType<Map<String, dynamic>>()
        .map(HrAdminItem.fromJson)
        .toList();
  }

  static Future<void> tambahPerusahaan({
    required String code,
    required String name,
    String logo = '',
    http.Client? client,
  }) async {
    await _post(
      'companies.php',
      <String, dynamic>{
        'company_code': code.trim(),
        'company_name': name.trim(),
        if (logo.trim().isNotEmpty) 'logo': logo.trim(),
      },
      'Gagal menambahkan perusahaan.',
      client: client,
    );
  }

  static Future<void> tambahHrAdmin({
    required int companyId,
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    http.Client? client,
  }) async {
    await _post(
      'super_admin_hr.php',
      <String, dynamic>{
        'company_id': companyId,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      },
      'Gagal menambahkan akun HR/Admin.',
      client: client,
    );
  }

  static Future<void> editPerusahaan({
    required int id,
    required String code,
    required String name,
    String logo = '',
    http.Client? client,
  }) async {
    await _put(
      'companies.php',
      <String, dynamic>{
        'id': id,
        'company_code': code.trim(),
        'company_name': name.trim(),
        if (logo.trim().isNotEmpty) 'logo': logo.trim(),
      },
      'Gagal memperbarui perusahaan.',
      client: client,
    );
  }

  static Future<void> hapusPerusahaan({
    required int id,
    http.Client? client,
  }) async {
    await _delete(
      'companies.php',
      id,
      'Gagal menghapus perusahaan.',
      client: client,
    );
  }

  static Future<void> hapusHrAdmin({
    required int id,
    http.Client? client,
  }) async {
    await _delete(
      'super_admin_hr.php',
      id,
      'Gagal menghapus akun HR/Admin.',
      client: client,
    );
  }

  static Future<void> _delete(
    String endpoint,
    int id,
    String fallbackMessage, {
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final http.Request request = http.Request('DELETE', ApiConfig.uri(endpoint));
    request.headers.addAll(ApiConfig.authHeaders(token));
    request.body = jsonEncode(<String, dynamic>{'action': 'delete', 'id': id});
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      final http.StreamedResponse streamed = await httpClient
          .send(request)
          .timeout(ApiConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } finally {
      if (ownsClient) httpClient.close();
    }
    final Map<String, dynamic> envelope = _decode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        envelope['success'] == false) {
      throw SuperAdminException(
        textValue(envelope['message']).isEmpty
            ? fallbackMessage
            : textValue(envelope['message']),
      );
    }
  }

  static Future<List<dynamic>> _fetchList(
    String endpoint,
    List<String> keys, {
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .get(
            ApiConfig.uri(endpoint),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.requestTimeout);
    } finally {
      if (ownsClient) httpClient.close();
    }
    if (response.statusCode != 200) return const <dynamic>[];
    return _decodeList(response.body, keys);
  }

  static Future<void> _post(
    String endpoint,
    Map<String, dynamic> body,
    String fallbackMessage, {
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .post(
            ApiConfig.uri(endpoint),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);
    } finally {
      if (ownsClient) httpClient.close();
    }
    final Map<String, dynamic> envelope = _decode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        envelope['success'] == false) {
      throw SuperAdminException(
        textValue(envelope['message']).isEmpty
            ? fallbackMessage
            : textValue(envelope['message']),
      );
    }
  }

  static Future<void> _put(
    String endpoint,
    Map<String, dynamic> body,
    String fallbackMessage, {
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final http.Request request = http.Request('PUT', ApiConfig.uri(endpoint));
    request.headers.addAll(ApiConfig.authHeaders(token));
    request.body = jsonEncode(body);
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      final http.StreamedResponse streamed = await httpClient
          .send(request)
          .timeout(ApiConfig.requestTimeout);
      response = await http.Response.fromStream(streamed);
    } finally {
      if (ownsClient) httpClient.close();
    }
    final Map<String, dynamic> envelope = _decode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        envelope['success'] == false) {
      throw SuperAdminException(
        textValue(envelope['message']).isEmpty
            ? fallbackMessage
            : textValue(envelope['message']),
      );
    }
  }

  static List<dynamic> _decodeList(String body, List<String> keys) {
    if (body.trim().isEmpty) return const <dynamic>[];
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const <dynamic>[];
    }
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];
      if (data is List) return data;
      if (data is Map<String, dynamic>) {
        for (final String key in keys) {
          if (data[key] is List) return data[key] as List<dynamic>;
        }
      }
      for (final String key in keys) {
        if (decoded[key] is List) return decoded[key] as List<dynamic>;
      }
    }
    return const <dynamic>[];
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      return decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static int intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static String textValue(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static bool boolValue(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value == 1;
    final String text = textValue(value).toLowerCase();
    if (text == '1' || text == 'true' || text == 'active' || text == 'aktif') {
      return true;
    }
    if (text == '0' ||
        text == 'false' ||
        text == 'inactive' ||
        text == 'nonaktif') {
      return false;
    }
    return fallback;
  }
}

class SuperAdminException implements Exception {
  const SuperAdminException(this.message);

  final String message;

  @override
  String toString() => message;
}
