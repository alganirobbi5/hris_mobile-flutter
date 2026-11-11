import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _identityController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static const String _loginUrl =
      'http://192.168.1.2/HumanResourceManagementSystem/src/api/login.php';

  bool _isLoading = false;

  @override
  void dispose() {
    _companyController.dispose();
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kolom ini wajib diisi';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);

    try {
      final http.Response response = await http.post(
        Uri.parse(_loginUrl),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'username': _identityController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      if (!mounted) return;

      Map<String, dynamic> body = <String, dynamic>{};
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        body = <String, dynamic>{};
      }

      if (response.statusCode == 200) {
        messenger.showSnackBar(const SnackBar(content: Text('Login Berhasil')));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainScreen()),
        );
      } else {
        final String message =
            body['message'] as String? ??
            'Login gagal (${response.statusCode})';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } on SocketException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat terhubung ke server. Periksa koneksi Wi-Fi dan pastikan server aktif.',
          ),
        ),
      );
    } on http.ClientException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat terhubung ke server. Periksa koneksi Wi-Fi dan pastikan server aktif.',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan. Silakan coba lagi.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/logo/logo-hrms.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Selamat datang',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        letterSpacing: -0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Masuk ke akun perusahaanmu untuk absen dan mengajukan cuti.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    AppTextField(
                      label: 'Kode Perusahaan',
                      hint: 'Contoh: CMJ-2026',
                      controller: _companyController,
                      prefixIcon: Icons.business_outlined,
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'NIK atau Email',
                      hint: 'Masukkan NIK atau email',
                      controller: _identityController,
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _required,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Kata Sandi',
                      hint: 'Masukkan kata sandi',
                      controller: _passwordController,
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: _required,
                    ),
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Masuk',
                      icon: Icons.login_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text(
                        'Butuh bantuan? Hubungi tim HR perusahaanmu.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
