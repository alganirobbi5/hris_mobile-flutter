import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/cuti_refresh.dart';
import '../services/izin_keluar_service.dart';
import '../services/leave_leader_service.dart';
import '../services/riwayat_cuti_service.dart';
import '../theme/app_theme.dart';
import '../widgets/riwayat_cuti_izin_keluar.dart';
import '../widgets/section_card.dart';
import 'cuti_screen.dart';
import 'izin_keluar_screen.dart';

class LayananCutiScreen extends StatefulWidget {
  const LayananCutiScreen({
    super.key,
    this.cutiLoader,
    this.izinLoader,
    this.httpClient,
  });

  final Future<List<RiwayatCutiItem>> Function()? cutiLoader;
  final Future<List<IzinKeluarItem>> Function()? izinLoader;
  final http.Client? httpClient;

  @override
  State<LayananCutiScreen> createState() => _LayananCutiScreenState();
}

class _LayananCutiScreenState extends State<LayananCutiScreen> {
  List<LeaveLeader> _leaders = const <LeaveLeader>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLeaders();
  }

  Future<void> _fetchLeaders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final LeaveLeadersResult result = await LeaveLeaderService.fetch(
        includeEligible: false,
        client: widget.httpClient,
      );
      if (!mounted) return;
      setState(() {
        _leaders = result.leaders;
        _isLoading = false;
      });
    } on LeaveLeaderException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal terhubung ke server';
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _fetchLeaders();
    CutiRefresh.notify();
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  Widget _buildLeaderCard() {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Leader Pemberi Izin Cuti',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Column(
              children: <Widget>[
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _fetchLeaders,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ],
            )
          else if (_leaders.isEmpty)
            const Text(
              'Belum ada Leader terdaftar.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const <DataColumn>[
                  DataColumn(label: Text('No')),
                  DataColumn(label: Text('Nama Leader')),
                  DataColumn(label: Text('Jabatan')),
                ],
                rows: _leaders.asMap().entries.map((MapEntry<int, LeaveLeader> e) {
                  final LeaveLeader leader = e.value;
                  return DataRow(
                    cells: <DataCell>[
                      DataCell(Text('${e.key + 1}')),
                      DataCell(Text(leader.displayName)),
                      DataCell(
                        Text(
                          leader.jabatan.isEmpty ? '-' : leader.jabatan,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 28, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuti & Izin Keluar')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: <Widget>[
              _buildLeaderCard(),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.calendar_month_outlined,
                      label: 'Pengajuan Cuti',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const CutiScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      icon: Icons.exit_to_app_rounded,
                      label: 'Izin Keluar',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const IzinKeluarScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Riwayat Cuti & Izin Keluar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              RiwayatCutiIzinKeluar(
                cutiLoader: widget.cutiLoader,
                izinLoader: widget.izinLoader,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
