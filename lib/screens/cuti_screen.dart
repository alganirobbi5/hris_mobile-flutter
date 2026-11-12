import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key});

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen> {
  static const String _cutiUrl =
      'http://127.0.0.1/HumanResourceManagementSystem/src/api/cuti.php';
  static const String _riwayatUrl =
      'http://127.0.0.1/HumanResourceManagementSystem/src/api/'
      'riwayat_cuti.php?employee_id=2';

  static const List<String> _replacementOptions = [
    'Siti Aminah',
    'Andi Wijaya',
    'Rina Kartika',
    'Dewi Lestari',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _daysController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _replacement;
  bool _isSubmitting = false;
  int _formResetToken = 0;
  bool _isLoadingRiwayat = true;
  String? _riwayatError;
  List<_RiwayatCuti> _riwayat = const [];

  @override
  void initState() {
    super.initState();
    _fetchRiwayatCuti();
  }

  @override
  void dispose() {
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

    final String reason = _reasonController.text.trim();
    final DateTime? startDate = _startDate;
    final DateTime? endDate = _endDate;

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

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(_cutiUrl),
              headers: const {'Content-Type': 'application/json'},
              body: jsonEncode(<String, dynamic>{
                'employee_id': 2,
                'start_date': _formatApiDate(startDate),
                'end_date': _formatApiDate(endDate),
                'reason': reason,
              }),
            )
            .timeout(const Duration(seconds: 20));
      } catch (_) {
        if (!mounted) return;
        _showMessage('Gagal terhubung ke server');
        return;
      }

      if (!mounted) return;

      if (response.statusCode == 201) {
        _clearForm();
        _showMessage('Pengajuan cuti berhasil dikirim');
        _fetchRiwayatCuti();
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
    _reasonController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _daysController.clear();

    setState(() {
      _startDate = null;
      _endDate = null;
      _replacement = null;
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _fetchRiwayatCuti() async {
    setState(() {
      _isLoadingRiwayat = true;
      _riwayatError = null;
    });

    try {
      final http.Response response = await http
          .get(Uri.parse(_riwayatUrl))
          .timeout(const Duration(seconds: 20));

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

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
                          StatusBadge(label: statusLabel, color: statusColor),
                        ],
                      ),
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuti')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Form(
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
                const _StatusSummary(),
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
                      DropdownButtonFormField<String>(
                        key: ValueKey<int>(_formResetToken),
                        initialValue: _replacement,
                        isExpanded: true,
                        hint: const Text(
                          'Pilih pengganti',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                        ),
                        items: _replacementOptions
                            .map(
                              (String name) => DropdownMenuItem<String>(
                                value: name,
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (String? value) {
                          setState(() => _replacement = value);
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih karyawan pengganti';
                          }
                          return null;
                        },
                      ),
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
                      )
                    else
                      IconButton(
                        onPressed: _fetchRiwayatCuti,
                        tooltip: 'Muat ulang riwayat',
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: AppColors.textSecondary,
                        ),
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
          ),
        ),
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary();

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
            children: const [
              Expanded(
                child: _StatusCount(
                  label: 'Menunggu',
                  count: 1,
                  color: AppColors.warning,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatusCount(
                  label: 'Disetujui',
                  count: 2,
                  color: AppColors.success,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: _StatusCount(
                  label: 'Ditolak',
                  count: 0,
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
    required this.type,
    required this.leavFrom,
    required this.leavTo,
    required this.status,
  });

  factory _RiwayatCuti.fromJson(Map<String, dynamic> json) {
    return _RiwayatCuti(
      type: _stringValue(json['type'], '-'),
      leavFrom: _stringValue(
        json['leav_from'] ?? json['leave_from'] ?? json['start_date'],
        '-',
      ),
      leavTo: _stringValue(
        json['leav_to'] ?? json['leave_to'] ?? json['end_date'],
        '-',
      ),
      status: _stringValue(json['staus'] ?? json['status'], '-'),
    );
  }

  final String type;
  final String leavFrom;
  final String leavTo;
  final String status;

  static String _stringValue(dynamic value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}
