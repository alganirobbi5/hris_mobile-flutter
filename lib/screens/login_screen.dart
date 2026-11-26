import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../services/company_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/primary_button.dart';
import 'splash_after_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  static Uri get _loginUrl => ApiConfig.uri('login.php');

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    CompanyProfile.load();
  }

  @override
  void dispose() {
    _companyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Kolom ini wajib diisi';
    }
    return null;
  }

  String? _validateCompany(String? value) {
    final String kode = value?.trim() ?? '';
    if (kode.isEmpty) return null;

    if (kode.toUpperCase() != CompanyProfile.current.code.toUpperCase()) {
      return 'Kode perusahaan tidak sesuai dengan data HR';
    }
    return null;
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    await AppSession.setFromLogin(body);
    final String? token = await AppSession.resolveToken();
    if (AppSession.responseDeclaresToken(body) &&
        (token == null || token.isEmpty)) {
      debugPrint(
        'Login session error: token gagal disimpan ke SharedPreferences',
      );
    }
  }

  bool _isSuccessResponse(Map<String, dynamic> body) {
    final dynamic success = body['success'];
    if (success == true) return true;
    if (success != null) return false;

    final String status =
        (body['status'] as String?)?.trim().toLowerCase() ?? '';
    return status == 'success' || status == 'ok';
  }

  String? _validateSessionData(Map<String, dynamic> body) {
    final Map<String, dynamic>? data = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : null;
    final String bentuk = data != null && data['user'] is Map<String, dynamic>
        ? 'data.user'
        : 'format lama';

    final String? token = AppSession.getToken();
    if (AppSession.responseDeclaresToken(body) &&
        (token == null || token.isEmpty)) {
      debugPrint(
        'Login extraction error: token kosong (data.token / token / api_token)',
      );
      return 'Token autentikasi tidak diterima dari server.';
    }

    final int? userId = AppSession.getUserId();
    if (userId == null) {
      debugPrint(
        'Login extraction error: user_id kosong (data.user.user_id / user_id)',
      );
      return 'ID user tidak diterima dari server.';
    }

    final String? role = AppSession.getRole();
    if (role == null || role.isEmpty) {
      debugPrint('Login extraction error: role kosong (data.user.role / role)');
      return 'Role user tidak diterima dari server.';
    }

    debugPrint(
      'Login session extracted ($bentuk): user_id=$userId, role=$role',
    );
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final String kodePerusahaan = _companyController.text.trim();
    if (kodePerusahaan.isNotEmpty &&
        kodePerusahaan.toUpperCase() !=
            CompanyProfile.current.code.toUpperCase()) {
      AppToast.error('Kode perusahaan tidak sesuai dengan data HR.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Login URL: $_loginUrl');

      final http.Response response = await http
          .post(
            _loginUrl,
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'company_code': kodePerusahaan,
              'username': _usernameController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(ApiConfig.requestTimeout);

      debugPrint('Login status code: ${response.statusCode}');

      if (!mounted) return;

      Map<String, dynamic>? body;
      try {
        final Object? decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else {
          debugPrint('Login JSON error: respons bukan objek JSON');
        }
      } on FormatException catch (e, stackTrace) {
        debugPrint('Login JSON error: $e');
        debugPrintStack(stackTrace: stackTrace);
      }

      if (body == null) {
        debugPrint(
          'Login response error: status=${response.statusCode}, '
          'body=${response.body.isEmpty ? "kosong" : "bukan objek JSON"}',
        );
        AppToast.error(
          'Server balas: ${response.body} (Status: ${response.statusCode})',
        );
      } else if (response.statusCode == 200 && _isSuccessResponse(body)) {
        await _saveSession(body);

        final String? extractionError = _validateSessionData(body);
        if (extractionError != null) {
          await AppSession.clear();
          if (!mounted) return;
          AppToast.error('$extractionError Silakan coba lagi.');
          return;
        }

        // Mode token: backend mengirim field token, jadi token wajib ada.
        // Backend lama tidak mengirim field token sama sekali dan tetap
        // diizinkan agar pengguna tidak terkunci.
        if (AppSession.responseDeclaresToken(body)) {
          final String? token = await AppSession.resolveToken();
          if (token == null || token.isEmpty) {
            await AppSession.clear();
            if (!mounted) return;
            AppToast.error(
              'Token autentikasi tidak diterima dari server. Silakan coba lagi.',
            );
            return;
          }
        }

        if (!mounted) return;

        if (!mounted) return;
        AppToast.success('Login Berhasil');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const SplashAfterLoginScreen(),
          ),
        );
      } else {
        debugPrint(
          'Login ditolak server: status=${response.statusCode}, '
          'success=${body['success']}, message=${body['message']}',
        );
        final String message =
            body['message'] as String? ??
            'Login gagal (${response.statusCode})';
        AppToast.error(message);
      }
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('Login timeout: $e');
      debugPrintStack(stackTrace: stackTrace);
      AppToast.error(
        'Koneksi ke server timeout (${ApiConfig.baseUrl}). '
        'Pastikan HP dan server berada di jaringan yang sama.',
      );
    } on SocketException catch (e, stackTrace) {
      debugPrint('Login SocketException: $e');
      debugPrintStack(stackTrace: stackTrace);
      AppToast.error(
        'Tidak dapat terhubung ke ${ApiConfig.baseUrl}. '
        'Periksa koneksi Wi-Fi dan pastikan server aktif.',
      );
    } on http.ClientException catch (e, stackTrace) {
      debugPrint('Login ClientException: $e');
      debugPrintStack(stackTrace: stackTrace);
      AppToast.error(
        'Tidak dapat terhubung ke ${ApiConfig.baseUrl}. '
        'Periksa koneksi Wi-Fi dan pastikan server aktif.',
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('Login FormatException: $e');
      debugPrintStack(stackTrace: stackTrace);
      AppToast.error('Respons server tidak valid.');
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      AppToast.error('Error: ${e.toString()}');
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
                          'assets/logo/icon-dignity.png',
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
                      label: 'Kode Perusahaan (Kosongkan jika Super Admin)',
                      hint: 'Contoh: CMJ-2026',
                      controller: _companyController,
                      prefixIcon: Icons.business_outlined,
                      textInputAction: TextInputAction.next,
                      validator: _validateCompany,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      label: 'Nama User',
                      hint: 'Masukkan nama user dari HR',
                      controller: _usernameController,
                      prefixIcon: Icons.person_outline_rounded,
                      keyboardType: TextInputType.text,
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
