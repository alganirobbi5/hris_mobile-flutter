import 'package:shared_preferences/shared_preferences.dart';

class ProfileEmailStore {
  ProfileEmailStore._();

  static String _key(int? userId) => 'profile_email_${userId ?? 'guest'}';

  static Future<String?> load(int? userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? value = prefs.getString(_key(userId));
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int? userId, String email) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), email.trim());
    } catch (_) {
      return;
    }
  }
}
