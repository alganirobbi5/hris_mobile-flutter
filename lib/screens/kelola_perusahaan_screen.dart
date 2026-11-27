import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/super_admin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_text_field.dart';
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
  final Set<int> _deletingIds = <int>{};

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
        logo: hasil.logo,
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

  Future<void> _edit(PerusahaanItem item) async {
    final _PerusahaanResult? hasil = await showDialog<_PerusahaanResult>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _PerusahaanDialog(item: item),
    );
    if (hasil == null || !mounted) return;
    try {
      await SuperAdminService.editPerusahaan(
        id: item.id,
        code: hasil.code,
        name: hasil.name,
        logo: hasil.logo,
        client: _httpClient,
      );
      if (!mounted) return;
      AppToast.success('Perusahaan berhasil diperbarui');
      await _fetch();
    } on SuperAdminException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Gagal terhubung ke server');
    }
  }

  Future<void> _hapus(PerusahaanItem item) async {
    final bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus perusahaan?'),
        content: Text('${item.code} • ${item.name} akan dihapus.'),
        actions: <Widget>[
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
    if (konfirmasi != true || !mounted) return;
    setState(() => _deletingIds.add(item.id));
    try {
      await SuperAdminService.hapusPerusahaan(
        id: item.id,
        client: _httpClient,
      );
      if (!mounted) return;
      AppToast.success('Perusahaan berhasil dihapus');
      await _fetch();
    } on SuperAdminException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(item.id));
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
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            StatusBadge(
                              label: item.statusLabel,
                              color: item.statusAktif
                                  ? AppColors.success
                                  : AppColors.danger,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Edit perusahaan',
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: AppColors.primary,
                              ),
                              onPressed: () => _edit(item),
                            ),
                            IconButton(
                              tooltip: 'Hapus perusahaan',
                              icon: _deletingIds.contains(item.id)
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.danger,
                                    ),
                              onPressed: _deletingIds.contains(item.id)
                                  ? null
                                  : () => _hapus(item),
                            ),
                          ],
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
  const _PerusahaanResult(this.code, this.name, this.logo);

  final String code;
  final String name;
  final String logo;
}

class _PerusahaanDialog extends StatefulWidget {
  const _PerusahaanDialog({this.item});

  final PerusahaanItem? item;

  @override
  State<_PerusahaanDialog> createState() => _PerusahaanDialogState();
}

class _PerusahaanDialogState extends State<_PerusahaanDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController =
      TextEditingController(text: widget.item?.code ?? '');
  late final TextEditingController _nameController =
      TextEditingController(text: widget.item?.name ?? '');
  String _logo = '';

  @override
  void initState() {
    super.initState();
    _logo = widget.item?.logo ?? '';
  }

  Future<void> _pilihLogo() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;
    final List<int> bytes = await file.readAsBytes();
    final String mime = file.mimeType ?? 'image/png';
    setState(() {
      _logo = 'data:$mime;base64,${base64Encode(bytes)}';
    });
  }

  Widget _logoPreview() {
    final int comma = _logo.indexOf(',');
    if (!_logo.startsWith('data:image/') || comma < 0) {
      return const Icon(Icons.broken_image_outlined);
    }
    try {
      return Image.memory(
        base64Decode(_logo.substring(comma + 1)),
        height: 80,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
      );
    } catch (_) {
      return const Icon(Icons.broken_image_outlined);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _wajib(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label wajib diisi' : null;

  String? _validasiKode(String? value) {
    final String? wajib = _wajib(value, 'Kode perusahaan');
    if (wajib != null) return wajib;
    final String kode = value!.trim();
    if (kode.length != 8 ||
        !RegExp(r'^[A-Z]{3}-\d{4}$').hasMatch(kode)) {
      return 'Kode harus 8 karakter dengan format CMJ-2026 (3 huruf, "-", 4 angka)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item == null ? 'Tambah Perusahaan' : 'Edit Perusahaan'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const FormSectionHeader(
                title: 'Identitas Perusahaan',
                icon: Icons.business_outlined,
              ),
              AppTextField(
                label: 'Kode Perusahaan',
                hint: 'CMJ-2026',
                controller: _codeController,
                prefixIcon: Icons.qr_code_2_outlined,
                validator: _validasiKode,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Nama Perusahaan',
                hint: 'Masukkan nama perusahaan',
                controller: _nameController,
                prefixIcon: Icons.business_outlined,
                validator: (String? value) => _wajib(value, 'Nama perusahaan'),
              ),
              const SizedBox(height: 16),
              const FormSectionHeader(
                title: 'Logo Perusahaan',
                icon: Icons.image_outlined,
              ),
              InkWell(
                onTap: _pilihLogo,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 90,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.field,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: _logo.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _logoPreview(),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Pilih logo perusahaan',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                ),
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
                _logo,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
