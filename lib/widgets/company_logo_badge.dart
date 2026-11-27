import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/company_profile.dart';
import '../theme/app_theme.dart';

class CompanyLogoBadge extends StatefulWidget {
  const CompanyLogoBadge({super.key});

  @override
  State<CompanyLogoBadge> createState() => _CompanyLogoBadgeState();
}

class _CompanyLogoBadgeState extends State<CompanyLogoBadge> {
  String _logo = '';

  @override
  void initState() {
    super.initState();
    _load();
    CompanyProfile.revision.addListener(_load);
  }

  @override
  void dispose() {
    CompanyProfile.revision.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final CompanyProfileData data = await CompanyProfile.load();
    if (!mounted) return;
    setState(() => _logo = data.logo);
  }

  Widget _content() {
    final int comma = _logo.indexOf(',');
    if (_logo.startsWith('data:image/') && comma > 0) {
      try {
        return Image.memory(
          base64Decode(_logo.substring(comma + 1)),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Image.asset(
            'assets/logo/icon-dignity.png',
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        // lanjut ke logo bawaan
      }
    }
    return Image.asset(
      'assets/logo/icon-dignity.png',
      fit: BoxFit.cover,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 10,
      left: 16,
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          label: 'Logo perusahaan',
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface.withValues(alpha: 0.92),
              border: Border.all(color: AppColors.border, width: 1.4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: _content(),
          ),
        ),
      ),
    );
  }
}
