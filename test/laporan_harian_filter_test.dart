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
}
