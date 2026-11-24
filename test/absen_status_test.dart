import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/services/absen_status.dart';

void main() {
  test('pulang lebih awal dari jam selesai kerja', () {
    final StatusAbsenKind status = AbsenStatus.statusPulang(
      jamPulang: '16:30',
      jamSelesaiKerja: '17:00',
    );
    expect(status, StatusAbsenKind.pulangLebihAwal);
    expect(status.label, 'Pulang Lebih Awal');
  });

  test('pulang tepat waktu sampai batas 30 menit', () {
    expect(
      AbsenStatus.statusPulang(
        jamPulang: '17:05:22',
        jamSelesaiKerja: '17:00',
      ),
      StatusAbsenKind.tepatWaktu,
    );
    expect(
      AbsenStatus.statusPulang(
        jamPulang: '17:30 WIB',
        jamSelesaiKerja: '17:00',
      ),
      StatusAbsenKind.tepatWaktu,
    );
  });

  test('pulang terlambat lebih dari 30 menit', () {
    final StatusAbsenKind status = AbsenStatus.statusPulang(
      jamPulang: '17:31',
      jamSelesaiKerja: '17:00',
    );
    expect(status, StatusAbsenKind.pulangTerlambat);
    expect(status.label, 'Pulang Terlambat');
  });

  test('parsing jam aman untuk beberapa format', () {
    expect(AbsenStatus.menitDariJam('17:05'), 1025);
    expect(AbsenStatus.menitDariJam('17:05:22'), 1025);
    expect(AbsenStatus.menitDariJam('17:05 WIB'), 1025);
    expect(
      AbsenStatus.menitDariJam('08:30 - 17:00', ambilTerakhir: true),
      1020,
    );
    expect(AbsenStatus.menitDariJam('--:--'), isNull);
    expect(AbsenStatus.menitDariJam('25:99'), isNull);
  });

  test('status eksplisit dari API dipakai jika valid', () {
    expect(
      AbsenStatus.statusPulang(
        jamPulang: '17:45',
        jamSelesaiKerja: '17:00',
        statusEksplisit: 'early',
      ),
      StatusAbsenKind.pulangLebihAwal,
    );
    expect(
      AbsenStatus.statusPulang(
        jamPulang: '16:00',
        jamSelesaiKerja: '17:00',
        statusEksplisit: 'terlambat',
      ),
      StatusAbsenKind.pulangTerlambat,
    );
  });

  test('tanpa jam pulang tidak menampilkan badge', () {
    expect(
      AbsenStatus.statusPulang(jamPulang: null, jamSelesaiKerja: '17:00'),
      StatusAbsenKind.tidakAda,
    );
    expect(
      AbsenStatus.statusPulang(
        jamPulang: '--:--',
        jamSelesaiKerja: '17:00',
      ).label,
      isEmpty,
    );
  });

  test('status masuk tetap memakai jam mulai kerja', () {
    expect(
      AbsenStatus.statusMasuk(jamMasuk: '08:20', jamMulaiKerja: '08:30'),
      StatusAbsenKind.tepatWaktu,
    );
    expect(
      AbsenStatus.statusMasuk(jamMasuk: '08:45', jamMulaiKerja: '08:30'),
      StatusAbsenKind.terlambat,
    );
  });
}
