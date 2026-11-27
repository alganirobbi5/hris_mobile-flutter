import 'package:flutter/material.dart';

import '../services/izin_keluar_service.dart';
import '../services/riwayat_cuti_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class RiwayatCutiIzinKeluar extends StatefulWidget {
  const RiwayatCutiIzinKeluar({
    super.key,
    this.cutiLoader,
    this.izinLoader,
  });

  final Future<List<RiwayatCutiItem>> Function()? cutiLoader;
  final Future<List<IzinKeluarItem>> Function()? izinLoader;

  @override
  State<RiwayatCutiIzinKeluar> createState() =>
      _RiwayatCutiIzinKeluarState();
}

class _RiwayatCutiIzinKeluarState extends State<RiwayatCutiIzinKeluar> {
  static const List<MapEntry<String, String>> _filterList =
      <MapEntry<String, String>>[
    MapEntry<String, String>('all', 'Semua'),
    MapEntry<String, String>('cuti', 'Cuti'),
    MapEntry<String, String>('izin', 'Izin Keluar'),
  ];
  static const List<String> _bulan = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _filter = 'all';
  bool _isLoading = true;
  String? _error;
  List<_RiwayatItem> _items = const <_RiwayatItem>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final Future<List<RiwayatCutiItem>> cutiFuture =
          (widget.cutiLoader ?? (() => RiwayatCutiService.fetch()))();
      final Future<List<IzinKeluarItem>> izinFuture =
          (widget.izinLoader ?? (() => IzinKeluarService.fetch()))();
      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[cutiFuture, izinFuture],
      );
      final List<_RiwayatItem> merged = <_RiwayatItem>[
        ...(results[0] as List<RiwayatCutiItem>).map(_dariCuti),
        ...(results[1] as List<IzinKeluarItem>).map(_dariIzin),
      ]..sort((_RiwayatItem a, _RiwayatItem b) =>
          b.urutan.compareTo(a.urutan));
      if (!mounted) return;
      setState(() {
        _items = merged;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat riwayat cuti & izin keluar';
        _isLoading = false;
      });
    }
  }

  _RiwayatItem _dariCuti(RiwayatCutiItem item) {
    final DateTime? mulai = DateTime.tryParse(item.leavFrom);
    final DateTime? selesai = DateTime.tryParse(item.leavTo);
    final int durasi = (mulai != null && selesai != null)
        ? selesai.difference(mulai).inDays + 1
        : 0;
    final String waktu = durasi > 0
        ? '${_formatTanggal(item.leavFrom)} - '
            '${_formatTanggal(item.leavTo)} • $durasi hari'
        : '${_formatTanggal(item.leavFrom)} - ${_formatTanggal(item.leavTo)}';
    final String status = _statusLabel(item.status);
    final String keputusan = item.approvedByName.isEmpty
        ? ''
        : '$status oleh ${item.approvedByName}';
    return _RiwayatItem(
      jenis: 'Cuti',
      judul: item.type,
      status: status,
      waktu: waktu,
      keterangan: '',
      alasan: item.alasan,
      tujuan: item.targetLeaderName,
      keputusan: keputusan,
      catatan: item.catatanLeader.isNotEmpty
          ? item.catatanLeader
          : item.komentar,
      urutan: _waktuUrutan(item.createdAt, item.leavFrom),
    );
  }

  _RiwayatItem _dariIzin(IzinKeluarItem item) {
    final String jam = '${item.jamKeluarPendek} - ${item.jamKembaliPendek}';
    final String status = _statusLabel(item.status);
    final String keputusan = item.approvedByName.isEmpty
        ? ''
        : '$status oleh ${item.approvedByName}';
    return _RiwayatItem(
      jenis: 'Izin Keluar',
      judul: item.kategori,
      status: status,
      waktu: '${_formatTanggal(item.tanggal)} • $jam',
      keterangan: item.kategori,
      alasan: item.alasan,
      tujuan: item.targetLeaderName,
      keputusan: keputusan,
      catatan: item.catatanHr,
      urutan: _waktuUrutan(item.createdAt, item.tanggal),
    );
  }

  static DateTime _waktuUrutan(String createdAt, String fallback) {
    return DateTime.tryParse(createdAt) ??
        DateTime.tryParse(fallback) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatTanggal(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';
    final DateTime? parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;
    return '${parsed.day} ${_bulan[parsed.month - 1]} ${parsed.year}';
  }

  static String _statusLabel(String status) {
    final String value = status.trim().toLowerCase();
    if (value == 'approved' || value == 'approve' || value == '2') {
      return 'Disetujui';
    }
    if (value == 'rejected' || value == 'reject' || value == '3') {
      return 'Ditolak';
    }
    return 'Menunggu';
  }

  static Color _statusColor(String status) {
    switch (_statusLabel(status)) {
      case 'Disetujui':
        return AppColors.success;
      case 'Ditolak':
        return AppColors.danger;
      default:
        return AppColors.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_RiwayatItem> terfilter = _filter == 'all'
        ? _items
        : _items
            .where(
              (_RiwayatItem item) =>
                  _filter == 'cuti'
                      ? item.jenis == 'Cuti'
                      : item.jenis == 'Izin Keluar',
            )
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          spacing: 8,
          children: _filterList.map((MapEntry<String, String> entry) {
            return ChoiceChip(
              label: Text(entry.value),
              selected: _filter == entry.key,
              onSelected: (bool selected) {
                if (!selected) return;
                setState(() => _filter = entry.key);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const SectionCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (_error != null)
          SectionCard(
            child: Column(
              children: <Widget>[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: _fetch,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          )
        else if (terfilter.isEmpty)
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Center(
                child: Text(
                  _items.isEmpty
                      ? 'Belum ada riwayat cuti & izin keluar'
                      : 'Tidak ada riwayat untuk filter ini',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          )
        else
          ...terfilter.map(
            (_RiwayatItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCard(item),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(_RiwayatItem item) {
    final Color jenisColor =
        item.jenis == 'Cuti' ? AppColors.primary : AppColors.blue;
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: jenisColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.jenis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: jenisColor,
                  ),
                ),
              ),
              const Spacer(),
              StatusBadge(
                label: item.status,
                color: _statusColor(item.status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.judul,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  item.waktu,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (item.keterangan.isNotEmpty &&
              item.keterangan != item.judul) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Kategori: ${item.keterangan}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (item.alasan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Alasan: ${item.alasan}',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (item.tujuan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Ditujukan ke: ${item.tujuan}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (item.keputusan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              item.keputusan,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _statusColor(item.status),
              ),
            ),
          ],
          if (item.catatan.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'Catatan: ${item.catatan}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiwayatItem {
  const _RiwayatItem({
    required this.jenis,
    required this.judul,
    required this.status,
    required this.waktu,
    required this.keterangan,
    required this.alasan,
    required this.tujuan,
    required this.keputusan,
    required this.catatan,
    required this.urutan,
  });

  final String jenis;
  final String judul;
  final String status;
  final String waktu;
  final String keterangan;
  final String alasan;
  final String tujuan;
  final String keputusan;
  final String catatan;
  final DateTime urutan;
}
