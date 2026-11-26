import 'dart:async';

import 'package:flutter/material.dart';

import '../services/absen_polling_service.dart';
import '../services/app_session.dart';
import '../services/notification_service.dart';
import '../widgets/glass_bottom_nav.dart';
import '../widgets/profile_avatar_button.dart';
import 'absen_screen.dart';
import 'layanan_cuti_screen.dart';
import 'pengumuman_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

typedef _AksesNavigasi = ({bool isHr, bool tampilPersetujuan});

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final Future<_AksesNavigasi> _aksesFuture;
  PageController? _pageController;
  Timer? _pollingTimer;
  bool _isHr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _aksesFuture = _loadAkses();
    _startPolling();
  }

  Future<void> _startPolling() async {
    await AppNotificationService.initialize();
    await AbsenPollingService.loadSeen();
    final _AksesNavigasi akses = await _aksesFuture;
    if (!mounted || !akses.isHr) return;
    setState(() => _isHr = akses.isHr);
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => AbsenPollingService.pollOnce(),
    );
    AbsenPollingService.pollOnce();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isHr) {
      AbsenPollingService.pollOnce();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  Future<_AksesNavigasi> _loadAkses() async {
    try {
      final String? role = await AppSession.resolveRole();
      await AppSession.refreshLeaderStatus();
      final bool isHr = AppSession.isHrRole(role);
      return (
        isHr: isHr,
        tampilPersetujuan: isHr || AppSession.isLeaveLeader,
      );
    } catch (_) {
      return (isHr: false, tampilPersetujuan: false);
    }
  }

  void _goToPage(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> _screens(_AksesNavigasi akses) => <Widget>[
    const AbsenScreen(),
    const LayananCutiScreen(),
    const PengumumanScreen(),
    if (akses.tampilPersetujuan)
      SettingsScreen(
        isHr: akses.isHr,
        canApprove: akses.tampilPersetujuan,
      ),
  ];

  List<AppNavItem> _navItems(_AksesNavigasi akses) => <AppNavItem>[
    const AppNavItem(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt_rounded,
      label: 'Absen',
    ),
    const AppNavItem(
      icon: Icons.event_available_outlined,
      activeIcon: Icons.event_available_rounded,
      label: 'Cuti & Izin',
    ),
    const AppNavItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      label: 'Pengumuman',
    ),
    if (akses.tampilPersetujuan)
      const AppNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AksesNavigasi>(
      future: _aksesFuture,
      builder: (
        BuildContext context,
        AsyncSnapshot<_AksesNavigasi> snapshot,
      ) {
        final _AksesNavigasi akses = snapshot.data ??
            const (isHr: false, tampilPersetujuan: false);
        final List<Widget> screens = _screens(akses);
        final List<AppNavItem> navItems = _navItems(akses);
        final int index = _currentIndex < screens.length ? _currentIndex : 0;
        _pageController ??= PageController(initialPage: index);

            return Scaffold(
              extendBody: true,
              body: Stack(
                children: [
                  PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (int pageIndex) {
                      if (pageIndex != _currentIndex) {
                        setState(() => _currentIndex = pageIndex);
                      }
                    },
                    children: [
                      for (final Widget screen in screens)
                        _KeepAlivePage(child: screen),
                    ],
                  ),
                  const ProfileAvatarButton(),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GlassBottomNav(
                      currentIndex: index,
                      onTap: _goToPage,
                      items: navItems,
                    ),
                  ),
                ],
              ),
        );
      },
    );
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin<_KeepAlivePage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

