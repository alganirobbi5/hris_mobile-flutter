import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/profil_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/employee_request.dart';
import 'package:hris_mobile/services/profile_credential_service.dart';
import 'package:hris_mobile/utils/whatsapp_helper.dart';
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

  test('body update username memakai endpoint profil', () {
    expect(
      EmployeeRequest.usernameUpdate().path,
      endsWith('/update_username.php'),
    );
    expect(EmployeeRequest.usernameUpdateBody('baru'), <String, dynamic>{
      'username': 'baru',
    });
  });

  test('body update nomor HP profil memuat mobile_no dan no_hp', () {
    expect(
      EmployeeRequest.profilePhoneUpdate().path,
      endsWith('/update_no_hp.php'),
    );
    expect(
      EmployeeRequest.profilePhoneUpdateBody('08123456789'),
      <String, dynamic>{'mobile_no': '08123456789', 'no_hp': '08123456789'},
    );
    expect(WhatsAppHelper.validatePhone('08123456789'), isNull);
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

  testWidgets('super admin melihat baris username dan password di kartu', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'super_admin');
    AppSession.role = 'super_admin';

    await tester.pumpWidget(const MaterialApp(home: ProfilScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Username & Password'), findsNothing);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('••••••••'), findsOneWidget);
    expect(_editIcon(tester, 'Username'), findsOneWidget);
    expect(_editIcon(tester, 'Password'), findsOneWidget);
    expect(find.text('Sisa Kuota Cuti'), findsNothing);
  });

  testWidgets('employee tidak bisa mengubah username sendiri', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ubah Username & Password'), findsNothing);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(_editIcon(tester, 'Username'), findsNothing);
    expect(_editIcon(tester, 'Password'), findsOneWidget);
    expect(find.text('Sisa Kuota Cuti'), findsOneWidget);
  });

  testWidgets('leader tidak bisa mengubah username sendiri', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'leader');
    AppSession.role = 'leader';

    await tester.pumpWidget(const MaterialApp(home: ProfilScreen()));
    await tester.pumpAndSettle();

    expect(_editIcon(tester, 'Username'), findsNothing);
    expect(_editIcon(tester, 'Password'), findsOneWidget);
  });

  testWidgets('No. HP profil dapat diisi sendiri oleh karyawan', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProfilScreen()));
    await tester.pumpAndSettle();

    final Finder tombolEditHp = _editIcon(tester, 'No. HP (WhatsApp)');
    await tester.ensureVisible(tombolEditHp);
    await tester.tap(tombolEditHp);
    await tester.pumpAndSettle();

    expect(find.text('Ubah No. HP (WhatsApp)'), findsOneWidget);
    expect(find.text('NO. HP (WHATSAPP)'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '12345');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('No. HP harus diawali 08 atau 628'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });

  testWidgets('HR mengubah username lewat dialog khusus', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/update_username.php')) {
        terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'message': 'Username berhasil disimpan.',
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    AppSession.role = 'hr';

    await tester.pumpWidget(
      MaterialApp(home: ProfilScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    final Finder tombolEditUsername = _editIcon(tester, 'Username');
    await tester.ensureVisible(tombolEditUsername);
    await tester.tap(tombolEditUsername);
    await tester.pumpAndSettle();

    expect(find.text('Ubah Username'), findsOneWidget);
    expect(find.text('PASSWORD LAMA'), findsNothing);
    await tester.enterText(find.byType(TextFormField).last, 'baru');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single, <String, dynamic>{'username': 'baru'});
    expect(AppSession.getUsername(), 'baru');
    expect(
      (await SharedPreferences.getInstance()).getString('username'),
      'baru',
    );
  });

  testWidgets('semua role bisa mengubah password lewat dialog', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/update_username_password.php')) {
        terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'message': 'Password berhasil diubah',
            'data': <String, dynamic>{'username': 'lama'},
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

    final Finder tombolEditPassword = _editIcon(tester, 'Password');
    await tester.ensureVisible(tombolEditPassword);
    await tester.tap(tombolEditPassword);
    await tester.pumpAndSettle();

    expect(find.text('Ubah Password'), findsOneWidget);
    expect(find.text('PASSWORD LAMA'), findsOneWidget);
    expect(find.text('PASSWORD BARU'), findsOneWidget);
    expect(find.text('KONFIRMASI PASSWORD BARU'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Password lama wajib diisi'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'lama123');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia123');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single, <String, dynamic>{
      'username': 'lama',
      'old_password': 'lama123',
      'new_password': 'rahasia123',
      'confirm_password': 'rahasia123',
    });
  });

  testWidgets('semua dialog edit profil tampil ringkas dan dapat digulir', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    AppSession.role = 'hr';
    await tester.pumpWidget(
      MaterialApp(home: ProfilScreen(httpClient: _profilClient())),
    );
    await tester.pumpAndSettle();

    await _expectDialogRingkas(
      tester,
      _tombolUbahNama(),
      'Ubah Nama',
      maksTinggi: 360,
    );
    await _expectDialogRingkas(
      tester,
      _editIcon(tester, 'Email'),
      'Ubah Email',
      maksTinggi: 360,
    );
    await _expectDialogRingkas(
      tester,
      _editIcon(tester, 'Username'),
      'Ubah Username',
      maksTinggi: 360,
    );
    await _expectDialogRingkas(
      tester,
      _editIcon(tester, 'Password'),
      'Ubah Password',
      maksTinggi: 520,
    );
    await _expectDialogRingkas(
      tester,
      _editIcon(tester, 'No. HP (WhatsApp)'),
      'Ubah No. HP (WhatsApp)',
      maksTinggi: 400,
    );
  });

  testWidgets('pesan sukses Ubah Nama spesifik', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilScreen(httpClient: _profilClient())),
    );
    await tester.pumpAndSettle();

    await tester.tap(_tombolUbahNama());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'Nama Baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama berhasil diperbarui'), findsOneWidget);
    expect(find.text('Nama berhasil disimpan.'), findsNothing);
  });

  testWidgets('pesan sukses Ubah Email spesifik', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilScreen(httpClient: _profilClient())),
    );
    await tester.pumpAndSettle();

    await tester.tap(_editIcon(tester, 'Email'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).last,
      'baru@perusahaan.com',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Email berhasil diperbarui'), findsOneWidget);
    expect(find.text('Email profil berhasil disimpan.'), findsNothing);
  });

  testWidgets('pesan sukses Ubah Username mengabaikan pesan server', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    AppSession.role = 'hr';
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          httpClient: _profilClient('Username berhasil disimpan.'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_editIcon(tester, 'Username'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Username berhasil diperbarui'), findsOneWidget);
    expect(find.text('Username berhasil disimpan.'), findsNothing);
  });

  testWidgets('pesan sukses Ubah Password spesifik', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilScreen(
          httpClient: _profilClient(
            'Username dan password berhasil diperbarui.',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder tombolPassword = _editIcon(tester, 'Password');
    await tester.ensureVisible(tombolPassword);
    await tester.tap(tombolPassword);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'lama123');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia123');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Password berhasil diperbarui'), findsOneWidget);
    expect(
      find.text('Username dan password berhasil diperbarui.'),
      findsNothing,
    );
  });

  testWidgets('pesan sukses Ubah No. HP spesifik', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProfilScreen(httpClient: _profilClient())),
    );
    await tester.pumpAndSettle();

    final Finder tombolHp = _editIcon(tester, 'No. HP (WhatsApp)');
    await tester.ensureVisible(tombolHp);
    await tester.tap(tombolHp);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '08123456789');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('No. HP (WhatsApp) berhasil diperbarui'), findsOneWidget);
    expect(find.text('No. HP profil berhasil disimpan.'), findsNothing);
  });
}

Finder _editIcon(WidgetTester tester, String label) {
  final Finder baris = find.ancestor(
    of: find.text(label),
    matching: find.byType(Row),
  );
  return find.descendant(of: baris, matching: find.byIcon(Icons.edit_outlined));
}

Finder _tombolUbahNama() => find.byKey(const Key('ubah-nama'));

http.Client _profilClient([String? serverMessage]) {
  return MockClient((http.Request request) async {
    if (request.method == 'GET') {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'nama_lengkap': 'Pengguna Profil',
            'role': 'employee',
            'username': 'lama',
            'email': 'lama@perusahaan.com',
            'mobile_no': '08123456789',
          },
        }),
        200,
      );
    }
    return http.Response(
      jsonEncode(<String, dynamic>{
        'success': true,
        'message': serverMessage ?? 'Data tersimpan.',
      }),
      200,
    );
  });
}

Future<void> _expectDialogRingkas(
  WidgetTester tester,
  Finder pembuka,
  String judul, {
  double maksTinggi = 400,
}) async {
  await tester.ensureVisible(pembuka);
  await tester.tap(pembuka);
  await tester.pumpAndSettle();

  final Finder dialog = find.byType(AlertDialog);
  expect(dialog, findsOneWidget);
  expect(find.text(judul), findsOneWidget);
  final Finder kartuDialog = find.descendant(
    of: dialog,
    matching: find.byType(IntrinsicWidth),
  );
  expect(tester.getRect(kartuDialog).height, lessThan(maksTinggi));
  expect(
    find.descendant(of: dialog, matching: find.byType(SingleChildScrollView)),
    findsOneWidget,
  );
  final List<Column> kolom = tester
      .widgetList<Column>(
        find.descendant(of: dialog, matching: find.byType(Column)),
      )
      .toList();
  expect(
    kolom.any((Column widget) => widget.mainAxisSize == MainAxisSize.min),
    isTrue,
  );
  expect(
    find.descendant(of: dialog, matching: find.byType(Spacer)),
    findsNothing,
  );
  expect(
    find.descendant(of: dialog, matching: find.byType(Expanded)),
    findsNothing,
  );

  await tester.tap(find.text('Batal'));
  await tester.pumpAndSettle();
}
