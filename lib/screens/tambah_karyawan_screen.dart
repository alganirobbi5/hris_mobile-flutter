import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/karyawan_option_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class TambahKaryawanScreen extends StatefulWidget {
  const TambahKaryawanScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<TambahKaryawanScreen> createState() => _TambahKaryawanScreenState();
}

class _TambahKaryawanScreenState extends State<TambahKaryawanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileNoController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  http.Client? _ownedClient;

  http.Client get _httpClient {
    if (widget.httpClient != null) return widget.httpClient!;
    return _ownedClient ??= http.Client();
  }

  bool _isLoading = false;
  bool _isLoadingOptions = true;
  String? _gender;
  int? _departmentId;
  int? _designationId;
  String _status = '1';
  List<KaryawanOption> _departments = const <KaryawanOption>[];
  List<KaryawanOption> _designations = const <KaryawanOption>[];

  @override
  void initState() {
    super.initState();
    _fetchOptions();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileNoController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    if (!mounted) return;
    setState(() => _isLoadingOptions = true);
    final KaryawanOptionsResult hasil = await KaryawanOptionService.fetchAll(
      client: widget.httpClient,
    );
    if (!mounted) return;
    setState(() {
      _departments = hasil.departments;
      _designations = hasil.designations;
      _isLoadingOptions = false;
    });
  }

  String? _wajib(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  Future<void> _simpanKaryawan() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await _httpClient
          .post(
            ApiConfig.uri('tambah_karyawan.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'first_name': _firstNameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
              'gender': _gender,
              'email': _emailController.text.trim(),
              'mobile_no': _mobileNoController.text.trim(),
              'department_id': _departmentId,
              'designation_id': _designationId,
              'status': _status,
              'user_name': _usernameController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        AppToast.success('Karyawan berhasil ditambahkan!');
        Navigator.pop(context);
        return;
      }
      AppToast.error(_pesanGagal(response));
    } catch (_) {
      if (!mounted) return;
      AppToast.error('Terjadi kesalahan koneksi ke server');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _pesanGagal(http.Response response) {
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic message = decoded['message'] ?? decoded['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } on FormatException {
      return 'Gagal menambah karyawan';
    }
    return 'Gagal menambah karyawan';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Karyawan'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan data karyawan baru. Akun login akan otomatis dibuatkan.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              AppTextField(
                label: 'Nama Depan',
                hint: 'Masukkan nama depan',
                controller: _firstNameController,
                maxLength: 30,
                validator: (String? value) => _wajib(value, 'Nama Depan'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Nama Belakang',
                hint: 'Masukkan nama belakang',
                controller: _lastNameController,
                maxLength: 30,
                validator: (String? value) => _wajib(value, 'Nama Belakang'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'Male',
                    child: Text('Laki-laki'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'Female',
                    child: Text('Perempuan'),
                  ),
                ],
                validator: (String? value) =>
                    value == null ? 'Jenis Kelamin wajib dipilih' : null,
                onChanged: (String? value) =>
                    setState(() => _gender = value),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email',
                hint: 'contoh: budi@perusahaan.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                maxLength: 30,
                validator: (String? value) => _wajib(value, 'Email'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'No. HP',
                hint: 'Masukkan nomor handphone',
                controller: _mobileNoController,
                keyboardType: TextInputType.phone,
                maxLength: 15,
                validator: (String? value) => _wajib(value, 'No. HP'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Departemen'),
                hint: Text(
                  _isLoadingOptions
                      ? 'Memuat departemen...'
                      : 'Pilih Departemen',
                ),
                items: _departments
                    .map(
                      (KaryawanOption option) => DropdownMenuItem<int>(
                        value: option.id,
                        child: Text(
                          option.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (int? value) =>
                    value == null ? 'Departemen wajib dipilih' : null,
                onChanged: (int? value) =>
                    setState(() => _departmentId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _designationId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Jabatan'),
                hint: Text(
                  _isLoadingOptions
                      ? 'Memuat jabatan...'
                      : 'Pilih Jabatan',
                ),
                items: _designations
                    .map(
                      (KaryawanOption option) => DropdownMenuItem<int>(
                        value: option.id,
                        child: Text(
                          option.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                validator: (int? value) =>
                    value == null ? 'Jabatan wajib dipilih' : null,
                onChanged: (int? value) =>
                    setState(() => _designationId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: '1', child: Text('Aktif')),
                  DropdownMenuItem<String>(
                    value: '0',
                    child: Text('Nonaktif'),
                  ),
                ],
                onChanged: (String? value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Username (untuk Login)',
                hint: 'Masukkan username',
                controller: _usernameController,
                maxLength: 30,
                validator: (String? value) => _wajib(value, 'Username'),
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                hint: 'Masukkan password',
                controller: _passwordController,
                obscureText: true,
                maxLength: 20,
                validator: (String? value) => _wajib(value, 'Password'),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Simpan Karyawan',
                icon: Icons.save_rounded,
                isLoading: _isLoading,
                onPressed: _simpanKaryawan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
