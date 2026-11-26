import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/super_admin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/status_badge.dart';
import '../widgets/app_refresh_indicator.dart';

class KelolaPerusahaanScreen extends StatefulWidget {
  const KelolaPerusahaanScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<KelolaPerusahaanScreen> createState() => _KelolaPerusahaanScreenState();
}

class _KelolaPerusahaanScreenState extends State<KelolaPerusahaanScreen> {
  http.Client? _ownedClient;

  http.Client get _httpClient {
    if (widget.httpClient != null) return widget.httpClient!;
    return _ownedClient ??= http.Client();
  }

  bool _isLoading = true;
  String? _error;
  List<PerusahaanItem> _items = const <PerusahaanItem>[];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    super.dispose();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<PerusahaanItem> items =
          await SuperAdminService.fetchPerusahaan(client: widget.httpClient);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat daftar perusahaan';
        _isLoading = false;
      });
    }
  }

  Future<void> _tambah() async {
    final _PerusahaanResult? hasil = await showDialog<_PerusahaanResult>(
      context: context,
      builder: (BuildContext dialogContext) => const _PerusahaanDialog(),
    );
    if (hasil == null || !mounted) return;
    try {
      await SuperAdminService.tambahPerusahaan(
        code: hasil.code,
        name: hasil.name,
        address: hasil.address,
        client: _httpClient,
      );
      if (!mounted) return;
      AppToast.success('Perusahaan berhasil ditambahkan');
      await _fetch();
    } on SuperAdminException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Gagal terhubung ke server');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Kelola Perusahaan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Perusahaan'),
      ),
      body: SafeArea(
        top: false,
        child: AppRefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: <Widget>[
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada perusahaan terdaftar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ..._items.map(
                  (PerusahaanItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        title: Text(
                          '${item.code} • ${item.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: item.address.isEmpty
                            ? null
                            : Text(item.address),
                        trailing: StatusBadge(
                          label: item.statusLabel,
                          color: item.statusAktif
                              ? AppColors.success
                              : AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerusahaanResult {
  const _PerusahaanResult(this.code, this.name, this.address);

  final String code;
  final String name;
  final String address;
}

class _PerusahaanDialog extends StatefulWidget {
  const _PerusahaanDialog();

  @override
  State<_PerusahaanDialog> createState() => _PerusahaanDialogState();
}

class _PerusahaanDialogState extends State<_PerusahaanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _wajib(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Perusahaan'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Kode Perusahaan',
                ),
                validator: (String? value) => _wajib(value, 'Kode perusahaan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Perusahaan',
                ),
                validator: (String? value) => _wajib(value, 'Nama perusahaan'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Alamat'),
                validator: (String? value) => _wajib(value, 'Alamat'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _PerusahaanResult(
                _codeController.text.trim(),
                _nameController.text.trim(),
                _addressController.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
