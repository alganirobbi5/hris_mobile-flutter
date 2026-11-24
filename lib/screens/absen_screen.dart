import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/employee_request.dart';
import '../services/selfie_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'absen_success_screen.dart';
import 'cuti_screen.dart';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _muatPathSelfieLokal();
    _dapatkanLokasi();
    _cekStatusAbsen();
    _fetchJamKerja();
  }

  String _kunciTanggalHariIni() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _muatPathSelfieLokal() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String hariIni = _kunciTanggalHariIni();
    final int? employeeId = await AppSession.currentEmployeeId();
    final String? employeeTersimpan = prefs.getString(_prefSelfieEmployee);
    if (prefs.getString(_prefSelfieTanggal) != hariIni ||
        employeeTersimpan != employeeId?.toString()) {
      await prefs.remove(_prefSelfieMasuk);
      await prefs.remove(_prefSelfiePulang);
      await prefs.setString(_prefSelfieTanggal, hariIni);
      await prefs.setString(_prefSelfieEmployee, employeeId?.toString() ?? '');
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
    await prefs.setString(
      _prefSelfieEmployee,
      (await AppSession.currentEmployeeId())?.toString() ?? '',
    );
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
    if (employeeId == null) return;

    final String? token = await AppSession.resolveToken();
    if (!mounted) return;
    setState(() => _token = token);

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/status_absen.php?employee_id=$employeeId',
        ),
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

  Future<String?> _selfieDataUrl(String path) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return null;
      final List<int> bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 2 * 1024 * 1024) return null;
      final String ext = path.contains('.')
          ? path.substring(path.lastIndexOf('.') + 1).toLowerCase()
          : 'jpg';
      final String mime = switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      return 'data:$mime;base64,${base64Encode(bytes)}';
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleAbsenMasuk() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final int? employeeId = await AppSession.currentEmployeeId();
      if (employeeId == null) {
        final String? role = await AppSession.resolveRole();
        if (!mounted) return;
        _showMessage(EmployeeRequest.absenUnavailableMessage(role));
        return;
      }

      final bool hasLocationPermission = await _ensureLocationPermission();
      if (!mounted) return;
      if (!hasLocationPermission) return;

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
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
        imageQuality: 85,
        maxWidth: 1600,
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
            Uri.parse('${ApiConfig.baseUrl}/absen.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(
              EmployeeRequest.absenMasuk(
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
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AbsenSuccessScreen(
              photoPath: selfiePath,
              latitude: position.latitude,
              longitude: position.longitude,
              takenAt: now,
              jamMasuk: _jamAbsenTeks,
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
      final int? employeeId = await AppSession.currentEmployeeId();
      if (employeeId == null) {
        final String? role = await AppSession.resolveRole();
        if (!mounted) return;
        _showMessage(EmployeeRequest.absenUnavailableMessage(role));
        return;
      }

      final bool hasLocationPermission = await _ensureLocationPermission();
      if (!mounted) return;
      if (!hasLocationPermission) return;

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
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
        imageQuality: 85,
        maxWidth: 1600,
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
            Uri.parse('${ApiConfig.baseUrl}/absen_pulang.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(
              EmployeeRequest.absenPulang(
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
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AbsenSuccessScreen(
              photoPath: selfiePath,
              latitude: position.latitude,
              longitude: position.longitude,
              takenAt: now,
              jamMasuk: _jamPulangTeks,
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(
                  label: actionLabel,
                  textColor: Colors.white,
                  onPressed: onAction,
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SelfiePreview(
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
                const CutiScreen(embedded: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelfiePreview extends StatefulWidget {
  const _SelfiePreview({
    required this.sudahMasuk,
    required this.sudahPulang,
    required this.jamMasuk,
    required this.jamPulang,
    required this.lokalMasuk,
    required this.lokalPulang,
    required this.urlMasuk,
    required this.urlPulang,
    required this.headers,
    required this.koordinat,
  });

  final bool sudahMasuk;
  final bool sudahPulang;
  final String jamMasuk;
  final String jamPulang;
  final String? lokalMasuk;
  final String? lokalPulang;
  final String? urlMasuk;
  final String? urlPulang;
  final Map<String, String> headers;
  final String koordinat;

  @override
  State<_SelfiePreview> createState() => _SelfiePreviewState();
}

class _SelfiePreviewState extends State<_SelfiePreview> {
  String _mode = 'masuk';

  @override
  void initState() {
    super.initState();
    _mode = widget.sudahPulang ? 'pulang' : 'masuk';
  }

  @override
  void didUpdateWidget(covariant _SelfiePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sudahPulang && !oldWidget.sudahPulang) {
      setState(() => _mode = 'pulang');
    }
  }

  static const LinearGradient _latar = LinearGradient(
    colors: <Color>[Color(0xFF23213A), Color(0xFF3A3560)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool _adaFoto(String? lokal, String? url) {
    if (url != null && url.trim().isNotEmpty) return true;
    if (lokal != null && lokal.isNotEmpty) return File(lokal).existsSync();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool masukAda =
        _adaFoto(widget.lokalMasuk, widget.urlMasuk) || widget.sudahMasuk;
    final bool pulangAda =
        _adaFoto(widget.lokalPulang, widget.urlPulang) || widget.sudahPulang;

    if (!masukAda && !pulangAda) return _buildKosong();

    final bool pakaiPulang = _mode == 'pulang' && pulangAda;
    final String? lokal = pakaiPulang ? widget.lokalPulang : widget.lokalMasuk;
    final String? url = pakaiPulang ? widget.urlPulang : widget.urlMasuk;
    final String jam = pakaiPulang ? widget.jamPulang : widget.jamMasuk;
    final String label = pakaiPulang ? 'Selfie Pulang' : 'Selfie Masuk';

    return SizedBox(
      height: 195,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: _latar)),
            _buildGambar(lokal, url),
            Positioned(
              top: 12,
              left: 12,
              child: _buildBadge('$label • $jam'),
            ),
            if (pulangAda)
              Positioned(
                top: 12,
                right: 12,
                child: _buildToggle(),
              ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                'Koordinat: ${widget.koordinat}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(offset: Offset(0, 1), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGambar(String? lokal, String? url) {
    if (lokal != null && lokal.isNotEmpty) {
      final File file = File(lokal);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    }

    final String? alamat = url?.trim();
    if (alamat != null && alamat.isNotEmpty) {
      return Image.network(
        alamat,
        headers: widget.headers,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (BuildContext context, Widget child, Object? progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _buildTercatat();
        },
      );
    }

    return _buildTercatat();
  }

  Widget _buildTercatat() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_rounded, size: 46, color: Color(0xFF66D19E)),
          SizedBox(height: 10),
          Text(
            'Absensi tercatat',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKosong() {
    return SizedBox(
      height: 195,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: _latar)),
            const Positioned(
              top: 12,
              left: 12,
              child: Icon(
                Icons.camera_front_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.camera_front_rounded,
                    size: 54,
                    color: Colors.white,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Belum ada foto selfie hari ini',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Tekan tombol di bawah untuk mengambil selfie absen masuk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String teks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _togglePill('Masuk', _mode == 'masuk'),
          _togglePill('Pulang', _mode == 'pulang'),
        ],
      ),
    );
  }

  Widget _togglePill(String label, bool aktif) {
    return GestureDetector(
      onTap: () => setState(() => _mode = label == 'Pulang' ? 'pulang' : 'masuk'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: aktif ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: aktif ? const Color(0xFF23213A) : Colors.white,
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
