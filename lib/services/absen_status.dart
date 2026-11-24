import 'package:flutter/material.dart';

enum StatusAbsenKind {
  tidakAda('', Colors.transparent),
  tepatWaktu('Tepat Waktu', Color(0xFF2E9E6B)),
  terlambat('Terlambat', Color(0xFFE5484D)),
  pulangLebihAwal('Pulang Lebih Awal', Color(0xFFF59E0B)),
  pulangTerlambat('Pulang Terlambat', Color(0xFFE5484D));

  const StatusAbsenKind(this.label, this.color);

  final String label;
  final Color color;
}

class AbsenStatus {
  const AbsenStatus._();

  static const String jamMasukDefault = '08:30';
  static const String jamPulangDefault = '17:00';
  static const int toleransiPulangMenit = 30;

  static int? menitDariJam(dynamic value, {bool ambilTerakhir = false}) {
    if (value == null) return null;
    final String teks = value.toString().trim();
    if (teks.isEmpty || teks == '--:--') return null;

    final Iterable<Match> matches = RegExp(r'(\d{1,2}):(\d{2})').allMatches(teks);
    if (matches.isEmpty) return null;
    final Match match = ambilTerakhir ? matches.last : matches.first;

    final int jam = int.tryParse(match.group(1) ?? '') ?? -1;
    final int menit = int.tryParse(match.group(2) ?? '') ?? -1;
    if (jam < 0 || jam > 23 || menit < 0 || menit > 59) return null;
    return jam * 60 + menit;
  }

  static StatusAbsenKind statusMasuk({
    dynamic jamMasuk,
    dynamic jamMulaiKerja,
  }) {
    final int? masuk = menitDariJam(jamMasuk);
    if (masuk == null) return StatusAbsenKind.tidakAda;
    final int mulai = menitDariJam(jamMulaiKerja) ??
        menitDariJam(jamMasukDefault, ambilTerakhir: true)!;
    return masuk > mulai ? StatusAbsenKind.terlambat : StatusAbsenKind.tepatWaktu;
  }

  static StatusAbsenKind statusPulang({
    dynamic jamPulang,
    dynamic jamSelesaiKerja,
    dynamic statusEksplisit,
  }) {
    final int? pulang = menitDariJam(jamPulang);
    if (pulang == null) return StatusAbsenKind.tidakAda;

    final String eksplisit =
        statusEksplisit?.toString().trim().toLowerCase() ?? '';
    if (eksplisit.isNotEmpty) {
      if (const <String>[
        'early',
        'too_early',
        'lebih_awal',
        'pulang_lebih_awal',
      ].contains(eksplisit)) {
        return StatusAbsenKind.pulangLebihAwal;
      }
      if (const <String>[
        'ontime',
        'on_time',
        'tepat',
        'tepat_waktu',
      ].contains(eksplisit)) {
        return StatusAbsenKind.tepatWaktu;
      }
      if (const <String>[
        'late',
        'terlambat',
        'pulang_terlambat',
      ].contains(eksplisit)) {
        return StatusAbsenKind.pulangTerlambat;
      }
    }

    final int selesai = menitDariJam(
          jamSelesaiKerja,
          ambilTerakhir: true,
        ) ??
        menitDariJam(jamPulangDefault, ambilTerakhir: true)!;
    if (pulang < selesai) return StatusAbsenKind.pulangLebihAwal;
    if (pulang <= selesai + toleransiPulangMenit) {
      return StatusAbsenKind.tepatWaktu;
    }
    return StatusAbsenKind.pulangTerlambat;
  }
}
