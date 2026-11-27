import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/absen_screen.dart';
import 'package:hris_mobile/screens/izin_keluar_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/employee_request.dart';
import 'package:hris_mobile/services/izin_keluar_service.dart';
import 'package:hris_mobile/services/leave_leader_service.dart';
import 'package:hris_mobile/widgets/section_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  test('URI dan body request izin keluar sesuai kontrak backend', () {
    expect(EmployeeRequest.izinKeluarUri().queryParameters, isEmpty);
    expect(
      EmployeeRequest.izinKeluarUri(
        allScope: true,
        status: 'approved',
      ).queryParameters,
      <String, String>{'scope': 'all', 'status': 'approved'},
    );

    final Map<String, dynamic> body = EmployeeRequest.ajukanIzinKeluarBody(
      tanggal: '2026-11-25',
      jamKeluar: '10:30',
      jamKembali: '12:00',
      kembaliKeKantor: true,
      kategori: 'Tugas Luar Kantor',
      alasan: 'Menemui klien',
      leaderUserId: 9,
    );
    expect(body['kembali_ke_kantor'], 1);
    expect(body['jam_keluar'], '10:30');
    expect(body['leader_user_id'], 9);
    expect(body.containsKey('employee_id'), isFalse);

    final Map<String, dynamic> decision =
        EmployeeRequest.approveIzinKeluarBody(
      12,
      'approved',
      catatanHr: 'Disetujui',
    );
    expect(decision['id'], 12);
    expect(decision['status'], 'approved');
    expect(decision['catatan_hr'], 'Disetujui');
  });

  test('parsing response izin keluar dari format backend', () {
    final IzinKeluarItem item = IzinKeluarItem.fromJson(<String, dynamic>{
      'id': 7,
      'employee_id': 3,
      'tanggal': '2026-11-25',
      'jam_keluar': '10:30:00',
      'jam_kembali': '12:00:00',
      'kembali_ke_kantor': 1,
      'kategori': 'Tugas Luar Kantor',
      'alasan': 'Menemui klien',
      'status': 'pending',
      'catatan_hr': null,
      'first_name': 'Andi',
      'last_name': 'Pratama',
    });

    expect(item.id, 7);
    expect(item.namaKaryawan, 'Andi Pratama');
    expect(item.jamKeluarPendek, '10:30');
    expect(item.jamKembaliPendek, '12:00');
    expect(item.kembaliKeKantor, isTrue);
    expect(item.status, 'pending');
    expect(item.catatanHr, isEmpty);
  });

  testWidgets('kartu Status pengajuan menghitung riwayat izin keluar', (
    WidgetTester tester,
  ) async {
    final List<IzinKeluarItem> items = <IzinKeluarItem>[
      _izinItem(1, 'pending'),
      _izinItem(2, 'menunggu'),
      _izinItem(3, 'approved'),
      _izinItem(4, 'ditolak'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: IzinKeluarScreen(
          loader: () async => items,
          leaderLoader: () async => const LeaveLeadersResult(
            leaders: <LeaveLeader>[],
            eligibleUsers: <EligibleLeaveUser>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pengajuan Izin Keluar'), findsNWidgets(2));
    expect(
      find.text('Ajukan izin keluar dan pantau status persetujuannya.'),
      findsOneWidget,
    );

    final Finder kartu = find.ancestor(
      of: find.text('Status pengajuan'),
      matching: find.byType(SectionCard),
    );
    expect(kartu, findsOneWidget);
    expect(find.descendant(of: kartu, matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: kartu, matching: find.text('1')), findsNWidgets(2));
    for (final String label in <String>['Menunggu', 'Disetujui', 'Ditolak']) {
      expect(
        find.descendant(of: kartu, matching: find.text(label)),
        findsOneWidget,
      );
    }
    final Finder kartuForm = find.ancestor(
      of: find.text('Pengajuan Izin Keluar').last,
      matching: find.byType(SectionCard),
    );
    expect(
      tester.getCenter(kartu).dy,
      lessThan(tester.getCenter(kartuForm).dy),
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026-11-25 • 10:00 - 12:00'), findsWidgets);
  });

  testWidgets('karyawan tidak melihat tombol Cuti & Izin di halaman absen', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'employee');
    await prefs.setInt('user_id', 1);

    await tester.pumpWidget(const MaterialApp(home: AbsenScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Cuti & Izin Keluar'), findsNothing);
    expect(find.text('MENU HR'), findsNothing);
    expect(find.text('Kelola Kuota Cuti'), findsNothing);
  });

  testWidgets('HR tidak melihat menu HR di halaman absen', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt('user_id', 2);

    await tester.pumpWidget(const MaterialApp(home: AbsenScreen()));
    await tester.pumpAndSettle();

    expect(find.text('MENU HR'), findsNothing);
    expect(find.text('Persetujuan Cuti'), findsNothing);
    expect(find.text('Cuti & Izin Keluar'), findsNothing);
    expect(find.text('Izin Keluar'), findsNothing);
    expect(find.text('Kelola Kuota Cuti'), findsNothing);
    expect(find.text('Pengajuan Cuti'), findsNothing);
  });
}

IzinKeluarItem _izinItem(int id, String status) {
  return IzinKeluarItem(
    id: id,
    employeeId: 3,
    tanggal: '2026-11-25',
    jamKeluar: '10:00:00',
    jamKembali: '12:00:00',
    kembaliKeKantor: true,
    kategori: 'Keperluan Pribadi',
    alasan: 'Acara keluarga',
    status: status,
    catatanHr: '',
    namaKaryawan: 'Andi Pratama',
    createdAt: '2026-11-25T09:00:00',
  );
}
