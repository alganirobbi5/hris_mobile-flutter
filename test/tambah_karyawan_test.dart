import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/tambah_karyawan_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/utils/whatsapp_helper.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    AppSession.token = 'test-token';
  });

  test('normalisasi dan validasi nomor WhatsApp', () {
    expect(WhatsAppHelper.normalizePhone('08123456789'), '628123456789');
    expect(WhatsAppHelper.normalizePhone('628123456789'), '628123456789');
    expect(WhatsAppHelper.normalizePhone(' 0812-3456-789 '), '628123456789');
    expect(WhatsAppHelper.normalizePhone('8123456789'), '628123456789');
    expect(WhatsAppHelper.isValidPhone('08123'), isFalse);
    expect(WhatsAppHelper.validatePhone(''), isNull);
    expect(
      WhatsAppHelper.validatePhone('12345'),
      'No. HP harus diawali 08 atau 628',
    );
  });

  testWidgets('form menampilkan field tanpa departemen dan jabatan', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(home: TambahKaryawanScreen(httpClient: _client(terkirim))),
    );
    await tester.pumpAndSettle();

    expect(find.text('NAMA DEPAN'), findsOneWidget);
    expect(find.text('NAMA BELAKANG'), findsOneWidget);
    expect(find.text('JENIS KELAMIN'), findsOneWidget);
    expect(find.text('EMAIL'), findsOneWidget);
    expect(find.text('NO. HP (WHATSAPP)'), findsOneWidget);
    expect(find.text('DEPARTEMEN'), findsNothing);
    expect(find.text('JABATAN'), findsNothing);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Nonaktif'), findsNothing);
    expect(find.text('USERNAME (UNTUK LOGIN)'), findsOneWidget);
    expect(find.text('PASSWORD'), findsOneWidget);

    await tester.ensureVisible(find.text('Simpan Karyawan'));
    await tester.tap(find.text('Simpan Karyawan'));
    await tester.pump();

    expect(find.text('Nama Depan wajib diisi'), findsOneWidget);
    expect(find.text('Nama Belakang wajib diisi'), findsOneWidget);
    expect(find.text('Jenis Kelamin wajib dipilih'), findsOneWidget);
    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('No. HP wajib diisi'), findsNothing);
    expect(find.text('Departemen wajib dipilih'), findsNothing);
    expect(find.text('Jabatan wajib dipilih'), findsNothing);
    expect(find.text('Username wajib diisi'), findsOneWidget);
    expect(find.text('Password wajib diisi'), findsOneWidget);
    expect(terkirim, isEmpty);
  });

  testWidgets('No. HP opsional dan memvalidasi format 08/628', (
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
    await tester.enterText(find.byType(TextFormField).at(4), 'budi.s');
    await tester.enterText(find.byType(TextFormField).at(5), 'rahasia123');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>).first);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laki-laki').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(3), '12345');
    await tester.ensureVisible(find.text('Simpan Karyawan'));
    await tester.tap(find.text('Simpan Karyawan'));
    await tester.pump();
    expect(
      find.text('No. HP harus diawali 08 atau 628'),
      findsOneWidget,
    );
    expect(terkirim, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(3), '');
    await tester.tap(find.text('Simpan Karyawan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single.containsKey('department_id'), isFalse);
    expect(terkirim.single.containsKey('designation_id'), isFalse);
    expect(terkirim.single['mobile_no'], '');
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
      'status': '1',
      'user_name': 'budi.s',
      'password': 'rahasia123',
    });
  });
}

http.Client _client(List<Map<String, dynamic>> terkirim) {
  return MockClient((http.Request request) async {
    if (request.url.path.endsWith('/tambah_karyawan.php')) {
      terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true, 'message': 'Berhasil'}),
        201,
      );
    }
    return http.Response('', 404);
  });
}
