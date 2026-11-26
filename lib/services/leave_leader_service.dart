import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class LeaveLeader {
  const LeaveLeader({
    required this.id,
    required this.userId,
    required this.employeeId,
    required this.username,
    required this.namaLengkap,
    required this.keterangan,
  });

  final int id;
  final int userId;
  final int? employeeId;
  final String username;
  final String namaLengkap;
  final String keterangan;

  String get displayName =>
      namaLengkap.isNotEmpty ? namaLengkap : (username.isNotEmpty ? username : '-');

  factory LeaveLeader.fromJson(Map<String, dynamic> json) {
    return LeaveLeader(
      id: _int(json['id']) ?? 0,
      userId: _int(json['user_id']) ?? 0,
      employeeId: _int(json['employee_id']),
      username: _text(json['username']),
      namaLengkap: _text(json['nama_lengkap']),
      keterangan: _text(json['keterangan']),
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }
}

class EligibleLeaveUser {
  const EligibleLeaveUser({
    required this.userId,
    required this.username,
    required this.namaLengkap,
    required this.employeeId,
  });

  final int userId;
  final String username;
  final String namaLengkap;
  final int? employeeId;

  String get displayName => namaLengkap.isNotEmpty ? namaLengkap : username;

  factory EligibleLeaveUser.fromJson(Map<String, dynamic> json) {
    return EligibleLeaveUser(
      userId:
          LeaveLeader._int(json['user_id']) ?? LeaveLeader._int(json['id']) ?? 0,
      username: LeaveLeader._text(json['username']),
      namaLengkap: LeaveLeader._text(json['nama_lengkap']),
      employeeId: LeaveLeader._int(json['employee_id']),
    );
  }
}

class LeaveLeadersResult {
  const LeaveLeadersResult({
    required this.leaders,
    required this.eligibleUsers,
  });

  final List<LeaveLeader> leaders;
  final List<EligibleLeaveUser> eligibleUsers;
}

class LeaveLeaderException implements Exception {
  const LeaveLeaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LeaveLeaderService {
  const LeaveLeaderService._();

  static Future<LeaveLeadersResult> fetch({
    bool includeEligible = false,
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final Uri uri = ApiConfig.uri('leave_leaders.php').replace(
      queryParameters: includeEligible
          ? <String, String>{'eligible': '1'}
          : <String, String>{},
    );
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.requestTimeout);
    } finally {
      if (ownsClient) httpClient.close();
    }
    final Map<String, dynamic> envelope = _decode(response.body);
    if (response.statusCode != 200 || envelope['success'] != true) {
      throw LeaveLeaderException(_message(envelope, 'Gagal memuat daftar Leader.'));
    }

    final List<LeaveLeader> leaders = (envelope['leaders'] is List)
        ? (envelope['leaders'] as List)
            .whereType<Map<String, dynamic>>()
            .map(LeaveLeader.fromJson)
            .toList()
        : const <LeaveLeader>[];
    final List<EligibleLeaveUser> eligible = (envelope['eligible_users'] is List)
        ? (envelope['eligible_users'] as List)
            .whereType<Map<String, dynamic>>()
            .map(EligibleLeaveUser.fromJson)
            .toList()
        : const <EligibleLeaveUser>[];
    return LeaveLeadersResult(leaders: leaders, eligibleUsers: eligible);
  }

  static Future<void> add(int userId, {String? keterangan}) async {
    final String? token = await AppSession.resolveToken();
    final http.Response response = await http
        .post(
          ApiConfig.uri('leave_leaders.php'),
          headers: ApiConfig.authHeaders(token),
          body: jsonEncode(<String, dynamic>{
            'user_id': userId,
            if (keterangan != null && keterangan.trim().isNotEmpty)
              'keterangan': keterangan.trim(),
          }),
        )
        .timeout(ApiConfig.requestTimeout);
    final Map<String, dynamic> envelope = _decode(response.body);
    if (response.statusCode != 200 || envelope['success'] != true) {
      throw LeaveLeaderException(
        _message(envelope, 'Gagal menambahkan Leader.'),
      );
    }
  }

  static Future<void> remove(int leaderId) async {
    final String? token = await AppSession.resolveToken();
    final http.Request request = http.Request(
      'DELETE',
      ApiConfig.uri('leave_leaders.php'),
    );
    request.headers.addAll(ApiConfig.authHeaders(token));
    request.body = jsonEncode(<String, dynamic>{'action': 'delete', 'id': leaderId});
    final http.StreamedResponse streamed =
        await request.send().timeout(ApiConfig.requestTimeout);
    final http.Response response = await http.Response.fromStream(streamed);
    final Map<String, dynamic> envelope = _decode(response.body);
    if (response.statusCode != 200 || envelope['success'] != true) {
      throw LeaveLeaderException(
        _message(envelope, 'Gagal menghapus Leader.'),
      );
    }
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static String _message(Map<String, dynamic> envelope, String fallback) {
    final dynamic message = envelope['message'];
    return message != null && message.toString().isNotEmpty
        ? message.toString()
        : fallback;
  }
}
