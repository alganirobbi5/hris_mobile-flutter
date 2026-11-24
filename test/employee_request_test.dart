import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/config/api_config.dart';
import 'package:hris_mobile/services/employee_request.dart';

void main() {
  test('profil menyertakan employee_id, riwayat_cuti memakai token', () {
    final Uri profil = EmployeeRequest.profile(42);
    final Uri riwayat = EmployeeRequest.leaveHistory(42);

    expect(profil.path, endsWith('/profil.php'));
    expect(profil.queryParameters['employee_id'], '42');
    expect(riwayat.path, endsWith('/riwayat_cuti.php'));
    expect(riwayat.queryParameters['employee_id'], isNull);
    expect(profil.toString(), startsWith(ApiConfig.baseUrl));
  });

  test('riwayat_cuti sama untuk HR dan karyawan', () {
    final Uri karyawan = EmployeeRequest.leaveHistory(42, role: 'employee');
    final Uri hr = EmployeeRequest.leaveHistory(null, role: 'hr');

    expect(hr.toString(), karyawan.toString());
    expect(hr.path, endsWith('/riwayat_cuti.php'));
  });

  test('employee_id kosong ditolak sebelum request dikirim', () {
    expect(() => EmployeeRequest.profile(null),
        throwsA(isA<EmployeeIdMissingException>()));
    expect(
      () => EmployeeRequest.absenMasuk(
        employeeId: null,
        latitude: -6.2,
        longitude: 106.8,
        tanggalLokal: '2026-11-20',
        waktuLokal: '08:00:00',
      ),
      throwsA(isA<EmployeeIdMissingException>()),
    );
  });

  test('pesan absen admin HR spesifik tanpa employee_id palsu', () {
    expect(
      EmployeeRequest.absenUnavailableMessage('hr'),
      contains('belum didukung backend'),
    );
    expect(
      EmployeeRequest.absenUnavailableMessage('HR'),
      contains('belum didukung backend'),
    );
    expect(
      EmployeeRequest.absenUnavailableMessage('employee'),
      contains('employee_id tidak ditemukan'),
    );
  });

  test('payload absen masuk memenuhi validasi absen.php', () {
    final Map<String, dynamic> payload = EmployeeRequest.absenMasuk(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '08:02:17',
    );

    expect(payload['employee_id'], 42);
    expect(payload['latitude'], '-6.252707');
    expect(payload['longitude'], '106.777752');
    expect(payload['tanggal_lokal'], '2026-11-20');
    expect(payload['waktu_lokal'], '08:02:17');
    expect(payload.values.every((dynamic value) => value != null), isTrue);
  });

  test('payload absen masuk mengirim koordinat dan accuracy tanpa selfie', () {
    final Map<String, dynamic> payload = EmployeeRequest.absenMasuk(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '08:02:17',
      accuracy: 12.5,
    );

    expect(payload['latitude'], '-6.252707');
    expect(payload['longitude'], '106.777752');
    expect(payload['gps_accuracy'], '12.50');
    expect(payload.containsKey('selfie'), isFalse);
    expect(payload.containsKey('selfie_path'), isFalse);
    expect(payload.values.every((dynamic value) => value != null), isTrue);
  });

  test('payload absen masuk menyertakan selfie base64 saat tersedia', () {
    const String dataUrl = 'data:image/jpeg;base64,AAAA';
    final Map<String, dynamic> payload = EmployeeRequest.absenMasuk(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '08:02:17',
      selfie: dataUrl,
    );

    expect(payload['selfie'], dataUrl);
  });

  test('payload absen pulang mengirim koordinat dan accuracy tanpa selfie', () {
    final Map<String, dynamic> payload = EmployeeRequest.absenPulang(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '2026-11-20 17:02:38',
      accuracy: 9.25,
    );

    expect(payload['latitude'], '-6.252707');
    expect(payload['longitude'], '106.777752');
    expect(payload['gps_accuracy'], '9.25');
    expect(payload['tanggal_lokal'], '2026-11-20');
    expect(payload['waktu_lokal'], '2026-11-20 17:02:38');
    expect(payload.containsKey('selfie'), isFalse);
    expect(payload.values.every((dynamic value) => value != null), isTrue);
  });

  test('payload absen pulang menyertakan selfie base64 saat tersedia', () {
    const String dataUrl = 'data:image/jpeg;base64,AAAA';
    final Map<String, dynamic> payload = EmployeeRequest.absenPulang(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '2026-11-20 17:02:38',
      accuracy: 9.25,
      selfie: dataUrl,
    );

    expect(payload['selfie'], dataUrl);
    expect(payload['waktu_lokal'], '2026-11-20 17:02:38');
  });
}
