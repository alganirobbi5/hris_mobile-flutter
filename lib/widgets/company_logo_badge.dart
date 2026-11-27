import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/company_profile.dart';
import '../theme/app_theme.dart';

class CompanyLogoBadge extends StatefulWidget {
  const CompanyLogoBadge({super.key, this.standalone = true});

  final bool standalone;

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
        return Padding(
          padding: const EdgeInsets.all(6),
          child: Image.memory(
            base64Decode(_logo.substring(comma + 1)),
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.business_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        );
      } catch (_) {
        // lanjut ke ikon bawaan
      }
    }
    return const Icon(
      Icons.business_outlined,
      color: AppColors.primary,
      size: 22,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget badge = Material(
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
    );
    if (!widget.standalone) return badge;
    final double top = MediaQuery.of(context).padding.top;
    return Positioned(top: top + 10, right: 16, child: badge);
  }
}
