class WorkDuration {
  const WorkDuration._();

  static const String kosong = '00:00:00';

  static String format(Duration? value) {
    if (value == null || value.isNegative) return kosong;
    final int total = value.inSeconds;
    final int jam = total ~/ 3600;
    final int menit = (total % 3600) ~/ 60;
    final int detik = total % 60;
    return '${_dua(jam)}:${_dua(menit)}:${_dua(detik)}';
  }

  static DateTime? parse(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    final String teks = value.toString().trim();
    if (teks.isEmpty || teks == '-' || teks.toLowerCase() == 'null') {
      return null;
    }
    final String bersih = teks
        .replaceAll(RegExp(r'\bWIB\b', caseSensitive: false), '')
        .trim();

    final DateTime? iso = DateTime.tryParse(bersih);
    if (iso != null) return iso;

    final RegExpMatch? lengkap = RegExp(
      r'^(\d{4})-(\d{1,2})-(\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(bersih);
    if (lengkap != null) {
      final int tahun = int.tryParse(lengkap.group(1) ?? '') ?? -1;
      final int bulan = int.tryParse(lengkap.group(2) ?? '') ?? -1;
      final int hari = int.tryParse(lengkap.group(3) ?? '') ?? -1;
      final int jam = int.tryParse(lengkap.group(4) ?? '') ?? -1;
      final int menit = int.tryParse(lengkap.group(5) ?? '') ?? -1;
      final int detik = int.tryParse(lengkap.group(6) ?? '0') ?? 0;
      if (_valid(tahun, bulan, hari, jam, menit, detik)) {
        return DateTime(tahun, bulan, hari, jam, menit, detik);
      }
      return null;
    }

    final RegExpMatch? jamSaja = RegExp(
      r'^(\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(bersih);
    if (jamSaja != null) {
      final int jam = int.tryParse(jamSaja.group(1) ?? '') ?? -1;
      final int menit = int.tryParse(jamSaja.group(2) ?? '') ?? -1;
      final int detik = int.tryParse(jamSaja.group(3) ?? '0') ?? 0;
      if (_valid(1970, 1, 1, jam, menit, detik)) {
        return DateTime(1970, 1, 1, jam, menit, detik);
      }
    }
    return null;
  }

  static String dariDateTime(DateTime? masuk, DateTime? pulang) {
    if (masuk == null || pulang == null) return kosong;
    return format(pulang.difference(masuk));
  }

  static String dariString(dynamic masuk, dynamic pulang) {
    final DateTime? waktuMasuk = parse(masuk);
    final DateTime? waktuPulang = parse(pulang);
    if (waktuMasuk == null || waktuPulang == null) return kosong;
    Duration selisih = waktuPulang.difference(waktuMasuk);
    if (selisih.isNegative && _hanyaJam(masuk) && _hanyaJam(pulang)) {
      selisih += const Duration(days: 1);
    }
    return format(selisih);
  }

  static String normalize(dynamic value) {
    if (value == null) return kosong;
    final String teks = value.toString().trim();
    if (teks.isEmpty) return kosong;

    final RegExpMatch? jam = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(teks);
    if (jam != null) {
      final DateTime? parsed = parse(teks);
      if (parsed != null) {
        return format(
          Duration(hours: parsed.hour, minutes: parsed.minute, seconds: parsed.second),
        );
      }
    }

    final List<String> bagian = teks.split(':');
    if (bagian.length >= 2) {
      final int? jamAngka = int.tryParse(bagian[0].trim());
      final int? menitAngka = int.tryParse(bagian[1].trim());
      final int? detikAngka = bagian.length > 2
          ? int.tryParse(bagian[2].trim().split('.').first)
          : 0;
      if (jamAngka != null &&
          menitAngka != null &&
          detikAngka != null &&
          menitAngka < 60 &&
          detikAngka < 60) {
        return format(
          Duration(hours: jamAngka, minutes: menitAngka, seconds: detikAngka),
        );
      }
    }

    final double? jamDesimal = double.tryParse(teks);
    if (jamDesimal != null && jamDesimal >= 0) {
      return format(
        Duration(milliseconds: (jamDesimal * 3600000).round()),
      );
    }
    return kosong;
  }

  static bool _hanyaJam(dynamic value) =>
      value is String && RegExp(r'^\d{1,2}:\d{2}').hasMatch(value.trim());

  static bool _valid(
    int tahun,
    int bulan,
    int hari,
    int jam,
    int menit,
    int detik,
  ) {
    if (tahun < 1970 || bulan < 1 || bulan > 12 || hari < 1 || hari > 31) {
      return false;
    }
    return jam >= 0 && jam <= 23 && menit >= 0 && menit <= 59 && detik >= 0 && detik <= 59;
  }

  static String _dua(int nilai) => nilai.toString().padLeft(2, '0');
}
