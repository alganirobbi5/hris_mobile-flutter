// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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

  Future<void> _handleAbsen() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
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

      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(
                'http://127.0.0.1/HumanResourceManagementSystem/'
                'src/api/absen.php',
              ),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(<String, dynamic>{
                'employee_id': 2,
                'latitude': position.latitude.toString(),
                'longitude': position.longitude.toString(),
              }),
            )
            .timeout(const Duration(seconds: 20));
      } catch (error) {
        print('HTTP Error: $error');
        if (!mounted) return;
        _showMessage('Gagal terhubung ke server: $error');
        return;
      }

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode != 201) {
        _showMessage(_apiErrorMessage(response));
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AbsenSuccessScreen(
            photoPath: photo.path,
            latitude: position.latitude,
            longitude: position.longitude,
            takenAt: DateTime.now(),
          ),
        ),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      _showMessage(
        error.code == 'camera_access_denied'
            ? 'Akses kamera ditolak. Aktifkan izin kamera di pengaturan.'
            : 'Kamera tidak dapat dibuka. Silakan coba lagi.',
      );
    } on TimeoutException {
      if (!mounted) return;
      _showMessage('Gagal mendapatkan lokasi GPS. Coba lagi di area terbuka.');
    } on LocationServiceDisabledException {
      if (!mounted) return;
      _showMessage('Layanan lokasi tidak aktif. Aktifkan GPS terlebih dahulu.');
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'Terjadi kesalahan saat memproses absensi. Silakan coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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

  String _apiErrorMessage(http.Response response) {
    final String fallback =
        'Gagal mengirim absensi (HTTP ${response.statusCode}).';
    final String body = response.body.trim();
    if (body.isEmpty) return fallback;

    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic message =
            decoded['message'] ?? decoded['error'] ?? decoded['pesan'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return body.length <= 140 ? body : fallback;
    }

    return body.length <= 140 ? body : fallback;
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
              SectionCard(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _IconBox(icon: Icons.location_on_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOKASI TERDETEKSI',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.7,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Jl. Jenderal Sudirman, Jakarta',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Koordinat diambil saat absensi',
                            style: TextStyle(
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
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isProcessing ? 'Memproses...' : 'Ambil Selfie & Absen',
                icon: Icons.camera_front_rounded,
                isLoading: _isProcessing,
                onPressed: _handleAbsen,
              ),
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
                      'Pastikan kamu berada di area kantor dan izinkan akses '
                      'kamera serta lokasi saat melakukan absensi.',
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
