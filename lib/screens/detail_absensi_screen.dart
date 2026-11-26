import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/location_name_service.dart';
import '../services/work_duration.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/osm_map_preview.dart';
import '../widgets/section_card.dart';
import '../widgets/selfie_fullscreen_viewer.dart';

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
    this.selfieInUrl = '',
    this.selfieOutUrl = '',
    this.jabatan = '',
    this.totalWork = '',
    this.recordType = '',
    this.jamMasukLengkap = '',
    this.jamPulangLengkap = '',
    this.namaLokasiResolver,
  });

  final int absensiId;
  final String selfiePath;
  final String selfieInUrl;
  final String selfieOutUrl;
  final String jabatan;
  final String totalWork;
  final String recordType;
  final String jamMasukLengkap;
  final String jamPulangLengkap;
  final String nama;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String latitude;
  final String longitude;
  final Future<String> Function(double latitude, double longitude)?
      namaLokasiResolver;

  @override
  State<DetailAbsensiScreen> createState() => _DetailAbsensiScreenState();
}

class _DetailAbsensiScreenState extends State<DetailAbsensiScreen> {
  Uint8List? _selfieBytes;
  bool _isLoadingSelfie = false;
  String? _token;
  String? _namaLokasi;
  bool _isLoadingLokasi = false;

  @override
  void initState() {
    super.initState();
    _resolveToken();
    _resolveNamaLokasi();
    if (widget.absensiId > 0 &&
        widget.selfieInUrl.isEmpty &&
        widget.selfiePath.isNotEmpty) {
      _fetchSelfie();
    }
  }

  Future<void> _resolveToken() async {
    final String? token = await AppSession.resolveToken();
    if (!mounted) return;
    setState(() => _token = token);
  }

  Future<void> _resolveNamaLokasi() async {
    final double? latitude = _latitude;
    final double? longitude = _longitude;
    if (latitude == null || longitude == null) return;
    if (!mounted) return;
    setState(() {
      _namaLokasi = null;
      _isLoadingLokasi = true;
    });
    final String nama = await (widget.namaLokasiResolver ??
        ((double lat, double lon) => LocationNameService.resolve(lat, lon)))(
      latitude,
      longitude,
    );
    if (!mounted) return;
    setState(() {
      _namaLokasi = nama;
      _isLoadingLokasi = false;
    });
  }

  String get _teksNamaLokasi {
    if (_isLoadingLokasi || _namaLokasi == null) {
      return 'Memuat nama lokasi...';
    }
    return _namaLokasi!;
  }

  String get _waktuKerja {
    final String masuk = widget.jamMasukLengkap.trim().isNotEmpty
        ? widget.jamMasukLengkap
        : widget.jamMasuk;
    final String pulang = widget.jamPulangLengkap.trim().isNotEmpty
        ? widget.jamPulangLengkap
        : widget.jamKeluar;
    if (WorkDuration.parse(pulang) == null) return WorkDuration.kosong;
    final String hasil = WorkDuration.dariString(masuk, pulang);
    if (hasil != WorkDuration.kosong) return hasil;
    return WorkDuration.normalize(widget.totalWork);
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
                    if (widget.jabatan.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Jabatan',
                        value: widget.jabatan,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Durasi Kerja',
                      value: _waktuKerja,
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
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.pin_drop_outlined,
                      label: 'Lokasi',
                      value: _koordinat == null
                          ? '-'
                          : _teksNamaLokasi,
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
                    const SizedBox(height: 10),
                    const Text(
                      'Nama Tempat',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _koordinat == null
                          ? 'Koordinat lokasi tidak tersedia'
                          : _teksNamaLokasi,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _koordinat ?? '-',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_koordinat != null)
                      OsmMapPreview(
                        latitude: _latitude!,
                        longitude: _longitude!,
                        height: 180,
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 180,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.location_off_outlined,
                              size: 38,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Peta tidak tersedia',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
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
                padding: const EdgeInsets.all(16),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _buildSelfieWindow(
                            judul: 'Absen Masuk',
                            jam: widget.jamMasuk,
                            url: widget.selfieInUrl,
                            fallbackBytes: _selfieBytes,
                            placeholder: 'Belum ada foto masuk',
                            loading: _isLoadingSelfie && widget.selfieInUrl.isEmpty,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSelfieWindow(
                            judul: 'Absen Pulang',
                            jam: widget.jamKeluar,
                            url: widget.selfieOutUrl,
                            placeholder: 'Belum ada foto pulang',
                          ),
                        ),
                      ],
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

  Widget _buildSelfieWindow({
    required String judul,
    required String jam,
    required String url,
    required String placeholder,
    Uint8List? fallbackBytes,
    bool loading = false,
  }) {
    final String alamat = url.trim();
    final bool adaFoto = alamat.isNotEmpty || (fallbackBytes?.isNotEmpty ?? false);
    final String jamTeks = jam.trim().isEmpty || jam.trim() == '-' ? '' : jam;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          jamTeks.isEmpty ? judul : '$judul • $jamTeks',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          children: <Widget>[
            Container(
              width: double.infinity,
              height: 138,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: loading
                  ? const CircularProgressIndicator()
                  : adaFoto
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: alamat.isNotEmpty
                              ? Image.network(
                                  alamat,
                                  headers: ApiConfig.authHeaders(_token),
                                  width: double.infinity,
                                  height: 138,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (BuildContext context,
                                      Widget child, Object? progress) {
                                    if (progress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (BuildContext context,
                                      Object error, StackTrace? stack) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        const Icon(
                                          Icons.broken_image_outlined,
                                          size: 30,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          placeholder,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : Image.memory(
                                  fallbackBytes!,
                                  width: double.infinity,
                                  height: 138,
                                  fit: BoxFit.cover,
                                ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.photo_camera_outlined,
                              size: 32,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              placeholder,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
            ),
            if (adaFoto)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => SelfieFullScreenViewer.show(
                    context,
                    title: judul.startsWith('Absen Masuk')
                        ? 'Foto Absen Masuk'
                        : 'Foto Absen Pulang',
                    subtitle: '$widget.nama${jamTeks.isEmpty ? '' : ' • $jamTeks'}',
                    networkUrl: alamat.isEmpty ? null : alamat,
                    headers: ApiConfig.authHeaders(_token),
                    bytes: alamat.isEmpty ? fallbackBytes : null,
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.zoom_out_map_rounded,
                        size: 17,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
      AppToast.error('Tidak dapat membuka Google Maps');
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
