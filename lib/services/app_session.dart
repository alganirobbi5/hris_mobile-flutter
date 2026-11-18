class AppSession {
  static int? userId;
  static int? employeeId;
  static String? username;
  static String? name;
  static String? role;

  static bool get isHr => role == 'hr';

  static void setFromLogin(Map<String, dynamic> data) {
    userId = _asInt(data['user_id']);
    employeeId = _asInt(data['employee_id']);
    username = data['username'] as String?;
    name = data['nama_lengkap'] as String?;
    role = data['role'] as String?;
  }

  static void clear() {
    userId = null;
    employeeId = null;
    username = null;
    name = null;
    role = null;
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
