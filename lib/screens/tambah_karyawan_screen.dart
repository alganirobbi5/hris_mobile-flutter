import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class TambahKaryawanScreen extends StatefulWidget {
  const TambahKaryawanScreen({super.key});

  @override
  State<TambahKaryawanScreen> createState() => _TambahKaryawanScreenState();
}

class _TambahKaryawanScreenState extends State<TambahKaryawanScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _simpanKaryawan() async {
    // 1. Validasi Input
    if (_firstNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nama Depan, Email, Username, dan Password wajib diisi!',
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. Kirim HTTP POST ke API
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tambah_karyawan.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Sukses
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Karyawan berhasil ditambahkan!')),
        );
        // Kembali ke halaman sebelumnya
        Navigator.pop(context);
      } else {
        // Gagal dari API (misal username sudah dipakai)
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Gagal menambah karyawan')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan koneksi ke server')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Nama Belakang (Opsional)',
              hint: 'Masukkan nama belakang',
              controller: _lastNameController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Email',
              hint: 'contoh: budi@perusahaan.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Username (Untuk Login)',
              hint: 'Masukkan username',
              controller: _usernameController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              hint: 'Masukkan password',
              controller: _passwordController,
              obscureText: true,
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
    );
  }
}
