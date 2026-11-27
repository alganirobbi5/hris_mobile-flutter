import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/services/laporan_absensi_admin_service.dart';
import 'package:hris_mobile/services/laporan_excel_service.dart';

void main() {
  test('parser menerima format admin nama_lengkap dan jam_masuk', () {
    const String body = '''
    {"data":[{"id":9,"nama_lengkap":"Admin HR","tanggal":"2026-11-25",
      "jam_masuk":"08:01:00","jam_keluar":"17:05:00",
      "selfie_in_url":"http://x/foto.jpg"}]}
    ''';

    final List<LaporanAbsensiRow> rows =
        LaporanAbsensiAdminService.parse(body);

    expect(rows, hasLength(1));
    expect(rows.first.nama, 'Admin HR');
    expect(rows.first.tanggal, '2026-11-25');
    expect(rows.first.jamMasuk, '08:01:00');
    expect(rows.first.jamKeluar, '17:05:00');
    expect(rows.first.fotoUrl, 'http://x/foto.jpg');
  });

  test('parser menerima format laporan standar', () {
    const String body = '''
    {"data":[{"id":1,"date":"2026-11-25","clock_in":"07:59:00",
      "clock_out":"17:00:00","first_name":"Siti","last_name":"Aminah"}]}
    ''';

    final List<LaporanAbsensiRow> rows =
        LaporanAbsensiAdminService.parse(body);

    expect(rows, hasLength(1));
    expect(rows.first.nama, 'Siti Aminah');
    expect(rows.first.jamMasukTampil, '07:59');
  });

  test('parser admin membuang baris sintetis Libur', () {
    final List<LaporanAbsensiRow> rows = LaporanAbsensiAdminService.parse(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'nama': 'Andi Pratama',
            'status': 'Libur',
          },
          <String, dynamic>{
            'id': 4,
            'nama': 'Budi Santoso',
            'jam_masuk': '08:00:00',
          },
        ],
      }),
    );
    expect(rows, hasLength(1));
    expect(rows.single.nama, 'Budi Santoso');
  });

  test('parser mengembalikan kosong untuk respons tanpa daftar', () {
    expect(LaporanAbsensiAdminService.parse('{"status":"success"}'), isEmpty);
    expect(LaporanAbsensiAdminService.parse(''), isEmpty);
  });

  test('export laporan tetap bekerja saat endpoint admin belum ada', () async {
    final List<int> bytes = LaporanExcelService().buildWorkbookBytes(
      <LaporanAbsensiRow>[
        LaporanAbsensiRow(
          id: 1,
          tanggal: '2026-11-25',
          jamMasuk: '08:00:00',
          jamKeluar: '17:00:00',
          nama: 'Siti Aminah',
        ),
      ],
    );
    expect(bytes.isNotEmpty, isTrue);
  });
}
