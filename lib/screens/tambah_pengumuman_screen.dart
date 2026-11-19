import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/pengumuman_overlay.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class TambahPengumumanScreen extends StatefulWidget {
  const TambahPengumumanScreen({
    super.key,
    this.id,
    this.judulAwal,
    this.isiAwal,
  });

  final int? id;
  final String? judulAwal;
  final String? isiAwal;

  bool get isEdit => id != null;

  @override
  State<TambahPengumumanScreen> createState() => _TambahPengumumanScreenState();
}

class _TambahPengumumanScreenState extends State<TambahPengumumanScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.judulAwal ?? '');
    _messageController = TextEditingController(text: widget.isiAwal ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _simpanPengumuman() async {
    final String title = _titleController.text.trim();
    final String message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul dan isi pengumuman wajib diisi!')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final String endpoint = widget.isEdit
        ? '${ApiConfig.baseUrl}/edit_pengumuman.php'
        : '${ApiConfig.baseUrl}/tambah_pengumuman.php';
    final Map<String, dynamic> body = <String, dynamic>{
      'title': title,
      'message': message,
    };
    if (widget.isEdit) body['id'] = widget.id;

    bool serverBerhasil = false;
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));
      serverBerhasil = widget.isEdit
          ? response.statusCode == 200
          : response.statusCode == 201;
    } catch (_) {}

    if (!serverBerhasil && widget.isEdit) {
      await PengumumanOverlay.upsert(
        id: widget.id!,
        judul: title,
        isi: message,
      );
    }

    if (!mounted) return;

    if (serverBerhasil || widget.isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? (serverBerhasil
                    ? 'Pengumuman berhasil diperbarui!'
                    : 'Perubahan disimpan di perangkat ini.')
                : 'Pengumuman berhasil dibuat!',
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuat pengumuman. Coba lagi.')),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit Pengumuman' : 'Buat Pengumuman'),
      ),
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
              maxLines: 5,
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              label: widget.isEdit ? 'Simpan Perubahan' : 'Simpan Pengumuman',
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
