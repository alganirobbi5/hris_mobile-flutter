import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/tambah_karyawan_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/karyawan_option_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    AppSession.token = 'test-token';
  });

  test('parsing opsi departemen dan jabatan dari backend', () {
    final List<KaryawanOption> departemen = KaryawanOptionService.parse(
      jsonEncode(<String, dynamic>{
        'success': true,
        'data': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'department_name': 'IT'},
          <String, dynamic>{'department_id': 2, 'name': 'HR'},
        ],
      }),
      key: 'departments',
    );
    expect(departemen.map((KaryawanOption o) => o.name).toList(), <String>['IT', 'HR']);
    expect(departemen.last.id, 2);

    final List<KaryawanOption> jabatan = KaryawanOptionService.parse(
      jsonEncode(<String, dynamic>{
        'designations': <Map<String, dynamic>>[
          <String, dynamic>{'designation_id': 3, 'designation_name': 'Developer'},
        ],
      }),
      key: 'designations',
    );
    expect(jabatan.single.id, 3);
    expect(jabatan.single.name, 'Developer');
  });

  testWidgets('form menampilkan seluruh field wajib dan memblokir simpan', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(home: TambahKaryawanScreen(httpClient: _client(terkirim))),
    );
    await tester.pumpAndSettle();

    expect(find.text('NAMA DEPAN'), findsOneWidget);
    expect(find.text('NAMA BELAKANG'), findsOneWidget);
    expect(find.text('NAMA BELAKANG (OPSIONAL)'), findsNothing);
    expect(find.text('JENIS KELAMIN'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('NO. HP'), findsOneWidget);
    expect(find.text('DEPARTEMEN'), findsOneWidget);
    expect(find.text('JABATAN'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Nonaktif'), findsNothing);
    expect(find.text('USERNAME (UNTUK LOGIN)'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);
    expect(find.text('IT'), findsNothing);

    await tester.ensureVisible(find.text('Simpan Karyawan'));
    await tester.tap(find.text('Simpan Karyawan'));
    await tester.pump();

    expect(find.text('Nama Depan wajib diisi'), findsOneWidget);
    expect(find.text('Nama Belakang wajib diisi'), findsOneWidget);
    expect(find.text('Jenis Kelamin wajib dipilih'), findsOneWidget);
    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('No. HP wajib diisi'), findsOneWidget);
    expect(find.text('Departemen wajib dipilih'), findsOneWidget);
    expect(find.text('Jabatan wajib dipilih'), findsOneWidget);
    expect(find.text('Username wajib diisi'), findsOneWidget);
    expect(find.text('Password wajib diisi'), findsOneWidget);
    expect(terkirim, isEmpty);
  });

  testWidgets('Simpan Karyawan mengirim seluruh field ke backend', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(home: TambahKaryawanScreen(httpClient: _client(terkirim))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
    await tester.enterText(find.byType(TextFormField).at(1), 'Santoso');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'budi@perusahaan.com',
    );
    await tester.enterText(find.byType(TextFormField).at(3), '08123456789');
    await tester.enterText(find.byType(TextFormField).at(4), 'budi.s');
    await tester.enterText(find.byType(TextFormField).at(5), 'rahasia123');

    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laki-laki').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('IT').last);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Developer').last);
    await tester.pumpAndSettle();

    expect(find.text('Nonaktif'), findsNothing);

    await tester.ensureVisible(find.text('Simpan Karyawan'));
    await tester.tap(find.text('Simpan Karyawan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single, <String, dynamic>{
      'first_name': 'Budi',
      'last_name': 'Santoso',
      'gender': 'Male',
      'email': 'budi@perusahaan.com',
      'mobile_no': '08123456789',
      'department_id': 1,
      'designation_id': 3,
      'status': '1',
      'user_name': 'budi.s',
      'password': 'rahasia123',
    });
  });
}

http.Client _client(List<Map<String, dynamic>> terkirim) {
  return MockClient((http.Request request) async {
    final String path = request.url.path;
    if (path.endsWith('/departments.php')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'department_name': 'IT'},
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/designations.php')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{'designation_id': 3, 'designation_name': 'Developer'},
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/tambah_karyawan.php')) {
      terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true, 'message': 'Berhasil'}),
        201,
      );
    }
    return http.Response('', 404);
  });
}
