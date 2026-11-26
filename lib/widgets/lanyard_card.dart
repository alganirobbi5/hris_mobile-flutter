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
    this.kuota,
  });

  final Widget avatar;
  final String nama;
  final String role;
  final String companyName;
  final String companyCode;
  final String email;
  final String username;
  final String? kuota;

  @override
  State<LanyardCard> createState() => _LanyardCardState();
}

class _LanyardCardState extends State<LanyardCard>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _flip;

  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat(reverse: true);
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
  }

  @override
  void dispose() {
    _idle.dispose();
    _flip.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
    if (_isFlipped) {
      _flip.forward();
    } else {
      _flip.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[_idle, _flip]),
        builder: (BuildContext context, Widget? child) {
          final double t = _idle.value;
          final double sway =
              sin(t * 2 * pi) * 0.030 + sin(t * 2 * pi * 0.43 + 1.1) * 0.016;
          final double bob =
              sin(t * 2 * pi * 0.61 + 0.3) * 3.0 +
              sin(t * 2 * pi * 0.29) * 1.8;

          final double flipValue = _flip.value;
          final double flipLift = sin(flipValue * pi) * 10;

          return Transform.translate(
            offset: Offset(0, bob - flipLift),
            child: Transform(
              alignment: Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..rotateZ(sway * 0.5)
                ..rotateX(sway * 0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _buildStrap(),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: _buildClip(),
                  ),
                  _buildFlippingCard(flipValue),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFlippingCard(double flipValue) {
    final bool showBack = flipValue >= 0.5;
    final double angle = flipValue * pi;
    final double scale = 1 - sin(flipValue * pi) * 0.045;
    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0022)
      ..rotateY(angle)
      ..scaleByDouble(scale, scale, 1.0, 1.0);

    return Transform(
      alignment: Alignment.center,
      transform: transform,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..rotateY(showBack ? pi : 0),
        child: showBack ? _buildBackCard() : _buildFrontCard(),
      ),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
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
    );
  }

  Widget _buildFrontCard() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
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
                        if (widget.kuota != null &&
                            widget.kuota!.trim().isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          _row(Icons.beach_access_outlined, 'Sisa Kuota',
                              widget.kuota!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'HRIS DIGNITY  •  TAP UNTUK BALIK',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: Colors.white.withValues(alpha: 0.68),
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

  Widget _buildBackCard() {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.qr_code_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'QR ABSEN',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: CustomPaint(painter: const _QrPainter()),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.nama,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.companyCode} • ${widget.username}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'TAP UNTUK KEMBALI',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: Colors.white.withValues(alpha: 0.68),
                ),
              ),
            ],
          ),
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

class _QrPainter extends CustomPainter {
  const _QrPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dark = Paint()..color = const Color(0xFF1B1B2F);
    final Paint light = Paint()..color = const Color(0xFFFFFFFF);

    canvas.drawRect(Offset.zero & size, light);

    const List<int> widths = <int>[
      3, 1, 2, 1, 4, 2, 1, 3, 1, 2, 5, 1, 2, 3, 1, 4, 2, 1, 3, 1, 2, 4, 1,
      2, 3, 1, 5, 2, 1, 3,
    ];

    final double unit = size.width /
        (widths.fold<int>(0, (int sum, int w) => sum + w + 1) + 8);
    double x = unit * 4;
    final double top = unit * 5;
    final double bottom = size.height - unit * 5;

    for (int i = 0; i < widths.length; i++) {
      final double w = widths[i] * unit;
      final double h = (i % 4 == 0)
          ? bottom - top - unit * 2
          : bottom - top;
      canvas.drawRect(
        Rect.fromLTWH(x, top + (i % 4 == 0 ? unit : 0), w, h),
        dark,
      );
      x += w + unit;
    }

    final Paint frame = Paint()
      ..color = const Color(0xFF1B1B2F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 2;
    canvas.drawRect(
      Rect.fromLTWH(unit, unit, size.width - unit * 2, size.height - unit * 2),
      frame,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
