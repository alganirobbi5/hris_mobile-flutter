import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:hris_mobile/services/laporan_excel_service.dart';

void main() {
  test('fetchHariIni mengirim parameter date ke server', () async {
    late Uri terimaUrl;

    final http.Client client = MockClient((http.Request request) async {
      terimaUrl = request.url;
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
    expect(rows, hasLength(1));
    expect(rows.first.nama, 'Budi Santoso');
  });
}
