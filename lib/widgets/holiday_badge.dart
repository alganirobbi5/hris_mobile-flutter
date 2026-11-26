import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HolidayBadge extends StatelessWidget {
  const HolidayBadge({super.key, required this.isNational});

  final bool isNational;

  String get label => isNational ? 'Nasional' : 'Perusahaan';

  @override
  Widget build(BuildContext context) {
    final Color color = isNational ? AppColors.primary : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
