import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/cuti_refresh.dart';
import '../services/employee_request.dart';
import '../services/leave_balance.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class ApprovalCutiScreen extends StatefulWidget {
  const ApprovalCutiScreen({super.key});

  @override
  State<ApprovalCutiScreen> createState() => _ApprovalCutiScreenState();
}

class _ApprovalCutiScreenState extends State<ApprovalCutiScreen> {
  static String get _laporanUrl => EmployeeRequest.leaveHistory(null).toString();
  static const String _approveUrl = '${ApiConfig.baseUrl}/approve_cuti.php';
  static const String _ringkasanUrl = '${ApiConfig.baseUrl}/ringkasan_cuti.php';

  bool _isLoading = true;
  String? _error;
  List<_PengajuanCuti> _pengajuan = const [];
  Map<int, Map<String, dynamic>> _karyawanById =
      const <int, Map<String, dynamic>>{};
  final Set<int> _processingIds = <int>{};
  String _filterStatus = 'all';

  _RingkasanCuti _ringkasan = const _RingkasanCuti();
  bool _isLoadingRingkasan = true;
  String? _ringkasanError;
  int _bulanRingkasan = DateTime.now().month;
  int _tahunRingkasan = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _fetchPengajuan();
    _fetchRingkasanCuti();
  }

  Future<void> _fetchPengajuan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String? token = await AppSession.resolveToken();
      final List<Map<String, dynamic>> karyawan =
          await LeaveBalanceService.fetchEmployees();
      if (!mounted) return;
      _karyawanById = <int, Map<String, dynamic>>{
        for (final Map<String, dynamic> item in karyawan)
          if (item['id'] is int) item['id'] as int: item,
      };

      final Uri laporanUri = Uri.parse(_laporanUrl);
      final http.Response response = await http
          .get(laporanUri, headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _pengajuan = _parsePengajuan(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _apiErrorMessage(
            response,
            'Gagal memuat pengajuan cuti (HTTP ${response.statusCode}).',
          );
          _isLoading = false;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Format data pengajuan cuti tidak valid.';
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

  List<_PengajuanCuti> _parsePengajuan(String body) {
    if (body.trim().isEmpty) return const [];

    final dynamic decoded = jsonDecode(body);
    dynamic rawData = decoded;

    if (decoded is Map<String, dynamic>) {
      rawData =
          decoded['data'] ??
          decoded['pengajuan'] ??
          decoded['result'] ??
          decoded['laporan_cuti'];
    }

    if (rawData is! List) return const [];

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(_PengajuanCuti.fromJson)
        .map(_lengkapiKaryawan)
        .toList();
  }

  _PengajuanCuti _lengkapiKaryawan(_PengajuanCuti item) {
    final Map<String, dynamic>? karyawan = _karyawanById[item.employeeId];
    if (karyawan == null) return item;

    final String nama = (karyawan['name'] ?? '').toString().trim();
    final String nik = (karyawan['nik'] ?? '').toString().trim();
    return _PengajuanCuti(
      id: item.id,
      employeeName:
          item.employeeName.isEmpty || item.employeeName == 'Karyawan'
              ? (nama.isEmpty ? item.employeeName : nama)
              : item.employeeName,
      reason: item.reason,
      leaveFrom: item.leaveFrom,
      leaveTo: item.leaveTo,
      status: item.status,
      comment: item.comment,
      createdAt: item.createdAt,
      title: item.title,
      keterangan: item.keterangan,
      employeeId: item.employeeId,
      nik: item.nik.isEmpty ? nik : item.nik,
      department: item.department,
      position: item.position,
      replacementName: item.replacementName,
      days: item.days,
    );
  }

  Future<void> _fetchRingkasanCuti() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRingkasan = true;
      _ringkasanError = null;
    });

    try {
      final String? token = await AppSession.resolveToken();
      final Uri ringkasanUri = Uri.parse(_ringkasanUrl).replace(
        queryParameters: <String, String>{
          'bulan': '$_bulanRingkasan',
          'tahun': '$_tahunRingkasan',
        },
      );

      final http.Response response = await http
          .get(ringkasanUri, headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final _RingkasanCuti? result = _parseRingkasan(response.body);
        if (result == null) {
          setState(() {
            _ringkasanError = 'Format ringkasan cuti tidak valid.';
            _isLoadingRingkasan = false;
          });
          return;
        }
        setState(() {
          _ringkasan = result;
          _isLoadingRingkasan = false;
        });
      } else {
        setState(() {
          _ringkasan = response.statusCode == 404
              ? const _RingkasanCuti()
              : _ringkasan;
          _ringkasanError = _apiErrorMessage(
            response,
            'Gagal memuat ringkasan cuti (HTTP ${response.statusCode}).',
          );
          _isLoadingRingkasan = false;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _ringkasanError = 'Format ringkasan cuti tidak valid.';
        _isLoadingRingkasan = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ringkasanError = 'Gagal terhubung ke server';
        _isLoadingRingkasan = false;
      });
    }
  }

  void _geserBulanRingkasan(int delta) {
    if (!mounted || _isLoadingRingkasan) return;
    final DateTime target = DateTime(
      _tahunRingkasan,
      _bulanRingkasan + delta,
      1,
    );
    setState(() {
      _bulanRingkasan = target.month;
      _tahunRingkasan = target.year;
    });
    _fetchRingkasanCuti();
    _fetchPengajuan();
  }

  _RingkasanCuti? _parseRingkasan(String body) {
    if (body.trim().isEmpty) return null;

    final dynamic decoded = jsonDecode(body);
    Map<String, dynamic>? data;

    if (decoded is Map<String, dynamic>) {
      final dynamic nested =
          decoded['data'] ??
          decoded['result'] ??
          decoded['ringkasan'] ??
          decoded['summary'];
      if (nested is Map<String, dynamic>) {
        data = nested;
      } else if (nested is List &&
          nested.isNotEmpty &&
          nested.first is Map<String, dynamic>) {
        data = nested.first as Map<String, dynamic>;
      } else {
        data = decoded;
      }
    } else if (decoded is List &&
        decoded.isNotEmpty &&
        decoded.first is Map<String, dynamic>) {
      data = decoded.first as Map<String, dynamic>;
    }

    if (data == null) return null;
    return _RingkasanCuti.fromJson(data);
  }

  Widget _buildRingkasanCard() {
    final _RingkasanCuti ringkasan = _ringkasan;

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_month_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringkasan Bulan ${ringkasan.bulan}',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Statistik pengajuan cuti karyawan',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 36,
                height: 36,
                child: _isLoadingRingkasan
                    ? const Padding(
                        padding: EdgeInsets.all(9),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : IconButton(
                        onPressed: _fetchRingkasanCuti,
                        tooltip: 'Muat ulang ringkasan',
                        color: AppColors.primary,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
              ),
            ],
          ),
          if (_ringkasanError != null) ...[
            const SizedBox(height: 10),
            Text(
              ringkasan.bulan == '-' && _ringkasanError == null
                  ? 'Ringkasan belum tersedia.'
                  : '$_ringkasanError',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _isLoadingRingkasan
                    ? null
                    : () => _geserBulanRingkasan(-1),
                tooltip: 'Bulan sebelumnya',
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
              ),
              Text(
                '$_bulanRingkasan/$_tahunRingkasan',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _isLoadingRingkasan
                    ? null
                    : () => _geserBulanRingkasan(1),
                tooltip: 'Bulan berikutnya',
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildRingkasanStat(
                label: 'Total',
                value: ringkasan.total,
                color: AppColors.primary,
                icon: Icons.format_list_bulleted_rounded,
                filterKey: 'all',
              ),
              const SizedBox(width: 8),
              _buildRingkasanStat(
                label: 'Menunggu',
                value: ringkasan.pending,
                color: AppColors.warning,
                icon: Icons.schedule_rounded,
                filterKey: 'pending',
              ),
              const SizedBox(width: 8),
              _buildRingkasanStat(
                label: 'Disetujui',
                value: ringkasan.approved,
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
                filterKey: 'approved',
              ),
              const SizedBox(width: 8),
              _buildRingkasanStat(
                label: 'Ditolak',
                value: ringkasan.rejected,
                color: AppColors.danger,
                icon: Icons.cancel_outlined,
                filterKey: 'rejected',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRingkasanStat({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
    required String filterKey,
  }) {
    final bool aktif = _filterStatus == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterStatus = filterKey),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          decoration: BoxDecoration(
            color: aktif
                ? color.withValues(alpha: 0.18)
                : color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: aktif ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(height: 5),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _sesuaiPeriode(_PengajuanCuti item) {
    final DateTime? tanggal = _parseDateValue(item.leaveFrom) ??
        _parseDateValue(item.createdAt);
    if (tanggal == null) return true;
    return tanggal.year == _tahunRingkasan && tanggal.month == _bulanRingkasan;
  }

  bool _sesuaiFilter(_PengajuanCuti item) {
    if (!_sesuaiPeriode(item)) return false;
    if (_filterStatus == 'all') return true;
    final int? kode = _statusCode(item.status);
    switch (_filterStatus) {
      case 'pending':
        return kode == 1;
      case 'approved':
        return kode == 2;
      case 'rejected':
        return kode == 3;
      default:
        return true;
    }
  }

  Future<void> _konfirmasiStatus(_PengajuanCuti item, int status) async {
    final bool setuju = status == 2;
    final TextEditingController commentController = TextEditingController();
    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(setuju ? 'Setujui cuti?' : 'Tolak cuti?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Komentar untuk ${item.employeeName}${setuju ? '' : ' (alasan penolakan)'}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Tulis komentar (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(setuju ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
    if (yakin != true) return;
    await _updateStatus(item, status, commentController.text.trim());
  }

  Future<void> _updateStatus(
    _PengajuanCuti target,
    int status,
    String comment,
  ) async {
    if (_processingIds.contains(target.id)) return;

    setState(() => _processingIds.add(target.id));

    try {
      final String? token = await AppSession.resolveToken();

      final http.Response response = await http
          .post(
            Uri.parse(_approveUrl),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'leave_id': target.id,
              'status': status,
              'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _pengajuan = _pengajuan
              .map(
                (item) => item.id == target.id
                    ? _PengajuanCuti(
                        id: item.id,
                        employeeName: item.employeeName,
                        reason: item.reason,
                        leaveFrom: item.leaveFrom,
                        leaveTo: item.leaveTo,
                        status: status.toString(),
                        comment: comment.isEmpty ? item.comment : comment,
                        createdAt: item.createdAt,
                        title: item.title,
                        keterangan: item.keterangan,
                        employeeId: item.employeeId,
                        nik: item.nik,
                        department: item.department,
                        position: item.position,
                        replacementName: item.replacementName,
                        days: item.days,
                      )
                    : item,
              )
              .toList();
        });
        CutiRefresh.notify();
        _showMessage('Status berhasil diubah');
        await Future.wait<void>(<Future<void>>[
          _fetchPengajuan(),
          _fetchRingkasanCuti(),
        ]);
      } else {
        _showMessage(
          _apiErrorMessage(
            response,
            'Gagal mengubah status (HTTP ${response.statusCode}).',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal terhubung ke server');
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(target.id));
      }
    }
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    final DateTime? parsed = _parseDateValue(trimmed);
    if (parsed == null) return trimmed;

    return DateFormat('d MMMM yyyy', 'id_ID').format(parsed);
  }

  DateTime? _parseDateValue(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    for (final String format in <String>['dd/MM/yy', 'd/M/yy', 'dd-MM-yyyy']) {
      try {
        final DateTime? formatted = DateFormat(format).tryParse(value);
        if (formatted != null) return formatted;
      } on FormatException {
        continue;
      }
    }

    final int? timestamp = int.tryParse(value);
    if (timestamp == null) return null;

    final bool inSeconds = timestamp.abs() < 100000000000;
    return DateTime.fromMillisecondsSinceEpoch(
      inSeconds ? timestamp * 1000 : timestamp,
    );
  }

  int? _statusCode(String status) {
    final String normalized = status.trim().toLowerCase();

    if (normalized == '1' ||
        normalized == 'menunggu' ||
        normalized == 'pending') {
      return 1;
    }
    if (normalized == '2' ||
        normalized == 'disetujui' ||
        normalized == 'approved' ||
        normalized == 'approve') {
      return 2;
    }
    if (normalized == '3' ||
        normalized == 'ditolak' ||
        normalized == 'rejected' ||
        normalized == 'reject') {
      return 3;
    }

    return null;
  }

  String _statusLabel(String status) {
    switch (_statusCode(status)) {
      case 2:
        return 'Disetujui';
      case 3:
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  Color _statusColor(String status) {
    switch (_statusCode(status)) {
      case 2:
        return AppColors.success;
      case 3:
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Persetujuan Cuti')),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait<void>(<Future<void>>[
              _fetchPengajuan(),
              _fetchRingkasanCuti(),
            ]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Persetujuan Cuti',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tinjau dan proses pengajuan cuti dari seluruh karyawan.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _buildRingkasanCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Daftar Pengajuan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (!_isLoading && _error == null)
                    Text(
                      '${_pengajuan.length} data',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildList(),
            ],
          ),
        ),
        ),
      ),
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
              onPressed: _fetchPengajuan,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    final List<_PengajuanCuti> tersaring =
        _pengajuan.where(_sesuaiFilter).toList();

    if (tersaring.isEmpty) {
      return SectionCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              _pengajuan.isEmpty
                  ? 'Belum ada pengajuan cuti'
                  : 'Tidak ada pengajuan untuk filter ini',
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
      itemCount: tersaring.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildItem(tersaring[index]),
        );
      },
    );
  }

  Future<void> _tampilkanDetail(_PengajuanCuti item) async {
    final String judul = item.title.isNotEmpty
        ? item.title
        : (item.reason == '-' ? 'Detail Pengajuan Cuti' : item.reason);

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(judul),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('Nama Karyawan', item.employeeName),
              if (item.nik.isNotEmpty) _detailRow('NIK', item.nik),
              if (item.employeeId > 0)
                _detailRow('ID Karyawan', '${item.employeeId}'),
              if (item.department.isNotEmpty)
                _detailRow('Departemen', item.department),
              if (item.position.isNotEmpty) _detailRow('Jabatan', item.position),
              _detailRow('Status', _statusLabel(item.status)),
              const Divider(color: AppColors.border),
              if (item.title.isNotEmpty) _detailRow('Judul Cuti', item.title),
              _detailRow('Alasan', _detailKeterangan(item)),
              _detailRow(
                'Tanggal Mulai',
                _formatDate(item.leaveFrom),
              ),
              _detailRow(
                'Tanggal Selesai',
                _formatDate(item.leaveTo),
              ),
              if (item.days > 0) _detailRow('Jumlah Hari', '${item.days} hari'),
              if (item.replacementName.isNotEmpty)
                _detailRow('Pengganti', item.replacementName),
              if (item.createdAt.isNotEmpty)
                _detailRow('Diajukan', _formatDate(item.createdAt)),
              if (item.comment.isNotEmpty)
                _detailRow('Komentar HR', item.comment),
              const SizedBox(height: 4),
              Text(
                'ID Pengajuan: ${item.id}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  String _detailKeterangan(_PengajuanCuti item) {
    if (item.keterangan.isNotEmpty && item.keterangan != item.reason) {
      return item.keterangan;
    }
    if (item.reason.isEmpty || item.reason == '-') return '-';
    if (item.title.isNotEmpty && item.reason.startsWith(item.title)) {
      final String sisa = item.reason.substring(item.title.length).trim();
      if (sisa.startsWith('-')) return sisa.substring(1).trim();
      if (sisa.isNotEmpty) return sisa;
    }
    return item.reason;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_PengajuanCuti item) {
    final String statusLabel = _statusLabel(item.status);
    final Color statusColor = _statusColor(item.status);
    final bool isPending = _statusCode(item.status) == 1;
    final bool isProcessing = _processingIds.contains(item.id);

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
                child: Text(
                  item.employeeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _tampilkanDetail(item),
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('Lihat Detail'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notes_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.reason,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.date_range_rounded,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatDate(item.leaveFrom)} - '
                  '${_formatDate(item.leaveTo)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (item.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Komentar HR: ${item.comment}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: isPending && !isProcessing
                      ? () => _konfirmasiStatus(item, 2)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Setujui'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: isPending && !isProcessing
                      ? () => _konfirmasiStatus(item, 3)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Tolak'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PengajuanCuti {
  const _PengajuanCuti({
    required this.id,
    required this.employeeName,
    required this.reason,
    required this.leaveFrom,
    required this.leaveTo,
    required this.status,
    this.comment = '',
    this.createdAt = '',
    this.title = '',
    this.keterangan = '',
    this.employeeId = 0,
    this.nik = '',
    this.department = '',
    this.position = '',
    this.replacementName = '',
    this.days = 0,
  });

  factory _PengajuanCuti.fromJson(Map<String, dynamic> json) {
    final String firstName = _stringValue(
      json['first_name'] ?? json['firstName'],
      '',
    );
    final String lastName = _stringValue(
      json['last_name'] ?? json['lastName'],
      '',
    );
    final String fullName = '$firstName $lastName'.trim();

    return _PengajuanCuti(
      id: _intValue(json['id'] ?? json['leave_id']),
      employeeName: _stringValue(
        json['employee_name'] ?? json['name'],
        fullName.isEmpty ? 'Karyawan' : fullName,
      ),
      reason: _stringValue(
        json['reason'] ?? json['type'] ?? json['keterangan'],
        '-',
      ),
      leaveFrom: _stringValue(
        json['leave_from'] ?? json['leav_from'] ?? json['start_date'],
        '-',
      ),
      leaveTo: _stringValue(
        json['leave_to'] ?? json['leav_to'] ?? json['end_date'],
        '-',
      ),
      status: _stringValue(json['status'] ?? json['staus'], '-'),
      comment: _stringValue(json['comment'] ?? json['komentar'], ''),
      createdAt: _stringValue(
        json['created_at'] ?? json['tanggal_pengajuan'],
        '',
      ),
      title: _stringValue(
        json['title'] ?? json['judul'] ?? json['jenis_cuti'],
        '',
      ),
      keterangan: _stringValue(
        json['alasan'] ?? json['keterangan'] ?? json['reason'],
        '',
      ),
      employeeId: _intValue(
        json['employee_id'] ?? json['id_employee'],
      ),
      nik: _stringValue(json['nik'] ?? json['employee_nik'], ''),
      department: _stringValue(
        json['department'] ?? json['departemen'] ?? json['divisi'],
        '',
      ),
      position: _stringValue(
        json['position'] ?? json['jabatan'] ?? json['posisi'],
        '',
      ),
      replacementName: _stringValue(
        json['replacement_name'] ??
            json['pengganti'] ??
            json['replacement_employee_name'],
        '',
      ),
      days: _intValue(json['days'] ?? json['jumlah_hari'] ?? json['total_hari']),
    );
  }

  final int id;
  final String employeeName;
  final String reason;
  final String leaveFrom;
  final String leaveTo;
  final String status;
  final String comment;
  final String createdAt;
  final String title;
  final String keterangan;
  final int employeeId;
  final String nik;
  final String department;
  final String position;
  final String replacementName;
  final int days;

  static String _stringValue(dynamic value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _RingkasanCuti {
  const _RingkasanCuti({
    this.bulan = '-',
    this.total = 0,
    this.pending = 0,
    this.approved = 0,
    this.rejected = 0,
  });

  factory _RingkasanCuti.fromJson(Map<String, dynamic> json) {
    return _RingkasanCuti(
      bulan: _textValue(json['bulan'] ?? json['month'] ?? json['nama_bulan']),
      total: _intValue(
        json['total'] ?? json['total_pengajuan'] ?? json['total_cuti'],
      ),
      pending: _intValue(json['pending'] ?? json['menunggu']),
      approved: _intValue(json['approved'] ?? json['disetujui']),
      rejected: _intValue(json['rejected'] ?? json['ditolak']),
    );
  }

  final String bulan;
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  static String _textValue(dynamic value) {
    if (value == null) return '-';
    final String text = value.toString().trim();
    return text.isEmpty ? '-' : text;
  }

  static int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}
