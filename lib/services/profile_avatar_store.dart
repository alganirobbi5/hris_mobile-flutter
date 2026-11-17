import 'package:shared_preferences/shared_preferences.dart';

class ProfileAvatarStore {
  ProfileAvatarStore._();

  static String _key(int? userId) => 'profile_avatar_${userId ?? 'guest'}';

  static Future<String?> load(int? userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? value = prefs.getString(_key(userId));
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int? userId, String? avatarId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = _key(userId);
      if (avatarId == null || avatarId.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, avatarId);
      }
    } catch (_) {
      return;
    }
  }
}
