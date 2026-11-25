import '../config/api_config.dart';
import 'app_session.dart';

class EmployeeIdMissingException implements Exception {
  const EmployeeIdMissingException();

  @override
  String toString() => 'employee_id tidak ditemukan. Silakan login ulang.';
}

/// Request builders matching the deployed HRIS PHP endpoints.
///
/// login.php returns employee_id inside `data` (older backend) or inside
/// `data.user` (token backend). Both are normalized by AppSession before any
/// of these builders are used. `/profil.php` and `/riwayat_cuti.php` require
/// the employee_id query parameter; `/absen.php` and `/absen_pulang.php`
/// require it in the JSON body.
class EmployeeRequest {
  const EmployeeRequest._();

  /// No request is sent without an employee_id. The deployed backend has no
  /// attendance identity for HR admins, so they get a precise explanation
  /// instead of the generic "Data tidak lengkap" from absen.php.
  static String absenUnavailableMessage(String? role) {
    if (AppSession.isHrRole(role)) {
      return 'Absensi pribadi Admin HR belum didukung backend karena akun HR '
          'tidak memiliki data karyawan. Hubungi administrator.';
    }
    return 'employee_id tidak ditemukan. Silakan login ulang.';
  }

  static Uri profile(int? employeeId) =>
      _withEmployeeQuery('profil.php', employeeId);

  /// Riwayat cuti memakai satu endpoint untuk semua role.
  /// Backend `riwayat_cuti.php` sudah mengembalikan semua pengajuan untuk HR
  /// (employee_id null) dan hanya cuti sendiri untuk karyawan, dengan bentuk
  /// field yang sama — jadi tampilan tidak boleh bercabang.
  static Uri leaveHistory(int? employeeId, {String? role}) {
    return ApiConfig.uri('riwayat_cuti.php');
  }

  static Uri leaveCreate() => ApiConfig.uri('cuti.php');

  static Map<String, dynamic> leaveCreatePayload({
    required int? employeeId,
    required String title,
    required String reason,
    required String startDate,
    required String endDate,
    int? replacementEmployeeId,
    int? days,
    String? employeeName,
    String? nik,
    String? department,
    String? position,
  }) {
    _require(employeeId);
    return <String, dynamic>{
      'employee_id': employeeId,
      'title': title,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'replacement_employee_id': ?replacementEmployeeId,
      'days': ?days,
      'employee_name': ?employeeName,
      'nik': ?nik,
      'department': ?department,
      'position': ?position,
    };
  }

  static Map<String, dynamic> _absenBody({
    required double latitude,
    required double longitude,
    required String tanggalLokal,
    required String waktuLokal,
    double? accuracy,
    String? selfie,
  }) {
    return <String, dynamic>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (accuracy != null && accuracy.isFinite && accuracy >= 0)
        'gps_accuracy': accuracy.toStringAsFixed(2),
      'tanggal_lokal': tanggalLokal,
      'waktu_lokal': waktuLokal,
      if (selfie != null && selfie.isNotEmpty) 'selfie': selfie,
    };
  }

  static Map<String, dynamic> absenMasuk({
    required int? employeeId,
    required double latitude,
    required double longitude,
    required String tanggalLokal,
    required String waktuLokal,
    double? accuracy,
    String? selfie,
  }) {
    _require(employeeId);
    return <String, dynamic>{
      'employee_id': employeeId,
      ..._absenBody(
        latitude: latitude,
        longitude: longitude,
        tanggalLokal: tanggalLokal,
        waktuLokal: waktuLokal,
        accuracy: accuracy,
        selfie: selfie,
      ),
    };
  }

  static Map<String, dynamic> absenMasukAdmin({
    required double latitude,
    required double longitude,
    required String tanggalLokal,
    required String waktuLokal,
    double? accuracy,
    String? selfie,
  }) {
    return _absenBody(
      latitude: latitude,
      longitude: longitude,
      tanggalLokal: tanggalLokal,
      waktuLokal: waktuLokal,
      accuracy: accuracy,
      selfie: selfie,
    );
  }

  static Map<String, dynamic> absenPulang({
    required int? employeeId,
    required double latitude,
    required double longitude,
    required String tanggalLokal,
    required String waktuLokal,
    double? accuracy,
    String? selfie,
  }) {
    _require(employeeId);
    return <String, dynamic>{
      'employee_id': employeeId,
      ..._absenBody(
        latitude: latitude,
        longitude: longitude,
        tanggalLokal: tanggalLokal,
        waktuLokal: waktuLokal,
        accuracy: accuracy,
        selfie: selfie,
      ),
    };
  }

  static Map<String, dynamic> absenPulangAdmin({
    required double latitude,
    required double longitude,
    required String tanggalLokal,
    required String waktuLokal,
    double? accuracy,
    String? selfie,
  }) {
    return _absenBody(
      latitude: latitude,
      longitude: longitude,
      tanggalLokal: tanggalLokal,
      waktuLokal: waktuLokal,
      accuracy: accuracy,
      selfie: selfie,
    );
  }

  static Uri _withEmployeeQuery(String path, int? employeeId) {
    _require(employeeId);
    return ApiConfig.uri(path).replace(
      queryParameters: <String, String>{'employee_id': employeeId.toString()},
    );
  }

  static void _require(int? employeeId) {
    if (employeeId == null) throw const EmployeeIdMissingException();
  }
}
