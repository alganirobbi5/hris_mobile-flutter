import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hris_mobile/config/company_config.dart';
import 'package:hris_mobile/services/company_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    CompanyProfile.current = const CompanyProfileData(
      name: CompanyConfig.namaPerusahaan,
      code: CompanyConfig.kodePerusahaan,
    );
  });

  test('tanpa data tersimpan memakai nama dan kode perusahaan bawaan', () async {
    final CompanyProfileData data = await CompanyProfile.load();

    expect(data.name, CompanyConfig.namaPerusahaan);
    expect(data.code, CompanyConfig.kodePerusahaan);
  });

  test('save dan load menyimpan nama serta kode perusahaan', () async {
    await CompanyProfile.save(
      const CompanyProfileData(name: 'PT Dignity', code: 'DGN-2026'),
    );

    final CompanyProfileData data = await CompanyProfile.load();
    expect(data.name, 'PT Dignity');
    expect(data.code, 'DGN-2026');
    expect(CompanyProfile.current.code, 'DGN-2026');
  });

  test('fetch membaca data dari get_company.php', () async {
    late Uri requestedUrl;
    final http.Client client = MockClient((http.Request request) async {
      requestedUrl = request.url;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'status': 'success',
          'data': <String, dynamic>{
            'nama_perusahaan': 'PT Dignity',
            'kode_perusahaan': 'DGN-2026',
          },
        }),
        200,
      );
    });

    final CompanyProfileData? data = await CompanyProfile.fetch(client: client);

    expect(requestedUrl.path, endsWith('/get_company.php'));
    expect(data?.name, 'PT Dignity');
    expect(data?.code, 'DGN-2026');
  });

  test('fetch gagal tidak mengubah data lokal', () async {
    await CompanyProfile.save(
      const CompanyProfileData(name: 'Lama', code: 'LAMA-1'),
    );
    final http.Client client = MockClient(
      (_) async => http.Response('not found', 404),
    );

    expect(await CompanyProfile.fetch(client: client), isNull);
    expect((await CompanyProfile.load()).name, 'Lama');
  });

  test('update mengirim JSON dan menyimpan data hanya saat berhasil', () async {
    late String? body;
    late Uri requestedUrl;
    final http.Client client = MockClient((http.Request request) async {
      requestedUrl = request.url;
      body = request.body;
      return http.Response(jsonEncode(<String, dynamic>{'status': 'success'}), 200);
    });

    final bool saved = await CompanyProfile.update(
      name: 'PT Dignity',
      code: 'DGN-2026',
      client: client,
    );

    expect(requestedUrl.path, endsWith('/update_company.php'));
    expect(jsonDecode(body!)['nama_perusahaan'], 'PT Dignity');
    expect(jsonDecode(body!)['kode_perusahaan'], 'DGN-2026');
    expect(saved, isTrue);
    expect((await CompanyProfile.load()).code, 'DGN-2026');
  });

  test('update gagal tidak menyimpan data lokal', () async {
    await CompanyProfile.save(
      const CompanyProfileData(name: 'Lama', code: 'LAMA-1'),
    );
    final http.Client client = MockClient(
      (_) async => http.Response('{"message":"error"}', 500),
    );

    expect(
      await CompanyProfile.update(
        name: 'Baru',
        code: 'BARU-1',
        client: client,
      ),
      isFalse,
    );
    expect((await CompanyProfile.load()).name, 'Lama');
  });
}
