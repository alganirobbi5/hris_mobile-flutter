import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/glass_bottom_nav.dart';
import 'absen_screen.dart';
import 'approval_cuti_screen.dart';
import 'cuti_screen.dart';
import 'laporan_screen.dart';
import 'profil_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _isHr = false;

  List<Widget> get _screens => <Widget>[
    const AbsenScreen(),
    const CutiScreen(),
    const LaporanScreen(),
    const ProfilScreen(),
    if (_isHr) const ApprovalCutiScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String role = (prefs.getString('role') ?? '').trim().toLowerCase();
      if (!mounted) return;
      if (role == 'hr' && !_isHr) {
        setState(() => _isHr = true);
      }
    } catch (_) {
      // Abaikan kegagalan membaca preferensi; tampilkan tab default.
    }
  }

  List<AppNavItem> get _navItems => <AppNavItem>[
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
      icon: Icons.description_outlined,
      activeIcon: Icons.description_rounded,
      label: 'Laporan',
    ),
    const AppNavItem(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Profil',
    ),
    if (_isHr)
      const AppNavItem(
        icon: Icons.fact_check_outlined,
        activeIcon: Icons.fact_check_rounded,
        label: 'Persetujuan',
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: _navItems,
            ),
          ),
        ],
      ),
    );
  }
}
