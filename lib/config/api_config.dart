class ApiConfig {
  const ApiConfig._();

  /// URL backend produksi VPS.
  /// Bisa di-override saat build/run dengan:
  /// flutter build apk --release --dart-define=API_BASE_URL=http://31.97.199.58/HRM/src/api
  /// Atau override manual:
  /// flutter run --dart-define=API_BASE_URL=http://31.97.199.58/HRM/src/api
  static const String _defaultBaseUrl = 'http://31.97.199.58/HRM/src/api';

  /// Override saat build/run, contoh:
  /// flutter run --dart-define=API_BASE_URL=http://31.97.199.58/HRM/src/api

  /// Override saat build/run, contoh:
  /// flutter run --dart-define=API_BASE_URL=http://31.97.199.58/HRM/src/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Kunci token yang dipakai backend Bearer Auth yang baru.
  static const String authTokenPrefKey = 'auth_token';

  /// Kunci lama tetap dibaca/ditulis untuk kompatibilitas sesi existing.
  static const String tokenPrefKey = 'api_token';
  static const String employeeIdPrefKey = 'employee_id';

  /// Header standar untuk request API yang butuh autentikasi.
  static Map<String, String> authHeaders(String? token) {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }
    return headers;
  }

  static Uri uri(String path) {
    final String normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final String normalizedPath = path.startsWith('/')
        ? path.substring(1)
        : path;
    return Uri.parse('$normalizedBase/$normalizedPath');
  }
}
