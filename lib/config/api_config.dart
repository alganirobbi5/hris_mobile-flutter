class ApiConfig {
  const ApiConfig._();

  static const String _defaultBaseUrl = 'http://31.97.199.58/HRM/src/api';

  /// Override saat build/run, contoh:
  /// flutter run --dart-define=API_BASE_URL=http://31.97.199.58/HRM/src/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  static const Duration requestTimeout = Duration(seconds: 15);

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
