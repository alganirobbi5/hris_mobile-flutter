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

  test('setFromLogin menyimpan token ke auth_token dan api_token', () async {
    await AppSession.setFromLogin(loginResponse);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ApiConfig.authTokenPrefKey), 'vps-token-123');
    expect(prefs.getString(ApiConfig.tokenPrefKey), 'vps-token-123');
  });

  test('deteksi token-mode dan ekstraksi token dari dua bentuk respons', () {
    expect(
      AppSession.extractToken(<String, dynamic>{
        'data': <String, dynamic>{'token': 'token-level-data'},
      }),
      'token-level-data',
    );
    expect(
      AppSession.extractToken(<String, dynamic>{
        'data': <String, dynamic>{
          'data': <String, dynamic>{'token': 'token-level-nested'},
        },
      }),
      'token-level-nested',
    );
    expect(AppSession.extractToken(<String, dynamic>{'token': 'token-flat'}),
        'token-flat');

    expect(
      AppSession.responseDeclaresToken(<String, dynamic>{
        'data': <String, dynamic>{'token': null},
      }),
      isTrue,
    );
    expect(
      AppSession.responseDeclaresToken(<String, dynamic>{
        'data': <String, dynamic>{'user_id': 1, 'employee_id': 2},
      }),
      isFalse,
    );
  });

  test('restore dan resolveToken lebih mengutamakan auth_token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ApiConfig.authTokenPrefKey: 'token-baru',
      ApiConfig.tokenPrefKey: 'token-lama',
    });

    await AppSession.restore();
    expect(AppSession.getToken(), 'token-baru');

    AppSession.token = null;
    expect(await AppSession.resolveToken(), 'token-baru');
  });

  test('clear menghapus auth_token', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      ApiConfig.authTokenPrefKey: 'token-baru',
    });
    AppSession.token = 'token-baru';

    await AppSession.clear();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(ApiConfig.authTokenPrefKey), isFalse);
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

  test('respons login.php produksi (status/data datar) menyimpan employee_id', () async {
    await AppSession.setFromLogin(<String, dynamic>{
      'status': 'success',
      'message': 'Login berhasil',
      'data': <String, dynamic>{
        'user_id': 7,
        'employee_id': 42,
        'username': 'karyawan1',
        'role': 'employee',
        'nama_lengkap': 'Karyawan Satu',
      },
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('employee_id'), 42);
    expect(AppSession.getEmployeeId(), 42);
    expect(AppSession.getUserId(), 7);
    expect(AppSession.getEmployeeId(), isNot(AppSession.getUserId()));

    AppSession.employeeId = null;
    await AppSession.restore(prefs);
    expect(AppSession.getEmployeeId(), 42);
    expect(await AppSession.currentEmployeeId(), 42);
  });

  test('employee_id tidak disubstitusi dari user_id saat backend tidak mengirimnya', () async {
    await AppSession.setFromLogin(<String, dynamic>{
      'status': 'success',
      'data': <String, dynamic>{
        'user_id': 9,
        'username': 'admin-lama',
        'role': 'hr',
        'nama_lengkap': 'Admin Lama',
      },
    });

    expect(AppSession.getUserId(), 9);
    expect(AppSession.getEmployeeId(), isNull);
    expect(await AppSession.currentEmployeeId(), isNull);
  });
}
