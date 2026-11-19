import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class AppSession {
  static int? userId;
  static int? employeeId;
  static String? username;
  static String? name;
  static String? role;
  static String? token;

  static void setFromLogin(Map<String, dynamic> data) {
    // user id (prefer user_id, fallback id)
    final dynamic userIdVal = data['user_id'] ?? data['id'];
    userId = userIdVal is int ? userIdVal : int.tryParse(userIdVal?.toString() ?? '');

    // employee_id
    final dynamic empVal = data['employee_id'];
    employeeId = empVal is int ? empVal : int.tryParse(empVal?.toString() ?? '');

    // user details
    username = data['username'] as String?;
    name = data['nama_lengkap'] as String?;
    role = data['role'] as String?;

    // token
    token = data['token'] as String?;

    // persist to SharedPreferences
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      prefs.setInt('user_id', userId!);
    } else {
      prefs.remove('user_id');
    }
    if (username != null) {
      prefs.setString('username', username!);
    } else {
      prefs.remove('username');
    }
    if (role != null) {
      prefs.setString('role', role!);
    } else {
      prefs.remove('role');
    }
    if (token != null && token.isNotEmpty) {
      prefs.setString(ApiConfig.tokenPrefKey, token!);
    } else {
      prefs.remove(ApiConfig.tokenPrefKey);
    }
    if (employeeId != null) {
      prefs.setInt(ApiConfig.employeeIdPrefKey, employeeId!);
    } else {
      prefs.remove(ApiConfig.employeeIdPrefKey);
    }
  }

  static Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
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

  // Convenience getters
  static int? getUserId() => userId;
  static int? getEmployeeId() => employeeId;
  static String? getUsername() => username;
  static String? getName() => name;
  static String? getRole() => role;
  static String? getToken() => token;
}