import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

final DateTime _tanggalMaksimum = DateTime(9999, 12, 31);

const List<String> _namaBulanPendek = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

class HolidayItem {
  const HolidayItem({
    required this.id,
    required this.holidayDate,
    required this.title,
    this.description = '',
    this.isNational = false,
  });

  final int id;
  final String holidayDate;
  final String title;
  final String description;
  final bool isNational;

  String get jenisLabel => isNational ? 'Nasional' : 'Perusahaan';

  DateTime? get dateTime {
    final String raw = holidayDate.trim();
    if (raw.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }

  String get tanggalRingkas {
    final DateTime? date = dateTime;
    if (date == null || date.month < 1 || date.month > 12) {
      return holidayDate.isEmpty ? '-' : holidayDate;
    }
    return '${date.day} ${_namaBulanPendek[date.month - 1]} ${date.year}';
  }

  factory HolidayItem.fromJson(Map<String, dynamic> json) {
    return HolidayItem(
      id: HolidayService.intValue(json['id'] ?? json['holiday_id']),
      holidayDate: HolidayService.textValue(
        json['holiday_date'] ?? json['tanggal_libur'] ?? json['date'],
      ),
      title: HolidayService.textValue(
        json['title'] ?? json['nama_hari_libur'] ?? json['nama'],
      ),
      description: HolidayService.textValue(
        json['description'] ?? json['keterangan'],
      ),
      isNational: HolidayService.boolValue(
        json['is_national'] ?? json['isNational'] ?? json['jenis'],
      ),
    );
  }

  static String toIsoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static int compareByDate(HolidayItem a, HolidayItem b) =>
      (a.dateTime ?? _tanggalMaksimum).compareTo(
        b.dateTime ?? _tanggalMaksimum,
      );
}

class HolidayException implements Exception {
  const HolidayException(this.message);

  final String message;

  @override
  String toString() => message;
}

class HolidayService {
  const HolidayService._();

  static Future<List<HolidayItem>> fetch({http.Client? client}) async {
    final String? token = await AppSession.resolveToken();
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .get(
            ApiConfig.uri('holidays.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.requestTimeout);
    } finally {
      if (ownsClient) httpClient.close();
    }
    if (response.statusCode != 200) {
      throw const HolidayException('Gagal memuat daftar hari libur.');
    }
    final dynamic decoded = _decodeBody(response.body);
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw HolidayException(_message(decoded, 'Gagal memuat daftar hari libur.'));
    }
    return _decodeList(decoded)
        .whereType<Map<String, dynamic>>()
        .map(HolidayItem.fromJson)
        .toList()
      ..sort(HolidayItem.compareByDate);
  }

  static Future<void> add({
    required DateTime date,
    required String title,
    String description = '',
    bool isNational = false,
    http.Client? client,
  }) async {
    final String? token = await AppSession.resolveToken();
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    final http.Response response;
    try {
      response = await httpClient
          .post(
            ApiConfig.uri('holidays.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'holiday_date': HolidayItem.toIsoDate(date),
              'title': title.trim(),
              'description': description.trim(),
              'is_national': isNational,
            }),
          )
          .timeout(ApiConfig.requestTimeout);
    } finally {
      if (ownsClient) httpClient.close();
    }
    _validateMutation(response, 'Gagal menambahkan hari libur.');
  }

  static Future<void> remove(int id, {http.Client? client}) async {
    final String? token = await AppSession.resolveToken();
    final http.Request request = http.Request(
      'DELETE',
      ApiConfig.uri('holidays.php'),
    );
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
    _validateMutation(response, 'Gagal menghapus hari libur.');
  }

  static void _validateMutation(http.Response response, String fallback) {
    final Map<String, dynamic> envelope = _decode(response.body);
    if ((response.statusCode != 200 && response.statusCode != 201) ||
        envelope['success'] == false) {
      throw HolidayException(_message(envelope, fallback));
    }
  }

  static dynamic _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } on FormatException {
      return <String, dynamic>{};
    }
  }

  static Map<String, dynamic> _decode(String body) {
    final dynamic decoded = _decodeBody(body);
    return decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
  }

  static List<dynamic> _decodeList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      const List<String> keys = <String>['holidays', 'data', 'items'];
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

  static String _message(Map<String, dynamic> envelope, String fallback) {
    final String message = textValue(envelope['message']);
    return message.isEmpty ? fallback : message;
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

  static bool boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value == 1;
    final String text = textValue(value).toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'nasional' ||
        text == 'national';
  }
}
