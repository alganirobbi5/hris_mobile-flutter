import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/services/absen_polling_service.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/notification_service.dart';
import 'package:hris_mobile/widgets/app_toast.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('tipe toast ditebak dari isi pesan', () {
    expect(AppToast.typeFromMessage('Pengajuan cuti berhasil dikirim'),
        AppToastType.success);
    expect(AppToast.typeFromMessage('Gagal terhubung ke server'),
        AppToastType.error);
    expect(AppToast.typeFromMessage('Tanggal mulai harus dipilih'),
        AppToastType.warning);
    expect(AppToast.typeFromMessage('Info kuota cuti'), AppToastType.info);
  });

  test('jadwal notifikasi memakai jam tetap yang valid', () {
    expect(AppNotificationService.defaultCheckIn, '08:00');
    expect(AppNotificationService.defaultCheckOut, '17:00');
    expect(AppNotificationService.checkInId, 1001);
    expect(AppNotificationService.checkOutId, 1002);
  });

  test('tidak ada error saat notifikasi dipanggil di lingkungan test', () async {
    await AppNotificationService.initialize();
    await AppNotificationService.scheduleDefaultReminders();
    await AppNotificationService.cancelReminders();
    await AppNotificationService.showAttendanceReminderNow(
      title: 'Tes',
      body: 'Tes notifikasi',
    );
  });

  test('polling notifikasi dipanggil untuk semua peran', () async {
    for (final String peran in <String>['employee', 'hr', 'super_admin']) {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'role': peran,
        'api_token': 'token-$peran',
      });
      AppSession.role = null;
      await AppSession.restore();
      final List<String> dipanggil = <String>[];
      final http.Client client = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/notifications.php')) {
          dipanggil.add('notifications');
          return http.Response(
            jsonEncode(<String, dynamic>{
              'success': true,
              'data': <dynamic>[],
              'unread': 0,
            }),
            200,
          );
        }
        dipanggil.add('absensi');
        return http.Response(
          jsonEncode(<String, dynamic>{'success': true, 'data': <dynamic>[]}),
          200,
        );
      });
      await AbsenPollingService.pollOnce(client: client);
      expect(dipanggil, contains('notifications'), reason: 'peran $peran');
      if (peran == 'hr') {
        expect(dipanggil, contains('absensi'));
      } else {
        expect(dipanggil, isNot(contains('absensi')));
      }
    }
  });
}
