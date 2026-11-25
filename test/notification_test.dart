import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/services/notification_service.dart';
import 'package:hris_mobile/widgets/app_toast.dart';

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
}
