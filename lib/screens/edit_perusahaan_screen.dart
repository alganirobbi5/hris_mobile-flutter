import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../services/company_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

class EditPerusahaanScreen extends StatefulWidget {
  const EditPerusahaanScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<EditPerusahaanScreen> createState() => _EditPerusahaanScreenState();
}

class _EditPerusahaanScreenState extends State<EditPerusahaanScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late String _logo;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final CompanyProfileData data = CompanyProfile.current;
    _nameController = TextEditingController(text: data.name);
    _codeController = TextEditingController(text: data.code);
    _logo = data.logo;
    CompanyProfile.load().then((CompanyProfileData loaded) {
      if (!mounted) return;
      setState(() {
        _nameController.text = loaded.name;
        _codeController.text = loaded.code;
        _logo = loaded.logo;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _wajib(String? value, String label) =>
      (value == null || value.trim().isEmpty) ? '$label wajib diisi' : null;

  Future<void> _pilihLogo() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;
    final List<int> bytes = await file.readAsBytes();
    setState(() {
      _logo =
          'data:${file.mimeType ?? 'image/png'};base64,${base64Encode(bytes)}';
    });
  }

  Widget _logoPreview() {
    final int comma = _logo.indexOf(',');
    if (_logo.startsWith('data:image/') && comma > 0) {
      try {
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Image.memory(
            base64Decode(_logo.substring(comma + 1)),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.business_outlined,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        );
      } catch (_) {
        // lanjut ke ikon
      }
    }
    return const Icon(
      Icons.business_outlined,
      color: AppColors.primary,
      size: 28,
    );
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final bool berhasil = await CompanyProfile.update(
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        logo: _logo,
        client: widget.httpClient,
      );
      if (!mounted) return;
      final String pesan = berhasil
          ? 'Profil perusahaan berhasil disimpan.'
          : (CompanyProfile.lastError ?? 'Gagal menyimpan profil perusahaan.');
      AppToast.show(pesan, type: AppToast.typeFromMessage(pesan));
      if (berhasil) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Edit Perusahaan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                'Ubah identitas dan logo perusahaan. Perubahan akan berlaku '
                'untuk seluruh karyawan di perusahaan ini.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const FormSectionHeader(
                      title: 'Profil Perusahaan',
                      icon: Icons.business_outlined,
                    ),
                    AppTextField(
                      label: 'Nama Perusahaan',
                      hint: 'Masukkan nama perusahaan',
                      controller: _nameController,
                      prefixIcon: Icons.business_outlined,
                      validator: (String? value) =>
                          _wajib(value, 'Nama perusahaan'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Kode Perusahaan',
                      hint: 'Masukkan kode perusahaan',
                      controller: _codeController,
                      prefixIcon: Icons.qr_code_2_outlined,
                      validator: (String? value) =>
                          _wajib(value, 'Kode perusahaan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const FormSectionHeader(
                      title: 'Logo Perusahaan',
                      icon: Icons.image_outlined,
                    ),
                    InkWell(
                      onTap: _pilihLogo,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.field,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: _logo.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _logoPreview(),
                              )
                            : const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    color: AppColors.primary,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Pilih logo perusahaan',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Simpan Perubahan',
                icon: Icons.save_rounded,
                isLoading: _isLoading,
                onPressed: _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
