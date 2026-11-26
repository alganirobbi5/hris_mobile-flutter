import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/profil_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/employee_request.dart';
import 'package:hris_mobile/services/profile_credential_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    AppSession.token = 'token-profil';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppSession.userIdPrefKey, 2);
    await prefs.setString('username', 'lama');
    await prefs.setString('nama_lengkap', 'Pengguna Profil');
    await prefs.setString('role', 'employee');
    AppSession.username = 'lama';
    AppSession.role = null;
  });

  test('body update kredensial memuat username dan password', () {
    expect(
      EmployeeRequest.credentialUpdate().path,
      endsWith('/update_username_password.php'),
    );
    final Map<String, dynamic> body = EmployeeRequest.credentialUpdateBody(
      username: 'baru',
      oldPassword: 'lama123',
      newPassword: 'rahasia123',
      confirmPassword: 'rahasia123',
    );
    expect(body, <String, dynamic>{
      'username': 'baru',
      'old_password': 'lama123',
      'new_password': 'rahasia123',
      'confirm_password': 'rahasia123',
    });
  });

  test('service kredensial memakai pesan error dari server', () async {
    final http.Client client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': false,
          'message': 'Password lama tidak sesuai',
        }),
        422,
      );
    });

    await expectLater(
      ProfileCredentialService.update(
        username: 'baru',
        oldPassword: 'salah',
        newPassword: '',
        confirmPassword: '',
        client: client,
      ),
      throwsA(
        isA<ProfileCredentialException>().having(
          (ProfileCredentialException e) => e.message,
          'message',
          'Password lama tidak sesuai',
        ),
      ),
    );
  });

  testWidgets('super admin tidak melihat kuota cuti', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'super_admin');
    AppSession.role = null;

    await tester.pumpWidget(const MaterialApp(home: ProfilScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Username & Password'), findsOneWidget);
    expect(find.text('Sisa Kuota Cuti'), findsNothing);
    expect(find.text('Sisa Kuota'), findsNothing);
  });

  testWidgets('role lain tetap melihat kuota cuti', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sisa Kuota Cuti'), findsOneWidget);
    expect(find.text('Ubah Username & Password'), findsOneWidget);
  });

  testWidgets('validasi dan simpan ubah username & password', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/update_username_password.php')) {
        terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'message': 'Username dan password berhasil diubah',
            'data': <String, dynamic>{'username': 'baru'},
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(home: ProfilScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ubah Username & Password'));
    await tester.tap(find.text('Ubah Username & Password'));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Username & Password'), findsWidgets);
    expect(find.text('Password Lama'), findsOneWidget);
    expect(find.text('Password Baru (opsional)'), findsOneWidget);
    expect(find.text('Konfirmasi Password Baru'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Password lama wajib diisi'), findsOneWidget);
    expect(terkirim, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(1), 'lama123');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Password baru minimal 6 karakter'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia123');
    await tester.enterText(find.byType(TextFormField).at(3), 'tidakcocok');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Konfirmasi password tidak cocok'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'baru');
    await tester.enterText(find.byType(TextFormField).at(3), 'rahasia123');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single, <String, dynamic>{
      'username': 'baru',
      'old_password': 'lama123',
      'new_password': 'rahasia123',
      'confirm_password': 'rahasia123',
    });
    expect(AppSession.getUsername(), 'baru');
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('username'), 'baru');
  });
}
