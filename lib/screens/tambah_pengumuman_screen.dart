import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class TambahPengumumanScreen extends StatefulWidget {
  const TambahPengumumanScreen({super.key});

  @override
  State<TambahPengumumanScreen> createState() => _TambahPengumumanScreenState();
}

class _TambahPengumumanScreenState extends State<TambahPengumumanScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _simpanPengumuman() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi pengumuman wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/tambah_pengumuman.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': _titleController.text.trim(),
          'message': _messageController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengumuman berhasil dibuat!')),
        );
        Navigator.pop(context, true); // Kembali dan beri sinyal refresh
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Gagal membuat pengumuman'),
          ),
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
      appBar: AppBar(title: const Text('Buat Pengumuman')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            AppTextField(
              label: 'Judul Pengumuman',
              hint: 'Contoh: Libur Nasional',
              controller: _titleController,
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Isi Pengumuman',
              hint: 'Tulis pesan lengkap di sini...',
              controller: _messageController,
              maxLines: 5, // Agar kotaknya besar
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'Simpan Pengumuman',
              icon: Icons.send_rounded,
              isLoading: _isLoading,
              onPressed: _simpanPengumuman,
            ),
          ],
        ),
      ),
    );
  }
}
