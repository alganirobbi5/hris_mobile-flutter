import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

class TambahLokasiScreen extends StatefulWidget {
  const TambahLokasiScreen({super.key});

  @override
  State<TambahLokasiScreen> createState() => _TambahLokasiScreenState();
}

class _TambahLokasiScreenState extends State<TambahLokasiScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _namaLokasiController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _namaLokasiController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  String? _validasiWajib(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kolom ini wajib diisi';
    }
    return null;
  }

  String? _validasiLatitude(String? value) {
    final String? wajib = _validasiWajib(value);
    if (wajib != null) return wajib;
    final double? angka = double.tryParse(value!.trim());
    if (angka == null) return 'Latitude harus berupa angka';
    if (angka < -90 || angka > 90) {
      return 'Latitude harus antara -90 dan 90';
    }
    return null;
  }

  String? _validasiLongitude(String? value) {
    final String? wajib = _validasiWajib(value);
    if (wajib != null) return wajib;
    final double? angka = double.tryParse(value!.trim());
    if (angka == null) return 'Longitude harus berupa angka';
    if (angka < -180 || angka > 180) {
      return 'Longitude harus antara -180 dan 180';
    }
    return null;
  }

  String? _validasiRadius(String? value) {
    final String? wajib = _validasiWajib(value);
    if (wajib != null) return wajib;
    final double? angka = double.tryParse(value!.trim());
    if (angka == null) return 'Radius harus berupa angka';
    if (angka <= 0) return 'Radius harus lebih dari 0';
    return null;
  }

  Future<void> _bukaMaps() async {
    String lat = _latitudeController.text.trim();
    String lng = _longitudeController.text.trim();

    if (lat.isEmpty || lng.isEmpty) {
      AppToast.warning('Isi Latitude dan Longitude terlebih dahulu');
      return;
    }

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Tidak bisa membuka Maps');
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.error('Tidak dapat membuka Google Maps');
    }
  }

  Future<void> _simpanLokasi() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final http.Response response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/tambah_lokasi.php'),
            headers: ApiConfig.authHeaders(await AppSession.resolveToken()),
            body: jsonEncode(<String, dynamic>{
              'nama_lokasi': _namaLokasiController.text.trim(),
              'latitude': _latitudeController.text.trim(),
              'longitude': _longitudeController.text.trim(),
              'radius_meter':
                  int.tryParse(_radiusController.text.trim()) ?? 100,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.headers['content-type']?.contains('application/json') !=
          true) {
        AppToast.error('Respons server tidak valid. Coba lagi nanti.');
        return;
      }

      Map<String, dynamic>? body;
      try {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } on FormatException {
        body = null;
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        AppToast.success(
          body?['message']?.toString() ?? 'Lokasi berhasil ditambahkan!',
        );
        Navigator.of(context).pop(true);
      } else {
        AppToast.error(
          body?['message']?.toString() ??
              body?['error']?.toString() ??
              'Gagal menambah lokasi (${response.statusCode})',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.error('Terjadi kesalahan koneksi ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Lokasi Absensi'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lengkapi data lokasi absensi baru. Titik koordinat dan '
                  'radius dipakai untuk memvalidasi kehadiran karyawan.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Nama Lokasi',
                        hint: 'Contoh: Kantor Pusat Jakarta',
                        controller: _namaLokasiController,
                        prefixIcon: Icons.location_city_rounded,
                        textInputAction: TextInputAction.next,
                        validator: _validasiWajib,
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Latitude',
                        hint: 'Contoh: -6.200000',
                        controller: _latitudeController,
                        prefixIcon: Icons.my_location_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _validasiLatitude,
                        suffixIcon: IconButton(
                          onPressed: _bukaMaps,
                          tooltip: 'Cek koordinat di Google Maps',
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '*Isi koordinat manual atau ketuk ikon peta untuk cek di Google Maps',
                        style: TextStyle(fontSize: 10, color: Colors.grey),
                      ),

                      const SizedBox(height: 12),

                      AppTextField(
                        label: 'Longitude',
                        hint: 'Contoh: 106.816666',
                        controller: _longitudeController,
                        prefixIcon: Icons.explore_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: _validasiLongitude,
                        suffixIcon: IconButton(
                          onPressed: _bukaMaps,
                          tooltip: 'Cek koordinat di Google Maps',
                          icon: const Icon(
                            Icons.map_outlined,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      AppTextField(
                        label: 'Radius (meter)',
                        hint: 'Contoh: 100',
                        controller: _radiusController,
                        prefixIcon: Icons.radio_button_checked_rounded,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        validator: _validasiRadius,
                      ),
                    ],
                  ),
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
                        'Radius menentukan jarak maksimal karyawan dari titik '
                        'lokasi saat melakukan absensi.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isLoading ? 'Menyimpan...' : 'Simpan Lokasi',
                  icon: Icons.save_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _simpanLokasi,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
