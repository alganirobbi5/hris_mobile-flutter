import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import 'login_screen.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.28),
                            blurRadius: 22,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'BS',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Budi Santoso',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Staf Operasional',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'INFORMASI KARYAWAN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              SectionCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    const InfoRow(
                      icon: Icons.apartment_rounded,
                      label: 'Nama Perusahaan',
                      value: 'PT Contoh Maju Sejahtera',
                    ),
                    const InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Kode Perusahaan',
                      value: 'CMJ-2026',
                    ),
                    const InfoRow(
                      icon: Icons.credit_card_outlined,
                      label: 'NIK',
                      value: '3201019876540001',
                    ),
                    const InfoRow(
                      icon: Icons.mail_outline_rounded,
                      label: 'Email',
                      value: 'budi.santoso@contohmaju.co.id',
                    ),
                    const InfoRow(
                      icon: Icons.event_available_outlined,
                      label: 'Tanggal Bergabung',
                      value: '12 Januari 2022',
                    ),
                    const InfoRow(
                      icon: Icons.beach_access_outlined,
                      label: 'Sisa Kuota Cuti',
                      value: '9 dari 12 hari',
                      valueColor: AppColors.primary,
                      isLast: true,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        value: 9 / 12,
                        minHeight: 8,
                        backgroundColor: AppColors.field,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Expanded(
                          child: Text(
                            '3 hari terpakai',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '75% tersedia',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DangerButton(
                label: 'Keluar',
                icon: Icons.logout_rounded,
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'HRIS Mobile v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
