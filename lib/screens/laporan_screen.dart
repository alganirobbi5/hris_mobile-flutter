import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  static const String _laporanUrl =
      'http://192.168.1.2/HumanResourceManagementSystem/src/api/'
      'laporan_absensi.php';

  static const List<String> _shortMonthNames = [
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

  bool _isLoading = true;
  String? _error;
  List<_LaporanAbsensi> _laporan = const [];

  @override
  void initState() {
    super.initState();
    _fetchLaporan();
  }

  Future<void> _fetchLaporan() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final http.Response response = await http
          .get(Uri.parse(_laporanUrl))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _laporan = _parseLaporan(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _apiErrorMessage(response);
          _isLoading = false;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Format data laporan tidak valid.';
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

  List<_LaporanAbsensi> _parseLaporan(String body) {
    if (body.trim().isEmpty) return const [];

    final dynamic decoded = jsonDecode(body);
    dynamic rawData = decoded;

    if (decoded is Map<String, dynamic>) {
      rawData = decoded['data'] ??
          decoded['laporan'] ??
          decoded['result'] ??
          decoded['laporan_absensi'];
    }

    if (rawData is! List) return const [];

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(_LaporanAbsensi.fromJson)
        .toList();
  }

  String _apiErrorMessage(http.Response response) {
    final String fallback =
        'Gagal memuat laporan absensi (HTTP ${response.statusCode}).';
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

  String _formatDate(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    final DateTime? parsed = DateTime.tryParse(trimmed);
    if (parsed == null) return trimmed;

    return '${parsed.day} ${_shortMonthNames[parsed.month - 1]} ${parsed.year}';
  }

  String _statusLabel(String status) {
    final String normalized = status.trim().toLowerCase();

    if (normalized == '1' ||
        normalized == 'hadir' ||
        normalized == 'present') {
      return 'Hadir';
    }
    if (normalized == '0' ||
        normalized == 'tidak hadir' ||
        normalized == 'absent') {
      return 'Tidak Hadir';
    }

    return status.trim().isEmpty ? '-' : status.trim();
  }

  Color _statusColor(String status) {
    switch (_statusLabel(status)) {
      case 'Hadir':
        return AppColors.success;
      case 'Tidak Hadir':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Laporan Absensi',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            _HrBadge(),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Data absensi karyawan terbaru dari server',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _isLoading ? null : _fetchLaporan,
                    tooltip: 'Muat ulang laporan',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.09),
                      foregroundColor: AppColors.primary,
                    ),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
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
                      '${_laporan.length} data',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _buildLaporan(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaporan() {
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
              onPressed: _fetchLaporan,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_laporan.isEmpty) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Belum ada data absensi',
              textAlign: TextAlign.center,
              style: TextStyle(
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
      itemCount: _laporan.length,
      itemBuilder: (BuildContext context, int index) {
        final _LaporanAbsensi item = _laporan[index];
        final String statusLabel = _statusLabel(item.status);
        final Color statusColor = _statusColor(item.status);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
                            item.employeeName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 13,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  _formatDate(item.date),
                                  style: const TextStyle(
                                    fontSize: 12,
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
                    StatusBadge(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TimeInfo(
                          icon: Icons.login_rounded,
                          label: 'Jam Masuk',
                          value: item.clockIn,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 30,
                        color: AppColors.border,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TimeInfo(
                          icon: Icons.logout_rounded,
                          label: 'Jam Keluar',
                          value: item.clockOut,
                        ),
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
}

class _HrBadge extends StatelessWidget {
  const _HrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'HR',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _TimeInfo extends StatelessWidget {
  const _TimeInfo({
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
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LaporanAbsensi {
  const _LaporanAbsensi({
    required this.date,
    required this.clockIn,
    required this.clockOut,
    required this.firstName,
    required this.lastName,
    required this.status,
  });

  factory _LaporanAbsensi.fromJson(Map<String, dynamic> json) {
    return _LaporanAbsensi(
      date: _stringValue(json['date'], '-'),
      clockIn: _stringValue(json['clock_in'], '-'),
      clockOut: _stringValue(json['clock_out'], '-'),
      firstName: _stringValue(json['first_name'], ''),
      lastName: _stringValue(json['last_name'], ''),
      status: _stringValue(json['status'], '-'),
    );
  }

  final String date;
  final String clockIn;
  final String clockOut;
  final String firstName;
  final String lastName;
  final String status;

  String get employeeName {
    final String fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? 'Belum tersedia' : fullName;
  }

  static String _stringValue(dynamic value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}
