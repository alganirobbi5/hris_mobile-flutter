import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';
import 'employee_request.dart';

class ProfileCredentialException implements Exception {
  const ProfileCredentialException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ProfileCredentialResult {
  const ProfileCredentialResult({
    required this.username,
    required this.message,
  });

  final String username;
  final String message;
}

class ProfileCredentialService {
  const ProfileCredentialService._();

  static Future<ProfileCredentialResult> update({
    required String username,
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final String body = jsonEncode(
      EmployeeRequest.credentialUpdateBody(
        username: username,
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      ),
    );

    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    http.Response response;
    try {
      response = await httpClient
          .post(
            EmployeeRequest.credentialUpdate(),
            headers: ApiConfig.authHeaders(token),
            body: body,
          )
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await httpClient
            .post(
              EmployeeRequest.credentialUpdateFallback(),
              headers: ApiConfig.authHeaders(token),
              body: body,
            )
            .timeout(ApiConfig.requestTimeout);
      }
    } catch (_) {
      throw const ProfileCredentialException('Gagal terhubung ke server.');
    } finally {
      if (ownsClient) httpClient.close();
    }

    final Map<String, dynamic>? envelope = _decode(response.body);
    final bool httpSukses =
        response.statusCode >= 200 && response.statusCode < 300;
    final String? statusTeks = envelope?['status']?.toString();
    final bool serverTolak = envelope?['success'] == false ||
        (statusTeks != null &&
            statusTeks.toLowerCase() != 'success' &&
            statusTeks.toLowerCase() != 'ok');
    if (!httpSukses || serverTolak) {
      final String pesan = envelope?['message']?.toString().trim() ?? '';
      throw ProfileCredentialException(
        pesan.isEmpty ? 'Gagal menyimpan username dan password.' : pesan,
      );
    }

    final dynamic data = envelope?['data'];
    final String usernameServer = data is Map<String, dynamic>
        ? _text(data['username'] ?? data['user_name'])
        : _text(envelope?['username'] ?? envelope?['user_name']);

    return ProfileCredentialResult(
      username: usernameServer.isEmpty ? username.trim() : usernameServer,
      message: _text(envelope?['message']).isEmpty
          ? 'Username dan password berhasil diperbarui.'
          : _text(envelope!['message']),
    );
  }

  static Map<String, dynamic>? _decode(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}
