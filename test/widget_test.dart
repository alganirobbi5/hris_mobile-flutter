import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/main.dart';
import 'package:hris_mobile/screens/absen_success_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';
import 'package:hris_mobile/widgets/glass_bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Halaman login tampil sebagai halaman awal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HrisApp(isLoggedIn: false));

    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.text('KODE PERUSAHAAN'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Login menolak kode perusahaan yang tidak sesuai HR', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const HrisApp(isLoggedIn: false));

    await tester.enterText(find.byType(TextFormField).at(0), 'SALAH-2026');
    await tester.enterText(find.byType(TextFormField).at(1), 'razu');
    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia');
    await tester.ensureVisible(find.text('Masuk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(
      find.text('Kode perusahaan tidak sesuai dengan data HR'),
      findsOneWidget,
    );
  });

  testWidgets('Navigasi tab beranda berjalan tanpa error', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));

    expect(find.text('Ambil Selfie & Absen Masuk'), findsOneWidget);

    final Finder navigationBar = find.byType(GlassBottomNav);

    await tester.tap(
      find.descendant(
        of: navigationBar,
        matching: find.byIcon(Icons.calendar_today_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pengajuan Cuti'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: navigationBar,
        matching: find.byIcon(Icons.description_outlined),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Laporan Absensi'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: navigationBar,
        matching: find.byIcon(Icons.person_outline_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<GlassBottomNav>(navigationBar).currentIndex, 3);
  });

  testWidgets('Tab Persetujuan Cuti tampil untuk role HR', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{'role': 'hr'});

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Persetujuan'), findsOneWidget);
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
