import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class SemuaAbsensiScreen extends StatelessWidget {
  const SemuaAbsensiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Semua Absensi')),
      body: SafeArea(
        top: false,
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: SemuaAbsensiView(),
        ),
      ),
    );
  }
}

class SemuaAbsensiView extends StatefulWidget {
  const SemuaAbsensiView({
    super.key,
    this.autoFetch = true,
    this.showHeader = true,
  });

  final bool autoFetch;
  final bool showHeader;

  @override
  State<SemuaAbsensiView> createState() => SemuaAbsensiViewState();
}

class SemuaAbsensiViewState extends State<SemuaAbsensiView> {
  static const String _absensiUrl =
      '${ApiConfig.baseUrl}/laporan_absensi.php';

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  String _query = '';
  List<_AbsensiItem> _daftarAbsensi = const [];

  @override
  void initState() {
    super.initState();
    if (widget.autoFetch) {
      _fetchSemuaAbsensi();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> reload() => _fetchSemuaAbsensi();

  Future<void> _fetchSemuaAbsensi() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String? token = AppSession.getToken();

      // Jika token kosong, hentikan request dan tampilkan pesan session invalid
      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session invalid. Silakan login kembali.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final http.Response response = await http
          .get(Uri.parse(_absensiUrl),
              headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _daftarAbsensi = _parseAbsensi(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _apiErrorMessage(
            response,
            'Gagal memuat data absensi (HTTP ${response.statusCode}).',
          );
          _isLoading = false;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Format data absensi tidak valid.';
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal terhubung ke server';
        _isLoading = false;
      });
    }
  }

  List<_AbsensiItem> _parseAbsensi(String body) {
    if (body.trim().isEmpty) return const [];

    final dynamic decoded = jsonDecode(body);
    dynamic rawData = decoded;

    if (decoded is Map<String, dynamic>) {
      rawData =
          decoded['data'] ??
          decoded['absensi'] ??
          decoded['result'] ??
          decoded['list'];
    }

    if (rawData is! List) return const [];

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(_AbsensiItem.fromJson)
        .toList();
  }

  String _apiErrorMessage(http.Response response, String fallback) {
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

  List<_AbsensiItem> get _filteredAbsensi {
    final String keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return _daftarAbsensi;

    return _daftarAbsensi
        .where((_AbsensiItem item) => item.nama.toLowerCase().contains(keyword))
        .toList();
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'hadir':
      case 'tepat waktu':
        return AppColors.success;
      case 'terlambat':
      case 'belum pulang':
        return AppColors.warning;
      case 'tidak hadir':
      case 'alpha':
      case 'absen':
        return AppColors.danger;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          const Text(
            'Rekap Absensi Karyawan',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pantau kehadiran seluruh karyawan berdasarkan tanggal, jam masuk, '
            'jam keluar, dan statusnya.',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
        ],
        TextField(
          controller: _searchController,
          onChanged: (String value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Cari nama karyawan...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    tooltip: 'Bersihkan pencarian',
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Daftar Absensi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (!_isLoading && _error == null)
              Text(
                '${_filteredAbsensi.length} data',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            IconButton(
              onPressed: _isLoading ? null : _fetchSemuaAbsensi,
              tooltip: 'Muat ulang data absensi',
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildList(),
      ],
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return SectionCard(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchSemuaAbsensi,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final List<_AbsensiItem> items = _filteredAbsensi;

    if (items.isEmpty) {
      return SectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              _query.trim().isEmpty
                  ? 'Belum ada data absensi'
                  : 'Tidak ada karyawan yang cocok dengan pencarian',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildItem(items[index]),
        );
      },
    );
  }

  Widget _buildItem(_AbsensiItem item) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 21,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nama,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.tanggal,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: item.status, color: _statusColor(item.status)),
            ],
          ),
          const Divider(height: 20, color: AppColors.border),
          Row(
            children: [
              Expanded(
                child: _InfoJam(
                  icon: Icons.login_rounded,
                  label: 'Jam Masuk',
                  value: item.jamMasuk,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoJam(
                  icon: Icons.logout_rounded,
                  label: 'Jam Keluar',
                  value: item.jamKeluar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoJam extends StatelessWidget {
  const _InfoJam({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AbsensiItem {
  const _AbsensiItem({
    required this.nama,
    required this.tanggal,
    required this.jamMasuk,
    required this.jamKeluar,
    required this.status,
  });

  final String nama;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String status;

  factory _AbsensiItem.fromJson(Map<String, dynamic> json) {
    final String firstName = _textOf(json['first_name'], '');
    final String lastName = _textOf(json['last_name'], '');
    final String namaLengkap = '$firstName $lastName'.trim();
    final String nama = _textOf(
      json['nama_lengkap'] ??
          json['nama_karyawan'] ??
          json['nama'] ??
          json['employee_name'] ??
          json['name'],
      namaLengkap.isEmpty ? 'Tanpa Nama' : namaLengkap,
    );
    final String jamMasuk = _formatJam(
      json['jam_masuk'] ??
          json['masuk'] ??
          json['check_in'] ??
          json['clock_in'],
    );
    final String jamKeluar = _formatJam(
      json['jam_keluar'] ??
          json['jam_pulang'] ??
          json['check_out'] ??
          json['clock_out'],
    );

    return _AbsensiItem(
      nama: nama,
      tanggal: _formatTanggal(
        json['tanggal'] ??
            json['date'] ??
            json['tanggal_absen'] ??
            json['tanggal_lokal'] ??
            json['created_at'],
      ),
      jamMasuk: jamMasuk,
      jamKeluar: jamKeluar,
      status: _statusOf(
        json['status'] ?? json['kehadiran'] ?? json['keterangan'],
        jamMasuk: jamMasuk,
        jamKeluar: jamKeluar,
      ),
    );
  }

  static String _textOf(dynamic value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String _formatJam(dynamic value) {
    if (value == null) return '-';
    final String text = value.toString().trim();
    if (text.isEmpty) return '-';
    return text.length >= 5 ? text.substring(0, 5) : text;
  }

  static String _formatTanggal(dynamic value) {
    if (value == null) return '-';

    final String text = value.toString().trim();
    if (text.isEmpty || text == '-') return '-';

    final DateTime? parsed = _parseTanggal(text);
    if (parsed == null) return text;

    return DateFormat('d MMMM yyyy', 'id_ID').format(parsed);
  }

  static DateTime? _parseTanggal(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    final int? timestamp = int.tryParse(value);
    if (timestamp == null) return null;

    final bool inSeconds = timestamp.abs() < 100000000000;
    return DateTime.fromMillisecondsSinceEpoch(
      inSeconds ? timestamp * 1000 : timestamp,
    );
  }

  static String _statusOf(
    dynamic value, {
    required String jamMasuk,
    required String jamKeluar,
  }) {
    final String raw = _textOf(value, '');
    final String status = raw.toLowerCase();

    if (status == '1' || status == 'hadir' || status == 'tepat waktu') {
      return 'Hadir';
    }
    if (status == '0' || status == 'alpha' || status == 'tidak hadir') {
      return 'Tidak Hadir';
    }
    if (status == 'terlambat') return 'Terlambat';
    if (status == 'izin') return 'Izin';
    if (status == 'sakit') return 'Sakit';
    if (status == 'cuti') return 'Cuti';
    if (status.isNotEmpty) return raw;

    if (jamMasuk != '-' && jamKeluar == '-') return 'Belum Pulang';
    if (jamMasuk != '-') return 'Hadir';
    return 'Tidak Hadir';
  }
}
