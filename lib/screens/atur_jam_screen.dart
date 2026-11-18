import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

class AturJamScreen extends StatefulWidget {
  const AturJamScreen({super.key});

  @override
  State<AturJamScreen> createState() => _AturJamScreenState();
}

class _AturJamScreenState extends State<AturJamScreen> {
  static const String _updateJamUrl =
      '${ApiConfig.baseUrl}/update_jam_kerja.php';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _jamMasukController = TextEditingController();
  final TextEditingController _jamKeluarController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _jamMasukController.dispose();
    _jamKeluarController.dispose();
    super.dispose();
  }

  TimeOfDay? _parseJam(String value) {
    final RegExpMatch? match = RegExp(r'^([01]?\d|2[0-3]):([0-5]\d)$')
        .firstMatch(value.trim());
    if (match == null) return null;

    return TimeOfDay(
      hour: int.parse(match.group(1)!),
      minute: int.parse(match.group(2)!),
    );
  }

  String? _validasiJam(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Jam wajib diisi';
    }
    if (_parseJam(value) == null) {
      return 'Format jam harus HH:MM';
    }
    return null;
  }

  Future<void> _pilihJam(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime:
          _parseJam(controller.text) ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null) return;

    final String jam =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    controller.text = jam;
  }

  String _apiErrorMessage(http.Response response) {
    final String fallback =
        'Gagal mengubah jam kerja (HTTP ${response.statusCode}).';
    final String body = response.body.trim();
    if (body.isEmpty) return fallback;

    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic message =
            decoded['message'] ?? decoded['error'] ?? decoded['pesan'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return body.length <= 140 ? body : fallback;
    }

    return body.length <= 140 ? body : fallback;
  }

  Future<void> _simpanJamKerja() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      final http.Response response = await http
          .post(
            Uri.parse(_updateJamUrl),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, String>{
              'jam_masuk': _jamMasukController.text.trim(),
              'jam_keluar': _jamKeluarController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Jam kerja berhasil diubah')),
        );
        Navigator.of(context).pop(true);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(_apiErrorMessage(response))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan koneksi ke server')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Atur Jam Kerja')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atur jam masuk dan jam keluar perusahaan. Format waktu '
                  'menggunakan 24 jam (HH:MM).',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        label: 'Jam Masuk',
                        hint: 'HH:MM',
                        controller: _jamMasukController,
                        prefixIcon: Icons.login_rounded,
                        readOnly: true,
                        onTap: () => _pilihJam(_jamMasukController),
                        validator: _validasiJam,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Jam Keluar',
                        hint: 'HH:MM',
                        controller: _jamKeluarController,
                        prefixIcon: Icons.logout_rounded,
                        readOnly: true,
                        onTap: () => _pilihJam(_jamKeluarController),
                        validator: _validasiJam,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Ketuk kolom jam untuk memilih waktu. Perubahan akan '
                        'berlaku untuk semua karyawan.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isLoading ? 'Menyimpan...' : 'Simpan Pengaturan Jam',
                  icon: Icons.save_rounded,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _simpanJamKerja,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
