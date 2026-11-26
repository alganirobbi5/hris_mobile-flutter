import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class KaryawanOption {
  const KaryawanOption({required this.id, required this.name});

  final int id;
  final String name;

  static KaryawanOption? fromJson(
    Map<String, dynamic> json, {
    required List<String> idKeys,
    required List<String> nameKeys,
  }) {
    final int? id = _firstInt(json, idKeys);
    if (id == null) return null;
    final String name = _firstText(json, nameKeys);
    if (name.isEmpty) return null;
    return KaryawanOption(id: id, name: name);
  }

  static int? _firstInt(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value == null) continue;
      final int? parsed = value is int
          ? value
          : int.tryParse(value.toString().trim());
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String _firstText(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value == null) continue;
      final String text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}

class KaryawanOptionsResult {
  const KaryawanOptionsResult({
    required this.departments,
    required this.designations,
  });

  final List<KaryawanOption> departments;
  final List<KaryawanOption> designations;
}

class KaryawanOptionService {
  KaryawanOptionService._();

  static const List<String> departmentEndpoints = <String>[
    'departments.php',
    'get_departments.php',
  ];
  static const List<String> designationEndpoints = <String>[
    'designations.php',
    'get_designations.php',
  ];

  static const List<String> _departmentIdKeys = <String>[
    'id',
    'department_id',
    'dept_id',
  ];
  static const List<String> _departmentNameKeys = <String>[
    'name',
    'department_name',
    'nama',
    'nama_departemen',
  ];
  static const List<String> _designationIdKeys = <String>[
    'id',
    'designation_id',
    'designationId',
    'jabatan_id',
  ];
  static const List<String> _designationNameKeys = <String>[
    'name',
    'designation_name',
    'jabatan',
    'nama_jabatan',
    'title',
  ];

  static Future<KaryawanOptionsResult> fetchAll({
    http.Client? client,
  }) async {
    final List<List<KaryawanOption>> hasil = await Future.wait<
      List<KaryawanOption>
    >(<Future<List<KaryawanOption>>>[
      _fetchPertama(
        departmentEndpoints,
        key: 'departments',
        client: client,
      ),
      _fetchPertama(
        designationEndpoints,
        key: 'designations',
        client: client,
      ),
    ]);
    return KaryawanOptionsResult(
      departments: hasil[0],
      designations: hasil[1],
    );
  }

  static Future<List<KaryawanOption>> _fetchPertama(
    List<String> endpoints, {
    required String key,
    http.Client? client,
  }) async {
    for (final String endpoint in endpoints) {
      final List<KaryawanOption> hasil = await _fetch(
        endpoint,
        key: key,
        client: client,
      );
      if (hasil.isNotEmpty) return hasil;
    }
    return const <KaryawanOption>[];
  }

  static Future<List<KaryawanOption>> _fetch(
    String endpoint, {
    required String key,
    http.Client? client,
  }) async {
    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .get(
            ApiConfig.uri(endpoint),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode != 200) return const <KaryawanOption>[];
      return parse(response.body, key: key);
    } catch (_) {
      return const <KaryawanOption>[];
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  static List<KaryawanOption> parse(
    String body, {
    required String key,
  }) {
    if (body.trim().isEmpty) return const <KaryawanOption>[];
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return const <KaryawanOption>[];
    }

    dynamic raw = decoded;
    if (decoded is Map<String, dynamic>) {
      final dynamic data = decoded['data'];
      if (data is Map<String, dynamic>) {
        raw = data[key] ?? data['items'] ?? data['data'];
      } else if (data is List) {
        raw = data;
      } else {
        raw = decoded[key] ?? decoded['items'];
      }
    }
    if (raw is! List) return const <KaryawanOption>[];

    final bool departemen = key == 'departments';
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> item) => KaryawanOption.fromJson(
            item,
            idKeys: departemen ? _departmentIdKeys : _designationIdKeys,
            nameKeys: departemen ? _departmentNameKeys : _designationNameKeys,
          ),
        )
        .whereType<KaryawanOption>()
        .toList();
  }
}
