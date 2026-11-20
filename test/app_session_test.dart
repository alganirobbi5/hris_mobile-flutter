import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/config/api_config.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const Map<String, dynamic> loginResponse = <String, dynamic>{
    'success': true,
    'message': 'Login berhasil',
    'data': <String, dynamic>{
      'token': 'vps-token-123',
      'user': <String, dynamic>{
        'user_id': 7,
        'employee_id': 42,
        'username': 'karyawan1',
        'role': 'employee',
        'nama_lengkap': 'Karyawan Satu',
      },
    },
  };

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppSession.token = null;
    AppSession.userId = null;
    AppSession.employeeId = null;
    AppSession.username = null;
    AppSession.name = null;
    AppSession.role = null;
  });

  test('setFromLogin membaca token dari data.token dan menyimpan field sesi', () async {
    await AppSession.setFromLogin(loginResponse);

    expect(AppSession.getToken(), 'vps-token-123');
    expect(AppSession.getUserId(), 7);
    expect(AppSession.getEmployeeId(), 42);
    expect(AppSession.getUsername(), 'karyawan1');
    expect(AppSession.getName(), 'Karyawan Satu');
    expect(AppSession.getRole(), 'employee');

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ApiConfig.tokenPrefKey), 'vps-token-123');
    expect(prefs.getInt('user_id'), 7);
    expect(prefs.getInt(ApiConfig.employeeIdPrefKey), 42);
    expect(prefs.getString('role'), 'employee');
  });

  test('setFromLogin menerima id numerik sebagai string', () async {
    await AppSession.setFromLogin(<String, dynamic>{
      'data': <String, dynamic>{
        'token': 'token-string-id',
        'user': <String, dynamic>{
          'user_id': '9',
          'employee_id': '11',
          'username': 'karyawan2',
          'role': 'hr',
        },
      },
    });

    expect(AppSession.getUserId(), 9);
    expect(AppSession.getEmployeeId(), 11);
    expect(AppSession.getRole(), 'hr');
  });

  test('restore mengisi ulang sesi setelah aplikasi dimulai ulang', () async {
    await AppSession.setFromLogin(loginResponse);

    AppSession.token = null;
    AppSession.userId = null;
    AppSession.employeeId = null;
    AppSession.role = null;

    await AppSession.restore();

    expect(AppSession.isLoggedIn, isTrue);
    expect(AppSession.getToken(), 'vps-token-123');
    expect(AppSession.getEmployeeId(), 42);
    expect(AppSession.getRole(), 'employee');
  });

  test('resolveToken memakai api_token dari prefs bila statis kosong', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ApiConfig.tokenPrefKey: 'token-dari-prefs',
    });
    AppSession.token = null;

    expect(await AppSession.resolveToken(), 'token-dari-prefs');
    expect(AppSession.getToken(), 'token-dari-prefs');
  });

  test('currentEmployeeId tidak mengarang id saat backend tidak mengirimnya', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    expect(await AppSession.currentEmployeeId(), isNull);
  });

  test('clear menghapus sesi di memori dan di penyimpanan', () async {
    await AppSession.setFromLogin(loginResponse);
    await AppSession.clear();

    expect(AppSession.isLoggedIn, isFalse);
    expect(AppSession.getToken(), isNull);
    expect(await AppSession.resolveToken(), isNull);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ApiConfig.tokenPrefKey), isFalse);
    expect(prefs.containsKey('user_id'), isFalse);
  });

  test('payload flat lama tetap diterima', () async {
    await AppSession.setFromLogin(<String, dynamic>{
      'token': 'token-lama',
      'user_id': 3,
      'employee_id': 5,
      'username': 'lama',
      'role': 'employee',
    });

    expect(AppSession.getToken(), 'token-lama');
    expect(AppSession.getUserId(), 3);
    expect(AppSession.getEmployeeId(), 5);
  });
}
