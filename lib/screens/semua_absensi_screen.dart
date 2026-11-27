import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../services/laporan_absensi_admin_service.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import 'detail_absensi_screen.dart';

class SemuaAbsensiScreen extends StatelessWidget {
  const SemuaAbsensiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Semua Absensi')),
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
    this.onDataChanged,
  });

  final bool autoFetch;
  final bool showHeader;
  final VoidCallback? onDataChanged;

  @override
  State<SemuaAbsensiView> createState() => SemuaAbsensiViewState();
}

class SemuaAbsensiViewState extends State<SemuaAbsensiView> {
  static const String _absensiUrl = '${ApiConfig.baseUrl}/laporan_absensi.php';

  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _error;
  String _query = '';
  List<_AbsensiItem> _daftarAbsensi = const [];
  bool _isHr = false;
  final Set<int> _deletingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final String? role = await AppSession.resolveRole();
    if (!mounted) return;
    setState(() => _isHr = AppSession.isHrRole(role));
    if (widget.autoFetch) await _fetchSemuaAbsensi();
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
      final String? token = await AppSession.resolveToken();

      final http.Response response = await http
          .get(Uri.parse(_absensiUrl), headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        List<dynamic> adminRows = const <dynamic>[];
        try {
          final http.Response adminResponse = await http
              .get(
                ApiConfig.uri(LaporanAbsensiAdminService.endpoint),
                headers: ApiConfig.authHeaders(token),
              )
              .timeout(const Duration(seconds: 15));
          if (adminResponse.statusCode == 200) {
            adminRows = _parseAbsensiRaw(adminResponse.body);
          }
        } catch (_) {
          // Endpoint laporan admin opsional; abaikan bila belum tersedia.
        }
        setState(() {
          final List<_AbsensiItem> gabungan = _parseAbsensi(response.body);
          final Set<String> kunci = gabungan
              .map(
                (_AbsensiItem item) => _rowKey(item),
              )
              .toSet();
          for (final dynamic raw in adminRows) {
            if (raw is! Map<String, dynamic>) continue;
            final _AbsensiItem item = _AbsensiItem.fromJson(raw);
            if (kunci.add(_rowKey(item))) gabungan.add(item);
          }
          _daftarAbsensi = gabungan;
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

  List<dynamic> _parseAbsensiRaw(String body) {
    if (body.trim().isEmpty) return const <dynamic>[];
    final dynamic decoded = jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final dynamic raw = decoded['data'] ??
          decoded['absensi'] ??
          decoded['result'] ??
          decoded['list'] ??
          decoded['admin'];
      if (raw is List) return raw;
    }
    return const <dynamic>[];
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
    return _daftarAbsensi
        .where(
          (_AbsensiItem item) =>
              item.status.toLowerCase() != 'libur' &&
              (keyword.isEmpty || item.nama.toLowerCase().contains(keyword)),
        )
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
      case 'libur':
        return AppColors.primary;
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

  Future<void> _hapusAbsensi(_AbsensiItem item) async {
    if (item.id <= 0 || _deletingIds.contains(item.id)) return;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus data absensi'),
        content: Text(
          'Yakin ingin menghapus absensi ${item.nama} pada ${item.tanggal}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _deletingIds.add(item.id));
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .post(
            ApiConfig.uri('hapus_absensi.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, Object>{
              'id': item.id,
              'record_type': item.recordType == 'admin' ? 'admin' : 'employee',
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showMessage('Data absensi berhasil dihapus');
        await _fetchSemuaAbsensi();
        widget.onDataChanged?.call();
      } else {
        _showMessage('Gagal menghapus data absensi (HTTP ${response.statusCode})');
      }
    } catch (_) {
      if (mounted) _showMessage('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(item.id));
    }
  }

  String _rowKey(_AbsensiItem item) =>
      '${item.recordType}|${item.id}|${item.tanggal}|${item.nama}|${item.jamMasuk}';

  void _showMessage(String message) {
    AppToast.show(message, type: AppToast.typeFromMessage(message));
  }

  Widget _buildItem(_AbsensiItem item) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DetailAbsensiScreen(
              absensiId: item.id,
              nama: item.nama,
              tanggal: item.tanggal,
              jamMasuk: item.jamMasuk,
              jamKeluar: item.jamKeluar,
              latitude: item.latitude,
              longitude: item.longitude,
              selfiePath: item.selfiePath,
              selfieInUrl: item.selfieInUrl,
              selfieOutUrl: item.selfieOutUrl,
              jabatan: item.jabatan,
              totalWork: item.totalWork,
              recordType: item.recordType,
              jamMasukLengkap: item.jamMasukLengkap,
              jamPulangLengkap: item.jamPulangLengkap,
              noHp: item.noHp,
            ),
          ),
        );
      },
      child: SectionCard(
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
                Flexible(
                  child: StatusBadge(
                    label: item.status,
                    color: _statusColor(item.status),
                  ),
                ),
                if (_isHr && item.id > 0) ...[
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Hapus absensi',
                      onPressed: _deletingIds.contains(item.id)
                          ? null
                          : () => _hapusAbsensi(item),
                      icon: _deletingIds.contains(item.id)
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_outline_rounded,
                              size: 17,
                              color: AppColors.danger,
                            ),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
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
    this.id = 0,
    required this.nama,
    required this.tanggal,
    required this.jamMasuk,
    required this.jamKeluar,
    required this.status,
    this.latitude = '',
    this.longitude = '',
    this.selfiePath = '',
    this.selfieInUrl = '',
    this.selfieOutUrl = '',
    this.jabatan = '',
    this.totalWork = '',
    this.recordType = '',
    this.jamMasukLengkap = '',
    this.jamPulangLengkap = '',
    this.noHp = '',
  });

  final int id;
  final String nama;
  final String tanggal;
  final String jamMasuk;
  final String jamKeluar;
  final String status;
  final String latitude;
  final String longitude;
  final String selfiePath;
  final String selfieInUrl;
  final String selfieOutUrl;
  final String jabatan;
  final String totalWork;
  final String recordType;
  final String jamMasukLengkap;
  final String jamPulangLengkap;
  final String noHp;

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
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
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
      latitude: _textOf(json['latitude'] ?? json['lat'], ''),
      longitude: _textOf(json['longitude'] ?? json['lng'] ?? json['lon'], ''),
      selfiePath: _textOf(
        json['selfie_path'] ?? json['selfie'] ?? json['foto_selfie'],
        '',
      ),
      selfieInUrl: _textOf(json['selfie_in_url'], ''),
      selfieOutUrl: _textOf(json['selfie_out_url'], ''),
      jabatan: _textOf(
        json['jabatan'] ?? json['designation_name'] ?? json['position'],
        '',
      ),
      totalWork: _textOf(
        json['total_work'] ?? json['total_jam_kerja'],
        '',
      ),
      recordType: _textOf(json['record_type'], 'employee'),
      jamMasukLengkap: _textOf(
        json['waktu_masuk'] ??
            json['waktu_masuk_lengkap'] ??
            json['jam_masuk_lengkap'] ??
            json['waktu_lokal'] ??
            json['jam_masuk'] ??
            json['created_at'],
        '',
      ),
      jamPulangLengkap: _textOf(
        json['waktu_pulang'] ??
            json['waktu_pulang_lengkap'] ??
            json['jam_pulang_lengkap'] ??
            json['jam_keluar_lengkap'] ??
            json['jam_pulang'] ??
            json['jam_keluar'] ??
            json['check_out'],
        '',
      ),
      noHp: _textOf(
        json['mobile_no'] ?? json['no_hp'] ?? json['phone'] ?? json['whatsapp'],
        '',
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
    if (status == 'libur' || status == 'holiday') return 'Libur';
    if (status == 'izin') return 'Izin';
    if (status == 'sakit') return 'Sakit';
    if (status == 'cuti') return 'Cuti';
    if (status.isNotEmpty) return raw;

    if (jamMasuk != '-' && jamKeluar == '-') return 'Belum Pulang';
    if (jamMasuk != '-') return 'Hadir';
    return 'Tidak Hadir';
  }
}
