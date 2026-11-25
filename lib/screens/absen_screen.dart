import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/absen_status.dart';
import '../services/app_session.dart';
import '../services/employee_request.dart';
import '../services/notification_service.dart';
import '../services/selfie_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/selfie_preview_card.dart';
import '../widgets/status_badge.dart';
import 'absen_success_screen.dart';
import 'atur_jam_screen.dart';
import 'kelola_kuota_cuti_screen.dart';
import 'layanan_cuti_screen.dart';
import 'login_screen.dart';
import 'tambah_lokasi_screen.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  static const String _prefSelfieTanggal = 'absen_selfie_tanggal';
  static const String _prefSelfieMasuk = 'absen_selfie_masuk_path';
  static const String _prefSelfiePulang = 'absen_selfie_pulang_path';
  static const String _prefSelfieEmployee = 'absen_selfie_employee_id';
  static const int _selfieDimensiMaksimal = 720;
  static const int _selfieKualitasJpeg = 70;
  static const Duration _gpsUmurMaksimal = Duration(seconds: 45);
  static const double _gpsAkurasiMaksimal = 50;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  bool _sudahAbsenMasuk = false;
  bool _sudahAbsenPulang = false; // Tambahan status pulang

  String _lokasiTeks = 'Mencari lokasi...';
  String _koordinatTeks = 'Mengambil koordinat...';
  String _jamAbsenTeks = '--:--';
  String _jamPulangTeks = '--:--';
  String _jamMasukKerja = '--:--';
  String _jamKeluarKerja = '--:--';

  String? _selfieMasukPath;
  String? _selfiePulangPath;
  String? _selfieMasukUrl;
  String? _selfiePulangUrl;
  String? _token;
  String _koordinatAbsenTeks = '';
  String? _statusPulangApi;
  String _role = '';
  Position? _posisiTerakhir;
  DateTime? _waktuPosisiTerakhir;

  @override
  void initState() {
    super.initState();
    _muatRole();
    _muatPathSelfieLokal();
    _dapatkanLokasi();
    _cekStatusAbsen();
    _fetchJamKerja();
    _jadwalkanPengingatAbsen();
  }

  Future<void> _jadwalkanPengingatAbsen() async {
    final String? role = await AppSession.resolveRole();
    if (AppSession.isHrRole(role)) return;
    await AppNotificationService.scheduleDefaultReminders();
  }

  String _kunciTanggalHariIni() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _muatRole() async {
    final String? role = await AppSession.resolveRole();
    if (!mounted) return;
    setState(() => _role = role ?? '');
  }

  Future<String> _kunciIdentitas() async {
    final int? employeeId = await AppSession.currentEmployeeId();
    if (employeeId != null) return 'emp_$employeeId';
    final int? userId = await AppSession.resolveUserId();
    if (userId != null) return 'user_$userId';
    return 'role_${(await AppSession.resolveRole()) ?? 'unknown'}';
  }

  Future<void> _muatPathSelfieLokal() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String hariIni = _kunciTanggalHariIni();
    final String identitas = await _kunciIdentitas();
    final String? identitasTersimpan = prefs.getString(_prefSelfieEmployee);
    if (prefs.getString(_prefSelfieTanggal) != hariIni ||
        identitasTersimpan != identitas) {
      await prefs.remove(_prefSelfieMasuk);
      await prefs.remove(_prefSelfiePulang);
      await prefs.setString(_prefSelfieTanggal, hariIni);
      await prefs.setString(_prefSelfieEmployee, identitas);
    }
    if (!mounted) return;
    setState(() {
      _selfieMasukPath = prefs.getString(_prefSelfieMasuk);
      _selfiePulangPath = prefs.getString(_prefSelfiePulang);
    });
  }

  Future<void> _simpanPathSelfieLokal(String jenis, String path) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefSelfieTanggal, _kunciTanggalHariIni());
    await prefs.setString(_prefSelfieEmployee, await _kunciIdentitas());
    await prefs.setString(
      jenis == 'masuk' ? _prefSelfieMasuk : _prefSelfiePulang,
      path,
    );
    if (!mounted) return;
    setState(() {
      if (jenis == 'masuk') {
        _selfieMasukPath = path;
      } else {
        _selfiePulangPath = path;
      }
    });
  }

  String _tanggalHariIni() {
    const List<String> hari = <String>[
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const List<String> bulan = <String>[
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final DateTime now = DateTime.now();
    return '${hari[now.weekday - 1]}, ${now.day} ${bulan[now.month - 1]} ${now.year}';
  }

  String? _formatJamKerja(dynamic nilai) {
    if (nilai == null) return null;
    final String teks = nilai.toString().trim();
    if (teks.isEmpty) return null;
    return teks.length >= 5 ? teks.substring(0, 5) : teks;
  }

  Future<void> _fetchJamKerja() async {
    try {
      final String? token = await AppSession.resolveToken();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/get_jam_kerja.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return;

      final dynamic decoded = jsonDecode(response.body);
      dynamic data = decoded;

      if (decoded is Map<String, dynamic>) {
        final dynamic nested = decoded['data'];
        if (nested is Map<String, dynamic>) {
          data = nested;
        } else if (nested is List &&
            nested.isNotEmpty &&
            nested.first is Map<String, dynamic>) {
          data = nested.first;
        }
      }

      if (data is! Map<String, dynamic>) return;

      final String? jamMasuk = _formatJamKerja(data['jam_masuk']);
      final String? jamKeluar = _formatJamKerja(data['jam_keluar']);

      if (!mounted) return;
      setState(() {
        if (jamMasuk != null) _jamMasukKerja = jamMasuk;
        if (jamKeluar != null) _jamKeluarKerja = jamKeluar;
      });
    } catch (e) {
      debugPrint('Gagal memuat jam kerja: $e');
    }
  }

  String _teksDari(dynamic nilai) {
    if (nilai == null) return '';
    final String teks = nilai.toString().trim();
    if (teks.isEmpty || teks == '-' || teks.toLowerCase() == 'null') return '';
    return teks;
  }

  String? _urlSelfieServer(
    dynamic nilai,
    dynamic idAbsen, {
    bool pulang = false,
  }) {
    final String teks = _teksDari(nilai);
    if (teks.isEmpty) return null;

    Uri? uri;
    if (teks.startsWith('http://') || teks.startsWith('https://')) {
      uri = Uri.tryParse(teks);
    } else if (teks.startsWith('/')) {
      uri = Uri.parse(ApiConfig.baseUrl).resolve(teks);
    } else {
      uri = ApiConfig.uri('').resolve(teks);
    }
    if (uri == null || !uri.hasScheme) return null;

    final Map<String, String> params = Map<String, String>.from(
      uri.queryParameters,
    );
    final String id = _teksDari(idAbsen);
    if ((params['id'] ?? '').isEmpty && id.isNotEmpty && id != '0') {
      params['id'] = id;
    }
    if (pulang && (params['type'] ?? '').isEmpty) {
      params['type'] = 'out';
    }
    if ((params['id'] ?? '').isEmpty) return null;

    final Uri finalUri = uri.path.endsWith('selfie.php')
        ? uri.replace(queryParameters: params)
        : ApiConfig.uri('selfie.php').replace(queryParameters: params);
    return finalUri.toString();
  }

  Future<void> _cekStatusAbsen() async {
    final int? employeeId = await AppSession.currentEmployeeId();
    final Uri statusUri = ApiConfig.uri('status_absen.php').replace(
      queryParameters: employeeId == null
          ? <String, String>{}
          : <String, String>{'employee_id': employeeId.toString()},
    );

    final String? token = await AppSession.resolveToken();
    if (!mounted) return;
    setState(() => _token = token);

    try {
      final response = await http.get(
        statusUri,
        headers: ApiConfig.authHeaders(token),
      );
      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        dynamic data = decoded;
        if (decoded is Map<String, dynamic>) {
          final dynamic nested = decoded['data'] ?? decoded['result'];
          if (nested is Map<String, dynamic>) data = nested;
        }
        if (data is! Map<String, dynamic>) return;
        if (mounted) {
          setState(() {
            _sudahAbsenMasuk = data['sudah_masuk'] == true;
            _sudahAbsenPulang = data['sudah_pulang'] == true;

            final String? jamMasuk = _formatJamKerja(data['jam_masuk']);
            if (jamMasuk != null) _jamAbsenTeks = '$jamMasuk WIB';
            final String? jamPulang = _formatJamKerja(data['jam_pulang']);
            if (jamPulang != null) _jamPulangTeks = '$jamPulang WIB';
            _statusPulangApi = _teksDari(
              data['status_pulang'] ??
                  data['status_pulang_label'] ??
                  data['keterangan_pulang'],
            );

            final dynamic idAbsen = data['attendance_id'] ??
                data['absen_id'] ??
                data['id'] ??
                data['id_masuk'];
            _selfieMasukUrl = _urlSelfieServer(
              data['selfie_in_url'] ??
                  data['selfie_masuk_url'] ??
                  data['selfie_in'] ??
                  data['selfie_masuk'] ??
                  data['selfie_path'],
              idAbsen,
            );
            _selfiePulangUrl = _urlSelfieServer(
              data['selfie_out_url'] ??
                  data['selfie_pulang_url'] ??
                  data['selfie_out'] ??
                  data['selfie_pulang'] ??
                  data['selfie_path'],
              data['attendance_id_pulang'] ?? data['absen_id_pulang'] ?? idAbsen,
              pulang: true,
            );

            final String lat = _teksDari(data['latitude'] ?? data['lat']);
            final String lng = _teksDari(data['longitude'] ?? data['lng'] ?? data['lon']);
            if (lat.isNotEmpty && lng.isNotEmpty) {
              _koordinatAbsenTeks = '$lat, $lng';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal cek status absen: $e');
    }
  }

  Future<void> _dapatkanLokasi() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _lokasiTeks = 'GPS Tidak Aktif';
          _koordinatTeks = 'Aktifkan GPS di HP Anda';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );

        if (mounted) {
          _posisiTerakhir = position;
          _waktuPosisiTerakhir = DateTime.now();
          setState(() {
            _koordinatTeks =
                '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
            _lokasiTeks = 'Mencari nama jalan...';
          });

          try {
            final url = Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
            );
            final response = await http.get(
              url,
              headers: {'User-Agent': 'HRIS-Mobile-App'},
            );

            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final displayName = data['display_name'];
              if (mounted) {
                setState(() {
                  _lokasiTeks = displayName.toString().split(',')[0];
                });
              }
            }
          } catch (e) {
            if (mounted) {
              setState(() => _lokasiTeks = 'Nama jalan tidak ditemukan');
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lokasiTeks = 'Gagal Mendapatkan Lokasi';
          _koordinatTeks = 'Pastikan Anda di area terbuka';
        });
      }
    }
  }

  bool _posisiMasihSegar(Position position) {
    final DateTime? waktu = _waktuPosisiTerakhir;
    if (waktu == null) return false;
    if (DateTime.now().difference(waktu) > _gpsUmurMaksimal) return false;
    if (!position.latitude.isFinite ||
        !position.longitude.isFinite ||
        !position.accuracy.isFinite) {
      return false;
    }
    return position.accuracy <= _gpsAkurasiMaksimal;
  }

  Future<Position?> _ambilPosisiAbsen() async {
    final Position? tersimpan = _posisiTerakhir;
    if (tersimpan != null && _posisiMasihSegar(tersimpan)) return tersimpan;

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      _posisiTerakhir = position;
      _waktuPosisiTerakhir = DateTime.now();
      return position;
    } on LocationServiceDisabledException {
      rethrow;
    } on PermissionDeniedException {
      rethrow;
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<String?> _selfieDataUrl(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return null;
      List<int> bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) return null;

      final img.Image? decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded != null) {
        int width = decoded.width;
        int height = decoded.height;
        if (width > _selfieDimensiMaksimal || height > _selfieDimensiMaksimal) {
          final double skala = _selfieDimensiMaksimal /
              (width > height ? width : height);
          width = (width * skala).round();
          height = (height * skala).round();
          final img.Image resized = img.copyResize(
            decoded,
            width: width,
            height: height,
          );
          bytes = img.encodeJpg(resized, quality: _selfieKualitasJpeg);
        } else {
          bytes = img.encodeJpg(decoded, quality: _selfieKualitasJpeg);
        }
      }

      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleAbsenMasuk() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final String? role = await AppSession.resolveRole();
      final bool hr = AppSession.isHrRole(role);
      final int? employeeId = await AppSession.currentEmployeeId();
      if (employeeId == null && !hr) {
        if (!mounted) return;
        _showMessage(EmployeeRequest.absenUnavailableMessage(role));
        return;
      }

      final bool hasLocationPermission = await _ensureLocationPermission();
      if (!mounted) return;
      if (!hasLocationPermission) return;

      late final Position position;
      try {
        final Position? kandidat = await _ambilPosisiAbsen();
        if (kandidat == null) {
          _showMessage('Koordinat GPS belum tersedia. Coba lagi sebentar.');
          return;
        }
        position = kandidat;
      } on LocationServiceDisabledException {
        _showMessage(
          'Layanan lokasi tidak aktif. Aktifkan GPS terlebih dahulu.',
        );
        return;
      } on PermissionDeniedException {
        _showMessage('Izin lokasi diperlukan untuk melakukan absensi.');
        return;
      } catch (e) {
        _showMessage(
          'Gagal memperoleh koordinat GPS: $e. Pastikan berada di area '
          'terbuka dengan sinyal GPS yang baik.',
        );
        return;
      }
      if (!mounted) return;

      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180) {
        _showMessage('Koordinat GPS tidak valid. Absensi dibatalkan.');
        return;
      }

      setState(() {
        _koordinatTeks =
            '${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}';
        _lokasiTeks = 'Lokasi terverifikasi';
      });

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: _selfieKualitasJpeg,
        maxWidth: _selfieDimensiMaksimal.toDouble(),
        maxHeight: _selfieDimensiMaksimal.toDouble(),
      );
      if (!mounted) return;
      if (photo == null) {
        _showMessage('Pengambilan foto dibatalkan.');
        return;
      }

      final now = DateTime.now();
      final String tanggalLokal =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final String waktuLokal =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final String selfiePath;
      try {
        selfiePath = await SelfieStorage.save(
          photo,
          jenis: 'masuk',
          takenAt: now,
        );
      } catch (e) {
        if (mounted) {
          _showMessage('Gagal menyimpan foto selfie di perangkat: $e');
        }
        return;
      }

      final String? selfieDataUrl = await _selfieDataUrl(selfiePath);
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/${hr ? 'absen_admin.php' : 'absen.php'}',
            ),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(
              hr
                  ? EmployeeRequest.absenMasukAdmin(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      tanggalLokal: tanggalLokal,
                      waktuLokal: waktuLokal,
                      accuracy: position.accuracy,
                      selfie: selfieDataUrl,
                    )
                  : EmployeeRequest.absenMasuk(
                      employeeId: employeeId,
                      latitude: position.latitude,
                      longitude: position.longitude,
                      tanggalLokal: tanggalLokal,
                      waktuLokal: waktuLokal,
                      accuracy: position.accuracy,
                      selfie: selfieDataUrl,
                    ),
            ),
          )
          .timeout(ApiConfig.requestTimeout);

      if (!mounted) return;
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 201) {
        await _simpanPathSelfieLokal('masuk', selfiePath);
        // Refresh status setelah absen masuk
        await _cekStatusAbsen();
        await AppNotificationService.showAttendanceReminderNow(
          title: 'Absen Masuk Berhasil',
          body: 'Absen masuk tercatat pukul $_jamAbsenTeks. Selamat bekerja!',
        );
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AbsenSuccessScreen(
              photoPath: selfiePath,
              latitude: position.latitude,
              longitude: position.longitude,
              takenAt: now,
              jamMasuk: _jamAbsenTeks,
              jamMulaiKerja: _jamMasukKerja,
            ),
          ),
        );
      } else {
        String message = 'Gagal menyimpan absen (${response.statusCode}).';
        try {
          final Object? decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final Object? serverMessage = decoded['message'];
            if (serverMessage != null && serverMessage.toString().isNotEmpty) {
              message = serverMessage.toString();
            }
          }
        } on FormatException {
          message = 'Balasan server tidak valid (${response.statusCode}).';
        }
        _showMessage(message);
      }
    } catch (e) {
      if (mounted) _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleAbsenPulang() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final String? role = await AppSession.resolveRole();
      final bool hr = AppSession.isHrRole(role);
      final int? employeeId = await AppSession.currentEmployeeId();
      if (employeeId == null && !hr) {
        if (!mounted) return;
        _showMessage(EmployeeRequest.absenUnavailableMessage(role));
        return;
      }

      final bool hasLocationPermission = await _ensureLocationPermission();
      if (!mounted) return;
      if (!hasLocationPermission) return;

      late final Position position;
      try {
        final Position? kandidat = await _ambilPosisiAbsen();
        if (kandidat == null) {
          _showMessage('Koordinat GPS belum tersedia. Coba lagi sebentar.');
          return;
        }
        position = kandidat;
      } on LocationServiceDisabledException {
        _showMessage(
          'Layanan lokasi tidak aktif. Aktifkan GPS terlebih dahulu.',
        );
        return;
      } on PermissionDeniedException {
        _showMessage('Izin lokasi diperlukan untuk melakukan absensi.');
        return;
      } catch (e) {
        _showMessage(
          'Gagal memperoleh koordinat GPS: $e. Pastikan berada di area '
          'terbuka dengan sinyal GPS yang baik.',
        );
        return;
      }
      if (!mounted) return;

      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          position.longitude < -180 ||
          position.longitude > 180) {
        _showMessage('Koordinat GPS tidak valid. Absensi dibatalkan.');
        return;
      }

      setState(() {
        _koordinatTeks =
            '${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}';
        _lokasiTeks = 'Lokasi terverifikasi';
      });

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: _selfieKualitasJpeg,
        maxWidth: _selfieDimensiMaksimal.toDouble(),
        maxHeight: _selfieDimensiMaksimal.toDouble(),
      );
      if (!mounted) return;
      if (photo == null) {
        _showMessage('Pengambilan foto dibatalkan.');
        return;
      }

      final now = DateTime.now();
      final String tanggalLokal =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final String waktuLokal =
          "$tanggalLokal ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final String selfiePath;
      try {
        selfiePath = await SelfieStorage.save(
          photo,
          jenis: 'pulang',
          takenAt: now,
        );
      } catch (e) {
        if (mounted) {
          _showMessage('Gagal menyimpan foto selfie di perangkat: $e');
        }
        return;
      }

      final String? selfieDataUrl = await _selfieDataUrl(selfiePath);
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .post(
            Uri.parse(
              '${ApiConfig.baseUrl}/${hr ? 'absen_pulang_admin.php' : 'absen_pulang.php'}',
            ),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(
              hr
                  ? EmployeeRequest.absenPulangAdmin(
                      latitude: position.latitude,
                      longitude: position.longitude,
                      tanggalLokal: tanggalLokal,
                      waktuLokal: waktuLokal,
                      accuracy: position.accuracy,
                      selfie: selfieDataUrl,
                    )
                  : EmployeeRequest.absenPulang(
                      employeeId: employeeId,
                      latitude: position.latitude,
                      longitude: position.longitude,
                      tanggalLokal: tanggalLokal,
                      waktuLokal: waktuLokal,
                      accuracy: position.accuracy,
                      selfie: selfieDataUrl,
                    ),
            ),
          )
          .timeout(ApiConfig.requestTimeout);

      if (!mounted) return;
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        await _simpanPathSelfieLokal('pulang', selfiePath);
        await _cekStatusAbsen();
        await AppNotificationService.showAttendanceReminderNow(
          title: 'Absen Pulang Berhasil',
          body: 'Absen pulang tercatat pukul $_jamPulangTeks. Terima kasih!',
          id: AppNotificationService.checkOutId,
        );
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AbsenSuccessScreen(
              photoPath: selfiePath,
              latitude: position.latitude,
              longitude: position.longitude,
              takenAt: now,
              jamMasuk: _jamPulangTeks,
              isPulang: true,
              jamSelesaiKerja: _jamKeluarKerja,
              statusPulang: _statusPulangApi,
            ),
          ),
        );
      } else {
        String message = 'Gagal menyimpan absen (${response.statusCode}).';
        try {
          final Object? decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            final Object? serverMessage = decoded['message'];
            if (serverMessage != null && serverMessage.toString().isNotEmpty) {
              message = serverMessage.toString();
            }
          }
        } on FormatException {
          message = 'Balasan server tidak valid (${response.statusCode}).';
        }
        _showMessage(message);
      }
    } catch (e) {
      if (mounted) _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUnauthorized() async {
    await AppSession.clear();
    if (!mounted) return;
    _showMessage('Sesi login berakhir. Silakan login kembali.');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return false;
    if (permission == LocationPermission.denied) {
      _showMessage('Izin lokasi diperlukan untuk melakukan absensi.');
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      _showMessage(
        'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
        actionLabel: 'Buka pengaturan',
        onAction: () => Geolocator.openAppSettings(),
      );
      return false;
    }
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return false;
    if (!serviceEnabled) {
      _showMessage(
        'Layanan lokasi tidak aktif. Aktifkan GPS terlebih dahulu.',
        actionLabel: 'Aktifkan',
        onAction: () => Geolocator.openLocationSettings(),
      );
      return false;
    }
    return true;
  }

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final AppToastType type = AppToast.typeFromMessage(message);
    AppToast.show(
      message,
      type: type,
      action: actionLabel == null || onAction == null
          ? null
          : AppToastAction(label: actionLabel, onPressed: onAction),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? subtitle,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 24, color: AppColors.primary),
              const SizedBox(height: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StatusAbsenKind statusMasuk = AbsenStatus.statusMasuk(
      jamMasuk: _sudahAbsenMasuk ? _jamAbsenTeks : null,
      jamMulaiKerja: _jamMasukKerja,
    );
    final StatusAbsenKind statusPulang = AbsenStatus.statusPulang(
      jamPulang: _sudahAbsenPulang ? _jamPulangTeks : null,
      jamSelesaiKerja: _jamKeluarKerja,
      statusEksplisit: _statusPulangApi,
    );
    final bool hr = AppSession.isHrRole(_role);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Absen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              _tanggalHariIni(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait(<Future<void>>[
              _fetchJamKerja(),
              _cekStatusAbsen(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 116),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelfiePreviewCard(
                  sudahMasuk: _sudahAbsenMasuk,
                  sudahPulang: _sudahAbsenPulang,
                  jamMasuk: _jamAbsenTeks,
                  jamPulang: _jamPulangTeks,
                  lokalMasuk: _selfieMasukPath,
                  lokalPulang: _selfiePulangPath,
                  urlMasuk: _selfieMasukUrl,
                  urlPulang: _selfiePulangUrl,
                  headers: ApiConfig.authHeaders(_token),
                  koordinat: _koordinatAbsenTeks.isEmpty
                      ? _koordinatTeks
                      : _koordinatAbsenTeks,
                ),
                const SizedBox(height: 16),

                SectionCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _IconBox(icon: Icons.location_on_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'LOKASI TERDETEKSI',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _lokasiTeks,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _koordinatTeks,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const StatusBadge(
                        label: 'GPS aktif',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SectionCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const _IconBox(icon: Icons.schedule_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jam kerja hari ini',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$_jamMasukKerja - $_jamKeluarKerja',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SectionCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const _IconBox(icon: Icons.access_time_filled_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waktu masuk hari ini',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _jamAbsenTeks == '--:--'
                                  ? 'Belum melakukan absen'
                                  : _jamAbsenTeks,
                              style: TextStyle(
                                fontSize: _jamAbsenTeks == '--:--' ? 14 : 18,
                                fontWeight: FontWeight.w800,
                                color: _jamAbsenTeks == '--:--'
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (statusMasuk != StatusAbsenKind.tidakAda) ...[
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: statusMasuk.label,
                          color: statusMasuk.color,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                SectionCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const _IconBox(icon: Icons.logout_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waktu keluar hari ini',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _jamPulangTeks == '--:--'
                                  ? 'Belum melakukan absen pulang'
                                  : _jamPulangTeks,
                              style: TextStyle(
                                fontSize: _jamPulangTeks == '--:--' ? 14 : 18,
                                fontWeight: FontWeight.w800,
                                color: _jamPulangTeks == '--:--'
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (statusPulang != StatusAbsenKind.tidakAda) ...[
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: statusPulang.label,
                          color: statusPulang.color,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // LOGIKA TOMBOL DINAMIS
                // Tombol "Absen Masuk" hanya muncul jika belum absen masuk
                if (!_sudahAbsenMasuk) ...[
                  PrimaryButton(
                    label: _isProcessing
                        ? 'Memproses...'
                        : 'Ambil Selfie & Absen Masuk',
                    icon: Icons.camera_front_rounded,
                    isLoading: _isProcessing,
                    onPressed: _isProcessing ? null : _handleAbsenMasuk,
                  ),
                ]
                // Tombol "Absen Pulang" hanya muncul jika sudah absen masuk TAPI belum absen pulang
                else if (!_sudahAbsenPulang) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleAbsenPulang,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Absen Pulang'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ]
                // Jika sudah absen pulang, tampilkan teks status
                else ...[
                  const Center(
                    child: Text(
                      'Anda sudah menyelesaikan absensi hari ini.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pastikan kamu berada di area kantor dan izinkan akses kamera serta lokasi saat melakukan absensi.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),
                const Divider(color: AppColors.border),
                const SizedBox(height: 20),
                Text(
                  hr ? 'MENU HR' : 'FITUR',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.15,
                  children: hr
                      ? <Widget>[
                          _actionCard(
                            icon: Icons.event_available_outlined,
                            label: 'Cuti & Izin Keluar',
                            subtitle: 'Pengajuan cuti, izin keluar & riwayat',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const LayananCutiScreen(),
                                ),
                              );
                            },
                          ),
                          _actionCard(
                            icon: Icons.beach_access_outlined,
                            label: 'Kelola Kuota Cuti',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const KelolaKuotaCutiScreen(),
                                ),
                              );
                            },
                          ),
                          _actionCard(
                            icon: Icons.schedule_rounded,
                            label: 'Atur Jam Kerja',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const AturJamScreen(),
                                ),
                              );
                            },
                          ),
                          _actionCard(
                            icon: Icons.add_location_alt_rounded,
                            label: 'Tambah Lokasi',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const TambahLokasiScreen(),
                                ),
                              );
                            },
                          ),
                        ]
                      : <Widget>[
                          _actionCard(
                            icon: Icons.event_available_outlined,
                            label: 'Cuti & Izin Keluar',
                            subtitle: 'Pengajuan cuti, izin keluar & riwayat',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const LayananCutiScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 21, color: AppColors.primary),
    );
  }
}
