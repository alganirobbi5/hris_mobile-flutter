import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/kontak_karyawan_screen.dart';
import 'package:hris_mobile/screens/settings_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/karyawan_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  test('KaryawanItem membaca role/jabatan dari backend', () {
    final KaryawanItem item = KaryawanItem.fromJson(<String, dynamic>{
      'id': 1,
      'username': 'andi.hr',
      'nama_lengkap': 'Andi Pratama',
      'email': 'andi@example.com',
      'mobile_no': '08123456789',
      'designation_name': 'Staff HR',
    });
    expect(item.role, 'Staff HR');
    expect(item.namaLengkap, 'Andi Pratama');
  });

  test('label role dinormalisasi tanpa TEACHER', () {
    KaryawanItem item({
      String role = '',
      bool isLeader = false,
    }) =>
        KaryawanItem(
          id: 1,
          username: 'karyawan',
          namaLengkap: 'Karyawan',
          email: '',
          mobileNo: '',
          statusAktif: true,
          role: role,
          isLeader: isLeader,
        );

    expect(item(role: 'leader').roleLabel, 'LEADER');
    expect(item(role: 'employee', isLeader: true).roleLabel, 'LEADER');
    expect(item(role: 'hr').roleLabel, 'HR');
    expect(item(role: 'admin').roleLabel, 'HR');
    expect(item(role: 'super_admin').roleLabel, 'SUPER ADMIN');
    expect(item(role: 'employee').roleLabel, 'EMPLOYEE');
    expect(item(role: 'teacher').roleLabel, 'EMPLOYEE');
    expect(item().roleLabel, 'EMPLOYEE');

    final KaryawanItem dariJson = KaryawanItem.fromJson(<String, dynamic>{
      'id': 9,
      'username': 'pimpinan',
      'nama_lengkap': 'Pimpinan',
      'is_leader': true,
    });
    expect(dariJson.roleLabel, 'LEADER');
  });

  testWidgets('Settings HR menampilkan menu Hubungi Karyawan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SettingsScreen(isHr: true, canApprove: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hubungi Karyawan'), findsOneWidget);
    expect(find.text('Edit Karyawan'), findsOneWidget);
  });

  testWidgets('ID Card karyawan menampilkan No. HP dan Chat WhatsApp', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', 'PT Contoh');
    await prefs.setString('company_code', 'CMJ-2026');

    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/employees.php')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'username': 'andi.hr',
                'nama_lengkap': 'Andi Pratama',
                'email': 'andi@example.com',
                'mobile_no': '08123456789',
                'role': 'leader',
                'status': '1',
              },
              <String, dynamic>{
                'id': 2,
                'username': 'budi.s',
                'nama_lengkap': 'Budi Santoso',
                'email': 'budi@example.com',
                'mobile_no': '',
                'role': 'teacher',
                'status': '1',
              },
              <String, dynamic>{
                'id': 3,
                'username': 'siti.hr',
                'nama_lengkap': 'Siti Rahmawati',
                'email': 'siti@example.com',
                'mobile_no': '62812345670',
                'role': 'hr',
                'status': '1',
              },
              <String, dynamic>{
                'id': 4,
                'username': 'rudi.l',
                'nama_lengkap': 'Rudi Hartono',
                'email': 'rudi@example.com',
                'mobile_no': '08123456771',
                'role': 'employee',
                'is_leader': true,
                'status': '1',
              },
            ],
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(home: KontakKaryawanScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('ID CARD'), findsNWidgets(4));
    expect(find.text('CMJ-2026'), findsNWidgets(4));
    expect(find.text('PT Contoh'), findsNWidgets(4));
    expect(find.text('@andi.hr'), findsOneWidget);
    expect(find.text('@budi.s'), findsOneWidget);
    expect(find.text('08123456789'), findsWidgets);
    expect(find.text('No. HP belum diisi'), findsWidgets);
    expect(find.text('Chat WhatsApp'), findsNWidgets(4));

    expect(find.text('LEADER'), findsNWidgets(2));
    expect(find.text('HR'), findsOneWidget);
    expect(find.text('EMPLOYEE'), findsOneWidget);
    expect(find.text('TEACHER'), findsNothing);

    final Finder kolomCari = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TextField &&
          widget.decoration?.hintText ==
              'Cari nama, username, atau No. HP karyawan...',
    );
    expect(kolomCari, findsOneWidget);

    await tester.enterText(kolomCari, '08123456789');
    await tester.pumpAndSettle();
    expect(find.text('@andi.hr'), findsOneWidget);
    expect(find.text('@budi.s'), findsNothing);

    await tester.tap(find.byTooltip('Bersihkan pencarian'));
    await tester.pumpAndSettle();
    await tester.enterText(kolomCari, 'budi');
    await tester.pumpAndSettle();
    expect(find.text('@budi.s'), findsOneWidget);
    expect(find.text('@andi.hr'), findsNothing);
  });
}
