import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../widgets/glass_app_bar.dart';

import '../config/company_config.dart';
import '../services/company_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import 'approval_cuti_screen.dart';
import 'atur_jam_screen.dart';
import 'edit_karyawan_screen.dart';
import 'kelola_hr_admin_screen.dart';
import 'kelola_kuota_cuti_screen.dart';
import 'kontak_karyawan_screen.dart';
import 'kelola_perusahaan_screen.dart';
import 'laporan_screen.dart';
import 'tambah_karyawan_screen.dart';
import 'tambah_lokasi_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isHr,
    required this.canApprove,
    this.isSuperAdmin = false,
  });

  final bool isHr;
  final bool canApprove;
  final bool isSuperAdmin;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _companyName = CompanyConfig.namaPerusahaan;
  String _companyCode = CompanyConfig.kodePerusahaan;

  @override
  void initState() {
    super.initState();
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    final CompanyProfileData local = await CompanyProfile.load();
    if (!mounted) return;
    setState(() {
      _companyName = local.name;
      _companyCode = local.code;
    });
  }

  Future<void> _showEditCompanyDialog() async {
    final TextEditingController nameController =
        TextEditingController(text: _companyName);
    final TextEditingController codeController =
        TextEditingController(text: _companyCode);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String logo = CompanyProfile.current.logo;

    Future<void> pilihLogo(StateSetter setState) async {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      final List<int> bytes = await file.readAsBytes();
      setState(() {
        logo = 'data:${file.mimeType ?? 'image/png'};base64,${base64Encode(bytes)}';
      });
    }

    Widget previewLogo(String value) {
      final int comma = value.indexOf(',');
      if (value.startsWith('data:image/') && comma > 0) {
        try {
          return Padding(
            padding: const EdgeInsets.all(6),
            child: Image.memory(
              base64Decode(value.substring(comma + 1)),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(Icons.business_outlined),
            ),
          );
        } catch (_) {}
      }
      return const Icon(Icons.business_outlined, color: AppColors.primary);
    }

    final Map<String, String>? hasil = await showDialog<Map<String, String>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Edit Profil Perusahaan'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const FormSectionHeader(
                        title: 'Profil Perusahaan',
                        icon: Icons.business_outlined,
                      ),
                      AppTextField(
                        label: 'Nama Perusahaan',
                        hint: 'Masukkan nama perusahaan',
                        controller: nameController,
                        prefixIcon: Icons.business_outlined,
                        validator: (String? value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Nama perusahaan wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        label: 'Kode Perusahaan',
                        hint: 'Masukkan kode perusahaan',
                        controller: codeController,
                        prefixIcon: Icons.qr_code_2_outlined,
                        validator: (String? value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Kode perusahaan wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      const FormSectionHeader(
                        title: 'Logo Perusahaan',
                        icon: Icons.image_outlined,
                      ),
                      InkWell(
                        onTap: () => pilihLogo(setState),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.field,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: logo.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: previewLogo(logo),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: AppColors.primary),
                                    SizedBox(height: 4),
                                    Text('Pilih logo perusahaan',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(dialogContext).pop(<String, String>{
                      'name': nameController.text.trim(),
                      'code': codeController.text.trim(),
                      'logo': logo,
                    });
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (hasil == null || !mounted) return;
    await _saveCompany(hasil['name'] ?? '', hasil['code'] ?? '', hasil['logo'] ?? '');
  }

  Future<bool> _saveCompany(String name, String code, [String logo = '']) async {
    final bool saved = await CompanyProfile.update(
      name: name,
      code: code,
      logo: logo,
    );
    if (!mounted) return saved;
    final String message = saved
        ? 'Profil perusahaan berhasil disimpan.'
        : (CompanyProfile.lastError ?? 'Gagal menyimpan profil perusahaan.');
    AppToast.show(message, type: AppToast.typeFromMessage(message));
    if (saved) await _loadCompany();
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: <Widget>[
            if (widget.isSuperAdmin) ...<Widget>[
              const Text(
                'MENU SUPER ADMIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildMenuCard(
                context: context,
                icon: Icons.business_outlined,
                label: 'Kelola Perusahaan',
                subtitle: 'Daftar dan tambah perusahaan',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const KelolaPerusahaanScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.admin_panel_settings_outlined,
                label: 'Kelola HR / Admin',
                subtitle: 'Daftar dan tambah akun HR/Admin',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const KelolaHrAdminScreen(),
                  ),
                ),
              ),
            ],
            if (!widget.isSuperAdmin)
              const Text(
              'MENU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.isHr && !widget.isSuperAdmin)
              _buildMenuCard(
                context: context,
                icon: Icons.description_outlined,
                label: 'Laporan',
                subtitle: 'Lihat dan unduh laporan absensi',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const LaporanScreen(),
                  ),
                ),
              ),
            if (widget.canApprove && !widget.isSuperAdmin)
              _buildMenuCard(
                context: context,
                icon: Icons.fact_check_outlined,
                label: 'Persetujuan',
                subtitle: 'Periksa dan setujui cuti serta izin keluar',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ApprovalCutiScreen(),
                  ),
                ),
              ),
            if (widget.isHr && !widget.isSuperAdmin) ...<Widget>[
              const SizedBox(height: 18),
              const Text(
                'MENU HR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _buildMenuCard(
                context: context,
                icon: Icons.business_center_outlined,
                label: 'Edit Perusahaan',
                subtitle: 'Ubah nama dan kode perusahaan',
                onTap: _showEditCompanyDialog,
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.person_add_alt_1_rounded,
                label: 'Tambah Karyawan',
                subtitle: 'Daftarkan karyawan baru',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const TambahKaryawanScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.person_outline_rounded,
                label: 'Edit Karyawan',
                subtitle: 'Ubah data karyawan perusahaan',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const EditKaryawanScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.chat_bubble_outlined,
                label: 'Hubungi Karyawan',
                subtitle: 'ID Card dan chat WhatsApp karyawan',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const KontakKaryawanScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.add_location_alt_rounded,
                label: 'Tambah Lokasi',
                subtitle: 'Atur lokasi absensi kantor',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const TambahLokasiScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.schedule_rounded,
                label: 'Atur Jam Kerja',
                subtitle: 'Atur jam masuk dan pulang kerja',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const AturJamScreen(),
                  ),
                ),
              ),
              _buildMenuCard(
                context: context,
                icon: Icons.groups_outlined,
                label: 'Kelola Kuota Cuti',
                subtitle: 'Tambah kuota cuti karyawan',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const KelolaKuotaCutiScreen(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 21, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
