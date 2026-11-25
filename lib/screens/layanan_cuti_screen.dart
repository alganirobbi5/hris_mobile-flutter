import 'package:flutter/material.dart';

import 'cuti_screen.dart';
import 'izin_keluar_screen.dart';

class LayananCutiScreen extends StatelessWidget {
  const LayananCutiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuti & Izin Keluar'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.event_available_outlined, size: 20),
                text: 'Pengajuan Cuti',
              ),
              Tab(
                icon: Icon(Icons.exit_to_app_rounded, size: 20),
                text: 'Izin Keluar',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 20),
                text: 'Riwayat Cuti',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            CutiScreen(embedded: true),
            IzinKeluarScreen(embedded: true),
            CutiScreen(embedded: true, onlyHistory: true),
          ],
        ),
      ),
    );
  }
}
