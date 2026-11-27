import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/super_admin_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/app_refresh_indicator.dart';

class KelolaHrAdminScreen extends StatefulWidget {
  const KelolaHrAdminScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<KelolaHrAdminScreen> createState() => _KelolaHrAdminScreenState();
}

class _KelolaHrAdminScreenState extends State<KelolaHrAdminScreen> {
  http.Client? _ownedClient;

  http.Client get _httpClient {
    if (widget.httpClient != null) return widget.httpClient!;
    return _ownedClient ??= http.Client();
  }

  bool _isLoading = true;
  String? _error;
  List<PerusahaanItem> _companies = const <PerusahaanItem>[];
  List<HrAdminItem> _items = const <HrAdminItem>[];
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
      final List<dynamic> hasil = await Future.wait<dynamic>(
        <Future<dynamic>>[
          SuperAdminService.fetchPerusahaan(client: widget.httpClient),
          SuperAdminService.fetchHrAdmin(client: _httpClient),
        ],
      );
      if (!mounted) return;
      setState(() {
        _companies = hasil[0] as List<PerusahaanItem>;
        _items = hasil[1] as List<HrAdminItem>;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data HR/Admin';
        _isLoading = false;
      });
    }
  }

  Future<void> _tambah() async {
    final _HrAdminResult? hasil = await showDialog<_HrAdminResult>(
      context: context,
      builder: (BuildContext dialogContext) =>
          _HrAdminDialog(companies: _companies),
    );
    if (hasil == null || !mounted) return;
    try {
      await SuperAdminService.tambahHrAdmin(
        companyId: hasil.companyId,
        firstName: hasil.firstName,
        lastName: hasil.lastName,
        username: hasil.username,
        email: hasil.email,
        password: hasil.password,
        client: _httpClient,
      );
      if (!mounted) return;
      AppToast.success('Akun HR/Admin berhasil ditambahkan');
      await _fetch();
    } on SuperAdminException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Gagal terhubung ke server');
    }
  }

  Future<void> _hapus(HrAdminItem item) async {
    final String nama = item.name.isEmpty ? item.username : item.name;
    final bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus akun HR/Admin?'),
        content: Text('$nama (${item.username}) akan dihapus.'),
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
      await SuperAdminService.hapusHrAdmin(
        id: item.id,
        client: _httpClient,
      );
      if (!mounted) return;
      AppToast.success('Akun HR/Admin berhasil dihapus');
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
      appBar: GlassAppBar(title: const Text('Kelola HR / Admin')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah HR / Admin'),
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
                    'Belum ada akun HR/Admin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ..._items.map(
                  (HrAdminItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        title: Text(
                          item.name.isEmpty ? item.username : item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          <String>[
                            item.username,
                            item.email,
                            item.companyName,
                          ].where((String value) => value.isNotEmpty).join(' • '),
                        ),
                        trailing: _deletingIds.contains(item.id)
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : IconButton(
                                tooltip: 'Hapus akun HR/Admin',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.danger,
                                ),
                                onPressed: () => _hapus(item),
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

class _HrAdminResult {
  const _HrAdminResult(
    this.companyId,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.password,
  );

  final int companyId;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
}

class _HrAdminDialog extends StatefulWidget {
  const _HrAdminDialog({required this.companies});

  final List<PerusahaanItem> companies;

  @override
  State<_HrAdminDialog> createState() => _HrAdminDialogState();
}

class _HrAdminDialogState extends State<_HrAdminDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  int? _companyId;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _wajib(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label wajib diisi' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah HR / Admin'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FormSectionHeader(
                title: 'Perusahaan',
                icon: Icons.business_outlined,
              ),
              AppFormDropdown<int>(
                label: 'Perusahaan',
                value: _companyId,
                hint: 'Pilih perusahaan',
                prefixIcon: Icons.business_outlined,
                items: widget.companies
                    .map(
                      (PerusahaanItem company) => DropdownMenuItem<int>(
                        value: company.id,
                        child: Text(
                          '${company.code} • ${company.name}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (int? value) =>
                    value == null ? 'Perusahaan wajib dipilih' : null,
                onChanged: (int? value) =>
                    setState(() => _companyId = value),
              ),
              const SizedBox(height: 20),
              const FormSectionHeader(
                title: 'Data Pribadi',
                icon: Icons.person_outline_rounded,
              ),
              AppTextField(
                label: 'Nama Depan',
                hint: 'Masukkan nama depan',
                controller: _firstNameController,
                prefixIcon: Icons.badge_outlined,
                validator: (String? value) => _wajib(value, 'Nama depan'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Nama Belakang',
                hint: 'Masukkan nama belakang',
                controller: _lastNameController,
                prefixIcon: Icons.badge_outlined,
                validator: (String? value) => _wajib(value, 'Nama belakang'),
              ),
              const SizedBox(height: 20),
              const FormSectionHeader(
                title: 'Akun Login',
                icon: Icons.lock_outline_rounded,
              ),
              AppTextField(
                label: 'Username',
                hint: 'Masukkan username',
                controller: _usernameController,
                prefixIcon: Icons.person_outline_rounded,
                validator: (String? value) => _wajib(value, 'Username'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Email',
                hint: 'nama@perusahaan.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
                validator: (String? value) => _wajib(value, 'Email'),
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Password',
                hint: 'Masukkan password',
                controller: _passwordController,
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                validator: (String? value) => _wajib(value, 'Password'),
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
              _HrAdminResult(
                _companyId!,
                _firstNameController.text.trim(),
                _lastNameController.text.trim(),
                _usernameController.text.trim(),
                _emailController.text.trim(),
                _passwordController.text,
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
