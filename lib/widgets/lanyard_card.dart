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
  late final AnimationController _idle;
  Offset _drag = Offset.zero;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.buttons == 0) return;
    setState(() {
      _drag = Offset(
        (_drag.dx + event.delta.dx).clamp(-70.0, 70.0),
        (_drag.dy + event.delta.dy).clamp(-55.0, 55.0),
      );
    });
  }

  void _onPointerUp([Object? event]) {
    setState(() => _drag = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _idle,
      builder: (BuildContext context, Widget? child) {
        final double t = _idle.value;
        final double idleSwing = sin(t * 2 * pi) * 0.045;
        final double idleLift = sin(t * 2 * pi + 0.7) * 4;

        final double dx = _drag.dx;
        final double dy = _drag.dy;
        final double tiltY = dx / 70 * 0.30 + idleSwing;
        final double tiltX = -dy / 55 * 0.22;
        final double swingZ = dx / 70 * 0.055 + idleSwing * 0.35;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: (_) => _onPointerUp(),
          child: Transform.translate(
            offset: Offset(dx * 0.35, dy * 0.25 + idleLift),
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..rotateZ(swingZ)
                ..rotateX(tiltX)
                ..rotateY(tiltY),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildStrap(),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: _buildClip(),
                  ),
                  _buildCard(),
                ],
              ),
            ),
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }

  Widget _buildStrap() {
    return SizedBox(
      width: 210,
      height: 58,
      child: CustomPaint(painter: const _StrapPainter()),
    );
  }

  Widget _buildClip() {
    return Container(
      width: 26,
      height: 18,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE6E8F0), Colors.white, Color(0xFFC7CBD9)],
        ),
        borderRadius: BorderRadius.circular(5),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF4436D6),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF7B5CFF),
            Color(0xFF5B4CFF),
            Color(0xFF3B5BDB),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.4),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.42),
            blurRadius: 34,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: <Widget>[
            Positioned(
              right: -50,
              top: -40,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -40,
              bottom: 30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'ID CARD',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Text(
                        widget.companyCode,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        width: 78,
                        height: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: widget.avatar,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.nama,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                widget.role.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.companyName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: <Widget>[
                        _row(Icons.mail_outline_rounded, 'Email', widget.email),
                        const SizedBox(height: 10),
                        _row(Icons.person_outline_rounded, 'Username',
                            widget.username),
                        const SizedBox(height: 10),
                        _row(Icons.beach_access_outlined, 'Sisa Kuota',
                            widget.kuota),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'HRIS DIGNITY',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 22,
                        child: CustomPaint(painter: const _BarcodePainter()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
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
      ..color = const Color(0xFF3B2FA8)
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final Path path = Path()
      ..moveTo(size.width * 0.12, 0)
      ..lineTo(size.width * 0.38, size.height * 0.9)
      ..lineTo(size.width * 0.5, size.height)
      ..lineTo(size.width * 0.62, size.height * 0.9)
      ..lineTo(size.width * 0.88, 0);
    canvas.drawPath(path, paint);

    final Paint highlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, highlight);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BarcodePainter extends CustomPainter {
  const _BarcodePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final List<int> widths = <int>[2, 1, 3, 1, 2, 4, 1, 2, 1, 3, 2, 1];
    double x = 0;
    for (int i = 0; i < widths.length; i++) {
      if (x >= size.width) break;
      final double w = widths[i].toDouble();
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), paint);
      x += w + 2;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
