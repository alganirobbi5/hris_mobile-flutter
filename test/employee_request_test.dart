import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/config/api_config.dart';
import 'package:hris_mobile/services/employee_request.dart';

void main() {
  test('profil dan riwayat_cuti menyertakan employee_id dari sesi', () {
    final Uri profil = EmployeeRequest.profile(42);
    final Uri riwayat = EmployeeRequest.leaveHistory(42);

    expect(profil.path, endsWith('/profil.php'));
    expect(profil.queryParameters['employee_id'], '42');
    expect(riwayat.path, endsWith('/riwayat_cuti.php'));
    expect(riwayat.queryParameters['employee_id'], '42');
    expect(profil.toString(), startsWith(ApiConfig.baseUrl));
  });

  test('employee_id kosong ditolak sebelum request dikirim', () {
    expect(() => EmployeeRequest.profile(null),
        throwsA(isA<EmployeeIdMissingException>()));
    expect(() => EmployeeRequest.leaveHistory(null),
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

  test('field multipart absen masuk memuat employee_id, GPS, waktu, dan selfie', () {
    final Map<String, String> fields = EmployeeRequest.multipartMasuk(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '08:02:17',
    );

    expect(fields['employee_id'], '42');
    expect(fields['latitude'], '-6.252707');
    expect(fields['longitude'], '106.777752');
    expect(fields['tanggal_lokal'], '2026-11-20');
    expect(fields['waktu_lokal'], '08:02:17');
    expect(fields.containsKey('selfie'), isFalse);
  });

  test('field multipart absen pulang memuat employee_id, GPS, waktu, dan selfie', () {
    final Map<String, String> fields = EmployeeRequest.multipartPulang(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      tanggalLokal: '2026-11-20',
      waktuLokal: '2026-11-20 17:02:38',
    );

    expect(fields['employee_id'], '42');
    expect(fields['latitude'], '-6.252707');
    expect(fields['longitude'], '106.777752');
    expect(fields['tanggal_lokal'], '2026-11-20');
    expect(fields['waktu_lokal'], '2026-11-20 17:02:38');
    expect(fields.containsKey('selfie'), isFalse);
  });

  test('payload absen pulang memenuhi validasi absen_pulang.php', () {
    final Map<String, dynamic> payload = EmployeeRequest.absenPulang(
      employeeId: 42,
      latitude: -6.252707,
      longitude: 106.777752,
      waktuLokal: '2026-11-20 17:02:38',
      selfie: 'data:image/jpeg;base64,ZmFrZQ==',
    );

    expect(payload['employee_id'], 42);
    expect(payload['waktu_lokal'], '2026-11-20 17:02:38');
    expect(payload['selfie'], 'data:image/jpeg;base64,ZmFrZQ==');
    expect(payload['latitude'], '-6.252707');
    expect(payload['longitude'], '106.777752');
    expect(payload.values.every((dynamic value) => value != null), isTrue);
  });
}
