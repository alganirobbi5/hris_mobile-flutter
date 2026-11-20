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
  /// Expected backend contract:
  /// { success: true, message: "...", data: { token: "...", user: { user_id: ..., employee_id: ..., username: "...", role: "...", nama_lengkap: "..." } } }
  static Future<void> setFromLogin(Map<String, dynamic> data) async {
    // Extract user object from nested 'data.user'
    final dynamic user = data['data']?['user'];

    // user id (prefer user_id, fallback id)
    userId = user?['user_id'] is int ? user['user_id'] : (user?['id'] is int ? user['id'] : int.tryParse((user?['id'] ?? '').toString()));

    // employee_id from the same user object
    employeeId = user?['employee_id'] is int ? user['employee_id'] : int.tryParse(user?['employee_id']?.toString() ?? '');

    // user details
    username = user?['username'] as String?;
    name = user?['nama_lengkap'] as String?;
    role = user?['role'] as String?;

    // token at top-level 'data.token'
    token = data['token'] as String?;

    // persist to SharedPreferences (project pattern)
    final prefs = await SharedPreferences.getInstance();
    userId != null ? prefs.setInt('user_id', userId!) : prefs.remove('user_id');
    username != null ? prefs.setString('username', username!) : prefs.remove('username');
    role != null ? prefs.setString('role', role!) : prefs.remove('role');
    token != null && token!.isNotEmpty
        ? prefs.setString(ApiConfig.tokenPrefKey, token!)
        : prefs.remove(ApiConfig.tokenPrefKey);
    employeeId != null
        ? prefs.setInt(ApiConfig.employeeIdPrefKey, employeeId!)
        : prefs.remove(ApiConfig.employeeIdPrefKey);
  }

  /// Clear all session data.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
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

  /// Return the employee_id that was stored during login.
  /// Returns null if employee_id was not provided by the backend.
  static int? get storedEmployeeId => employeeId;

  /// Convenience getter for userId
  static int? getUserId() => userId;
  static int? getEmployeeId() => employeeId;
  static String? getUsername() => username;
  static String? getName() => name;
  static String? getRole() => role;
  static String? getToken() => token;

  /// Return the employee_id stored during login, as a Future for compatibility with existing await calls.
  static Future<int?> currentEmployeeId() async => employeeId;
}