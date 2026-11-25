import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/company_profile.dart';
import '../services/laporan_excel_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/section_card.dart';
import 'semua_absensi_screen.dart';

class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key});

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

enum LaporanPeriode { harian, mingguan, bulanan, tahunan, rentang }

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

  LaporanPeriode _periode = LaporanPeriode.harian;
  DateTime _tanggalAcuan = DateTime.now();
  DateTime? _rentangMulai;
  DateTime? _rentangAkhir;

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

  String _formatTanggalApi(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  ({DateTime mulai, DateTime akhir}) _rentangTerpilih() {
    final DateTime t = _tanggalAcuan;
    switch (_periode) {
      case LaporanPeriode.harian:
        return (mulai: t, akhir: t);
      case LaporanPeriode.mingguan:
        final DateTime mulai = t.subtract(Duration(days: t.weekday - 1));
        return (mulai: mulai, akhir: mulai.add(const Duration(days: 6)));
      case LaporanPeriode.bulanan:
        return (
          mulai: DateTime(t.year, t.month),
          akhir: DateTime(t.year, t.month + 1, 0),
        );
      case LaporanPeriode.tahunan:
        return (mulai: DateTime(t.year), akhir: DateTime(t.year, 12, 31));
      case LaporanPeriode.rentang:
        return (
          mulai: _rentangMulai ?? t,
          akhir: _rentangAkhir ?? _rentangMulai ?? t,
        );
    }
  }

  String _labelPeriode(DateTime mulai, DateTime akhir) {
    final String awal = DateFormat('dd/MM/yyyy').format(mulai);
    final String akhirTeks = DateFormat('dd/MM/yyyy').format(akhir);
    final String nama = switch (_periode) {
      LaporanPeriode.harian => 'Harian',
      LaporanPeriode.mingguan => 'Mingguan',
      LaporanPeriode.bulanan => 'Bulanan',
      LaporanPeriode.tahunan => 'Tahunan',
      LaporanPeriode.rentang => 'Rentang',
    };
    return awal == akhirTeks
        ? '$awal ($nama)'
        : '$awal s/d $akhirTeks ($nama)';
  }

  Future<void> _pilihTanggalAcuan() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tanggalAcuan,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Pilih tanggal acuan',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggalAcuan = picked;
      _rentangMulai = picked;
      _rentangAkhir = picked;
    });
  }

  Future<void> _pilihTanggalRentang({required bool mulai}) async {
    final DateTime initial = mulai
        ? (_rentangMulai ?? _tanggalAcuan)
        : (_rentangAkhir ?? _rentangMulai ?? _tanggalAcuan);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: mulai ? 'Pilih tanggal mulai' : 'Pilih tanggal akhir',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (mulai) {
        _rentangMulai = picked;
        if (_rentangAkhir != null && _rentangAkhir!.isBefore(picked)) {
          _rentangAkhir = picked;
        }
      } else {
        final DateTime awal = _rentangMulai ?? _tanggalAcuan;
        _rentangAkhir = picked.isBefore(awal) ? awal : picked;
      }
    });
  }

  Future<void> _downloadExcel() async {
    setState(() => _isLoading = true);

    try {
      final DateTime acuan = _tanggalAcuan;
      final DateTime mulai = _periode == LaporanPeriode.rentang
          ? (_rentangMulai ?? acuan)
          : _rentangTerpilih().mulai;
      final DateTime akhir = _periode == LaporanPeriode.rentang
          ? (_rentangAkhir ?? _rentangMulai ?? acuan)
          : _rentangTerpilih().akhir;
      if (mulai.isAfter(akhir)) {
        throw const LaporanExcelException(
          'Tanggal akhir tidak boleh sebelum tanggal mulai.',
        );
      }
      final String label = _labelPeriode(mulai, akhir);
      await CompanyProfile.load();
      await _excelService.exportAndShare(
        startDate: _formatTanggalApi(mulai),
        endDate: _formatTanggalApi(akhir),
        periodeLabel: label,
        namaPerusahaan: CompanyProfile.current.name,
      );

      if (!mounted) return;
      AppToast.success('Laporan Excel berhasil dibuat.');
    } on LaporanExcelException catch (e) {
      if (!mounted) return;
      AppToast.error(e.message);
    } catch (e) {
      if (!mounted) return;
      AppToast.error('Gagal membuat laporan: $e');
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
        child: RefreshIndicator(
          onRefresh: () async {
            await _muatRows();
            _fetchSemuaAbsensi();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                    const SizedBox(height: 20),

                    const Text(
                      'Periode laporan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LaporanPeriode.values.map((LaporanPeriode p) {
                        final String label = switch (p) {
                          LaporanPeriode.harian => 'Harian',
                          LaporanPeriode.mingguan => 'Mingguan',
                          LaporanPeriode.bulanan => 'Bulanan',
                          LaporanPeriode.tahunan => 'Tahunan',
                          LaporanPeriode.rentang => 'Rentang',
                        };
                        return ChoiceChip(
                          label: Text(label),
                          selected: _periode == p,
                          onSelected: _isLoading
                              ? null
                              : (bool selected) {
                                  if (!selected) return;
                                  setState(() => _periode = p);
                                },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pilihTanggalAcuan,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        _periode == LaporanPeriode.rentang
                            ? 'Mulai: ${DateFormat('dd/MM/yyyy').format(_rentangMulai ?? _tanggalAcuan)}  �  Akhir: ${DateFormat('dd/MM/yyyy').format(_rentangAkhir ?? _rentangMulai ?? _tanggalAcuan)}'
                            : 'Tanggal acuan: ${DateFormat('dd/MM/yyyy').format(_tanggalAcuan)}',
                      ),
                    ),
                    if (_periode == LaporanPeriode.rentang) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _pilihTanggalRentang(mulai: true),
                              child: Text(
                                'Mulai: ${DateFormat('dd/MM/yyyy').format(_rentangMulai ?? _tanggalAcuan)}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => _pilihTanggalRentang(mulai: false),
                              child: Text(
                                'Akhir: ${DateFormat('dd/MM/yyyy').format(_rentangAkhir ?? _rentangMulai ?? _tanggalAcuan)}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),

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
      ),
    );
  }
}

