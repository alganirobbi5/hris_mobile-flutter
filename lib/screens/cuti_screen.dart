import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/cuti_refresh.dart';
import '../services/employee_request.dart';
import '../services/leave_balance.dart';
import '../services/leave_leader_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/app_refresh_indicator.dart';

class CutiScreen extends StatefulWidget {
  const CutiScreen({
    super.key,
    this.embedded = false,
    this.onlyHistory = false,
  });

  /// Saat true, widget dirender tanpa Scaffold untuk disisipkan di halaman lain.
  final bool embedded;

  /// Saat true, hanya menampilkan riwayat (dipakai tab Riwayat Cuti).
  final bool onlyHistory;

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen>
    with WidgetsBindingObserver {
  static String get _cutiUrl => EmployeeRequest.leaveCreate().toString();
  static String get _cutiFallbackUrl =>
      ApiConfig.uri('leave-requests.php').toString();
  static Future<String> _riwayatUrl() async {
    final int? employeeId = await AppSession.currentEmployeeId();
    final String? role = await AppSession.resolveRole();
    return EmployeeRequest.leaveHistory(employeeId, role: role).toString();
  }

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  int? _replacementId;
  List<_EmployeeOption> _employees = const [];
  List<LeaveLeader> _leaders = const <LeaveLeader>[];
  int? _selectedLeaderId;
  bool _isLoadingLeaders = true;
  bool _isLoadingEmployees = true;
  bool _isSubmitting = false;
  int _formResetToken = 0;
  bool _isLoadingRiwayat = true;
  String? _riwayatError;
  List<_RiwayatCuti> _riwayat = const [];
  bool _isHr = false;
  final Set<int> _deletingIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CutiRefresh.revision.addListener(_onCutiChanged);
    _loadRole();
    if (!widget.onlyHistory) _fetchLeaders();
  }

  Future<void> _fetchLeaders() async {
    if (!mounted) return;
    setState(() => _isLoadingLeaders = true);
    try {
      final int? currentUserId = await AppSession.resolveUserId();
      final LeaveLeadersResult result =
          await LeaveLeaderService.fetch(includeEligible: false);
      if (!mounted) return;
      setState(() {
        _leaders = LeaveLeaderService.tanpaDiriSendiri(
          result.leaders,
          currentUserId,
        );
        _isLoadingLeaders = false;
      });
    } on LeaveLeaderException catch (e) {
      if (!mounted) return;
      setState(() {
        _leaders = const <LeaveLeader>[];
        _isLoadingLeaders = false;
      });
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _leaders = const <LeaveLeader>[];
        _isLoadingLeaders = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onCutiChanged();
  }

  void _onCutiChanged() {
    if (!mounted) return;
    _fetchRiwayatCuti();

    final LeaveUpdate? update = CutiRefresh.lastUpdate.value;
    if (update == null || _isHr) return;
    final String statusText = update.status == 2 ? 'Disetujui' : 'Ditolak';
    AppNotificationService.showLeaveStatus(
      title: 'Pengajuan Cuti $statusText',
      body: 'Pengajuan "${update.title}" telah $statusText oleh HR.',
    );
    CutiRefresh.lastUpdate.value = null;
  }

  Future<void> _loadRole() async {
    final String? role = await AppSession.resolveRole();
    if (!mounted) return;
    setState(() => _isHr = AppSession.isHrRole(role));
    await Future.wait<void>(<Future<void>>[
      _fetchRiwayatCuti(),
      _fetchEmployees(),
    ]);
  }

  Future<void> _fetchEmployees() async {
    LeaveEmployeeError.message = null;
    setState(() => _isLoadingEmployees = true);
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .get(
            ApiConfig.uri('employees.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (response.statusCode != 200) {
        LeaveEmployeeError.message =
            'Gagal memuat karyawan (HTTP ${response.statusCode})';
        setState(() => _isLoadingEmployees = false);
        return;
      }
      final dynamic decoded = jsonDecode(response.body);
      dynamic raw = decoded;
      if (decoded is Map<String, dynamic>) raw = decoded['data'];
      if (raw is! List) {
        LeaveEmployeeError.message = 'Format daftar karyawan tidak valid';
        setState(() => _isLoadingEmployees = false);
        return;
      }
      final List<_EmployeeOption> parsed = raw
          .whereType<Map<String, dynamic>>()
          .map<_EmployeeOption>(
            (Map<String, dynamic> item) => _EmployeeOption.fromJson(item),
          )
          .toList();
      setState(() {
        _employees = parsed;
        _isLoadingEmployees = false;
        if (_employees.isEmpty) {
          LeaveEmployeeError.message = 'Belum ada karyawan aktif tersedia';
        }
      });
    } catch (e) {
      LeaveEmployeeError.message = 'Gagal terhubung ke server: $e';
      if (mounted) setState(() => _isLoadingEmployees = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CutiRefresh.revision.removeListener(_onCutiChanged);
    _titleController.dispose();
    _reasonController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = (date.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  String _formatApiDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  void _updateDuration() {
    final DateTime? start = _startDate;
    final DateTime? end = _endDate;
    if (start == null || end == null) return;

    final int days = end.difference(start).inDays + 1;
    if (days > 0) {
      _daysController.text = days.toString();
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 1);
    final DateTime lastDate = DateTime(now.year + 2);

    final DateTime initialDate = isStart
        ? (_startDate ?? now)
        : (_endDate ?? _startDate ?? now);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: isStart ? firstDate : (_startDate ?? firstDate),
      lastDate: lastDate,
      helpText: isStart ? 'Pilih tanggal mulai' : 'Pilih tanggal selesai',
    );

    if (picked == null) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        _startDateController.text = _formatDate(picked);
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
          _endDateController.clear();
        }
      } else {
        _endDate = picked;
        _endDateController.text = _formatDate(picked);
      }
      _updateDuration();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_isSubmitting) return;

    final String title = _titleController.text.trim();
    final String reason = _reasonController.text.trim();
    final DateTime? startDate = _startDate;
    final DateTime? endDate = _endDate;

    if (title.isEmpty) {
      _formKey.currentState?.validate();
      _showMessage('Judul cuti tidak boleh kosong');
      return;
    }

    if (reason.isEmpty) {
      _formKey.currentState?.validate();
      _showMessage('Alasan cuti tidak boleh kosong');
      return;
    }

    if (startDate == null || endDate == null) {
      _formKey.currentState?.validate();
      _showMessage('Tanggal mulai dan selesai harus dipilih');
      return;
    }

    if (endDate.isBefore(startDate)) {
      _showMessage('Tanggal selesai tidak boleh sebelum tanggal mulai');
      return;
    }

    if (_selectedLeaderId == null) {
      _showMessage('Pilih Leader pemberi persetujuan terlebih dahulu');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final int? employeeId = await AppSession.currentEmployeeId();
    if (employeeId == null) {
      final String? role = await AppSession.resolveRole();
      _showMessage(
        AppSession.isHrRole(role)
            ? 'Akun HR tidak memiliki employee_id untuk mengajukan cuti'
            : 'employee_id tidak ditemukan. Silakan login ulang.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final String? token = await AppSession.resolveToken();
      final String body = jsonEncode(
        EmployeeRequest.leaveCreatePayload(
          employeeId: employeeId,
          title: title,
          reason: reason,
          startDate: _formatApiDate(startDate),
          endDate: _formatApiDate(endDate),
          leaderUserId: _selectedLeaderId!,
          replacementEmployeeId: _replacementId,
          days: int.tryParse(_daysController.text.trim()),
          employeeName: AppSession.name?.trim(),
          nik: AppSession.username?.trim(),
        ),
      );

      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(_cutiUrl),
              headers: ApiConfig.authHeaders(token),
              body: body,
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 404 || response.statusCode == 405) {
          response = await http
              .post(
                Uri.parse(_cutiFallbackUrl),
                headers: ApiConfig.authHeaders(token),
                body: jsonEncode(<String, dynamic>{
                  'action': 'create',
                  'employee_id': employeeId,
                  'title': title,
                  'reason': reason.isEmpty ? title : '$title - $reason',
                  'start_date': _formatApiDate(startDate),
                  'end_date': _formatApiDate(endDate),
                  'replacement_employee_id': _replacementId,
                  'leader_user_id': _selectedLeaderId,
                  'days': int.tryParse(_daysController.text.trim()),
                }),
              )
              .timeout(const Duration(seconds: 30));
        }
      } catch (_) {
        if (!mounted) return;
        _showMessage('Gagal terhubung ke server');
        return;
      }

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        _clearForm();
        _showMessage('Pengajuan cuti berhasil dikirim');
        await Future.wait<void>(<Future<void>>[
          _fetchRiwayatCuti(),
          _fetchEmployees(),
        ]);
        CutiRefresh.notify();
      } else {
        _showMessage(_apiErrorMessage(response));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _clearForm() {
    _titleController.clear();
    _reasonController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _daysController.clear();

    setState(() {
      _startDate = null;
      _endDate = null;
      _replacementId = null;
      _selectedLeaderId = null;
      _formResetToken++;
    });
  }

  String _apiErrorMessage(http.Response response, {String? fallbackMessage}) {
    final String fallback =
        fallbackMessage ??
        'Gagal mengirim pengajuan cuti (HTTP ${response.statusCode}).';
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
    AppToast.show(message, type: AppToast.typeFromMessage(message));
  }

  Future<void> _fetchRiwayatCuti() async {
    setState(() {
      _isLoadingRiwayat = true;
      _riwayatError = null;
    });

    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .get(Uri.parse(await _riwayatUrl()),
              headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _riwayat = _parseRiwayatCuti(response.body);
          _isLoadingRiwayat = false;
        });
      } else {
        setState(() {
          _riwayatError = _apiErrorMessage(
            response,
            fallbackMessage:
                'Gagal memuat riwayat cuti (HTTP ${response.statusCode}).',
          );
          _isLoadingRiwayat = false;
        });
      }
    } on EmployeeIdMissingException {
      if (!mounted) return;
      setState(() {
        _riwayatError =
            'employee_id tidak ditemukan. Silakan login ulang.';
        _isLoadingRiwayat = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _riwayatError = 'Format data riwayat cuti tidak valid.';
        _isLoadingRiwayat = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _riwayatError = 'Gagal terhubung ke server';
        _isLoadingRiwayat = false;
      });
    }
  }

  Future<void> _hapusCuti(_RiwayatCuti item) async {
    if (item.id <= 0 || _deletingIds.contains(item.id)) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Hapus riwayat cuti'),
        content: Text(
          'Yakin ingin menghapus riwayat cuti${item.employeeName.isEmpty ? '' : ' ${item.employeeName}'} ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
            ApiConfig.uri('hapus_cuti.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, int>{'id': item.id}),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (response.statusCode == 200) {
        _showMessage('Riwayat cuti berhasil dihapus');
        await _fetchRiwayatCuti();
      } else {
        _showMessage(_apiErrorMessage(
          response,
          fallbackMessage: 'Gagal menghapus riwayat cuti.',
        ));
      }
    } catch (_) {
      if (mounted) _showMessage('Gagal terhubung ke server');
    } finally {
      if (mounted) {
        setState(() => _deletingIds.remove(item.id));
      }
    }
  }

  List<_RiwayatCuti> _parseRiwayatCuti(String body) {
    if (body.trim().isEmpty) return const [];

    final dynamic decoded = jsonDecode(body);
    dynamic rawData = decoded;

    if (decoded is Map<String, dynamic>) {
      rawData =
          decoded['data'] ??
          decoded['riwayat'] ??
          decoded['result'] ??
          decoded['riwayat_cuti'];
    }

    if (rawData is! List) return const [];

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(_RiwayatCuti.fromJson)
        .toList();
  }

  String _formatRiwayatDate(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    final DateTime? parsed = _parseDateValue(trimmed);
    if (parsed == null) return trimmed;

    return DateFormat('d MMMM yyyy', 'id_ID').format(parsed);
  }

  DateTime? _parseDateValue(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    final int? timestamp = int.tryParse(value);
    if (timestamp == null) return null;

    final bool inSeconds = timestamp.abs() < 100000000000;
    return DateTime.fromMillisecondsSinceEpoch(
      inSeconds ? timestamp * 1000 : timestamp,
    );
  }

  String _statusLabel(String status) {
    final String normalized = status.trim().toLowerCase();

    if (normalized.isEmpty ||
        normalized == '-' ||
        normalized == 'menunggu' ||
        normalized == 'pending') {
      return 'Menunggu';
    }
    if (normalized == 'disetujui' ||
        normalized == 'approved' ||
        normalized == 'approve') {
      return 'Disetujui';
    }
    if (normalized == 'ditolak' ||
        normalized == 'rejected' ||
        normalized == 'reject') {
      return 'Ditolak';
    }

    switch (normalized) {
      case '1':
        return 'Menunggu';
      case '2':
        return 'Disetujui';
      case '3':
        return 'Ditolak';
    }

    return status;
  }

  Color _statusColor(String status) {
    switch (_statusLabel(status)) {
      case 'Disetujui':
        return AppColors.success;
      case 'Ditolak':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  Map<String, int> _ringkasanStatusBulanIni() {
    final DateTime now = DateTime.now();
    int menunggu = 0;
    int disetujui = 0;
    int ditolak = 0;

    for (final _RiwayatCuti item in _riwayat) {
      final DateTime? dibuat = DateTime.tryParse(item.createdAt.trim());
      if (dibuat == null ||
          dibuat.year != now.year ||
          dibuat.month != now.month) {
        continue;
      }
      switch (_statusLabel(item.status)) {
        case 'Menunggu':
          menunggu++;
          break;
        case 'Disetujui':
          disetujui++;
          break;
        case 'Ditolak':
          ditolak++;
          break;
      }
    }

    return <String, int>{
      'menunggu': menunggu,
      'disetujui': disetujui,
      'ditolak': ditolak,
    };
  }

  Future<void> _tampilkanDetailCuti(_RiwayatCuti item) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(item.type),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isHr && item.employeeName.isNotEmpty)
                _detailRow('Karyawan', item.employeeName),
              _detailRow('Status', _statusLabel(item.status)),
              _detailRow('Tanggal', '${item.leavFrom} s.d. ${item.leavTo}'),
              if (item.alasan != null && item.alasan!.isNotEmpty)
                _detailRow('Alasan', item.alasan!),
              if (item.komentar != null && item.komentar!.isNotEmpty)
                _detailRow('Komentar HR', item.komentar!),
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildRiwayatCuti() {
    if (_isLoadingRiwayat) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_riwayatError != null) {
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
              _riwayatError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchRiwayatCuti,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_riwayat.isEmpty) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: Text(
              'Belum ada riwayat cuti',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _riwayat.length,
      itemBuilder: (BuildContext context, int index) {
        final _RiwayatCuti item = _riwayat[index];
        final String statusLabel = _statusLabel(item.status);
        final Color statusColor = _statusColor(item.status);
        final bool isDeleting = _deletingIds.contains(item.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => _tampilkanDetailCuti(item),
            borderRadius: BorderRadius.circular(20),
            child: SectionCard(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                      Icons.event_note_outlined,
                      size: 21,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                item.type,
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
                            Flexible(
                              child: StatusBadge(
                                label: statusLabel,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                        if (_isHr && item.employeeName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  item.employeeName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.date_range_rounded,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '${_formatRiwayatDate(item.leavFrom)} - '
                                '${_formatRiwayatDate(item.leavTo)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (item.alasan != null && item.alasan!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.alasan!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (item.komentar != null &&
                            item.komentar!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Komentar HR: ${item.komentar}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                        if (item.targetLeaderName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tujuan Persetujuan: ${item.targetLeaderName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (statusLabel == 'Disetujui' &&
                            item.approvedByName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Disetujui oleh ${item.approvedByName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                        if (statusLabel == 'Ditolak' &&
                            item.approvedByName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ditolak oleh ${item.approvedByName}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                          if (item.catatanLeader.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Catatan: ${item.catatanLeader}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                        if (_isHr && item.id > 0) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: isDeleting
                                  ? null
                                  : () => _hapusCuti(item),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              icon: isDeleting
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 17,
                                    ),
                              label: Text(
                                isDeleting ? 'Menghapus...' : 'Hapus',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> ringkasan = _ringkasanStatusBulanIni();
    final Widget formSection = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengajuan Cuti',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ajukan cuti dan pantau status persetujuannya.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _StatusSummary(
                  menunggu: ringkasan['menunggu'] ?? 0,
                  disetujui: ringkasan['disetujui'] ?? 0,
                  ditolak: ringkasan['ditolak'] ?? 0,
                ),
                const SizedBox(height: 16),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detail pengajuan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Judul Cuti',
                        hint: 'Contoh: Cuti Tahunan / Urusan Keluarga',
                        controller: _titleController,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Judul cuti tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Alasan Cuti',
                        hint: 'Ceritakan alasan pengajuan cutimu',
                        controller: _reasonController,
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Alasan cuti tidak boleh kosong';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: 'Tanggal Mulai',
                              hint: 'dd/mm/yy',
                              controller: _startDateController,
                              readOnly: true,
                              onTap: () => _pickDate(isStart: true),
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Pilih tanggal';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              label: 'Tanggal Selesai',
                              hint: 'dd/mm/yy',
                              controller: _endDateController,
                              readOnly: true,
                              onTap: () => _pickDate(isStart: false),
                              suffixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Pilih tanggal';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<int>(
                        key: ValueKey<int>(_formResetToken),
                        initialValue: _selectedLeaderId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pilih Leader Pemberi Persetujuan',
                        ),
                        hint: _isLoadingLeaders
                            ? const Text('Memuat leader...')
                            : const Text('Pilih leader'),
                        items: _leaders
                            .map(
                              (LeaveLeader leader) => DropdownMenuItem<int>(
                                value: leader.userId,
                                child: Text(
                                  leader.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        validator: (int? value) => value == null
                            ? 'Leader wajib dipilih'
                            : null,
                        onChanged: (int? value) {
                          setState(() => _selectedLeaderId = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      AppTextField(
                        label: 'Jumlah Hari',
                        hint: 'Terisi otomatis',
                        controller: _daysController,
                        keyboardType: TextInputType.number,
                        suffixIcon: const Padding(
                          padding: EdgeInsets.only(right: 16),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              'hari',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Jumlah hari wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'PENGGANTI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        key: ValueKey<int>(_formResetToken),
                        initialValue: _replacementId,
                        isExpanded: true,
                        hint: Text(
                          _isLoadingEmployees
                              ? 'Memuat karyawan...'
                              : (_employees.isEmpty
                                  ? 'Belum ada karyawan tersedia'
                                  : 'Pilih pengganti'),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                        items: _employees
                            .map(
                              (_EmployeeOption employee) =>
                                  DropdownMenuItem<int>(
                                value: employee.id,
                                child: Text(
                                  employee.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (int? value) {
                          setState(() => _replacementId = value);
                        },
                        validator: (value) {
                          if (value == null || value <= 0) {
                            return 'Pilih karyawan pengganti';
                          }
                          return null;
                        },
                      ),
                      if (!_isLoadingEmployees && _employees.isEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                LeaveEmployeeError.message ??
                                    'Daftar karyawan belum tersedia',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _fetchEmployees,
                              icon: const Icon(Icons.refresh_rounded, size: 15),
                              label: const Text('Muat ulang'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: _isSubmitting ? 'Mengirim...' : 'Ajukan Cuti',
                        icon: Icons.send_rounded,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Riwayat Cuti',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (_isLoadingRiwayat)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Daftar pengajuan cuti terbaru',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                _buildRiwayatCuti(),
        ],
      ),
    );

    final Widget content = widget.onlyHistory
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Riwayat Cuti',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _buildRiwayatCuti(),
            ],
          )
        : formSection;

    if (widget.embedded) return content;

    return Scaffold(
      appBar: GlassAppBar(title: const Text('Cuti')),
      body: SafeArea(
        top: false,
        child: AppRefreshIndicator(
          onRefresh: _fetchRiwayatCuti,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.menunggu,
    required this.disetujui,
    required this.ditolak,
  });

  final int menunggu;
  final int disetujui;
  final int ditolak;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status pengajuan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusCount(
                  label: 'Menunggu',
                  count: menunggu,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusCount(
                  label: 'Disetujui',
                  count: disetujui,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusCount(
                  label: 'Ditolak',
                  count: ditolak,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiwayatCuti {
  const _RiwayatCuti({
    this.id = 0,
    this.employeeName = '',
    required this.type,
    required this.leavFrom,
    required this.leavTo,
    required this.status,
    this.alasan,
    this.komentar,
    this.targetLeaderName = '',
    this.approvedByName = '',
    this.catatanLeader = '',
    this.leaderUserId = 0,
    this.approvedByUserId = 0,
    this.createdAt = '',
  });

  factory _RiwayatCuti.fromJson(Map<String, dynamic> json) {
    final String firstName = _stringValue(
      json['first_name'] ?? json['firstName'],
      '',
    );
    final String lastName = _stringValue(
      json['last_name'] ?? json['lastName'],
      '',
    );
    final String fullName = '$firstName $lastName'.trim();

    return _RiwayatCuti(
      id: _intValue(json['id'] ?? json['leave_id']),
      employeeName: _stringValue(
        json['employee_name'] ?? json['name'],
        fullName,
      ),
      type: _stringValue(
        json['type'] ?? json['reason'] ?? json['keterangan'],
        '-',
      ),
      leavFrom: _stringValue(
        json['leav_from'] ?? json['leave_from'] ?? json['start_date'],
        '-',
      ),
      leavTo: _stringValue(
        json['leav_to'] ?? json['leave_to'] ?? json['end_date'],
        '-',
      ),
      status: _stringValue(json['staus'] ?? json['status'], '-'),
      alasan: _stringValue(json['reason'] ?? json['alasan'], ''),
      komentar: _stringValue(json['comment'] ?? json['komentar'], ''),
      targetLeaderName: _stringValue(json['target_leader_name'], ''),
      approvedByName: _stringValue(json['approved_by_name'], ''),
      catatanLeader: _stringValue(json['catatan_leader'], ''),
      leaderUserId: _intValue(json['leader_user_id']),
      approvedByUserId: _intValue(json['approved_by_user_id']),
      createdAt: _stringValue(
        json['created_at'] ?? json['tanggal_pengajuan'],
        '',
      ),
    );
  }

  final int id;
  final String employeeName;
  final String type;
  final String leavFrom;
  final String leavTo;
  final String status;
  final String? alasan;
  final String? komentar;
  final String targetLeaderName;
  final String approvedByName;
  final String catatanLeader;
  final int leaderUserId;
  final int approvedByUserId;
  final String createdAt;

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

class _EmployeeOption {
  const _EmployeeOption({
    required this.id,
    required this.name,
  });

  factory _EmployeeOption.fromJson(Map<String, dynamic> json) {
    return _EmployeeOption(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? '').toString().trim(),
    );
  }

  final int id;
  final String name;
}
