import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileAvatarStore {
  ProfileAvatarStore._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void notify() => revision.value++;

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

  static String _imageKey(int? userId) =>
      'profile_avatar_image_${userId ?? 'guest'}';

  static Future<String?> loadImage(int? userId) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? value = prefs.getString(_imageKey(userId));
      if (value == null || value.isEmpty) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveImage(int? userId, String? dataUrl) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String key = _imageKey(userId);
      if (dataUrl == null || dataUrl.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, dataUrl);
      }
    } catch (_) {
      return;
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

  /// Migrasi sekali dari kunci lama `user_avatar` yang tidak dibedakan per
  /// akun. Setelah dipindah ke penyimpanan per-user, kunci lama dihapus agar
  /// akun lain tidak mewarisi avatar akun sebelumnya.
  static Future<void> migrateLegacy(int? userId) async {
    if (userId == null) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? legacy = prefs.getString('user_avatar');
      if (legacy == null || legacy.isEmpty) return;
      final String imageKey = _imageKey(userId);
      if (prefs.getString(imageKey) == null) {
        await prefs.setString(imageKey, legacy);
      }
      await prefs.remove('user_avatar');
    } catch (_) {
      return;
    }
  }
}
