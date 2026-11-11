import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/main.dart';
import 'package:hris_mobile/screens/absen_success_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';

void main() {
  testWidgets('Halaman login tampil sebagai halaman awal', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const HrisApp());

    expect(find.text('Selamat datang'), findsOneWidget);
    expect(find.text('KODE PERUSAHAAN'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
  });

  testWidgets('Navigasi tab beranda berjalan tanpa error', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));

    expect(find.text('Ambil Selfie & Absen'), findsOneWidget);

    final Finder navigationBar = find.byType(BottomNavigationBar);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Cuti')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pengajuan Cuti'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Laporan')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Laporan Absensi'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navigationBar, matching: find.text('Profil')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Keluar'), findsOneWidget);
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
