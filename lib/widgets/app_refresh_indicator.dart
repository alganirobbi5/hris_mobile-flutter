import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pull-to-refresh dengan indikator garis di bawah header, bukan spinner
/// berputar. Garis tumbuh saat ditarik, lalu berjalan kanan -> kiri saat
/// proses refresh berlangsung.
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
  late final AnimationController _run;
  double _pull = 0;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _run = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  bool _handleOverscroll(OverscrollNotification notification) {
    if (notification.overscroll < 0) {
      final double next = (_pull + -notification.overscroll / 220)
          .clamp(0.0, 1.0);
      if ((next - _pull).abs() > 0.01 && mounted) {
        setState(() => _pull = next);
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
    _run.repeat();
    try {
      await widget.onRefresh();
    } finally {
      _run.stop();
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _pull = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh: _refresh,
          color: Colors.transparent,
          backgroundColor: Colors.transparent,
          strokeWidth: 0,
          displacement: 0,
          child: NotificationListener<OverscrollNotification>(
            onNotification: _handleOverscroll,
            child: widget.child,
          ),
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

    return SizedBox(
      height: 3,
      child: ClipRect(
        child: _isRefreshing
            ? SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.6, 0),
                  end: const Offset(-1.0, 0),
                ).animate(_run),
                child: const FractionallySizedBox(
                  widthFactor: 0.42,
                  alignment: Alignment.centerRight,
                  child: _RefreshBar(full: true),
                ),
              )
            : Align(
                alignment: Alignment.centerRight,
                widthFactor: _pull,
                child: const _RefreshBar(full: false),
              ),
      ),
    );
  }
}

class _RefreshBar extends StatelessWidget {
  const _RefreshBar({required this.full});

  final bool full;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: <Color>[
            AppColors.primary,
            AppColors.blue,
            AppColors.primary.withValues(alpha: full ? 0.25 : 0.55),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}
