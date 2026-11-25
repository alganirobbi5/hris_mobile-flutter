import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/absen_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/employee_request.dart';
import 'package:hris_mobile/services/izin_keluar_service.dart';
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
    );
    expect(body['kembali_ke_kantor'], 1);
    expect(body['jam_keluar'], '10:30');
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

  testWidgets('karyawan melihat tombol terpadu Cuti & Izin Keluar', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'employee');
    await prefs.setInt('user_id', 1);

    await tester.pumpWidget(const MaterialApp(home: AbsenScreen()));
    await tester.pumpAndSettle();

    expect(find.text('FITUR'), findsOneWidget);
    expect(find.text('Cuti & Izin Keluar'), findsOneWidget);
    expect(find.text('Kelola Kuota Cuti'), findsNothing);
  });

  testWidgets('HR melihat tombol aksi HR termasuk Cuti & Izin Keluar', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt('user_id', 2);

    await tester.pumpWidget(const MaterialApp(home: AbsenScreen()));
    await tester.pumpAndSettle();

    expect(find.text('MENU HR'), findsOneWidget);
    expect(find.text('Persetujuan Cuti'), findsNothing);
    expect(find.text('Cuti & Izin Keluar'), findsOneWidget);
    expect(find.text('Kelola Kuota Cuti'), findsOneWidget);
    expect(find.text('Pengajuan Cuti'), findsNothing);
  });
}
