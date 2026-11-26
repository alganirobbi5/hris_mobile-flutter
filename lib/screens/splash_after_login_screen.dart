import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/company_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_app_bar.dart';
import 'main_screen.dart';

class SplashAfterLoginScreen extends StatefulWidget {
  const SplashAfterLoginScreen({super.key});

  @override
  State<SplashAfterLoginScreen> createState() =>
      _SplashAfterLoginScreenState();
}

class _SplashAfterLoginScreenState extends State<SplashAfterLoginScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _navigateTimer;

  String get _companyName {
    final String name = AppSession.getCompanyName()?.trim() ??
        CompanyProfile.current.name.trim();
    return name.isEmpty ? 'HRIS Dignity' : name;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();

    _navigateTimer = Timer(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainScreen()),
      );
    });
  }

  @override
  void dispose() {
    _navigateTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Selamat Datang')),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final double t = Curves.easeOutCubic.transform(_controller.value);
          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFF6F7FB),
                  Color(0xFFEDEBFF),
                ],
              ),
            ),
            child: Center(
              child: Opacity(
                opacity: 0.25 + t * 0.75,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _buildOrbit(t),
                      const SizedBox(height: 34),
                      Text(
                        'Welcome to $_companyName',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'HRIS DIGNITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Menyiapkan workspace Anda',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 26),
                      _buildShimmer(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrbit(double t) {
    final double scale = 0.75 + t * 0.25;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.30),
                    blurRadius: 34,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: const Icon(
                Icons.badge_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
            Positioned.fill(
              child: RotationTransition(
                turns: AlwaysStoppedAnimation<double>(t),
                child: CustomPaint(painter: const _OrbitPainter()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      width: 180,
      height: 4,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: ShimmerLine(controller: _controller),
    );
  }
}

class ShimmerLine extends StatelessWidget {
  const ShimmerLine({super.key, required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final double value = (controller.value * 2) % 1;
        return Transform.translate(
          offset: Offset(-120 + value * 300, 0),
          child: Container(
            width: 110,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  Colors.transparent,
                  AppColors.primary.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      },
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 2,
      paint,
    );
    final Paint dot = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(size.width / 2, 4), 5, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
