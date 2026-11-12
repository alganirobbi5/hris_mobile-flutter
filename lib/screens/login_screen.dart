import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
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

<<<<<<< HEAD
  static const String _loginUrl =
      'http://127.0.0.1/HumanResourceManagementSystem/src/api/login.php';
=======
  static const String _loginUrl = '${ApiConfig.baseUrl}/login.php';
>>>>>>> 3f09f03 (Feat: Menyelesaikan semua fitur (Absensi, Cuti, Profil, Approval, Laporan Excel, Validasi, Logout))

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
      debugPrint('Login URL: $_loginUrl');

      final http.Response response = await http
          .post(
            Uri.parse(_loginUrl),
            headers: <String, String>{'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'username': _identityController.text.trim(),
              'password': _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('Login status code: ${response.statusCode}');
      debugPrint('Login response body: ${response.body}');

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

<<<<<<< HEAD
      if (response.statusCode == 200 && body?['status'] == 'success') {
=======
      if (response.statusCode == 200) {
        await _saveSession(body);

        if (!mounted) return;

>>>>>>> 3f09f03 (Feat: Menyelesaikan semua fitur (Absensi, Cuti, Profil, Approval, Laporan Excel, Validasi, Logout))
        messenger.showSnackBar(const SnackBar(content: Text('Login Berhasil')));
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MainScreen()),
        );
      } else if (response.statusCode == 200 && body == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Respons server tidak valid.')),
        );
      } else {
        final String message =
            body?['message'] as String? ??
            'Login gagal (${response.statusCode})';
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('Login timeout: $e');
      debugPrintStack(stackTrace: stackTrace);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Koneksi ke server timeout. Silakan coba lagi.'),
        ),
      );
    } on SocketException catch (e, stackTrace) {
      debugPrint('Login SocketException: $e');
      debugPrintStack(stackTrace: stackTrace);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat terhubung ke server. Periksa koneksi Wi-Fi dan pastikan server aktif.',
          ),
        ),
      );
    } on http.ClientException catch (e, stackTrace) {
      debugPrint('Login ClientException: $e');
      debugPrintStack(stackTrace: stackTrace);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak dapat terhubung ke server. Periksa koneksi Wi-Fi dan pastikan server aktif.',
          ),
        ),
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('Login FormatException: $e');
      debugPrintStack(stackTrace: stackTrace);
      messenger.showSnackBar(
        const SnackBar(content: Text('Respons server tidak valid.')),
      );
    } catch (e, stackTrace) {
      debugPrint('Login error: $e');
      debugPrintStack(stackTrace: stackTrace);
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan. Silakan coba lagi.')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final dynamic userIdValue = _bodyValue(body, <String>[
      'user_id',
      'id',
      'employee_id',
    ]);
    final dynamic usernameValue = _bodyValue(body, <String>[
      'username',
      'user_name',
      'name',
    ]);
    final dynamic roleValue = _bodyValue(body, <String>['role', 'user_role']);

    final int? userId = int.tryParse(userIdValue?.toString() ?? '');
    if (userId != null) {
      await prefs.setInt('user_id', userId);
    } else if (userIdValue != null) {
      await prefs.setString('user_id', userIdValue.toString());
    }

    await prefs.setString(
      'username',
      usernameValue?.toString() ?? _identityController.text.trim(),
    );
    await prefs.setString('role', roleValue?.toString() ?? '');
  }

  dynamic _bodyValue(Map<String, dynamic> body, List<String> keys) {
    dynamic source = body;
    for (final String container in <String>['data', 'user', 'result']) {
      final dynamic nested = body[container];
      if (nested is Map<String, dynamic>) {
        source = nested;
        break;
      }
    }

    for (final String key in keys) {
      final dynamic value = source[key] ?? body[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value;
      }
    }

    return null;
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
