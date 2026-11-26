import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      EmployeeRequest.izinKeluarUri(scope: 'leader').queryParameters,
      <String, String>{'scope': 'leader'},
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
    final http.Client client = _approvalClient(
      isLeaveLeader: true,
      scopes: scopes,
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

    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.text('Setujui'), findsOneWidget);
    expect(find.text('Tolak'), findsOneWidget);
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
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
    expect(scopes, contains('all'));
    expect(scopes.where((String scope) => scope == 'all').length, 2);

    await tester.tap(find.text('Persetujuan Izin Keluar (1)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Budi Santoso'), findsOneWidget);
    expect(find.text('Setujui'), findsNothing);
    expect(find.text('Tolak'), findsNothing);
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
}

http.Client _approvalClient({
  required bool isLeaveLeader,
  required List<String> scopes,
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
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'leaders': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 1,
              'user_id': 9,
              'username': 'leader',
              'nama_lengkap': 'Leader Satu',
            },
          ],
          'eligible_users': <dynamic>[],
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
              'leader_user_id': 9,
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
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 21,
              'employee_id': 3,
              'tanggal': '2026-11-25',
              'jam_keluar': '10:30:00',
              'jam_kembali': '12:00:00',
              'kategori': 'Tugas Luar Kantor',
              'alasan': 'Menemui klien',
              'status': izinStatus,
              'leader_user_id': 9,
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
