import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class DetailAbsensiScreen extends StatelessWidget {
  const DetailAbsensiScreen({
    super.key,
    required this.nama,
    required this.tanggal,
    required this.jamMasuk,
    required this.jamKeluar,
    required this.latitude,
    required this.longitude,
  });

  final String nama;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String latitude;
  final String longitude;

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
      double.tryParse(_teksKoordinat(latitude).replaceFirst(',', '.'));

  double? get _longitude =>
      double.tryParse(_teksKoordinat(longitude).replaceFirst(',', '.'));

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
                                nama,
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
                      value: nama,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Tanggal',
                      value: tanggal,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.login_rounded,
                      label: 'Jam Masuk',
                      value: jamMasuk,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.logout_rounded,
                      label: 'Jam Keluar',
                      value: jamKeluar,
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Latitude',
                      value: _teksKoordinat(latitude),
                    ),
                    const SizedBox(height: 14),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Longitude',
                      value: _teksKoordinat(longitude),
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
                    if (_koordinat != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _buildPeta(context),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _tampilkanPeta(context),
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
                      child: const Column(
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
                      ),
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

  void _tampilkanPeta(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Lokasi Absensi'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildPeta(context),
              ),
              const SizedBox(height: 10),
              const Text(
                'Klik peta untuk melihat lokasi detail',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildPeta(BuildContext context) {
    final String? koordinat = _koordinat;
    if (koordinat == null) {
      return _petaPlaceholder('Koordinat lokasi tidak tersedia');
    }

    final List<String> parts = koordinat.split(',');
    final String lat = parts.first;
    final String lng = parts.last;
    final Uri staticMapUrl = Uri.parse(
      'https://staticmap.openstreetmap.de/staticmap.php?'
      'center=$koordinat&zoom=15&size=600x300&maptype=mapnik'
      '&markers=$koordinat,red-pushpin',
    );

    return GestureDetector(
      onTap: () => _bukaGoogleMaps(context, lat, lng),
      child: Image.network(
        staticMapUrl.toString(),
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        loadingBuilder: (BuildContext context, Widget child, Object? progress) {
          if (progress == null) return child;
          return _petaPlaceholder('Peta sedang dimuat...');
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _petaPlaceholder('Peta tidak dapat dimuat');
        },
      ),
    );
  }

  Widget _petaPlaceholder(String pesan) {
    return Container(
      width: double.infinity,
      height: 200,
      color: AppColors.field,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.map_outlined,
            size: 30,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            pesan,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bukaGoogleMaps(
    BuildContext context,
    String lat,
    String lng,
  ) async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Tidak dapat membuka Maps');
      }
    } catch (_) {
      if (!context.mounted) return;
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
