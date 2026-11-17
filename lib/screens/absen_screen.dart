import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'absen_success_screen.dart';

class AbsenScreen extends StatefulWidget {
  const AbsenScreen({super.key});

  @override
  State<AbsenScreen> createState() => _AbsenScreenState();
}

class _AbsenScreenState extends State<AbsenScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _isProcessing = false;
  bool _sudahAbsenMasuk = false; // Status untuk tombol pulang

  String _lokasiTeks = 'Mencari lokasi...';
  String _koordinatTeks = 'Mengambil koordinat...';
  String _jamAbsenTeks = '--:--';
  String _jamPulangTeks = '--:--';

  @override
  void initState() {
    super.initState();
    _dapatkanLokasi();
    _cekStatusAbsen(); // Cek apakah sudah absen hari ini
  }

  Future<void> _cekStatusAbsen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 2;

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/status_absen.php?employee_id=$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _sudahAbsenMasuk =
                data['sudah_masuk'] == true && data['sudah_pulang'] == false;

            // Ambil jam masuk dan pulang dari API
            if (data['jam_masuk'] != null) {
              _jamAbsenTeks =
                  data['jam_masuk'].toString().substring(0, 5) + " WIB";
            }
            if (data['jam_pulang'] != null) {
              _jamPulangTeks =
                  data['jam_pulang'].toString().substring(0, 5) + " WIB";
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal cek status absen: $e');
    }
  }

  void _updateJamAbsen() {
    final now = DateTime.now();
    if (mounted) {
      setState(() {
        _jamAbsenTeks =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
      });
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
            if (mounted)
              setState(() => _lokasiTeks = 'Nama jalan tidak ditemukan');
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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 2;

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

      setState(() {
        _jamAbsenTeks =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/absen.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employee_id': userId,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'tanggal_lokal': tanggalLokal,
          'waktu_lokal': waktuLokal,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        setState(() => _sudahAbsenMasuk = true);

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
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 2;

      final Position position = await Geolocator.getCurrentPosition();
      final now = DateTime.now();
      final String waktuLokal =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/absen_pulang.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'employee_id': userId,
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'waktu_lokal': waktuLokal,
        }),
      );

      if (!mounted) return;

      // Tambahkan pengecekan: Jika response bukan JSON, jangan di-parse
      if (response.headers['content-type']?.contains('application/json') !=
          true) {
        _showMessage('File API absen_pulang.php belum tersedia di server.');
        return;
      }

      if (response.statusCode == 200) {
        _showMessage('Absen pulang berhasil!');
        setState(() => _sudahAbsenMasuk = false);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CameraPlaceholder(),
              const SizedBox(height: 16),

              // Card Lokasi
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

              // Card Jam Kerja
              SectionCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    const _IconBox(icon: Icons.schedule_rounded),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Jam kerja hari ini',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '08:00 - 17:00',
                            style: TextStyle(
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

              // Card Jam Masuk Saat Ini
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
                            'Waktu masuk saat ini',
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

              const SizedBox(height: 24),

              // Card Jam Pulang
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
                            'Waktu keluar saat ini',
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

              // Tombol Aksi (Masuk & Pulang)
              PrimaryButton(
                label: _isProcessing
                    ? 'Memproses...'
                    : 'Ambil Selfie & Absen Masuk',
                icon: Icons.camera_front_rounded,
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleAbsenMasuk,
              ),
              const SizedBox(height: 12),

              // Tombol Absen Pulang (Hanya muncul jika sudah absen masuk)
              if (_sudahAbsenMasuk) ...[
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
                const SizedBox(height: 14),
              ],

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
            ],
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
