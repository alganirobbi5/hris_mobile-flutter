import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pull-to-refresh tanpa lingkaran berputar. Garis tipis di bawah header
/// tumbuh saat ditarik, lalu mengalir pelan dari kanan ke kiri saat refresh.
class AppRefreshIndicator extends StatefulWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  State<AppRefreshIndicator> createState() => _AppRefreshIndicatorState();
}

class _AppRefreshIndicatorState extends State<AppRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  double _pull = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is OverscrollNotification && notification.overscroll < 0) {
      final double next =
          (_pull + (-notification.overscroll) / 260).clamp(0.0, 1.0);
      if ((next - _pull).abs() > 0.01 && mounted && !_isRefreshing) {
        setState(() => _pull = next);
      }
      return false;
    }
    if (notification is ScrollEndNotification && !_isRefreshing) {
      final bool shouldRefresh = _pull >= 0.35;
      if (shouldRefresh) {
        _refresh();
      } else if (_pull > 0 && mounted) {
        setState(() => _pull = 0);
      }
    }
    return false;
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
      _pull = 1;
    });
    _flow.forward(from: 0);
    try {
      await widget.onRefresh();
      // Biarkan garis menyelesaikan perjalanannya sebelum hilang.
      if (_flow.status != AnimationStatus.completed) {
        await Future<void>.delayed(
          Duration(milliseconds: (2200 * (1 - _flow.value)).round()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _pull = 0;
        });
      }
      _flow.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildLine(),
        ),
      ],
    );
  }

  Widget _buildLine() {
    if (!_isRefreshing && _pull <= 0) return const SizedBox.shrink();

    if (!_isRefreshing) {
      return Align(
        alignment: Alignment.centerRight,
        widthFactor: _pull,
        child: const _LineBar(opacity: 1),
      );
    }

    return AnimatedBuilder(
      animation: _flow,
      builder: (BuildContext context, Widget? child) {
        final double t = _flow.value;
        final double opacity = t < 0.75 ? 1.0 : (1 - t) / 0.25;
        final Offset offset = Offset(0.9 - t * 1.9, 0);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: offset,
            child: child,
          ),
        );
      },
      child: const FractionallySizedBox(
        widthFactor: 0.55,
        alignment: Alignment.centerRight,
        child: _LineBar(opacity: 1),
      ),
    );
  }
}

class _LineBar extends StatelessWidget {
  const _LineBar({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: <Color>[
            AppColors.primary.withValues(alpha: opacity),
            AppColors.blue.withValues(alpha: opacity),
            AppColors.primary.withValues(alpha: opacity * 0.15),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3 * opacity),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}
