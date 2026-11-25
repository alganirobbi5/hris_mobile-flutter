import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/absen_screen.dart';
import 'package:hris_mobile/screens/detail_absensi_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/laporan_excel_service.dart';
import 'package:hris_mobile/widgets/selfie_fullscreen_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  test('parsing absensi HR/admin dari endpoint laporan', () {
    final LaporanAbsensiRow row = LaporanAbsensiRow.fromJson(<String, dynamic>{
      'id': 12,
      'record_type': 'admin',
      'nama': 'Admin Utama',
      'first_name': 'Admin Utama',
      'last_name': '',
      'date': '2026-11-25',
      'clock_in': '08:05:00',
      'clock_out': '17:10:00',
      'total_work': 9.08,
      'latitude': '-6.25',
      'longitude': '106.77',
      'jabatan': 'HR / Admin',
      'selfie_in_url': 'selfie.php?id=12&type=in&scope=admin',
      'selfie_out_url': 'selfie.php?id=12&type=out&scope=admin',
    });

    expect(row.recordType, 'admin');
    expect(row.nama, 'Admin Utama');
    expect(row.jabatan, 'HR / Admin');
    expect(row.tanggal, '2026-11-25');
    expect(row.jamMasukTampil, '08:05');
    expect(row.jamKeluarTampil, '17:10');
    expect(row.totalWork, '9.08');
    expect(row.koordinatTampil, '-6.25, 106.77');
    expect(row.selfieInUrl, contains('scope=admin'));
    expect(row.selfieOutUrl, contains('type=out'));
  });

  testWidgets('detail absensi punya dua jendela foto yang bisa diperbesar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DetailAbsensiScreen(
          absensiId: 12,
          nama: 'Admin Utama',
          tanggal: '2026-11-25',
          jamMasuk: '08:05',
          jamKeluar: '17:10',
          latitude: '-6.25',
          longitude: '106.77',
          jabatan: 'HR / Admin',
          selfieInUrl: 'selfie.php?id=12&type=in&scope=admin',
          selfieOutUrl: 'selfie.php?id=12&type=out&scope=admin',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Absen Masuk • 08:05'), findsOneWidget);
    expect(find.text('Absen Pulang • 17:10'), findsOneWidget);
    expect(find.byIcon(Icons.zoom_out_map_rounded), findsNWidgets(2));

    await tester.ensureVisible(find.byIcon(Icons.zoom_out_map_rounded).first);
    await tester.tap(find.byIcon(Icons.zoom_out_map_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Foto Absen Masuk'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('viewer layar penuh mendukung foto lokal dan zoom', (
    WidgetTester tester,
  ) async {
    final Directory? dir = await tester.runAsync<Directory>(
      () => Directory.systemTemp.createTemp('selfie_viewer'),
    );
    final File file = File('${dir!.path}/selfie.png');
    await tester.runAsync<void>(
      () => file.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SelfieFullScreenViewer(
          title: 'Foto Absen Masuk',
          subtitle: 'Andi • 08:05',
          localPath: file.path,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Foto Absen Masuk'), findsOneWidget);
    expect(find.text('Andi • 08:05'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.runAsync<void>(() => dir.delete(recursive: true));
  });

  testWidgets('menu duplikat Persetujuan Cuti tidak ada di halaman absen HR', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'role': 'hr',
      'user_id': 2,
    });
    await AppSession.restore();

    await tester.pumpWidget(const MaterialApp(home: AbsenScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Persetujuan Cuti'), findsNothing);
    expect(find.text('Cuti & Izin Keluar'), findsOneWidget);
    expect(find.text('Kelola Kuota Cuti'), findsOneWidget);
  });
}
