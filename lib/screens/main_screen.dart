import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/glass_bottom_nav.dart';
import 'absen_screen.dart';
import 'approval_cuti_screen.dart';
import 'cuti_screen.dart';
import 'laporan_screen.dart';
import 'pengumuman_screen.dart';
import 'profil_screen.dart';
import 'semua_absensi_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final Future<bool> _isHrFuture;
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    _isHrFuture = _loadRole();
  }

  @override
  void dispose() {
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

  void _goToPage(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController?.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  List<Widget> _screens(bool isHr) => <Widget>[
    const AbsenScreen(),
    const CutiScreen(),
    const PengumumanScreen(),
    if (isHr) const LaporanScreen(),
    const ProfilScreen(),
    if (isHr) const ApprovalCutiScreen(),
  ];

  List<AppNavItem> _navItems(bool isHr) => <AppNavItem>[
    const AppNavItem(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt_rounded,
      label: 'Absen',
    ),
    const AppNavItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Cuti',
    ),
    const AppNavItem(
      icon: Icons.campaign_outlined,
      activeIcon: Icons.campaign_rounded,
      label: 'Pengumuman',
    ),
    if (isHr)
      const AppNavItem(
        icon: Icons.description_outlined,
        activeIcon: Icons.description_rounded,
        label: 'Laporan',
      ),
    const AppNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
    if (isHr)
      const AppNavItem(
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        label: 'Persetujuan',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isHrFuture,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        final bool isHr = snapshot.data ?? false;
        final List<Widget> screens = _screens(isHr);
        final List<AppNavItem> navItems = _navItems(isHr);
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
          floatingActionButton: isHr
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 88),
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SemuaAbsensiScreen(),
                        ),
                      );
                    },
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.table_chart_rounded),
                    label: const Text('Semua Absensi'),
                  ),
                )
              : null,
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

