import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

class AbsenSuccessScreen extends StatefulWidget {
  final String photoPath;
  final double latitude;
  final double longitude;
  final DateTime takenAt;
  final String jamMasuk;

  const AbsenSuccessScreen({
    super.key,
    required this.photoPath,
    required this.latitude,
    required this.longitude,
    required this.takenAt,
    required this.jamMasuk,
  });

  @override
  State<AbsenSuccessScreen> createState() => _AbsenSuccessScreenState();
}

class _AbsenSuccessScreenState extends State<AbsenSuccessScreen> {
  // Variabel untuk menyimpan nama lokasi asli
  String _namaLokasi = 'Mencari nama jalan...';

  @override
  void initState() {
    super.initState();
    _getNamaLokasi(); // Panggil API saat halaman dibuka
  }

  Future<void> _getNamaLokasi() async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${widget.latitude}&lon=${widget.longitude}',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'HRIS-Mobile-App', // Wajib untuk API Nominatim
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'];

        if (mounted) {
          setState(() {
            // Ambil nama jalan/daerah yang paling spesifik (sebelum koma pertama)
            _namaLokasi = displayName.toString().split(',')[0];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _namaLokasi = 'Lokasi tidak diketahui';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _namaLokasi = 'Gagal memuat nama lokasi';
        });
      }
    }
  }

  String _formatWaktu(DateTime dateTime) {
    final jam = dateTime.hour.toString().padLeft(2, '0');
    final menit = dateTime.minute.toString().padLeft(2, '0');
    final detik = dateTime.second.toString().padLeft(2, '0');
    return '$jam:$menit:$detik WIB';
  }

  String _formatTanggal(DateTime dateTime) {
    final listHari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    final listBulan = [
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
    final hari = listHari[dateTime.weekday - 1];
    final bulan = listBulan[dateTime.month - 1];
    return '$hari, ${dateTime.day} $bulan ${dateTime.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 28),
          child: Column(
            children: [
              // Foto Selfie
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    ClipOval(
                      child: Image.file(
                        File(widget.photoPath),
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Judul
              const Text(
                'Absen Berhasil',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _formatTanggal(widget.takenAt),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Card Detail
              SectionCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    // Waktu
                    _buildDetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Waktu absen',
                      value: widget.jamMasuk,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          // Cek jam: jika lewat jam 8, warna merah (Terlambat)
                          color: widget.takenAt.hour >= 8
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.takenAt.hour >= 8
                              ? '❌ Terlambat'
                              : '✓ Tepat waktu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.takenAt.hour >= 8
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 24, color: Colors.black12),

                    // Lokasi Nama Jalan
                    _buildDetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'Lokasi',
                      value: _namaLokasi, // Variabel dari API Nominatim
                    ),
                    const Divider(height: 24, color: Colors.black12),

                    // Koordinat GPS
                    _buildDetailRow(
                      icon: Icons.gps_fixed_rounded,
                      label: 'Koordinat GPS',
                      value: '${widget.latitude}, ${widget.longitude}',
                    ),
                    const Divider(height: 24, color: Colors.black12),

                    // Foto
                    _buildDetailRow(
                      icon: Icons.camera_alt_rounded,
                      label: 'Foto selfie',
                      value: 'Foto selfie tersimpan',
                      trailing: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Tombol Kembali
              PrimaryButton(
                label: 'Kembali ke Beranda',
                icon: Icons.home_rounded,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}
