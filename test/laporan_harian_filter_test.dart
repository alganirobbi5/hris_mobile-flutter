import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/laporan_excel_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'api_token': 'token-laporan',
    });
    AppSession.token = null;
  });

  test('fetchRows mengirim start_date dan end_date ke server', () async {
    late Uri terimaUrl;
    final http.Client client = MockClient((http.Request request) async {
      terimaUrl = request.url;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'status': 'success',
          'data': <dynamic>[],
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final LaporanExcelService service = LaporanExcelService(client: client);
    await service.fetchRows(startDate: '2026-11-01', endDate: '2026-11-30');

    expect(terimaUrl.queryParameters['start_date'], '2026-11-01');
    expect(terimaUrl.queryParameters['end_date'], '2026-11-30');
    expect(terimaUrl.queryParameters.containsKey('date'), isFalse);
  });

  test('fetchHariIni mengirim token dan parameter date ke server', () async {
    late Uri terimaUrl;
    late String? headerOtorisasi;

    final http.Client client = MockClient((http.Request request) async {
      terimaUrl = request.url;
      headerOtorisasi = request.headers['Authorization'];
      return http.Response(
        jsonEncode(<String, dynamic>{
          'status': 'success',
          'data': <dynamic>[
            <String, dynamic>{
              'id': 1,
              'date': LaporanExcelService.tanggalHariIni(),
              'clock_in': '07:45:00',
              'clock_out': null,
              'first_name': 'Budi',
              'last_name': 'Santoso',
            },
          ],
        }),
        200,
      );
    });

    final List<LaporanAbsensiRow> rows =
        await LaporanExcelService(client: client).fetchHariIni();

    expect(terimaUrl.queryParameters['date'],
        LaporanExcelService.tanggalHariIni());
    expect(headerOtorisasi, 'Bearer token-laporan');
    expect(rows, hasLength(1));
    expect(rows.first.nama, 'Budi Santoso');
  });

  test('laporan tetap diminta saat backend belum mengeluarkan token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.token = null;
    late String? headerOtorisasi;

    final http.Client client = MockClient((http.Request request) async {
      headerOtorisasi = request.headers['Authorization'];
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <dynamic>[
            <String, dynamic>{
              'id': 2,
              'date': LaporanExcelService.tanggalHariIni(),
              'clock_in': '08:05:00',
              'first_name': 'Siti',
              'last_name': 'Aminah',
            },
          ],
        }),
        200,
      );
    });

    final List<LaporanAbsensiRow> rows =
        await LaporanExcelService(client: client).fetchRows();

    expect(headerOtorisasi, isNull);
    expect(rows, hasLength(1));
  });

  test('baris sintetis Libur tidak masuk daftar laporan absensi', () async {
    final String hariIni = LaporanExcelService.tanggalHariIni();
    final LaporanAbsensiRow libur = LaporanAbsensiRow.fromJson(
      <String, dynamic>{
        'id': 3,
        'date': hariIni,
        'nama': 'Andi Pratama',
        'status': 'Libur',
      },
    );
    expect(libur.isLibur, isTrue);

    final http.Client client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 3,
              'date': hariIni,
              'nama': 'Andi Pratama',
              'status': 'Libur',
            },
            <String, dynamic>{
              'id': 4,
              'date': hariIni,
              'nama': 'Budi Santoso',
              'clock_in': '08:00:00',
              'clock_out': '17:00:00',
            },
          ],
        }),
        200,
      );
    });

    final List<LaporanAbsensiRow> rows =
        await LaporanExcelService(client: client).fetchHariIni();
    expect(rows, hasLength(1));
    expect(rows.single.nama, 'Budi Santoso');
    expect(rows.any((LaporanAbsensiRow row) => row.isLibur), isFalse);
  });
}
