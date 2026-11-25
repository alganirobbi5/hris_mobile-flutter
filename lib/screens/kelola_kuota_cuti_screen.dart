import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class KelolaKuotaCutiScreen extends StatefulWidget {
  const KelolaKuotaCutiScreen({super.key});

  @override
  State<KelolaKuotaCutiScreen> createState() => _KelolaKuotaCutiScreenState();
}

class _KelolaKuotaCutiScreenState extends State<KelolaKuotaCutiScreen> {
  final TextEditingController _hariController = TextEditingController();
  final Set<int> _selectedIds = <int>{};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  List<_KaryawanKuota> _karyawan = const [];

  @override
  void initState() {
    super.initState();
    _fetchKaryawan();
  }

  @override
  void dispose() {
    _hariController.dispose();
    super.dispose();
  }

  Future<void> _fetchKaryawan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .get(
            ApiConfig.uri('get_employees_kuota.php'),
            headers: ApiConfig.authHeaders(token),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _error = _apiErrorMessage(
            response,
            'Gagal memuat data karyawan (HTTP ${response.statusCode}).',
          );
          _isLoading = false;
        });
        return;
      }

      Map<String, dynamic>? envelope;
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) envelope = decoded;
      } on FormatException {
        envelope = null;
      }
      if (envelope == null) {
        setState(() {
          _error = 'Format data karyawan tidak valid.';
          _isLoading = false;
        });
        return;
      }

      final String status =
          envelope['status']?.toString().trim().toLowerCase() ?? '';
      if (status.isNotEmpty && status != 'success' && envelope['success'] != true) {
        final Object? serverMessage = envelope['message'];
        setState(() {
          _error = serverMessage != null && serverMessage.toString().isNotEmpty
              ? serverMessage.toString()
              : 'Gagal memuat data karyawan.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _karyawan = _parseKaryawan(response.body);
        _selectedIds.removeWhere(
          (int id) => !_karyawan.any((_KaryawanKuota item) => item.id == id),
        );
        _isLoading = false;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Format data karyawan tidak valid.';
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

  List<_KaryawanKuota> _parseKaryawan(String body) {
    if (body.trim().isEmpty) return const [];

    final dynamic decoded = jsonDecode(body);
    dynamic raw = decoded;
    if (decoded is Map<String, dynamic>) {
      raw = decoded['data'] ?? decoded['employees'] ?? decoded['result'];
    }
    if (raw is! List) return const [];

    return raw
        .whereType<Map<String, dynamic>>()
        .map(_KaryawanKuota.fromJson)
        .where((_KaryawanKuota item) => item.id > 0)
        .toList();
  }

  Future<void> _tambahkanKuota() async {
    final int? tambahan = int.tryParse(_hariController.text.trim());
    if (_selectedIds.isEmpty) {
      _showMessage('Pilih minimal satu karyawan terlebih dahulu.');
      return;
    }
    if (tambahan == null || tambahan <= 0) {
      _showMessage('Masukkan jumlah hari tambahan yang valid.');
      return;
    }
    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .post(
            ApiConfig.uri('update_kuota_cuti.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'employee_ids': _selectedIds.toList(),
              'tambahan_hari': tambahan,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      Map<String, dynamic>? decoded;
      try {
        final Object? body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } on FormatException {
        decoded = null;
      }

      final bool success = response.statusCode == 200 &&
          (decoded?['status'] == 'success' || decoded?['success'] == true);
      final Object? serverMessage = decoded?['message'];
      final String message = success
          ? (serverMessage != null && serverMessage.toString().isNotEmpty
              ? serverMessage.toString()
              : 'Kuota cuti berhasil ditambahkan.')
          : _apiErrorMessage(
              response,
              'Gagal menambahkan kuota cuti (HTTP ${response.statusCode}).',
            );

      _showMessage(message);
      if (success) {
        _hariController.clear();
        _selectedIds.clear();
        await _fetchKaryawan();
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal terhubung ke server saat menambahkan kuota cuti.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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

  bool get _semuaTerpilih =>
      _karyawan.isNotEmpty && _selectedIds.length == _karyawan.length;

  void _toggleSelectAll() {
    setState(() {
      if (_semuaTerpilih) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_karyawan.map((_KaryawanKuota item) => item.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kuota Cuti')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _toggleSelectAll,
                      icon: Icon(
                        _semuaTerpilih
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _semuaTerpilih ? 'Deselect All' : 'Select All',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _hariController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Hari Tambahan',
                        hintText: '0',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _tambahkanKuota,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 18),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : 'Tambahkan Kuota',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: _buildList()),
            ],
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
          mainAxisSize: MainAxisSize.min,
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
              onPressed: _fetchKaryawan,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_karyawan.isEmpty) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Belum ada data karyawan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _karyawan.length,
      itemBuilder: (BuildContext context, int index) {
        final _KaryawanKuota item = _karyawan[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: CheckboxListTile(
            value: _selectedIds.contains(item.id),
            onChanged: (bool? checked) {
              setState(() {
                if (checked == true) {
                  _selectedIds.add(item.id);
                } else {
                  _selectedIds.remove(item.id);
                }
              });
            },
            title: Text(
              item.nama,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Sisa Kuota: ${item.sisaKuota} hari',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
          ),
        );
      },
    );
  }
}

class _KaryawanKuota {
  const _KaryawanKuota({
    required this.id,
    required this.nama,
    required this.sisaKuota,
  });

  final int id;
  final String nama;
  final String sisaKuota;

  factory _KaryawanKuota.fromJson(Map<String, dynamic> json) {
    final int id = _asInt(
          json['employee_id'] ?? json['id'] ?? json['employeeId'],
        ) ??
        0;
    final String firstName = (json['first_name'] ?? '').toString().trim();
    final String lastName = (json['last_name'] ?? '').toString().trim();
    final String namaLengkap = '$firstName $lastName'.trim();
    final String nama = (json['nama_lengkap'] ??
            json['nama'] ??
            json['name'] ??
            namaLengkap)
        .toString()
        .trim();
    final dynamic sisa = json['sisa_kuota'] ??
        json['remaining_leav'] ??
        json['sisa_cuti'] ??
        json['sisa_kuota_cuti'] ??
        0;
    final String sisaTeks = sisa.toString().trim();

    return _KaryawanKuota(
      id: id,
      nama: nama.isEmpty ? 'Karyawan #$id' : nama,
      sisaKuota: sisaTeks.isEmpty ? '0' : sisaTeks,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
