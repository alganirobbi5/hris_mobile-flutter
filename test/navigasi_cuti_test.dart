import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/layanan_cuti_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/izin_keluar_service.dart';
import 'package:hris_mobile/services/riwayat_cuti_service.dart';
import 'package:hris_mobile/widgets/glass_bottom_nav.dart';
import 'package:hris_mobile/widgets/profile_avatar_button.dart';
import 'package:hris_mobile/widgets/status_badge.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  testWidgets('tab Cuti & Izin berada tepat di sebelah Absen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    final Finder nav = find.byType(GlassBottomNav);
    expect(nav, findsOneWidget);

    final List<String> labels = tester
        .widgetList<Text>(find.descendant(of: nav, matching: find.byType(Text)))
        .map((Text widget) => widget.data ?? '')
        .toList();

    expect(labels.first, 'Absen');
    expect(labels[1], 'Cuti & Izin');
    expect(labels, contains('Pengumuman'));
    expect(find.byType(ProfileAvatarButton), findsOneWidget);
  });

  testWidgets('halaman Cuti & Izin menyusun tabel, tombol, lalu riwayat', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LayananCutiScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Leader Pemberi Izin Cuti'), findsOneWidget);
    expect(find.text('Pengajuan Cuti'), findsOneWidget);
    expect(find.text('Izin Keluar'), findsWidgets);
    expect(find.text('Riwayat Cuti & Izin Keluar'), findsOneWidget);

    final double tabelY = _y(tester, 'Leader Pemberi Izin Cuti');
    final double pengajuanY = _y(tester, 'Pengajuan Cuti');
    final double izinY = _y(tester, 'Izin Keluar');
    final double riwayatY = _y(tester, 'Riwayat Cuti & Izin Keluar');

    expect(tabelY, lessThan(pengajuanY));
    expect(pengajuanY, closeTo(izinY, 4));
    expect(izinY, lessThan(riwayatY));
  });

  testWidgets('tabel Leader Pemberi Izin Cuti menampilkan jabatan', (
    WidgetTester tester,
  ) async {
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/leave_leaders.php')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'leaders': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 1,
                'user_id': 9,
                'username': 'andi',
                'nama_lengkap': 'Andi Pratama',
                'jabatan': 'Kepala Bagian',
              },
            ],
            'eligible_users': <dynamic>[],
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          httpClient: client,
          cutiLoader: () async => const <RiwayatCutiItem>[],
          izinLoader: () async => const <IzinKeluarItem>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jabatan'), findsOneWidget);
    expect(find.text('Kepala Bagian'), findsOneWidget);
    expect(find.text('Username / Jabatan'), findsNothing);
  });

  testWidgets('tombol aksi tidak menampilkan badge status', (
    WidgetTester tester,
  ) async {
    final http.Client client = _statusClient();
    final List<RiwayatCutiItem> cuti = <RiwayatCutiItem>[
      RiwayatCutiItem(
        id: 1,
        type: 'Cuti Tahunan',
        leavFrom: '2026-11-20',
        leavTo: '2026-11-21',
        status: 'approved',
        createdAt: '2026-11-25T10:00:00',
      ),
    ];
    final List<IzinKeluarItem> izin = <IzinKeluarItem>[
      IzinKeluarItem(
        id: 2,
        employeeId: 3,
        tanggal: '2026-11-26',
        jamKeluar: '10:00',
        jamKembali: '12:00',
        kembaliKeKantor: true,
        kategori: 'Keperluan Pribadi',
        alasan: 'Acara keluarga',
        status: 'pending',
        catatanHr: '',
        namaKaryawan: 'Andi Pratama',
        createdAt: '2026-11-26T09:00:00',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          httpClient: client,
          cutiLoader: () async => cuti,
          izinLoader: () async => izin,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder kartuCuti = find.ancestor(
      of: find.text('Pengajuan Cuti'),
      matching: find.byType(Card),
    );
    final Finder kartuIzin = find.ancestor(
      of: find.text('Izin Keluar'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: kartuCuti, matching: find.byType(StatusBadge)),
      findsNothing,
    );
    expect(
      find.descendant(of: kartuIzin, matching: find.byType(StatusBadge)),
      findsNothing,
    );
  });

  testWidgets('tombol aksi tanpa pengajuan tidak menampilkan badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          httpClient: _statusClient(),
          cutiLoader: () async => const <RiwayatCutiItem>[],
          izinLoader: () async => const <IzinKeluarItem>[],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder kartuCuti = find.ancestor(
      of: find.text('Pengajuan Cuti'),
      matching: find.byType(Card),
    );
    final Finder kartuIzin = find.ancestor(
      of: find.text('Izin Keluar'),
      matching: find.byType(Card),
    );
    expect(
      find.descendant(of: kartuCuti, matching: find.text('Menunggu')),
      findsNothing,
    );
    expect(
      find.descendant(of: kartuIzin, matching: find.text('Menunggu')),
      findsNothing,
    );
  });
}

http.Client _statusClient() {
  return MockClient((http.Request request) async => http.Response('', 404));
}

double _y(WidgetTester tester, String teks) {
  return tester.getCenter(find.text(teks).first).dy;
}
