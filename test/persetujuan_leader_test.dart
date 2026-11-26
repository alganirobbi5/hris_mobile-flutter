import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:hris_mobile/screens/approval_cuti_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/employee_request.dart';
import 'package:hris_mobile/widgets/glass_bottom_nav.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  test('scope leader dan all tersedia untuk cuti maupun izin keluar', () {
    expect(
      EmployeeRequest.leaveReportUri(scope: 'leader').queryParameters,
      <String, String>{'scope': 'leader'},
    );
    expect(
      EmployeeRequest.leaveReportUri(scope: 'all').queryParameters,
      <String, String>{'scope': 'all'},
    );
    expect(EmployeeRequest.leaveReportUri().queryParameters, isEmpty);
    expect(
      EmployeeRequest.izinKeluarUri(
        scope: 'leader',
        bulan: 11,
        tahun: 2026,
      ).queryParameters,
      <String, String>{'scope': 'leader', 'bulan': '11', 'tahun': '2026'},
    );
  });

  testWidgets('tab Persetujuan muncul untuk employee yang menjadi Leader', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'employee');
    await prefs.setInt(AppSession.userIdPrefKey, 9);
    await prefs.setBool(AppSession.isLeaveLeaderPrefKey, true);

    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle();

    final Finder nav = find.byType(GlassBottomNav);
    expect(nav, findsOneWidget);
    expect(
      find.descendant(of: nav, matching: find.text('Persetujuan')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: nav, matching: find.text('Laporan')),
      findsNothing,
    );
  });

  testWidgets('Leader melihat aksi setujui/tolak cuti dan izin keluar', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'employee');
    await prefs.setInt(AppSession.userIdPrefKey, 9);
    await prefs.setString('auth_token', 'leader-token');
    AppSession.token = 'leader-token';

    final List<String> scopes = <String>[];
    final List<Map<String, String>> izinParams = <Map<String, String>>[];
    final http.Client client = _approvalClient(
      isLeaveLeader: true,
      scopes: scopes,
      izinParams: izinParams,
    );
    await tester.pumpWidget(
      MaterialApp(home: ApprovalCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Persetujuan Cuti (1)'), findsOneWidget);
    expect(find.text('Persetujuan Izin Keluar (1)'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    expect(find.text('Tambah Leader'), findsNothing);
    expect(scopes, contains('leader'));
    expect(scopes.where((String scope) => scope == 'leader').length, 2);

    await tester.tap(find.text('Persetujuan Izin Keluar (1)'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ringkasan Bulan ${DateFormat('MMMM', 'id_ID').format(DateTime.now())} ${DateTime.now().year}',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Statistik pengajuan izin keluar karyawan'),
      findsOneWidget,
    );
    expect(find.text('Daftar Pengajuan Izin Keluar'), findsOneWidget);
    expect(find.text('1 data'), findsOneWidget);
    expect(_statValue('Total'), findsOneWidget);
    expect(_statValue('Menunggu'), findsOneWidget);
    expect(_statValue('Disetujui', '0'), findsOneWidget);
    expect(_statValue('Ditolak', '0'), findsOneWidget);
    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.textContaining('10:30 - 12:00'), findsOneWidget);
    expect(find.textContaining('Tugas Luar Kantor'), findsOneWidget);
    expect(find.text('Ditujukan ke: Leader Satu'), findsOneWidget);
    expect(find.text('Lihat Detail'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);

    await tester.ensureVisible(_statLabel('Disetujui'));
    await tester.tap(_statLabel('Disetujui'));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada pengajuan untuk filter ini'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);

    await tester.ensureVisible(_statLabel('Total'));
    await tester.tap(_statLabel('Total'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Budi Santoso'), findsOneWidget);

    final int bulanAwal = int.parse(izinParams.last['bulan']!);
    await tester.ensureVisible(find.byTooltip('Bulan berikutnya'));
    await tester.tap(find.byTooltip('Bulan berikutnya'));
    await tester.pumpAndSettle();
    expect(izinParams.last['bulan'], '${bulanAwal % 12 + 1}');
    expect(find.textContaining('Budi Santoso'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Bulan sebelumnya'));
    await tester.tap(find.byTooltip('Bulan sebelumnya'));
    await tester.pumpAndSettle();
    expect(izinParams.last['bulan'], '$bulanAwal');
    client.close();
  });

  testWidgets('HR non-leader memantau tanpa tombol setujui/tolak', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt(AppSession.userIdPrefKey, 2);
    await prefs.setString('auth_token', 'hr-token');
    AppSession.token = 'hr-token';

    final List<String> scopes = <String>[];
    final http.Client client = _approvalClient(
      isLeaveLeader: false,
      scopes: scopes,
    );
    await tester.pumpWidget(
      MaterialApp(home: ApprovalCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tambah Leader'), findsOneWidget);
    expect(find.byTooltip('Hapus leader'), findsOneWidget);
    expect(find.text('Jabatan'), findsOneWidget);
    expect(find.text('Kepala Bagian'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    expect(scopes, contains('all'));
    expect(scopes.where((String scope) => scope == 'all').length, 2);

    await tester.tap(find.text('Persetujuan Izin Keluar (1)'));
    await tester.pumpAndSettle();

    expect(
      find.text('Statistik pengajuan izin keluar karyawan'),
      findsOneWidget,
    );
    expect(find.text('Daftar Pengajuan Izin Keluar'), findsOneWidget);
    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.text('Ditujukan ke: Leader Satu'), findsOneWidget);
    expect(find.text('Lihat Detail'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);

    await tester.ensureVisible(_statLabel('Menunggu'));
    await tester.tap(_statLabel('Menunggu'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    client.close();
  });

  testWidgets('kartu cuti dan izin menampilkan pelaku keputusan', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'employee');
    await prefs.setInt(AppSession.userIdPrefKey, 9);
    await prefs.setString('auth_token', 'leader-token');
    AppSession.token = 'leader-token';

    final http.Client client = _approvalClient(
      isLeaveLeader: true,
      scopes: <String>[],
      cutiStatus: 'approved',
      izinStatus: 'rejected',
      approvedByName: 'Admin HR',
    );
    await tester.pumpWidget(
      MaterialApp(home: ApprovalCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Disetujui oleh Admin HR'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);

    await tester.tap(find.text('Persetujuan Izin Keluar (0)'));
    await tester.pumpAndSettle();

    expect(find.text('Ditolak oleh Admin HR'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    client.close();
  });

  testWidgets('HR yang juga Leader tetap bisa menyetujui', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt(AppSession.userIdPrefKey, 9);
    await prefs.setString('auth_token', 'hr-leader-token');
    AppSession.token = 'hr-leader-token';

    final List<String> scopes = <String>[];
    final http.Client client = _approvalClient(
      isLeaveLeader: true,
      scopes: scopes,
    );
    await tester.pumpWidget(
      MaterialApp(home: ApprovalCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tambah Leader'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    expect(scopes.where((String scope) => scope == 'leader').length, 2);

    await tester.tap(find.text('Persetujuan Izin Keluar (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    client.close();
  });

  testWidgets('Leader lain yang ditambahkan HR melihat pengajuannya sendiri', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'employee');
    await prefs.setInt(AppSession.userIdPrefKey, 12);
    await prefs.setString('auth_token', 'leader-dua-token');
    AppSession.token = 'leader-dua-token';

    final http.Client client = _approvalClient(
      isLeaveLeader: true,
      scopes: <String>[],
      leaderUserId: 12,
      leaderName: 'Leader Dua',
    );
    await tester.pumpWidget(
      MaterialApp(home: ApprovalCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Setujui'), findsOneWidget);
    await tester.tap(find.text('Persetujuan Izin Keluar (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Ditujukan ke: Leader Dua'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
    client.close();
  });

  testWidgets('HR wajib mengisi Jabatan saat menambah Leader', (
    WidgetTester tester,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'hr');
    await prefs.setInt(AppSession.userIdPrefKey, 2);
    await prefs.setString('auth_token', 'hr-token');
    AppSession.token = 'hr-token';

    final List<Map<String, dynamic>> addBodies = <Map<String, dynamic>>[];
    final http.Client client = _approvalClient(
      isLeaveLeader: false,
      scopes: <String>[],
      addBodies: addBodies,
    );
    await tester.pumpWidget(
      MaterialApp(home: ApprovalCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah Leader'));
    await tester.pumpAndSettle();

    expect(find.text('Pilih User'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Jabatan'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Jabatan wajib diisi'), findsOneWidget);
    expect(addBodies, isEmpty);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calon Leader').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Kepala Bagian');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(addBodies, hasLength(1));
    expect(addBodies.first['user_id'], 11);
    expect(addBodies.first['jabatan'], 'Kepala Bagian');
    client.close();
  });
}

Finder _statLabel(String label) => find.descendant(
      of: find.byType(AnimatedContainer),
      matching: find.text(label),
    );

Finder _statValue(String label, [String value = '1']) {
  final Finder box = find.ancestor(
    of: _statLabel(label),
    matching: find.byType(AnimatedContainer),
  );
  return find.descendant(of: box, matching: find.text(value));
}

http.Client _approvalClient({
  required bool isLeaveLeader,
  required List<String> scopes,
  List<Map<String, String>>? izinParams,
  List<Map<String, dynamic>>? addBodies,
  int leaderUserId = 9,
  String leaderName = 'Leader Satu',
  String cutiStatus = 'pending',
  String izinStatus = 'pending',
  String approvedByName = '',
}) {
  return MockClient((http.Request request) async {
    final String path = request.url.path;

    if (path.endsWith('/me.php')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'is_leave_leader': isLeaveLeader},
        }),
        200,
      );
    }
    if (path.endsWith('/leave_leaders.php')) {
      if (request.method == 'POST') {
        addBodies?.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true}),
          200,
        );
      }
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'leaders': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'user_id': leaderUserId,
              'username': 'leader',
              'nama_lengkap': leaderName,
              'jabatan': 'Kepala Bagian',
            },
          ],
          'eligible_users': <Map<String, dynamic>>[
            <String, dynamic>{
              'user_id': 11,
              'username': 'calon',
              'nama_lengkap': 'Calon Leader',
            },
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/employees.php')) {
      return http.Response(
        jsonEncode(<String, dynamic>{'data': <dynamic>[]}),
        200,
      );
    }
    if (path.endsWith('/laporan_cuti.php')) {
      scopes.add(request.url.queryParameters['scope'] ?? '');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 11,
              'employee_name': 'Andi Pratama',
              'reason': 'Keluarga',
              'leave_from': '-',
              'leave_to': '-',
              'status': cutiStatus,
              'leader_user_id': leaderUserId,
              'approved_by_name': approvedByName,
            },
          ],
        }),
        200,
      );
    }
    if (path.endsWith('/ringkasan_cuti.php')) {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': <String, dynamic>{'total': 1, 'pending': 1},
        }),
        200,
      );
    }
    if (path.endsWith('/izin_keluar.php')) {
      scopes.add(request.url.queryParameters['scope'] ?? '');
      izinParams?.add(Map<String, String>.from(request.url.queryParameters));
      final int bulan = int.tryParse(
            request.url.queryParameters['bulan'] ?? '',
          ) ??
          DateTime.now().month;
      final int tahun = int.tryParse(
            request.url.queryParameters['tahun'] ?? '',
          ) ??
          DateTime.now().year;
      final String tanggal =
          '$tahun-${bulan.toString().padLeft(2, '0')}-25';
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 21,
              'employee_id': 3,
              'tanggal': tanggal,
              'jam_keluar': '10:30:00',
              'jam_kembali': '12:00:00',
              'kategori': 'Tugas Luar Kantor',
              'alasan': 'Menemui klien',
              'status': izinStatus,
              'leader_user_id': leaderUserId,
              'target_leader_name': leaderName,
              'approved_by_name': approvedByName,
              'first_name': 'Budi',
              'last_name': 'Santoso',
            },
          ],
        }),
        200,
      );
    }
    return http.Response('', 404);
  });
}
