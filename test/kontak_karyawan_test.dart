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
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
                'designation_name': 'Staff HR',
                'status': '1',
              },
              <String, dynamic>{
                'id': 2,
                'username': 'budi.s',
                'nama_lengkap': 'Budi Santoso',
                'email': 'budi@example.com',
                'mobile_no': '',
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

    expect(find.text('ID CARD'), findsNWidgets(2));
    expect(find.text('@andi.hr'), findsOneWidget);
    expect(find.text('@budi.s'), findsOneWidget);
    expect(find.text('08123456789'), findsWidgets);
    expect(find.text('No. HP belum diisi'), findsWidgets);
    expect(find.text('Chat WhatsApp'), findsNWidgets(2));

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
