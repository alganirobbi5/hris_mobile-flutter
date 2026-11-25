import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AppSession {
  static const String userIdPrefKey = 'user_id';
  static const String isLeaveLeaderPrefKey = 'is_leave_leader';

  static int? userId;
  static int? employeeId;
  static String? username;
  static String? name;
  static String? role;
  static String? token;
  static bool isLeaveLeader = false;

  /// Populate from the login JSON response.
  /// Deployed login.php (pre-token): { status, message, data: { user_id,
  /// employee_id, username, role, nama_lengkap } }.
  /// Token backend: { success, message, data: { token, user: { ... } } }.
  /// Both shapes are normalized here; employee_id is never derived from
  /// user_id because the two ids refer to different tables.
  static Future<void> setFromLogin(Map<String, dynamic> response) async {
    final Map<String, dynamic> data = _asMap(response['data']);
    final Map<String, dynamic> user = _asMap(data['user']);

    final List<Map<String, dynamic>> sources = _sessionSources(response);
    final List<Map<String, dynamic>> identitySources =
        <Map<String, dynamic>>[user, ...sources];

    token = _text(data['token']) ?? extractToken(response);
    userId = _asInt(user['user_id']) ??
        _firstInt(identitySources, const <String>['user_id', 'id']);
    employeeId = _firstInt(identitySources, const <String>['employee_id']);
    username = _firstText(identitySources, const <String>['username']);
    name = _firstText(
      identitySources,
      const <String>['nama_lengkap', 'full_name', 'name'],
    );
    role = _text(user['role']) ??
        _firstText(identitySources, const <String>['role']);
    isLeaveLeader = _firstBool(
      identitySources,
      const <String>['is_leave_leader'],
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persist(prefs);
  }

  static Map<String, dynamic> _asMap(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};

  static List<Map<String, dynamic>> _sessionSources(
    Map<String, dynamic> response,
  ) {
    final List<Map<String, dynamic>> sources = <Map<String, dynamic>>[];

    void addIfMap(dynamic value) {
      if (value is Map<String, dynamic>) sources.add(value);
    }

    final dynamic data = response['data'];
    addIfMap(data);
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      addIfMap(data.first);
    }
    if (data is Map<String, dynamic>) {
      addIfMap(data['data']);
      addIfMap(data['result']);
    }
    addIfMap(response);

    return sources;
  }

  static int? _firstInt(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final Map<String, dynamic> source in sources) {
      for (final String key in keys) {
        final int? value = _asInt(source[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  static bool _firstBool(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final Map<String, dynamic> source in sources) {
      for (final String key in keys) {
        final dynamic value = source[key];
        if (value is bool) return value;
        if (value is num) return value == 1;
        if (value is String) {
          final String text = value.trim().toLowerCase();
          if (text == 'true' || text == '1') return true;
          if (text == 'false' || text == '0') return false;
        }
      }
    }
    return false;
  }

  static String? _firstText(
    List<Map<String, dynamic>> sources,
    List<String> keys,
  ) {
    for (final Map<String, dynamic> source in sources) {
      for (final String key in keys) {
        final String? value = _text(source[key]);
        if (value != null) return value;
      }
    }
    return null;
  }

  /// Token dari respons login: `token`, `data.token`, `data.data.token`,
  /// atau `data.user.token`.
  static String? extractToken(Map<String, dynamic> response) {
    for (final Map<String, dynamic> source in _tokenSources(response)) {
      final String? value = _text(source['token'] ?? source['api_token']);
      if (value != null) return value;
    }
    return null;
  }

  /// True bila backend menggunakan mode token (field token ada di respons),
  /// termasuk ketika nilainya null/kosong — ini harus ditolak sebagai login gagal.
  static bool responseDeclaresToken(Map<String, dynamic> response) {
    for (final Map<String, dynamic> source in _tokenSources(response)) {
      if (source.containsKey('token') || source.containsKey('api_token')) {
        return true;
      }
    }
    return false;
  }

  static List<Map<String, dynamic>> _tokenSources(
      Map<String, dynamic> response) {
    final List<Map<String, dynamic>> sources = <Map<String, dynamic>>[
      response,
    ];
    final dynamic data = response['data'];
    if (data is Map<String, dynamic>) {
      sources.add(data);
      final dynamic nested = data['data'];
      if (nested is Map<String, dynamic>) sources.add(nested);
      final dynamic user = data['user'];
      if (user is Map<String, dynamic>) sources.add(user);
    }
    return sources;
  }

  /// Rehydrate the in-memory statics from disk. Must run on every cold start:
  /// main() routes to MainScreen from prefs, so the statics would otherwise stay null.
  static Future<void> restore([SharedPreferences? prefs]) async {
    final SharedPreferences store = prefs ?? await SharedPreferences.getInstance();
    userId = _readIntPref(store, userIdPrefKey);
    employeeId = _readIntPref(store, ApiConfig.employeeIdPrefKey);
    username = _text(store.getString('username'));
    name = _text(store.getString('nama_lengkap'));
    role = _text(store.getString('role'));
    isLeaveLeader = store.getBool(isLeaveLeaderPrefKey) ?? false;
    token = _text(store.getString(ApiConfig.authTokenPrefKey)) ??
        _text(store.getString(ApiConfig.tokenPrefKey));
  }

  /// Single source of truth for the Bearer token. Falls back to the same
  /// SharedPreferences key used by [setFromLogin] so a valid persisted session
  /// is never rejected just because the statics were not restored.
  static Future<String?> resolveToken() async {
    final String? current = _text(token);
    if (current != null) return current;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = _text(prefs.getString(ApiConfig.authTokenPrefKey)) ??
        _text(prefs.getString(ApiConfig.tokenPrefKey));
    if (stored != null) token = stored;
    return stored;
  }

  static Future<int?> resolveUserId([SharedPreferences? prefs]) async {
    final int? current = userId;
    if (current != null) return current;
    final SharedPreferences store =
        prefs ?? await SharedPreferences.getInstance();
    final int? stored = _readIntPref(store, userIdPrefKey);
    if (stored != null) userId = stored;
    return stored;
  }

  /// Role from the same session keys used by setFromLogin/restore.
  static Future<String?> resolveRole() async {
    final String? current = _text(role);
    if (current != null) return current;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = _text(prefs.getString('role'));
    if (stored != null) role = stored;
    return stored;
  }

  static Future<bool> resolveIsLeaveLeader() async {
    if (isLeaveLeader) return true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    isLeaveLeader = prefs.getBool(isLeaveLeaderPrefKey) ?? false;
    return isLeaveLeader;
  }

  static Future<void> refreshFromMe() async {
    final String? token = await resolveToken();
    if (token == null || token.isEmpty) return;
    try {
      final http.Response response = await http
          .get(
            ApiConfig.uri('me.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(ApiConfig.requestTimeout);
      if (response.statusCode != 200) return;
      final dynamic decoded = jsonDecode(response.body);
      final dynamic data = decoded is Map<String, dynamic>
          ? decoded['data']
          : null;
      if (data is! Map<String, dynamic>) return;
      final bool value = _firstBool(
        <Map<String, dynamic>>[data],
        const <String>['is_leave_leader'],
      );
      if (value == isLeaveLeader) return;
      isLeaveLeader = value;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(isLeaveLeaderPrefKey, value);
    } catch (_) {
      // Status leader lama tetap dipakai bila me.php gagal.
    }
  }

  static bool isHrRole(String? value) =>
      (value ?? '').trim().toLowerCase() == 'hr';

  /// Employee identity from the value supplied by login.php. No probing and
  /// no synthetic fallback id: if the backend did not supply one, return null.
  static Future<int?> currentEmployeeId() async {
    final int? current = employeeId;
    if (current != null) return current;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? stored = _readIntPref(prefs, ApiConfig.employeeIdPrefKey);
    if (stored != null) employeeId = stored;
    return stored;
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(userIdPrefKey);
    await prefs.remove('username');
    await prefs.remove('nama_lengkap');
    await prefs.remove('role');
    await prefs.remove(ApiConfig.authTokenPrefKey);
    await prefs.remove(ApiConfig.tokenPrefKey);
    await prefs.remove(ApiConfig.employeeIdPrefKey);
    await prefs.remove(isLeaveLeaderPrefKey);

    userId = null;
    employeeId = null;
    username = null;
    name = null;
    role = null;
    token = null;
    isLeaveLeader = false;
  }

  static Future<void> _persist(SharedPreferences prefs) async {
    if (userId != null) {
      await prefs.setInt(userIdPrefKey, userId!);
    } else {
      await prefs.remove(userIdPrefKey);
    }
    if (username != null) {
      await prefs.setString('username', username!);
    } else {
      await prefs.remove('username');
    }
    if (name != null) {
      await prefs.setString('nama_lengkap', name!);
    } else {
      await prefs.remove('nama_lengkap');
    }
    if (role != null) {
      await prefs.setString('role', role!);
    } else {
      await prefs.remove('role');
    }
    if (token != null) {
      await prefs.setString(ApiConfig.authTokenPrefKey, token!);
      await prefs.setString(ApiConfig.tokenPrefKey, token!);
    } else {
      await prefs.remove(ApiConfig.authTokenPrefKey);
      await prefs.remove(ApiConfig.tokenPrefKey);
    }
    if (employeeId != null) {
      await prefs.setInt(ApiConfig.employeeIdPrefKey, employeeId!);
    } else {
      await prefs.remove(ApiConfig.employeeIdPrefKey);
    }
    await prefs.setBool(isLeaveLeaderPrefKey, isLeaveLeader);
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static int? _readIntPref(SharedPreferences prefs, String key) {
    return _asInt(prefs.get(key));
  }

  static String? _text(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static int? get storedEmployeeId => employeeId;
  static bool get isLoggedIn => userId != null || token != null;

  static int? getUserId() => userId;
  static int? getEmployeeId() => employeeId;
  static String? getUsername() => username;
  static String? getName() => name;
  static String? getRole() => role;
  static String? getToken() => token;
  static bool getLeaveLeaderFlag() => isLeaveLeader;
}
