import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late final Future<bool> _isHrFuture;
  late final Future<bool> _isLeaderFuture;
  PageController? _pageController;
  Timer? _pollingTimer;
  bool _isHr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isHrFuture = _loadRole();
    _isLeaderFuture = _loadLeader();
    _startPolling();
  }

  Future<void> _startPolling() async {
    await AppNotificationService.initialize();
    await AbsenPollingService.loadSeen();
    final bool isHr = await _isHrFuture;
    if (!mounted || !isHr) return;
    setState(() => _isHr = isHr);
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

  Future<bool> _loadRole() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String role = (prefs.getString('role') ?? '').trim().toLowerCase();
      return role == 'hr';
    } catch (_) {
      return false;
    }
  }

  Future<bool> _loadLeader() async {
    await AppSession.refreshFromMe();
    if (!mounted) return AppSession.getLeaveLeaderFlag();
    final bool isLeader = await AppSession.resolveIsLeaveLeader();
    return isLeader;
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

  List<Widget> _screens({required bool isHr, required bool canApprove}) => <Widget>[
    const AbsenScreen(),
    const LayananCutiScreen(),
    const PengumumanScreen(),
    if (canApprove)
      SettingsScreen(isHr: isHr, canApprove: canApprove),
  ];

  List<AppNavItem> _navItems({required bool canApprove}) => <AppNavItem>[
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
    if (canApprove)
      const AppNavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isHrFuture,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool isHr = snapshot.data ?? false;
        return FutureBuilder<bool>(
          future: _isLeaderFuture,
          builder: (BuildContext context, AsyncSnapshot<bool> leaderSnapshot) {
            final bool canApprove = isHr || (leaderSnapshot.data ?? false);
            final List<Widget> screens =
                _screens(isHr: isHr, canApprove: canApprove);
            final List<AppNavItem> navItems =
                _navItems(canApprove: canApprove);
            final int index =
                _currentIndex < screens.length ? _currentIndex : 0;
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

