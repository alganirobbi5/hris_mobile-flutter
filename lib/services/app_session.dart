import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AppSession {
  static int? userId;
  static int? employeeId;
  static String? username;
  static String? name;
  static String? role;
  static String? token;

  /// Populate from the login JSON response.
  /// Contract: { success, message, data: { token, user: { user_id, employee_id, username, role, nama_lengkap } } }
  /// A flat payload is also accepted for older backends.
  static Future<void> setFromLogin(Map<String, dynamic> response) async {
    final Map<String, dynamic> data = _unwrap(response);
    final dynamic rawUser = data['user'];
    final Map<String, dynamic> user = rawUser is Map<String, dynamic>
        ? rawUser
        : <String, dynamic>{};

    userId = _asInt(user['user_id'] ?? user['id'] ?? data['user_id'] ?? data['id']);
    employeeId = _asInt(user['employee_id'] ?? data['employee_id']);
    username = _text(user['username'] ?? data['username']);
    name = _text(user['nama_lengkap'] ?? data['nama_lengkap']);
    role = _text(user['role'] ?? data['role']);
    token = _text(
      data['token'] ?? data['api_token'] ?? response['token'] ?? response['api_token'],
    );

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await _persist(prefs);
  }

  /// Rehydrate the in-memory statics from disk. Must run on every cold start:
  /// main() routes to MainScreen from prefs, so the statics would otherwise stay null.
  static Future<void> restore([SharedPreferences? prefs]) async {
    final SharedPreferences store = prefs ?? await SharedPreferences.getInstance();
    userId = _asInt(store.getInt('user_id') ?? store.getString('user_id'));
    employeeId = _asInt(
      store.getInt(ApiConfig.employeeIdPrefKey) ??
          store.getString(ApiConfig.employeeIdPrefKey),
    );
    username = _text(store.getString('username'));
    name = _text(store.getString('nama_lengkap'));
    role = _text(store.getString('role'));
    token = _text(store.getString(ApiConfig.tokenPrefKey));
  }

  /// Single source of truth for the Bearer token. Falls back to the same
  /// SharedPreferences key used by [setFromLogin] so a valid persisted session
  /// is never rejected just because the statics were not restored.
  static Future<String?> resolveToken() async {
    final String? current = _text(token);
    if (current != null) return current;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? stored = _text(prefs.getString(ApiConfig.tokenPrefKey));
    if (stored != null) token = stored;
    return stored;
  }

  /// Employee identity from the value supplied by login.php. No probing and
  /// no synthetic fallback id: if the backend did not supply one, return null.
  static Future<int?> currentEmployeeId() async {
    final int? current = employeeId;
    if (current != null) return current;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? stored = _asInt(
      prefs.getInt(ApiConfig.employeeIdPrefKey) ??
          prefs.getString(ApiConfig.employeeIdPrefKey),
    );
    if (stored != null) employeeId = stored;
    return stored;
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('nama_lengkap');
    await prefs.remove('role');
    await prefs.remove(ApiConfig.tokenPrefKey);
    await prefs.remove(ApiConfig.employeeIdPrefKey);

    userId = null;
    employeeId = null;
    username = null;
    name = null;
    role = null;
    token = null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> response) {
    final dynamic nested = response['data'];
    if (nested is Map<String, dynamic>) return nested;
    if (nested is List && nested.isNotEmpty && nested.first is Map<String, dynamic>) {
      return nested.first as Map<String, dynamic>;
    }
    return response;
  }

  static Future<void> _persist(SharedPreferences prefs) async {
    if (userId != null) {
      await prefs.setInt('user_id', userId!);
    } else {
      await prefs.remove('user_id');
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
      await prefs.setString(ApiConfig.tokenPrefKey, token!);
    } else {
      await prefs.remove(ApiConfig.tokenPrefKey);
    }
    if (employeeId != null) {
      await prefs.setInt(ApiConfig.employeeIdPrefKey, employeeId!);
    } else {
      await prefs.remove(ApiConfig.employeeIdPrefKey);
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
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
}
