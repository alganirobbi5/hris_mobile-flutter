import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hris_mobile/services/leave_balance.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fetchEmployees membaca daftar karyawan dari employees.php', () async {
    final http.Client client = MockClient((http.Request request) async {
      expect(request.url.path, endsWith('/employees.php'));
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'data': <dynamic>[
            <String, dynamic>{'id': 3, 'name': 'Razu', 'nik': 'NIK-3'},
          ],
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final List<Map<String, dynamic>> result =
        await LeaveBalanceService.fetchEmployees(client: client);
    expect(result.length, 1);
    expect(result.first['id'], 3);
    expect(result.first['name'], 'Razu');
  });

  test('addEntitlement mengirim employee_id, days, dan tahun', () async {
    final http.Client client = MockClient((http.Request request) async {
      expect(request.url.path, endsWith('/tambah_kuota_cuti.php'));
      final Map<String, dynamic> body =
          jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['employee_id'], 3);
      expect(body['days'], 2.5);
      expect(body['entitlement_year'], 2026);
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': true,
          'message': 'OK',
          'data': <String, dynamic>{
            'employee_id': 3,
            'entitlement_year': 2026,
            'entitled_days': 14.5,
            'used_days': 0,
            'remaining_days': 14.5,
          },
        }),
        200,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final LeaveBalanceResult? result =
        await LeaveBalanceService.addEntitlement(
      employeeId: 3,
      days: 2.5,
      year: 2026,
      client: client,
    );
    expect(result, isNotNull);
    expect(result!.remainingDays, 14.5);
    expect(result.entitledDays, 14.5);
  });

  test('addEntitlement menolak balasan success false', () async {
    final http.Client client = MockClient((http.Request request) async {
      return http.Response(
        jsonEncode(<String, dynamic>{
          'success': false,
          'message': 'Karyawan tidak ditemukan',
        }),
        422,
        headers: <String, String>{'content-type': 'application/json'},
      );
    });

    final LeaveBalanceResult? result =
        await LeaveBalanceService.addEntitlement(
      employeeId: 0,
      days: 1,
      year: 2026,
      client: client,
    );
    expect(result, isNull);
    expect(LeaveBalanceService.lastError, 'Karyawan tidak ditemukan');
  });
}
