import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/layanan_cuti_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/izin_keluar_service.dart';
import 'package:hris_mobile/services/riwayat_cuti_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  RiwayatCutiItem cuti() => const RiwayatCutiItem(
        id: 11,
        type: 'Cuti Tahunan',
        leavFrom: '2026-11-20',
        leavTo: '2026-11-22',
        status: 'approved',
        alasan: 'Liburan keluarga',
        targetLeaderName: 'Leader Satu',
        approvedByName: 'Admin HR',
        createdAt: '2026-11-19T08:00:00Z',
      );

  IzinKeluarItem izin() => const IzinKeluarItem(
        id: 21,
        employeeId: 3,
        tanggal: '2026-11-25',
        jamKeluar: '10:30:00',
        jamKembali: '12:00:00',
        kembaliKeKantor: true,
        kategori: 'Tugas Luar Kantor',
        alasan: 'Menemui klien',
        status: 'rejected',
        catatanHr: 'Selesaikan laporan dulu',
        namaKaryawan: 'Andi Pratama',
        approvedByName: 'Admin HR',
        targetLeaderName: 'Leader Satu',
        createdAt: '2026-11-25T09:00:00Z',
      );

  testWidgets('halaman Cuti & Izin menampilkan judul dan kedua riwayat', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          cutiLoader: () async => <RiwayatCutiItem>[cuti()],
          izinLoader: () async => <IzinKeluarItem>[izin()],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Riwayat Cuti & Izin Keluar'), findsOneWidget);
    expect(find.text('Cuti Tahunan'), findsOneWidget);
    expect(find.text('Tugas Luar Kantor'), findsWidgets);
    expect(find.textContaining('20 Nov 2026 - 22 Nov 2026 • 3 hari'), findsOneWidget);
    expect(find.textContaining('25 Nov 2026 • 10:30 - 12:00'), findsOneWidget);
    expect(find.text('Alasan: Liburan keluarga'), findsOneWidget);
    expect(find.text('Alasan: Menemui klien'), findsOneWidget);
    expect(find.text('Ditujukan ke: Leader Satu'), findsNWidgets(2));
    expect(find.text('Disetujui oleh Admin HR'), findsOneWidget);
    expect(find.text('Ditolak oleh Admin HR'), findsOneWidget);
    expect(find.text('Catatan: Selesaikan laporan dulu'), findsOneWidget);

    final double izinY = tester.getCenter(find.text('Tugas Luar Kantor').last).dy;
    final double cutiY = tester.getCenter(find.text('Cuti Tahunan')).dy;
    expect(izinY, lessThan(cutiY));
  });

  testWidgets('filter chip menyaring riwayat cuti dan izin keluar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          cutiLoader: () async => <RiwayatCutiItem>[cuti()],
          izinLoader: () async => <IzinKeluarItem>[izin()],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cuti'));
    await tester.pump();

    expect(find.text('Cuti Tahunan'), findsOneWidget);
    expect(find.text('Ditolak oleh Admin HR'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Izin Keluar').last);
    await tester.pump();

    expect(find.text('Cuti Tahunan'), findsNothing);
    expect(find.text('Ditolak oleh Admin HR'), findsOneWidget);
  });

  testWidgets('riwayat tidak menampilkan pengajuan yang masih menunggu', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          cutiLoader: () async => <RiwayatCutiItem>[
            const RiwayatCutiItem(
              id: 12,
              type: 'Cuti Menunggu',
              leavFrom: '2026-11-26',
              leavTo: '2026-11-26',
              status: '1',
              createdAt: '2026-11-25T10:00:00Z',
            ),
          ],
          izinLoader: () async => <IzinKeluarItem>[
            IzinKeluarItem(
              id: 22,
              employeeId: 3,
              tanggal: '2026-11-26',
              jamKeluar: '08:00:00',
              jamKembali: '10:00:00',
              kembaliKeKantor: true,
              kategori: 'Izin Menunggu',
              alasan: 'Urusan pribadi',
              status: 'pending',
              catatanHr: '',
              namaKaryawan: 'Andi Pratama',
              createdAt: '2026-11-25T10:00:00Z',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Cuti Menunggu'), findsNothing);
    expect(find.text('Izin Menunggu'), findsNothing);
    expect(
      find.text('Belum ada riwayat cuti & izin keluar'),
      findsOneWidget,
    );
  });

  testWidgets('empty state saat kedua riwayat kosong', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          cutiLoader: () async => const <RiwayatCutiItem>[],
          izinLoader: () async => const <IzinKeluarItem>[],
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Belum ada riwayat cuti & izin keluar'),
      findsOneWidget,
    );
  });

  testWidgets('tombol Izin Keluar akun HR membuka form pengajuan', (
    WidgetTester tester,
  ) async {
    await _expectFormPengajuanUntukRole(tester, 'hr');
  });

  testWidgets('tombol Izin Keluar akun Employee membuka form yang sama', (
    WidgetTester tester,
  ) async {
    await _expectFormPengajuanUntukRole(tester, 'employee');
  });
}

Future<void> _expectFormPengajuanUntukRole(
  WidgetTester tester,
  String role,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setString('role', role);
  AppSession.role = null;
  await tester.pumpWidget(
    MaterialApp(
      home: LayananCutiScreen(
        cutiLoader: () async => const <RiwayatCutiItem>[],
        izinLoader: () async => const <IzinKeluarItem>[],
      ),
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Izin Keluar').first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.text('Pengajuan Izin Keluar'), findsWidgets);
  expect(find.text('Persetujuan Izin Keluar'), findsNothing);
  expect(find.text('Pilih Leader Pemberi Persetujuan'), findsOneWidget);
  expect(find.text('Tanggal'), findsOneWidget);
  expect(find.text('Jam Keluar'), findsOneWidget);
  expect(find.text('Kembali ke kantor setelah selesai'), findsOneWidget);
  expect(find.text('Estimasi Jam Kembali'), findsOneWidget);
  expect(find.text('Kategori'), findsOneWidget);
  expect(find.text('ALASAN / KETERANGAN'), findsOneWidget);
  expect(find.text('Kirim Pengajuan Izin Keluar'), findsOneWidget);

  await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
  await tester.pumpAndSettle();
  expect(find.text('Riwayat Izin Keluar'), findsOneWidget);
}
