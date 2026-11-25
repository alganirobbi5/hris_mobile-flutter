import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/app_theme.dart';

enum AppToastType { success, error, warning, info }

class AppToastAction {
  const AppToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

class AppToast {
  AppToast._();

  static OverlayState? _overlay;
  static OverlayEntry? _entry;
  static final List<_ToastData> _queue = <_ToastData>[];
  static Timer? _timer;

  static void attach(OverlayState overlay) {
    _overlay = overlay;
  }

  static void show(
    String message, {
    AppToastType type = AppToastType.info,
    String? title,
    AppToastAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    final String trimmed = message.trim();
    if (trimmed.isEmpty) return;

    _queue.add(
      _ToastData(
        message: trimmed,
        title: title ?? _defaultTitle(type),
        type: type,
        action: action,
        duration: duration,
      ),
    );
    if (_queue.length > 3) _queue.removeAt(0);
    _presentNext();
  }

  static AppToastType typeFromMessage(String message) {
    final String lower = message.toLowerCase();
    if (lower.contains('berhasil') || lower.contains('tersimpan') ||
        lower.contains('diubah') || lower.contains('dihapus')) {
      return AppToastType.success;
    }
    if (lower.contains('gagal') || lower.contains('error') ||
        lower.contains('tidak valid') || lower.contains('terjadi kesalahan')) {
      return AppToastType.error;
    }
    if (lower.contains('harus') || lower.contains('silakan') ||
        lower.contains('belum') || lower.contains('tidak boleh')) {
      return AppToastType.warning;
    }
    return AppToastType.info;
  }

  static void success(String message, {String? title}) =>
      show(message, type: AppToastType.success, title: title);

  static void error(String message, {String? title, AppToastAction? action}) =>
      show(message, type: AppToastType.error, title: title, action: action);

  static void warning(String message, {String? title}) =>
      show(message, type: AppToastType.warning, title: title);

  static void info(String message, {String? title}) =>
      show(message, type: AppToastType.info, title: title);

  static String _defaultTitle(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return 'Berhasil';
      case AppToastType.error:
        return 'Gagal';
      case AppToastType.warning:
        return 'Perhatian';
      case AppToastType.info:
        return 'Informasi';
    }
  }

  static void _presentNext() {
    if (_overlay == null || !_overlay!.mounted) return;
    if (_entry != null || _queue.isEmpty) return;

    final _ToastData data = _queue.removeAt(0);
    final _ToastController controller = _ToastController(data: data);
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => _ToastView(
        controller: controller,
        onDismissed: () {
          controller.dispose();
          _entry?.remove();
          _entry = null;
          _timer?.cancel();
          _timer = Timer(const Duration(milliseconds: 220), _presentNext);
        },
      ),
    );
    _entry = entry;
    _overlay!.insert(entry);

    controller.forward();
    _timer?.cancel();
    _timer = Timer(data.duration, controller.dismiss);
  }
}

class _ToastData {
  const _ToastData({
    required this.message,
    required this.title,
    required this.type,
    required this.duration,
    this.action,
  });

  final String message;
  final String title;
  final AppToastType type;
  final Duration duration;
  final AppToastAction? action;
}

class _ToastController {
  _ToastController({required this.data})
      : _animationController = AnimationController(
          vsync: _ToastTicker.instance,
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 180),
        );

  final _ToastData data;
  final AnimationController _animationController;
  bool _dismissed = false;
  VoidCallback? _onDismissed;

  Animation<double> get animation => CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

  void setOnDismissed(VoidCallback callback) => _onDismissed = callback;

  void forward() => _animationController.forward();

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _animationController.reverse().then((_) => _onDismissed?.call());
  }

  void dispose() => _animationController.dispose();
}

class _ToastTicker extends TickerProvider {
  _ToastTicker._();

  static final _ToastTicker instance = _ToastTicker._();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

class _ToastView extends StatefulWidget {
  const _ToastView({required this.controller, required this.onDismissed});

  final _ToastController controller;
  final VoidCallback onDismissed;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  @override
  void initState() {
    super.initState();
    widget.controller.setOnDismissed(widget.onDismissed);
  }

  @override
  Widget build(BuildContext context) {
    final _ToastData data = widget.controller.data;
    final Color accent = _accentOf(data.type);
    final IconData icon = _iconOf(data.type);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 14,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: widget.controller.animation,
        builder: (BuildContext context, Widget? child) {
          final double value = widget.controller.animation.value;
          return Transform.translate(
            offset: Offset(0, -24 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 4,
                    child: Container(color: accent),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(icon, color: accent, size: 21),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                data.title,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                data.message,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.3,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (data.action != null) ...<Widget>[
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () {
                                    data.action!.onPressed();
                                    widget.controller.dismiss();
                                  },
                                  child: Text(
                                    data.action!.label,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: widget.controller.dismiss,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _accentOf(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return AppColors.success;
      case AppToastType.error:
        return AppColors.danger;
      case AppToastType.warning:
        return AppColors.warning;
      case AppToastType.info:
        return AppColors.blue;
    }
  }

  IconData _iconOf(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.error:
        return Icons.error_rounded;
      case AppToastType.warning:
        return Icons.warning_amber_rounded;
      case AppToastType.info:
        return Icons.info_rounded;
    }
  }
}
