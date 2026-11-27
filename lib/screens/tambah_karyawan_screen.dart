import 'dart:convert';

import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

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
  String? _gender;

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
              'status': '1',
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
      appBar: const GlassAppBar(
        title: Text('Tambah Karyawan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Masukkan data karyawan baru. Akun login akan otomatis dibuatkan '
                'dengan status aktif.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormSectionHeader(
                      title: 'Data Pribadi',
                      icon: Icons.person_outline_rounded,
                    ),
                    AppTextField(
                      label: 'Nama Depan',
                      hint: 'Masukkan nama depan',
                      controller: _firstNameController,
                      maxLength: 30,
                      prefixIcon: Icons.badge_outlined,
                      validator: (String? value) => _wajib(value, 'Nama Depan'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Nama Belakang',
                      hint: 'Masukkan nama belakang',
                      controller: _lastNameController,
                      maxLength: 30,
                      prefixIcon: Icons.badge_outlined,
                      validator: (String? value) => _wajib(value, 'Nama Belakang'),
                    ),
                    const SizedBox(height: 16),
                    AppFormDropdown<String>(
                      label: 'Jenis Kelamin',
                      value: _gender,
                      hint: 'Pilih jenis kelamin',
                      prefixIcon: Icons.wc_outlined,
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
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: (String? value) => _wajib(value, 'Email'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'No. HP (WhatsApp)',
                      hint: 'Contoh: 08123456789 atau 628123456789',
                      controller: _mobileNoController,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      prefixIcon: Icons.phone_outlined,
                      validator: WhatsAppHelper.validatePhone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const FormSectionHeader(
                      title: 'Akun Login',
                      icon: Icons.lock_outline_rounded,
                    ),
                    AppTextField(
                      label: 'Username (untuk Login)',
                      hint: 'Masukkan username',
                      controller: _usernameController,
                      maxLength: 30,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (String? value) => _wajib(value, 'Username'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Password',
                      hint: 'Masukkan password',
                      controller: _passwordController,
                      obscureText: true,
                      maxLength: 20,
                      prefixIcon: Icons.lock_outline_rounded,
                      validator: (String? value) => _wajib(value, 'Password'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
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
