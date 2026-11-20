import '../config/api_config.dart';

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

  static Uri profile(int? employeeId) =>
      _withEmployeeQuery('profil.php', employeeId);

  static Uri leaveHistory(int? employeeId) =>
      _withEmployeeQuery('riwayat_cuti.php', employeeId);

  static Map<String, dynamic> absenMasuk({
    required int? employeeId,
    required double latitude,
    required double longitude,
    required String tanggalLokal,
    required String waktuLokal,
  }) {
    _require(employeeId);
    return <String, dynamic>{
      'employee_id': employeeId,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'tanggal_lokal': tanggalLokal,
      'waktu_lokal': waktuLokal,
    };
  }

  static Map<String, dynamic> absenPulang({
    required int? employeeId,
    required double latitude,
    required double longitude,
    required String waktuLokal,
    required String selfie,
  }) {
    _require(employeeId);
    return <String, dynamic>{
      'employee_id': employeeId,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'waktu_lokal': waktuLokal,
      'selfie': selfie,
    };
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
