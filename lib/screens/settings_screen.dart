import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';

import '../config/company_config.dart';
import '../services/company_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import 'approval_cuti_screen.dart';
import 'atur_jam_screen.dart';
import 'kelola_kuota_cuti_screen.dart';
import 'laporan_screen.dart';
import 'tambah_karyawan_screen.dart';
import 'tambah_lokasi_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isHr,
    required this.canApprove,
  });

  final bool isHr;
  final bool canApprove;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _companyName = CompanyConfig.namaPerusahaan;
  String _companyCode = CompanyConfig.kodePerusahaan;
  bool _isSavingCompany = false;

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

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profil Perusahaan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Perusahaan',
                  ),
                  validator: (String? value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Nama perusahaan wajib diisi'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Perusahaan',
                  ),
                  validator: (String? value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Kode perusahaan wajib diisi'
                          : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: _isSavingCompany
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final bool saved = await _saveCompany(
                        nameController.text,
                        codeController.text,
                      );
                      if (!mounted) return;
                      if (saved && dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
              child: Text(_isSavingCompany ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    codeController.dispose();
  }

  Future<bool> _saveCompany(String name, String code) async {
    setState(() => _isSavingCompany = true);
    final bool saved = await CompanyProfile.update(name: name, code: code);
    if (!mounted) return saved;
    setState(() => _isSavingCompany = false);
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
            if (widget.isHr)
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
            if (widget.canApprove)
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
            if (widget.isHr) ...<Widget>[
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
