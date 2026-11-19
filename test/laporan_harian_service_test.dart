import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hris_mobile/config/api_config.dart';
import 'package:hris_mobile/services/laporan_harian_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ApiConfig.tokenPrefKey: 'token-contoh',
    });
  });

  test('fetchHariIni mengirim token, scope=all, dan tanggal hari ini', () async {
    late Uri terimaUrl;
    late Map<String, String> terimaHeader;

    final http.Client client = MockClient((http.Request request) async {
      terimaUrl = request.url;
      terimaHeader = request.headers;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'items': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'date': LaporanHarianService.tanggalHariIni(),
                'clock_in': '07:45:00',
                'clock_out': null,
                'first_name': 'Budi',
                'last_name': 'Santoso',
                'status': 'recorded',
              },
            ],
            'total': 1,
          },
        }),
        200,
      );
    });

    final List<Map<String, dynamic>> rows =
        await LaporanHarianService(client: client).fetchHariIni();

    expect(terimaUrl.queryParameters['scope'], 'all');
    expect(
      terimaUrl.queryParameters['date'],
      LaporanHarianService.tanggalHariIni(),
    );
    expect(terimaHeader['Authorization'], 'Bearer token-contoh');
    expect(rows, hasLength(1));
    expect(rows.first['first_name'], 'Budi');
  });

  test('fetchHariIni menolak ketika token tidak ada', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    expect(
      () => LaporanHarianService(
        client: MockClient((_) async => http.Response('{}', 200)),
      ).fetchHariIni(),
      throwsA(
        isA<LaporanHarianException>().having(
          (LaporanHarianException e) => e.message,
          'message',
          contains('login'),
        ),
      ),
    );
  });
}
