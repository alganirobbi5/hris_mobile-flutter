import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LanyardCard extends StatefulWidget {
  const LanyardCard({
    super.key,
    required this.avatar,
    required this.nama,
    required this.role,
    required this.companyName,
    required this.companyCode,
    required this.email,
    required this.username,
    required this.kuota,
  });

  final Widget avatar;
  final String nama;
  final String role;
  final String companyName;
  final String companyCode;
  final String email;
  final String username;
  final String kuota;

  @override
  State<LanyardCard> createState() => _LanyardCardState();
}

class _LanyardCardState extends State<LanyardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        final double angle = sin(t * 2 * pi) * 0.10;
        final double lift = sin(t * 2 * pi + 0.6) * 6;

        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0016)
              ..rotateZ(angle * 0.45)
              ..rotateY(angle),
            child: child,
          ),
        );
      },
      child: Column(
        children: <Widget>[
          const SizedBox(height: 6),
          _buildStrap(),
          _buildCard(),
        ],
      ),
    );
  }

  Widget _buildStrap() {
    return SizedBox(
      width: 220,
      height: 70,
      child: CustomPaint(painter: _StrapPainter()),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF6C4DFF),
            Color(0xFF4436D6),
            Color(0xFF3B82F6),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          ClipOval(
            child: Container(
              width: 88,
              height: 88,
              color: Colors.white.withValues(alpha: 0.2),
              alignment: Alignment.center,
              child: widget.avatar,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.nama,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Text(
              widget.role.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: <Widget>[
                _row(Icons.apartment_rounded, 'Perusahaan', widget.companyName),
                const SizedBox(height: 12),
                _row(Icons.badge_outlined, 'Kode', widget.companyCode),
                const SizedBox(height: 12),
                _row(Icons.mail_outline_rounded, 'Email', widget.email),
                const SizedBox(height: 12),
                _row(Icons.person_outline_rounded, 'Username', widget.username),
                const SizedBox(height: 12),
                _row(Icons.beach_access_outlined, 'Sisa Kuota', widget.kuota),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'HRIS DIGNITY',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.4,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 10),
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _StrapPainter extends CustomPainter {
  const _StrapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF4436D6)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..moveTo(size.width * 0.1, 0)
      ..lineTo(size.width * 0.36, size.height * 0.92)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.64, size.height * 0.92)
      ..lineTo(size.width * 0.9, 0);
    canvas.drawPath(path, paint);

    final Paint clip = Paint()
      ..color = const Color(0xFF6C4DFF)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.44, size.height - 6, 20, 14),
        const Radius.circular(4),
      ),
      clip,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
