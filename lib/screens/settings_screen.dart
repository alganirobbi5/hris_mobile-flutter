import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';

import '../theme/app_theme.dart';
import 'approval_cuti_screen.dart';
import 'atur_jam_screen.dart';
import 'edit_karyawan_screen.dart';
import 'edit_perusahaan_screen.dart';
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
  Future<void> _bukaEditPerusahaan() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const EditPerusahaanScreen(),
      ),
    );
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
                onTap: _bukaEditPerusahaan,
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
