import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    required this.title,
    this.actions = const <Widget>[],
    this.leading,
  });

  final Widget title;
  final List<Widget> actions;
  final Widget? leading;

  static const double _height = 76;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;
    return Semantics(
      header: true,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(26),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            height: _height + top,
            padding: EdgeInsets.only(top: top),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  AppColors.primary.withValues(alpha: 0.16),
                  AppColors.blue.withValues(alpha: 0.10),
                  Colors.white.withValues(alpha: 0.52),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: <Widget>[
                  ?leading,
                  const SizedBox(width: 8),
                  Expanded(
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: AppColors.textPrimary,
                      ),
                      child: title,
                    ),
                  ),
                  ...actions,
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
