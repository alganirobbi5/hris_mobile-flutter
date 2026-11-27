import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/section_card.dart';

class KelolaKuotaCutiScreen extends StatefulWidget {
  const KelolaKuotaCutiScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<KelolaKuotaCutiScreen> createState() => _KelolaKuotaCutiScreenState();
}

class _KelolaKuotaCutiScreenState extends State<KelolaKuotaCutiScreen> {
  final TextEditingController _hariController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _selectedIds = <int>{};

  http.Client? _ownedClient;

  http.Client get _httpClient {
    if (widget.httpClient != null) return widget.httpClient!;
    return _ownedClient ??= http.Client();
  }

  String _query = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String _mode = 'tambah';
  String? _error;
  List<_KaryawanKuota> _karyawan = const [];

  @override
  void initState() {
    super.initState();
    _fetchKaryawan();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    _hariController.dispose();
    _searchController.dispose();
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
      final http.Response response = await _httpClient
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

  Future<void> _simpanKuota() async {
    final int? tambahan = int.tryParse(_hariController.text.trim());
    if (_selectedIds.isEmpty) {
      _showMessage('Pilih minimal satu karyawan terlebih dahulu.');
      return;
    }
    if (tambahan == null || tambahan <= 0) {
      _showMessage('Masukkan jumlah hari yang valid.');
      return;
    }
    if (!mounted) return;

    setState(() => _isSaving = true);
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await _httpClient
          .post(
            ApiConfig.uri('update_kuota_cuti.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'employee_ids': _selectedIds.toList(),
              'tambahan_hari': tambahan,
              'mode': _mode,
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
      final String aksi = _mode == 'kurang' ? 'dikurangi' : 'ditambahkan';
      final String message = success
          ? (serverMessage != null && serverMessage.toString().isNotEmpty
              ? serverMessage.toString()
              : 'Kuota cuti berhasil $aksi.')
          : _apiErrorMessage(
              response,
              'Gagal mengubah kuota cuti (HTTP ${response.statusCode}).',
            );

      _showMessage(message);
      if (success) {
        _hariController.clear();
        _selectedIds.clear();
        await _fetchKaryawan();
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal terhubung ke server saat mengubah kuota cuti.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    AppToast.show(message, type: AppToast.typeFromMessage(message));
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

  List<_KaryawanKuota> get _filteredKaryawan {
    final String keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return _karyawan;
    return _karyawan
        .where(
          (_KaryawanKuota item) =>
              item.nama.toLowerCase().contains(keyword) ||
              item.username.toLowerCase().contains(keyword),
        )
        .toList();
  }

  bool get _semuaTerpilih {
    final List<_KaryawanKuota> tampil = _filteredKaryawan;
    return tampil.isNotEmpty &&
        tampil.every((_KaryawanKuota item) => _selectedIds.contains(item.id));
  }

  void _toggleSelectAll() {
    setState(() {
      final List<_KaryawanKuota> tampil = _filteredKaryawan;
      if (_semuaTerpilih) {
        _selectedIds.removeWhere(
          (int id) => tampil.any((_KaryawanKuota item) => item.id == id),
        );
      } else {
        _selectedIds.addAll(tampil.map((_KaryawanKuota item) => item.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Kelola Kuota Cuti')),
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
                    TextField(
                      controller: _hariController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Jumlah Hari',
                        hintText: '0',
                        prefixIcon: Icon(Icons.calendar_month_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() => _mode = 'tambah');
                                    _simpanKuota();
                                  },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving
                                ? null
                                : () {
                                    setState(() => _mode = 'kurang');
                                    _simpanKuota();
                                  },
                            icon: const Icon(Icons.remove_rounded, size: 18),
                            label: const Text('Kurangi'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (String value) =>
                                setState(() => _query = value),
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: 'Cari nama atau username karyawan...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Bersihkan pencarian',
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _query = '');
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _toggleSelectAll,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 48),
                          ),
                          child: Text(
                            _semuaTerpilih ? 'Deselect All' : 'Select All',
                          ),
                        ),
                      ],
                    ),
                    if (_isSaving)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
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

    final List<_KaryawanKuota> tampil = _filteredKaryawan;
    if (tampil.isEmpty) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Tidak ada karyawan yang cocok',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: tampil.length,
      itemBuilder: (BuildContext context, int index) {
        final _KaryawanKuota item = tampil[index];
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
    this.username = '',
  });

  final int id;
  final String nama;
  final String sisaKuota;
  final String username;

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
        json['remaining_leave'] ??
        json['remaining_days'] ??
        json['sisa_cuti'] ??
        json['sisa_kuota_cuti'] ??
        0;
    final String sisaTeks = sisa.toString().trim();

    return _KaryawanKuota(
      id: id,
      nama: nama.isEmpty ? 'Karyawan #$id' : nama,
      sisaKuota: sisaTeks.isEmpty ? '0' : sisaTeks,
      username: (json['username'] ?? json['user_name'] ?? '').toString().trim(),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString().trim() ?? '');
  }
}
