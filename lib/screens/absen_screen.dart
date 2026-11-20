import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/employee_request.dart';
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

  @override
  void initState() {
    super.initState();
    _dapatkanLokasi();
    _cekStatusAbsen();
    _fetchJamKerja();
  }

  String? _formatJamKerja(dynamic nilai) {
    if (nilai == null) return null;
    final String teks = nilai.toString().trim();
    if (teks.isEmpty) return null;
    return teks.length >= 5 ? teks.substring(0, 5) : teks;
  }

  Future<void> _fetchJamKerja() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/get_jam_kerja.php'))
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

  Future<void> _cekStatusAbsen() async {
    final int? employeeId = await AppSession.currentEmployeeId();
    if (employeeId == null) return;

    final String? token = await AppSession.resolveToken();

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

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;

      final now = DateTime.now();
      final String tanggalLokal =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final String waktuLokal =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(ApiConfig.authTokenPrefKey);

      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/absen.php'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields.addAll(
        EmployeeRequest.multipartMasuk(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          tanggalLokal: tanggalLokal,
          waktuLokal: waktuLokal,
        ),
      );
      request.files.add(
        await http.MultipartFile.fromPath('selfie', photo.path),
      );

      final http.StreamedResponse streamed = await request.send();
      final http.Response response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 201) {
        // Refresh status setelah absen masuk
        await _cekStatusAbsen();
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AbsenSuccessScreen(
              photoPath: photo.path,
              latitude: position.latitude,
              longitude: position.longitude,
              takenAt: now,
              jamMasuk: _jamAbsenTeks,
            ),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        _showMessage(data['message'] ?? 'Gagal menyimpan absen.');
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

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;

      final now = DateTime.now();
      final String tanggalLokal =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final String waktuLokal =
          "$tanggalLokal ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? token = prefs.getString(ApiConfig.authTokenPrefKey);

      final http.MultipartRequest request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/absen_pulang.php'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.fields.addAll(
        EmployeeRequest.multipartPulang(
          employeeId: employeeId,
          latitude: position.latitude,
          longitude: position.longitude,
          tanggalLokal: tanggalLokal,
          waktuLokal: waktuLokal,
        ),
      );
      request.files.add(
        await http.MultipartFile.fromPath('selfie', photo.path),
      );

      final http.StreamedResponse streamed = await request.send();
      final http.Response response = await http.Response.fromStream(streamed);

      if (!mounted) return;
      if (response.statusCode == 401) {
        await _handleUnauthorized();
        return;
      }

      if (response.statusCode == 200) {
        await _cekStatusAbsen();
        if (!mounted) return;

        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AbsenSuccessScreen(
              photoPath: photo.path,
              latitude: position.latitude,
              longitude: position.longitude,
              takenAt: now,
              jamMasuk: _jamPulangTeks,
            ),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        _showMessage(data['message'] ?? 'Gagal absen pulang.');
      }
    } catch (e) {
      if (mounted) _showMessage('Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleUnauthorized() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.authTokenPrefKey);
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Absen',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 2),
            Text(
              'Rabu, 11 November 2026',
              style: TextStyle(
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
                // Jarak antar card dibuat konsisten (14)
                const _CameraPlaceholder(),
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.09),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Shift Pagi',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
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

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3.1,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF23213A), Color(0xFF3A3560)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Kamera depan',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_outline_rounded,
                      size: 58,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Posisikan wajah di dalam bingkai',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pastikan pencahayaan cukup',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.66),
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
