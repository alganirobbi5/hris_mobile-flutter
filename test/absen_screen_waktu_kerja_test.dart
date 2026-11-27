import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/absen_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/notification_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  test('pesan notifikasi pulang memuat waktu kerja JJ:MM:DD', () {
    final String pesan = AppNotificationService.checkOutBody(
      jamPulang: '16:15 WIB',
      waktuKerja: '08:15:32',
    );
    expect(pesan, contains('Waktu Kerja: 08:15:32'));
    expect(pesan, contains('16:15 WIB'));
  });

  testWidgets('absen pulang menampilkan kartu dan konfirmasi waktu kerja', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AbsenScreen(httpClient: _absenClient())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waktu Kerja Hari Ini'), findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -2000),
    );
    await tester.pump();
    expect(
      find.text('Anda sudah menyelesaikan absensi hari ini. '
          'Waktu Kerja: 08:15:32'),
      findsOneWidget,
    );
    expect(find.text('Absen Pulang'), findsNothing);
    expect(find.text('Ambil Selfie & Absen Masuk'), findsNothing);
  });

  testWidgets('timestamp masuk dan pulang dengan detik dimuat dari prefs', (
    WidgetTester tester,
  ) async {
    final DateTime wib = DateTime.now().toUtc().add(const Duration(hours: 7));
    final String hariIni =
        '${wib.year}-${wib.month.toString().padLeft(2, '0')}-'
        '${wib.day.toString().padLeft(2, '0')}';
    SharedPreferences.setMockInitialValues(<String, Object>{
      'absen_selfie_tanggal': hariIni,
      'absen_selfie_employee_id': 'role_unknown',
      'absen_waktu_masuk_lengkap': '2026-11-25 08:00:00',
      'absen_waktu_pulang_lengkap': '2026-11-25 16:15:32',
    });

    await tester.pumpWidget(
      MaterialApp(home: AbsenScreen(httpClient: _absenClient(dariApi: false))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waktu Kerja: 08:15:32'), findsWidgets);
  });

  testWidgets('durasi memakai working_seconds dari server bila tersedia', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbsenScreen(
          httpClient: _absenClient(
            statusTambahan: <String, dynamic>{'working_seconds': 29000},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waktu Kerja: 08:03:20'), findsWidgets);
    expect(find.text('Waktu Kerja: 00:00:00'), findsNothing);
  });

  testWidgets('durasi tetap dihitung saat hanya ada jam masuk dan pulang', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AbsenScreen(httpClient: _absenClient(dariApi: false))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waktu Kerja: 08:15:00'), findsWidgets);
    expect(find.text('Waktu Kerja: 00:00:00'), findsNothing);
  });
}

http.Client _absenClient({
  bool dariApi = true,
  Map<String, dynamic>? statusTambahan,
}) {
  return MockClient((http.Request request) async {
    final String path = request.url.path;
    if (path.endsWith('/get_jam_kerja.php')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'jam_masuk': '08:00', 'jam_keluar': '17:00'},
        }),
        200,
      );
    }
    if (path.endsWith('/status_absen.php')) {
      final Map<String, dynamic> data = <String, dynamic>{
        'sudah_masuk': true,
        'sudah_pulang': true,
        'jam_masuk': '08:00:00',
        'jam_pulang': '16:15:32',
        'status_pulang': 'tepat',
      };
      if (dariApi) {
        data['waktu_masuk'] = '2026-11-25 08:00:00';
        data['waktu_pulang'] = '2026-11-25 16:15:32';
      }
      if (statusTambahan != null) data.addAll(statusTambahan);
      return http.Response(
        jsonEncode(<String, dynamic>{'data': data}),
        200,
      );
    }
    return http.Response('', 404);
  });
}
