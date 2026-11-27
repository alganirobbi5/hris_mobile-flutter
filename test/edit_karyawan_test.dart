import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/edit_karyawan_screen.dart';
import 'package:hris_mobile/screens/settings_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/employee_service.dart';
import 'package:hris_mobile/services/karyawan_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    AppSession.token = 'token-edit';
  });

  test('parsing karyawan memuat username, nomor HP, dan status aktif', () {
    final KaryawanItem item = KaryawanItem.fromJson(<String, dynamic>{
      'employee_id': '7',
      'user_name': 'andi.hr',
      'nama_lengkap': 'Andi Pratama',
      'email': 'andi@example.com',
      'mobile_no': '08123456789',
      'is_active': 1,
    });
    expect(item.id, 7);
    expect(item.username, 'andi.hr');
    expect(item.namaLengkap, 'Andi Pratama');
    expect(item.email, 'andi@example.com');
    expect(item.mobileNo, '08123456789');
    expect(item.statusAktif, isTrue);
  });

  test('EmployeeService.update memakai POST employees.php dengan action update', () async {
    Uri? diminta;
    String? metode;
    Map<String, dynamic>? body;
    final http.Client client = MockClient((http.Request request) async {
      diminta = request.url;
      metode = request.method;
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
      );
    });

    final String pesan = await EmployeeService.update(
      id: 7,
      employeeId: 7,
      userId: 17,
      namaLengkap: 'Andi Pratama',
      username: 'andi.hr',
      email: 'andi@example.com',
      mobileNo: '08123456789',
      statusAktif: true,
      client: client,
    );

    expect(pesan, 'Data karyawan berhasil diperbarui.');
    expect(diminta!.path, endsWith('/employees.php'));
    expect(metode, 'POST');
    expect(body!['action'], 'update');
    expect(body!['id'], 7);
    expect(body!['employee_id'], 7);
    expect(body!['user_id'], 17);
  });

  testWidgets('Settings HR menampilkan Edit Karyawan setelah Tambah Karyawan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreen(isHr: true, canApprove: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tambah Karyawan'), findsOneWidget);
    expect(find.text('Edit Karyawan'), findsOneWidget);
  });

  testWidgets('Pilih Karyawan mengisi form, simpan, dan chat WhatsApp', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = MockClient((http.Request request) async {
      final String path = request.url.path;
      if (path.endsWith('/employees.php')) {
        if (request.method == 'POST') {
          expect(request.url.pathSegments.last, 'employees.php');
          terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Data karyawan berhasil diperbarui.',
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'user_id': 17,
                'username': 'andi.hr',
                'nama_lengkap': 'Andi Pratama',
                'email': 'andi@example.com',
                'mobile_no': '08123456789',
                'status': '1',
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('/update_karyawan.php')) {
        return http.Response('', 404);
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(home: EditKaryawanScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PILIH KARYAWAN'), findsOneWidget);
    expect(find.text('PASSWORD'), findsNothing);

    await tester.tap(find.text('Pilih Karyawan'));
    await tester.pumpAndSettle();

    expect(find.text('andi.hr'), findsOneWidget);
    expect(find.text('Andi Pratama'), findsWidgets);

    final Finder kolomCari = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Cari username atau nama karyawan...',
    );
    expect(kolomCari, findsOneWidget);
    await tester.enterText(kolomCari, 'tidakada');
    expect(
      tester.widget<TextField>(kolomCari).controller!.text,
      'tidakada',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada karyawan yang cocok'), findsOneWidget);

    await tester.tap(find.byTooltip('Bersihkan pencarian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('andi.hr'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Andi Pratama',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      'andi.hr',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      'andi@example.com',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField).at(3))
          .controller!
          .text,
      '08123456789',
    );
    expect(find.text('STATUS AKTIF'), findsOneWidget);
    expect(find.text('Chat WhatsApp'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), 'andi.baru@example.com');
    await tester.ensureVisible(find.text('Simpan Perubahan'));
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single['action'], 'update');
    expect(terkirim.single['id'], 7);
    expect(terkirim.single['employee_id'], 7);
    expect(terkirim.single['user_id'], 17);
    expect(terkirim.single['nama_lengkap'], 'Andi Pratama');
    expect(terkirim.single['username'], 'andi.hr');
    expect(terkirim.single['email'], 'andi.baru@example.com');
    expect(terkirim.single['mobile_no'], '08123456789');
    expect(terkirim.single['status'], '1');
    expect(terkirim.single.containsKey('department_id'), isFalse);
    expect(terkirim.single.containsKey('designation_id'), isFalse);
  });

  testWidgets('Daftar pilih karyawan tidak menampilkan tag #nomor', (
    WidgetTester tester,
  ) async {
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/employees.php')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 7,
                'username': '',
                'nama_lengkap': 'Karyawan Tanpa Username',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(home: EditKaryawanScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pilih Karyawan'));
    await tester.pumpAndSettle();

    expect(find.text('Karyawan'), findsOneWidget);
    expect(find.text('Karyawan #7'), findsNothing);
    expect(find.textContaining('#7'), findsNothing);
  });
}
