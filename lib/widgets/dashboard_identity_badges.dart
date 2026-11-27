import 'package:flutter/material.dart';

import 'company_logo_badge.dart';
import 'profile_avatar_button.dart';

class DashboardIdentityBadges extends StatelessWidget {
  const DashboardIdentityBadges({super.key});

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: top + 10,
      right: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          CompanyLogoBadge(standalone: false),
          SizedBox(width: 8),
          ProfileAvatarButton(standalone: false),
        ],
      ),
    );
  }
}
