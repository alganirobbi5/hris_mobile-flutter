import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/app_session.dart';
import '../models/lampiran_pengumuman.dart';
import '../services/pengumuman_overlay.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';

class TambahPengumumanScreen extends StatefulWidget {
  const TambahPengumumanScreen({
    super.key,
    this.id,
    this.judulAwal,
    this.isiAwal,
    this.lampiranAwal,
  });

  final int? id;
  final String? judulAwal;
  final String? isiAwal;
  final String? lampiranAwal;

  bool get isEdit => id != null;

  @override
  State<TambahPengumumanScreen> createState() => _TambahPengumumanScreenState();
}

class _TambahPengumumanScreenState extends State<TambahPengumumanScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _messageController;
  LampiranPengumuman? _lampiran;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.judulAwal ?? '');
    _messageController = TextEditingController(text: widget.isiAwal ?? '');
    _lampiran = LampiranPengumuman.fromJsonValue(widget.lampiranAwal);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pilihLampiran() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final PlatformFile file = result.files.single;
      final List<int>? bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal membaca file yang dipilih.')),
        );
        return;
      }

      final String ext = (file.extension ?? '').toLowerCase();
      final String mime = _mimeFromExtension(ext);
      setState(() {
        _lampiran = LampiranPengumuman(
          dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
          namaFile: file.name,
          mime: mime,
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuka pemilih file: $e')));
    }
  }

  String _mimeFromExtension(String ext) {
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
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
    if (_lampiran != null) body['attachment'] = _lampiran!.toJsonValue();
    if (widget.isEdit) body['id'] = widget.id;

    bool serverBerhasil = false;
    try {
      final String? token = await AppSession.resolveToken();

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      serverBerhasil = widget.isEdit
          ? response.statusCode == 200
          : response.statusCode == 201;
    } catch (_) {}

    if (!serverBerhasil && widget.isEdit) {
      await PengumumanOverlay.upsert(
        id: widget.id!,
        judul: title,
        isi: message,
        lampiran: _lampiran?.toJsonValue(),
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

  Widget _buildLampiran() {
    final bytes = _lampiran?.decodeBytes();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Lampiran (opsional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_lampiran != null)
          _lampiran!.isImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: bytes == null
                      ? Container(
                          height: 140,
                          alignment: Alignment.center,
                          color: Colors.grey.shade200,
                          child: const Text('Pratinjau tidak tersedia'),
                        )
                      : Image.memory(
                          bytes,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            height: 140,
                            alignment: Alignment.center,
                            color: Colors.grey.shade200,
                            child: const Text('Pratinjau tidak tersedia'),
                          ),
                        ),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _lampiran!.namaFile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pilihLampiran,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_lampiran == null ? 'Pilih File' : 'Ganti File'),
              ),
            ),
            if (_lampiran != null)
              IconButton(
                onPressed: () => setState(() => _lampiran = null),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Hapus lampiran',
              ),
          ],
        ),
      ],
    );
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
            const SizedBox(height: 16),
            _buildLampiran(),
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
