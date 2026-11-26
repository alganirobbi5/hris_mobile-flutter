import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/kelola_hr_admin_screen.dart';
import 'package:hris_mobile/screens/kelola_perusahaan_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';
import 'package:hris_mobile/screens/settings_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/widgets/glass_bottom_nav.dart';
import 'package:hris_mobile/widgets/profile_avatar_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    AppSession.token = 'token-super-admin';
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'super_admin');
    AppSession.role = null;
  });

  test('AppSession menyimpan data perusahaan dan mendeteksi super admin', () async {
    await AppSession.setFromLogin(<String, dynamic>{
      'data': <String, dynamic>{
        'token': 'token-super',
        'company_id': 3,
        'company_code': 'SUPER',
        'company_name': 'Super Admin',
        'user': <String, dynamic>{
          'user_id': 1,
          'username': 'superadmin',
          'role': 'super_admin',
        },
      },
    });

    expect(AppSession.isSuperAdmin, isTrue);
    expect(AppSession.getCompanyId(), 3);
    expect(AppSession.getCompanyCode(), 'SUPER');
    expect(AppSession.getCompanyName(), 'Super Admin');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(AppSession.companyIdPrefKey), 3);
    expect(prefs.getString(AppSession.companyCodePrefKey), 'SUPER');
    expect(prefs.getString(AppSession.companyNamePrefKey), 'Super Admin');

    AppSession.companyId = null;
    AppSession.companyCode = null;
    AppSession.companyName = null;
    await AppSession.restore(prefs);
    expect(AppSession.getCompanyCode(), 'SUPER');

    await AppSession.clear();
    expect(AppSession.isSuperAdmin, isFalse);
    expect(AppSession.getCompanyId(), isNull);
  });

  testWidgets('super admin hanya melihat tab Pengumuman dan Settings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final List<String> labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(GlassBottomNav),
            matching: find.byType(Text),
          ),
        )
        .map((Text widget) => widget.data ?? '')
        .toList();

    expect(labels, <String>['Pengumuman', 'Settings']);
    expect(find.text('Absen'), findsNothing);
    expect(find.text('Cuti & Izin'), findsNothing);
    expect(find.byType(ProfileAvatarButton), findsOneWidget);
  });

  testWidgets('Settings super admin menampilkan menu kelola', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(isHr: false, canApprove: false, isSuperAdmin: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MENU SUPER ADMIN'), findsOneWidget);
    expect(find.text('Kelola Perusahaan'), findsOneWidget);
    expect(find.text('Kelola HR / Admin'), findsOneWidget);
    expect(find.text('Tambah Karyawan'), findsNothing);
    expect(find.text('Persetujuan'), findsNothing);
  });

  testWidgets('Kelola Perusahaan menampilkan daftar dan menyimpan data', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = _client(terkirim: terkirim);
    await tester.pumpWidget(
      MaterialApp(home: KelolaPerusahaanScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('CMJ • Contoh Maju'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Nonaktif'), findsOneWidget);

    await tester.tap(find.text('Tambah Perusahaan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'BARU');
    await tester.enterText(find.byType(TextFormField).at(1), 'Perusahaan Baru');
    await tester.enterText(find.byType(TextFormField).at(2), 'Jl. Baru No. 1');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single, <String, dynamic>{
      'company_code': 'BARU',
      'company_name': 'Perusahaan Baru',
      'address': 'Jl. Baru No. 1',
    });
  });

  testWidgets('Kelola HR / Admin menampilkan daftar dan menyimpan data', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = _client(terkirim: terkirim);
    await tester.pumpWidget(
      MaterialApp(home: KelolaHrAdminScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Andi Admin'), findsOneWidget);
    expect(find.text('andi • andi@example.com • CMJ'), findsOneWidget);

    await tester.tap(find.text('Tambah HR / Admin'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CMJ • Contoh Maju').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Budi');
    await tester.enterText(find.byType(TextFormField).at(1), 'HR');
    await tester.enterText(find.byType(TextFormField).at(2), 'budi.hr');
    await tester.enterText(find.byType(TextFormField).at(3), 'budi@example.com');
    await tester.enterText(find.byType(TextFormField).at(4), 'rahasia');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    expect(terkirim, hasLength(1));
    expect(terkirim.single, <String, dynamic>{
      'company_id': 1,
      'first_name': 'Budi',
      'last_name': 'HR',
      'username': 'budi.hr',
      'email': 'budi@example.com',
      'password': 'rahasia',
    });
  });
}

http.Client _client({required List<Map<String, dynamic>> terkirim}) {
  return MockClient((http.Request request) async {
    final String path = request.url.path;
    if (path.endsWith('/companies.php')) {
      if (request.method == 'POST') {
        terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true}),
          201,
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'companies': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'company_code': 'CMJ',
              'company_name': 'Contoh Maju',
              'address': 'Jl. Contoh',
              'status': 1,
            },
            <String, dynamic>{
              'id': 2,
              'company_code': 'ABC',
              'company_name': 'Alpha Beta',
              'status': 0,
            },
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/super_admin_hr.php')) {
      if (request.method == 'POST') {
        terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true}),
          201,
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'hr': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 5,
              'first_name': 'Andi',
              'last_name': 'Admin',
              'username': 'andi',
              'email': 'andi@example.com',
              'company_name': 'CMJ',
            },
          ],
        }),
        200,
      );
    }
    return http.Response('', 404);
  });
}
