import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).padding.bottom;

    final bool ringkas = items.length > 5;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        ringkas ? 6 : 18,
        0,
        ringkas ? 6 : 18,
        12 + bottomInset,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.34),
                    Colors.white.withValues(alpha: 0.14),
                  ],
                ),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double itemWidth = constraints.maxWidth / items.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutCubic,
                        left: currentIndex * itemWidth + 4,
                        top: 7,
                        bottom: 7,
                        width: itemWidth - 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.38,
                                ),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (int i = 0; i < items.length; i++)
                            Expanded(
                              child: _NavButton(
                                item: items[i],
                                ringkas: ringkas,
                                selected: i == currentIndex,
                                onTap: () {
                                  if (i == currentIndex) return;
                                  HapticFeedback.lightImpact();
                                  onTap(i);
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.ringkas,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool ringkas;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: selected ? 1 : 0),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double t, Widget? child) {
          final Color color = Color.lerp(
            AppColors.textSecondary.withValues(alpha: 0.9),
            Colors.white,
            t,
          )!;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(
                  selected ? item.activeIcon : item.icon,
                  size: (ringkas ? 19 : 22) + 2 * t,
                  color: color,
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: ringkas ? 0 : 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: ringkas ? 8.5 : 10,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: ringkas ? -0.4 : -0.1,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
