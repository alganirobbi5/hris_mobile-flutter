import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'app_session.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocationItem {
  const LocationItem({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeter,
  });

  final int id;
  final String name;
  final String latitude;
  final String longitude;
  final int radiusMeter;

  String get koordinat => '$latitude, $longitude';

  static LocationItem fromJson(Map<String, dynamic> json) {
    return LocationItem(
      id: int.tryParse(
            (json['id'] ?? json['location_id'] ?? json['lokasi_id'] ?? '')
                .toString(),
          ) ??
          0,
      name: (json['nama_lokasi'] ??
              json['name'] ??
              json['nama'] ??
              json['location_name'] ??
              '')
          .toString()
          .trim(),
      latitude: (json['latitude'] ?? json['lat'] ?? '').toString().trim(),
      longitude: (json['longitude'] ?? json['lng'] ?? json['long'] ?? '')
          .toString()
          .trim(),
      radiusMeter: int.tryParse(
            (json['radius_meter'] ?? json['radius'] ?? '0').toString(),
          ) ??
          0,
    );
  }
}

class LocationService {
  const LocationService._();

  static Future<List<LocationItem>> getLocations({
    int? companyId,
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    final Uri base = ApiConfig.uri('get_lokasi.php');
    final Uri uri = companyId == null
        ? base
        : base.replace(
            queryParameters: <String, String>{'company_id': '$companyId'},
          );
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .get(uri, headers: ApiConfig.authHeaders(token))
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode != 200) {
        throw LocationException(
          'Gagal memuat daftar lokasi (HTTP ${response.statusCode}).',
        );
      }
      final dynamic decoded = jsonDecode(response.body);
      dynamic raw = decoded;
      if (decoded is Map<String, dynamic>) {
        raw = decoded['locations'] ??
            decoded['lokasi'] ??
            decoded['data'] ??
            decoded['result'];
      }
      if (raw is! List) return const <LocationItem>[];
      return raw
          .whereType<Map<String, dynamic>>()
          .map(LocationItem.fromJson)
          .where((LocationItem item) => item.name.isNotEmpty)
          .toList();
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException('Gagal terhubung ke server.');
    }
  }

  static Future<void> createLocation({
    required String name,
    required String latitude,
    required String longitude,
    required int radiusMeter,
    int? companyId,
    http.Client? client,
  }) async {
    await _post(
      'tambah_lokasi.php',
      <String, dynamic>{
        'nama_lokasi': name.trim(),
        'latitude': latitude.trim(),
        'longitude': longitude.trim(),
        'radius_meter': radiusMeter,
        'company_id': ?companyId,
      },
      'Gagal menambahkan lokasi.',
      client: client,
    );
  }

  static Future<void> deleteLocation(
    int id, {
    int? companyId,
    http.Client? client,
  }) async {
    await _post(
      'hapus_lokasi.php',
      <String, dynamic>{
        'id': id,
        'company_id': ?companyId,
      },
      'Gagal menghapus lokasi.',
      client: client,
    );
  }

  static Future<void> _post(
    String endpoint,
    Map<String, dynamic> body,
    String fallbackMessage, {
    http.Client? client,
  }) async {
    final http.Client httpClient = client ?? http.Client();
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await httpClient
          .post(
            ApiConfig.uri(endpoint),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw LocationException(
          _pesanGagal(response.body, fallbackMessage),
        );
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['success'] == false) {
        throw LocationException(_pesanGagal(response.body, fallbackMessage));
      }
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException('Gagal terhubung ke server.');
    }
  }

  static String _pesanGagal(String body, String fallback) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final String pesan = (decoded['message'] ?? decoded['error'] ?? '')
            .toString()
            .trim();
        if (pesan.isNotEmpty) return pesan;
      }
    } on FormatException {
      return fallback;
    }
    return fallback;
  }
}
