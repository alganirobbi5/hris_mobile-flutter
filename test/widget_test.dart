import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/main.dart';
import 'package:hris_mobile/screens/absen_success_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/screens/login_screen.dart';
import 'package:hris_mobile/services/company_profile.dart';
import 'package:hris_mobile/widgets/glass_bottom_nav.dart';
import 'package:hris_mobile/widgets/primary_button.dart';
import 'package:hris_mobile/widgets/profile_avatar_button.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    CompanyProfile.current = const CompanyProfileData(
      name: 'PT Contoh Maju Sejahtera',
      code: 'CMJ-2026',
    );
  });

  testWidgets('Halaman login tampil sebagai halaman awal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HrisApp(isLoggedIn: false));

    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.textContaining('KODE PERUSAHAAN'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Login meneruskan kode perusahaan apa pun ke server', (
    WidgetTester tester,
  ) async {
    Map<String, dynamic>? terkirim;
    final http.Client client = MockClient((http.Request request) async {
      terkirim = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(<String, dynamic>{'success': false, 'message': 'ditolak'}),
        401,
      );
    });

    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(httpClient: client)),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'DGN-2026');
    await tester.enterText(find.byType(TextFormField).at(1), 'razu');
    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(
      find.text('Kode perusahaan tidak sesuai dengan data HR'),
      findsNothing,
    );
    expect(terkirim, isNotNull);
    expect(terkirim!['company_code'], 'DGN-2026');
    expect(terkirim!['username'], 'razu');
  });

  testWidgets('Navigasi tab beranda berjalan tanpa error', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'role': 'hr',
      'api_token': 'token-widget-test',
    });
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));

    expect(find.text('Ambil Selfie & Absen Masuk'), findsOneWidget);

    final Finder navigationBar = find.byType(GlassBottomNav);

    expect(find.text('Cuti & Izin'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: navigationBar,
        matching: find.byIcon(Icons.campaign_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Daftar Pengumuman'), findsOneWidget);

    expect(find.byType(ProfileAvatarButton), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: navigationBar,
        matching: find.byIcon(Icons.settings_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsWidgets);
    expect(tester.widget<GlassBottomNav>(navigationBar).currentIndex, 3);

    await tester.tap(find.text('Laporan'));
    await tester.pumpAndSettle();
    expect(find.text('Laporan Absensi'), findsOneWidget);
  });

  testWidgets('Menu Persetujuan Cuti tersedia di Settings untuk role HR', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'role': 'hr',
      'api_token': 'token-widget-test',
    });

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Persetujuan'), findsOneWidget);
  });

  testWidgets('Tab Laporan tidak tampil untuk role employee', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'role': 'employee'});

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
    expect(find.text('Persetujuan'), findsNothing);
  });

  testWidgets('Halaman Profil bisa dibuka oleh role employee', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'role': 'employee',
      'user_id': 2,
      'employee_id': 2,
    });

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Cuti & Izin'), findsWidgets);
    expect(find.text('Ambil Selfie & Absen Masuk'), findsOneWidget);

    await tester.tap(find.byType(ProfileAvatarButton));
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsWidgets);
    expect(find.byType(DangerButton), findsOneWidget);
    expect(find.text('Edit Profil Perusahaan'), findsNothing);
  });

  testWidgets('Profil dan logout tersedia untuk Admin HR tanpa employee_id', (
    WidgetTester tester,
  ) async {
    await AppSession.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt('user_id', 1);
    await prefs.setString('username', 'admin');
    await prefs.setString('nama_lengkap', 'Admin HR');
    await prefs.setString('company_name', 'PT Dignity');
    await prefs.setString('company_code', 'DGN-2026');

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ambil Selfie & Absen Masuk'), findsOneWidget);
    expect(find.text('Pengumuman'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);

    await tester.tap(find.byType(ProfileAvatarButton));
    await tester.pumpAndSettle();

    expect(find.text('Memuat profil...'), findsNothing);
    expect(find.text('Admin HR'), findsWidgets);
    expect(find.text('admin'), findsWidgets);
    expect(find.text('hr'), findsWidgets);
    expect(find.text('PT Dignity'), findsWidgets);
    expect(find.text('DGN-2026'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.byType(DangerButton), findsOneWidget);
  });

  testWidgets('HR dapat membuka form edit profil perusahaan', (
    WidgetTester tester,
  ) async {
    await AppSession.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt('user_id', 1);
    await prefs.setString('username', 'admin');

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Edit Perusahaan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Perusahaan'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Profil Perusahaan'), findsWidgets);
    expect(find.text('NAMA PERUSAHAAN'), findsWidgets);
    expect(find.text('KODE PERUSAHAAN'), findsWidgets);
    expect(find.text('Simpan'), findsOneWidget);
  });

  testWidgets('Logout Admin HR membersihkan sesi tanpa API profil', (
    WidgetTester tester,
  ) async {
    await AppSession.clear();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt('user_id', 1);
    await prefs.setString('username', 'admin');
    await prefs.setString('nama_lengkap', 'Admin HR');

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProfileAvatarButton));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(DangerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DangerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya'));
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang'), findsOneWidget);
    expect(AppSession.getRole(), isNull);
    expect(AppSession.getToken(), isNull);
    expect((await SharedPreferences.getInstance()).containsKey('user_id'),
        isFalse);
  });

  testWidgets('Halaman sukses absen menampilkan foto dan koordinat GPS', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbsenSuccessScreen(
          photoPath: 'foto-tidak-ada.jpg',
          latitude: -6.123456,
          longitude: 106.654321,
          takenAt: DateTime(2026, 11, 11, 8, 2, 17),
          jamMasuk: '08:02:17 WIB',
        ),
      ),
    );

    expect(find.text('Absen Berhasil'), findsOneWidget);
    expect(find.text('Rabu, 11 November 2026'), findsOneWidget);
    expect(find.text('08:02:17 WIB'), findsOneWidget);
    expect(find.text('-6.123456, 106.654321'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
