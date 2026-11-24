import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/services/laporan_excel_service.dart';

void main() {
  test('buildWorkbookBytes memakai nama perusahaan dan periode dari parameter',
      () {
    const List<LaporanAbsensiRow> rows = <LaporanAbsensiRow>[
      LaporanAbsensiRow(
        id: 1,
        tanggal: '2026-11-01',
        jamMasuk: '08:00:00',
        jamKeluar: '17:00:00',
        nama: 'Budi Santoso',
      ),
    ];

    final List<int> bytes = LaporanExcelService().buildWorkbookBytes(
      rows,
      namaPerusahaan: 'PT Deswa Invisco Multitama',
      periodeLabel: '01/11/2026 s/d 30/11/2026 (Bulanan)',
    );
    final Sheet sheet = Excel.decodeBytes(bytes).tables['Laporan Absensi']!;

    expect(
      (sheet.rows[1][0]?.value as TextCellValue?)?.value.text,
      'PT DESWA INVISCO MULTITAMA',
    );
    expect(
      (sheet.rows[2][0]?.value as TextCellValue?)?.value.text,
      'Periode: 01/11/2026 s/d 30/11/2026 (Bulanan)',
    );
  });

  test('buildWorkbookBytes menghasilkan file xlsx ber-style yang valid', () {
    const List<LaporanAbsensiRow> rows = <LaporanAbsensiRow>[
      LaporanAbsensiRow(
        id: 1,
        tanggal: '2026-11-12',
        jamMasuk: '08:57:58',
        jamKeluar: '17:02:38',
        nama: 'Budi Santoso',
        fotoUrl: 'http://example.com/foto.jpg',
        alamat: 'Jalan Ciputat Raya',
        latitude: '-6.252707',
        longitude: '106.777752',
      ),
      LaporanAbsensiRow(
        id: 2,
        tanggal: '2026-11-12',
        jamMasuk: '07:50:14',
        jamKeluar: '00:00:00',
        nama: 'Siti Aminah',
      ),
    ];

    final List<int> bytes =
        LaporanExcelService().buildWorkbookBytes(rows);
    expect(bytes, isNotEmpty);

    final Excel decoded = Excel.decodeBytes(bytes);
    expect(decoded.tables.containsKey('Laporan Absensi'), isTrue);

    final Sheet sheet = decoded.tables['Laporan Absensi']!;
    final Data? title = sheet.rows[0][0];
    expect((title?.value as TextCellValue?)?.value.text,
        'LAPORAN ABSENSI KARYAWAN');

    final Archive archive = ZipDecoder().decodeBytes(bytes);
    final String stylesXml = utf8.decode(
      archive.findFile('xl/styles.xml')!.content as List<int>,
    );
    // Warna judul, header tabel, dan baris soft harus tertulis di styles.
    expect(stylesXml.contains('FF4436D6'), isTrue);
    expect(stylesXml.contains('FF5B4CFF'), isTrue);
    expect(stylesXml.contains('FFEEF0FF'), isTrue);

    final String sheetXml = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content as List<int>,
    );
    expect(sheetXml.contains('<mergeCells'), isTrue);
    expect(sheetXml.contains('HYPERLINK'), isFalse);

    final Data? headerNama = sheet.rows[5][3];
    expect((headerNama?.value as TextCellValue?)?.value.text, 'Nama Karyawan');

    final Data? headerFoto = sheet.rows[5][7];
    expect((headerFoto?.value as TextCellValue?)?.value.text, 'Koordinat');
    expect(sheet.rows[5].length, 8);

    final Data? nama = sheet.rows[6][3];
    expect((nama?.value as TextCellValue?)?.value.text, 'Budi Santoso');

    final Data? statusTerlambat = sheet.rows[6][6];
    expect((statusTerlambat?.value as TextCellValue?)?.value.text, 'Terlambat');

    final Data? statusTepat = sheet.rows[7][6];
    expect((statusTepat?.value as TextCellValue?)?.value.text, 'Tepat Waktu');

    final Data? koordinat = sheet.rows[6][7];
    expect(
      (koordinat?.value as TextCellValue?)?.value.text,
      '-6.252707, 106.777752',
    );

    final Data? jamKeluar = sheet.rows[7][5];
    expect((jamKeluar?.value as TextCellValue?)?.value.text, '-');
  });
}
