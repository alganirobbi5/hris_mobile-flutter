import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';
import 'employee_request.dart';

class IzinKeluarException implements Exception {
  const IzinKeluarException(this.message);

  final String message;

  @override
  String toString() => message;
}

class IzinKeluarItem {
  const IzinKeluarItem({
    required this.id,
    required this.employeeId,
    required this.tanggal,
    required this.jamKeluar,
    required this.jamKembali,
    required this.kembaliKeKantor,
    required this.kategori,
    required this.alasan,
    required this.status,
    required this.catatanHr,
    required this.namaKaryawan,
  });

  final int id;
  final int employeeId;
  final String tanggal;
  final String jamKeluar;
  final String jamKembali;
  final bool kembaliKeKantor;
  final String kategori;
  final String alasan;
  final String status;
  final String catatanHr;
  final String namaKaryawan;

  String get jamKeluarPendek => _jamPendek(jamKeluar);
  String get jamKembaliPendek => _jamPendek(jamKembali);

  static String _jamPendek(String value) {
    final String text = value.trim();
    if (text.isEmpty || text == '-') return '-';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  factory IzinKeluarItem.fromJson(Map<String, dynamic> json) {
    final String firstName = _text(json['first_name']);
    final String lastName = _text(json['last_name']);
    final String namaLengkap = '$firstName $lastName'.trim();

    return IzinKeluarItem(
      id: _int(json['id']) ?? 0,
      employeeId: _int(json['employee_id']) ?? 0,
      tanggal: _text(json['tanggal']),
      jamKeluar: _text(json['jam_keluar']),
      jamKembali: _text(json['jam_kembali']),
      kembaliKeKantor: _bool(json['kembali_ke_kantor']),
      kategori: _text(json['kategori']),
      alasan: _text(json['alasan']),
      status: _text(json['status']).isEmpty ? 'pending' : _text(json['status']),
      catatanHr: _text(json['catatan_hr']),
      namaKaryawan: _text(json['nama_lengkap']).isEmpty
          ? (namaLengkap.isEmpty ? _text(json['user_name']) : namaLengkap)
          : _text(json['nama_lengkap']),
    );
  }

  static String _text(dynamic value) {
    if (value == null) return '';
    final String text = value.toString().trim();
    return text.toLowerCase() == 'null' ? '' : text;
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(_text(value));
  }

  static bool _bool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final String text = _text(value).toLowerCase();
    return text == '1' || text == 'true';
  }
}

class IzinKeluarService {
  const IzinKeluarService._();

  static Future<List<IzinKeluarItem>> fetch({
    bool allScope = false,
    String? status,
  }) async {
    final String? token = await AppSession.resolveToken();
    final http.Response response = await http
        .get(
          EmployeeRequest.izinKeluarUri(allScope: allScope, status: status),
          headers: ApiConfig.authHeaders(token),
        )
        .timeout(ApiConfig.requestTimeout);

    final Map<String, dynamic> envelope = _decode(response.body);
    if (response.statusCode != 200 || envelope['success'] != true) {
      throw IzinKeluarException(
        _message(envelope, 'Gagal memuat pengajuan izin keluar.'),
      );
    }
    final dynamic data = envelope['data'];
    if (data is! List) return const <IzinKeluarItem>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(IzinKeluarItem.fromJson)
        .where((IzinKeluarItem item) => item.id > 0)
        .toList();
  }

  static Future<IzinKeluarItem> ajukan({
    required String tanggal,
    required String jamKeluar,
    String? jamKembali,
    required bool kembaliKeKantor,
    required String kategori,
    required String alasan,
    required int leaderUserId,
  }) async {
    final String? token = await AppSession.resolveToken();
    final http.Response response = await http
        .post(
          EmployeeRequest.izinKeluarUri(),
          headers: ApiConfig.authHeaders(token),
          body: jsonEncode(
            EmployeeRequest.ajukanIzinKeluarBody(
              tanggal: tanggal,
              jamKeluar: jamKeluar,
              jamKembali: jamKembali,
              kembaliKeKantor: kembaliKeKantor,
              kategori: kategori,
              alasan: alasan,
              leaderUserId: leaderUserId,
            ),
          ),
        )
        .timeout(ApiConfig.requestTimeout);

    final Map<String, dynamic> envelope = _decode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        envelope['success'] != true) {
      throw IzinKeluarException(
        _message(envelope, 'Gagal mengirim pengajuan izin keluar.'),
      );
    }
    return IzinKeluarItem.fromJson(_asMap(envelope['data']));
  }

  static Future<IzinKeluarItem> decide(
    int id,
    String status, {
    String? catatanHr,
  }) async {
    final String? token = await AppSession.resolveToken();
    final http.Response response = await http
        .post(
          ApiConfig.uri('approve_izin_keluar.php'),
          headers: ApiConfig.authHeaders(token),
          body: jsonEncode(
            EmployeeRequest.approveIzinKeluarBody(
              id,
              status,
              catatanHr: catatanHr,
            ),
          ),
        )
        .timeout(ApiConfig.requestTimeout);

    final Map<String, dynamic> envelope = _decode(response.body);
    if (response.statusCode != 200 || envelope['success'] != true) {
      throw IzinKeluarException(
        _message(envelope, 'Gagal memproses pengajuan izin keluar.'),
      );
    }
    return IzinKeluarItem.fromJson(_asMap(envelope['data']));
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static Map<String, dynamic> _decode(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{};
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
