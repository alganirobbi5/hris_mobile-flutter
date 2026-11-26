import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PengumumanOverlay {
  PengumumanOverlay._();

  static const String prefsKey = 'pengumuman_overlay';

  static Future<Map<String, Map<String, dynamic>>> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return <String, Map<String, dynamic>>{};

      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, Map<String, dynamic>>{};
      }

      return decoded.map<String, Map<String, dynamic>>(
        (String key, dynamic value) => MapEntry<String, Map<String, dynamic>>(
          key,
          value is Map<String, dynamic>
              ? value
              : <String, dynamic>{},
        ),
      );
    } catch (_) {
      return <String, Map<String, dynamic>>{};
    }
  }

  static Future<void> save(Map<String, Map<String, dynamic>> overlay) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefsKey, jsonEncode(overlay));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(prefsKey);
    } catch (_) {}
  }

  static Future<void> upsert({
    required int id,
    String? judul,
    String? isi,
    String? lampiran,
    bool? dihapus,
  }) async {
    final Map<String, Map<String, dynamic>> overlay = await load();
    final String key = id.toString();
    final Map<String, dynamic> entry =
        Map<String, dynamic>.from(overlay[key] ?? <String, dynamic>{});

    if (judul != null) entry['judul'] = judul;
    if (isi != null) entry['isi'] = isi;
    if (lampiran != null) entry['lampiran'] = lampiran;
    if (dihapus != null) entry['dihapus'] = dihapus;

    overlay[key] = entry;
    await save(overlay);
  }
}
