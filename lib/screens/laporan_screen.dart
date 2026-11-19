import 'package:flutter/material.dart';

import '../services/laporan_excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import 'semua_absensi_screen.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen>
    with WidgetsBindingObserver {
  final LaporanExcelService _excelService = LaporanExcelService();
  final GlobalKey<SemuaAbsensiViewState> _absensiKey =
      GlobalKey<SemuaAbsensiViewState>();

  bool _isLoading = false;
  bool _isLoadingRows = false;
  List<LaporanAbsensiRow> _rows = const <LaporanAbsensiRow>[];
  String? _rowsError;
  String _tanggalAktif = LaporanExcelService.tanggalHariIni();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _muatRows();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSemuaAbsensi();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshJikaTanggalBerubah();
  }

  Future<void> _refreshJikaTanggalBerubah() async {
    final String hariIni = LaporanExcelService.tanggalHariIni();
    if (hariIni != _tanggalAktif) await _muatRows();
  }

  Future<void> _muatRows() async {
    setState(() {
      _isLoadingRows = true;
      _rowsError = null;
      _tanggalAktif = LaporanExcelService.tanggalHariIni();
    });

    try {
      final List<LaporanAbsensiRow> rows =
          await _excelService.fetchHariIni();
      if (!mounted) return;
      setState(() => _rows = rows);
    } on LaporanExcelException catch (e) {
      if (!mounted) return;
      setState(() => _rowsError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _rowsError = 'Gagal memuat data absensi.');
    } finally {
      if (mounted) setState(() => _isLoadingRows = false);
    }
  }

  void _fetchSemuaAbsensi() {
    _absensiKey.currentState?.reload();
  }

  Future<void> _downloadExcel() async {
    setState(() => _isLoading = true);

    try {
      await _excelService.exportAndShare();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan Excel berhasil dibuat.')),
      );
    } on LaporanExcelException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal membuat laporan: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTabel() {
    if (_isLoadingRows) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_rowsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              _rowsError!,
              style: const TextStyle(fontSize: 13, color: AppColors.danger),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _muatRows,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_rows.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Belum ada data absensi hari ini.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              AppColors.primary.withValues(alpha: 0.1),
            ),
            columnSpacing: 16,
            columns: const <DataColumn>[
              DataColumn(label: Text('Tanggal')),
              DataColumn(label: Text('Nama')),
              DataColumn(label: Text('Masuk')),
              DataColumn(label: Text('Keluar')),
              DataColumn(label: Text('Status')),
            ],
            rows: _rows.map((row) {
              final String status = row.statusTampil;
              final Color statusColor = status == '-'
                  ? AppColors.textSecondary
                  : row.terlambat
                      ? AppColors.danger
                      : AppColors.success;
              return DataRow(
                cells: <DataCell>[
                  DataCell(Text(row.tanggalTampil)),
                  DataCell(Text(row.nama)),
                  DataCell(Text(row.jamMasukTampil)),
                  DataCell(Text(row.jamKeluarTampil)),
                  DataCell(
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total ${_rows.length} karyawan absen hari ini',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laporan Absensi',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Export data absensi ke file Excel',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'HR',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Card Export
              SectionCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.grid_on_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Export data absensi',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Format file: .xlsx (Microsoft Excel)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Tombol Download
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _downloadExcel,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.download_rounded),
                        label: Text(
                          _isLoading ? 'Memproses...' : 'Export ke Excel',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Ringkasan absensi hari ini (langsung dari database)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Absensi hari ini ($_tanggalAktif)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _isLoadingRows ? null : _muatRows,
                          icon: const Icon(Icons.refresh_rounded),
                          color: AppColors.primary,
                          tooltip: 'Muat ulang',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildTabel(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tabel absensi seluruh karyawan
              SemuaAbsensiView(
                key: _absensiKey,
                autoFetch: false,
                showHeader: false,
              ),

              const SizedBox(height: 16),

              // Info Card
              SectionCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Laporan dibuat langsung di perangkat dalam format Excel '
                        '(.xlsx) yang rapi dan siap dicetak, mencakup tanggal, '
                        'nama karyawan, jam masuk, jam keluar, status kehadiran, '
                        'foto, alamat, dan koordinat.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

