import 'dart:convert';

import 'package:http/http.dart' as http;

class LocationNameService {
  LocationNameService._();

  static const String fallbackLabel =
      'Lokasi terdeteksi pada koordinat tersebut';
  static const String userAgent = 'HRISDignityMobile/1.0';
  static const Duration requestTimeout = Duration(seconds: 5);

  static final Map<String, String> _cache = <String, String>{};

  static String cacheKey(double latitude, double longitude) =>
      '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';

  static String? cached(double latitude, double longitude) =>
      _cache[cacheKey(latitude, longitude)];

  static void clearCache() => _cache.clear();

  static void prime(double latitude, double longitude, String name) {
    _cache[cacheKey(latitude, longitude)] = name;
  }

  static Future<String> resolve(
    double latitude,
    double longitude, {
    http.Client? client,
  }) async {
    final String key = cacheKey(latitude, longitude);
    final String? cachedName = _cache[key];
    if (cachedName != null) return cachedName;

    final String name = await _fetch(latitude, longitude, client: client);
    _cache[key] = name;
    return name;
  }

  static Future<String> _fetch(
    double latitude,
    double longitude, {
    http.Client? client,
  }) async {
    final Uri uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse',
    ).replace(
      queryParameters: <String, String>{
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'accept-language': 'id',
      },
    );

    final bool ownsClient = client == null;
    final http.Client httpClient = client ?? http.Client();
    try {
      final http.Response response = await httpClient
          .get(uri, headers: <String, String>{'User-Agent': userAgent})
          .timeout(requestTimeout);
      if (response.statusCode != 200) return fallbackLabel;
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return fallbackLabel;
      final dynamic address = decoded['address'];
      return formatNamaTempat(
        address is Map<String, dynamic> ? address : <String, dynamic>{},
        displayName: decoded['display_name']?.toString(),
      );
    } catch (_) {
      return fallbackLabel;
    } finally {
      if (ownsClient) httpClient.close();
    }
  }

  static String formatNamaTempat(
    Map<String, dynamic> address, {
    String? displayName,
  }) {
    final List<String> parts = <String>[];

    final String jalan = _first(address, const <String>[
      'road',
      'pedestrian',
      'footway',
      'path',
      'building',
      'amenity',
      'tourism',
      'office',
    ]);
    final String nomor = _first(address, const <String>['house_number']);
    if (jalan.isNotEmpty) {
      parts.add(nomor.isEmpty ? jalan : '$jalan No. $nomor');
    } else if (nomor.isNotEmpty) {
      parts.add('No. $nomor');
    }

    final String kelurahan = _first(address, const <String>[
      'neighbourhood',
      'quarter',
      'village',
      'suburb',
    ]);
    final String kecamatan = _first(address, const <String>[
      'city_district',
      'district',
      'county',
    ]);
    final String kota = _first(address, const <String>[
      'city',
      'town',
      'municipality',
      'state',
    ]);

    for (final String part in <String>[kelurahan, kecamatan, kota]) {
      if (part.isNotEmpty && !parts.contains(part)) parts.add(part);
    }

    if (parts.isNotEmpty) return parts.take(4).join(', ');

    final String fallback = displayName?.trim() ?? '';
    if (fallback.isEmpty) return fallbackLabel;
    return fallback.split(',').map((String s) => s.trim()).where(
      (String s) => s.isNotEmpty,
    ).take(3).join(', ');
  }

  static String _first(Map<String, dynamic> json, List<String> keys) {
    for (final String key in keys) {
      final dynamic value = json[key];
      if (value == null) continue;
      final String text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return '';
  }
}
