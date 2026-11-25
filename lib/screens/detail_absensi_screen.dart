import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class DetailAbsensiScreen extends StatefulWidget {
  const DetailAbsensiScreen({
    super.key,
    this.absensiId = 0,
    this.selfiePath = '',
    required this.nama,
    required this.tanggal,
    required this.jamMasuk,
    required this.jamKeluar,
    required this.latitude,
    required this.longitude,
  });

  final int absensiId;
  final String selfiePath;
  final String nama;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String latitude;
  final String longitude;

  @override
  State<DetailAbsensiScreen> createState() => _DetailAbsensiScreenState();
}

class _DetailAbsensiScreenState extends State<DetailAbsensiScreen> {
  Uint8List? _selfieBytes;
  bool _isLoadingSelfie = false;

  @override
  void initState() {
    super.initState();
    if (widget.absensiId > 0) _fetchSelfie();
  }

  Future<void> _fetchSelfie() async {
    setState(() => _isLoadingSelfie = true);
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .get(
            ApiConfig.uri('selfie.php').replace(
              queryParameters: <String, String>{
                'id': widget.absensiId.toString(),
              },
            ),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() => _selfieBytes = response.bodyBytes);
      }
    } catch (_) {
      // Biarkan placeholder tetap tampil.
    } finally {
      if (mounted) setState(() => _isLoadingSelfie = false);
    }
  }

  static String _teksKoordinat(String value) {
    final String text = value.trim();
    if (text.isEmpty ||
        text == '-' ||
        text.toLowerCase() == 'null' ||
        text.toLowerCase() == 'n/a') {
      return '-';
    }
    return text;
  }

  double? get _latitude =>
      double.tryParse(_teksKoordinat(widget.latitude).replaceFirst(',', '.'));

  double? get _longitude =>
      double.tryParse(_teksKoordinat(widget.longitude).replaceFirst(',', '.'));

  String? get _koordinat {
    final double? lat = _latitude;
    final double? lng = _longitude;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return null;
    }
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return '${lat.toString()},${lng.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Absensi')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 22,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Detail Kehadiran',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.nama,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 10),
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Nama',
                      value: widget.nama,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Tanggal',
                      value: widget.tanggal,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.login_rounded,
                      label: 'Jam Masuk',
                      value: widget.jamMasuk,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.logout_rounded,
                      label: 'Jam Keluar',
                      value: widget.jamKeluar,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Latitude',
                      value: _teksKoordinat(widget.latitude),
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Longitude',
                      value: _teksKoordinat(widget.longitude),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lokasi Absen',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _koordinat ?? 'Koordinat lokasi tidak tersedia',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _koordinat == null ? null : _bukaPetaDariDetail,
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Lihat Peta'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto Selfie',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.field,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _isLoadingSelfie
                          ? const CircularProgressIndicator()
                          : (_selfieBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    _selfieBytes!,
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_camera_outlined,
                                      size: 36,
                                      color: AppColors.textSecondary,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Foto belum tersedia',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                )),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bukaPetaDariDetail() async {
    final String? koordinat = _koordinat;
    if (koordinat == null) return;
    final List<String> parts = koordinat.split(',');
    final String lat = parts.first;
    final String lng = parts.last;
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Tidak dapat membuka Maps');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka Google Maps')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 17, color: AppColors.primary),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
