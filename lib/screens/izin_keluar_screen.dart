import 'package:flutter/material.dart';

import '../services/app_session.dart';
import '../services/izin_keluar_service.dart';
import '../widgets/glass_app_bar.dart';
import '../services/leave_leader_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/app_refresh_indicator.dart';

class IzinKeluarScreen extends StatefulWidget {
  const IzinKeluarScreen({
    super.key,
    this.embedded = false,
    this.loader,
    this.leaderLoader,
  });

  final bool embedded;
  final Future<List<IzinKeluarItem>> Function()? loader;
  final Future<LeaveLeadersResult> Function()? leaderLoader;

  @override
  State<IzinKeluarScreen> createState() => _IzinKeluarScreenState();
}

class _IzinKeluarScreenState extends State<IzinKeluarScreen> {
  static const List<String> kategoriList = <String>[
    'Tugas Luar Kantor',
    'Keluarga / Saudara Sakit',
    'Keperluan Pribadi',
    'Lainnya',
  ];

  final TextEditingController _alasanController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;
  List<IzinKeluarItem> _items = const <IzinKeluarItem>[];

  DateTime _tanggal = DateTime.now();
  TimeOfDay _jamKeluar = TimeOfDay.now();
  TimeOfDay _jamKembali = TimeOfDay(
    hour: (TimeOfDay.now().hour + 2) % 24,
    minute: TimeOfDay.now().minute,
  );
  bool _kembaliKeKantor = true;
  String _kategori = kategoriList.first;
  List<LeaveLeader> _leaders = const <LeaveLeader>[];
  int? _selectedLeaderId;

  @override
  void initState() {
    super.initState();
    _fetchLeaders();
    _fetchData();
  }

  Future<void> _fetchLeaders() async {
    try {
      final int? currentUserId = await AppSession.resolveUserId();
      final LeaveLeadersResult result = widget.leaderLoader != null
          ? await widget.leaderLoader!()
          : await LeaveLeaderService.fetch();
      if (!mounted) return;
      setState(() {
        _leaders = LeaveLeaderService.tanpaDiriSendiri(
          result.leaders,
          currentUserId,
        );
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    _alasanController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<IzinKeluarItem> items = widget.loader != null
          ? await widget.loader!()
          : await IzinKeluarService.fetch();
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on IzinKeluarException catch (e) {
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

  Future<void> _submit() async {
    final String alasan = _alasanController.text.trim();
    if (alasan.isEmpty) {
      _showMessage('Alasan wajib diisi.');
      return;
    }
    if (_selectedLeaderId == null) {
      _showMessage('Pilih Leader pemberi persetujuan terlebih dahulu.');
      return;
    }
    if (!mounted) return;
    setState(() => _isSubmitting = true);
    try {
      await IzinKeluarService.ajukan(
        tanggal: _tanggalString(),
        jamKeluar: _jamString(_jamKeluar),
        jamKembali: _kembaliKeKantor ? _jamString(_jamKembali) : null,
        kembaliKeKantor: _kembaliKeKantor,
        kategori: _kategori,
        alasan: alasan,
        leaderUserId: _selectedLeaderId!,
      );
      if (!mounted) return;
      _alasanController.clear();
      _showMessage('Pengajuan izin keluar berhasil dikirim.');
      await _fetchData();
    } on IzinKeluarException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _tanggalString() {
    return '${_tanggal.year}-'
        '${_tanggal.month.toString().padLeft(2, '0')}-'
        '${_tanggal.day.toString().padLeft(2, '0')}';
  }

  String _jamString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pilihTanggal() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _tanggal = picked);
  }

  Future<void> _pilihJam(bool keluar) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: keluar ? _jamKeluar : _jamKembali,
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (keluar) {
        _jamKeluar = picked;
      } else {
        _jamKembali = picked;
      }
    });
  }

  String _statusLabel(String status) {
    final String value = status.trim().toLowerCase();
    if (value == '2' ||
        value == 'disetujui' ||
        value == 'approved' ||
        value == 'approve') {
      return 'Disetujui';
    }
    if (value == '3' ||
        value == 'ditolak' ||
        value == 'rejected' ||
        value == 'reject') {
      return 'Ditolak';
    }
    return 'Menunggu';
  }

  Color _statusColor(String status) {
    switch (_statusLabel(status)) {
      case 'Disetujui':
        return AppColors.success;
      case 'Ditolak':
        return AppColors.danger;
      default:
        return AppColors.pending;
    }
  }

  Map<String, int> _ringkasanStatus() {
    int menunggu = 0;
    int disetujui = 0;
    int ditolak = 0;

    for (final IzinKeluarItem item in _items) {
      switch (_statusLabel(item.status)) {
        case 'Menunggu':
          menunggu++;
          break;
        case 'Disetujui':
          disetujui++;
          break;
        case 'Ditolak':
          ditolak++;
          break;
      }
    }

    return <String, int>{
      'menunggu': menunggu,
      'disetujui': disetujui,
      'ditolak': ditolak,
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, int> ringkasan = _ringkasanStatus();
    final Widget content = AppRefreshIndicator(
      onRefresh: _fetchData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: <Widget>[
          const Text(
            'Pengajuan Izin Keluar',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajukan izin keluar dan pantau status persetujuannya.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          _StatusSummary(
            menunggu: ringkasan['menunggu'] ?? 0,
            disetujui: ringkasan['disetujui'] ?? 0,
            ditolak: ringkasan['ditolak'] ?? 0,
          ),
          const SizedBox(height: 16),
          _buildForm(),
          const SizedBox(height: 20),
          const Text(
            'Riwayat Izin Keluar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildList(),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: GlassAppBar(title: const Text('Izin Keluar')),
      body: SafeArea(top: false, child: content),
    );
  }

  Widget _buildForm() {
    return SectionCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Pengajuan Izin Keluar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedLeaderId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Pilih Leader Pemberi Persetujuan',
            ),
            items: _leaders
                .map(
                  (LeaveLeader leader) => DropdownMenuItem<int>(
                    value: leader.userId,
                    child: Text(
                      leader.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (int? value) =>
                value == null ? 'Leader wajib dipilih' : null,
            onChanged: (int? value) {
              setState(() => _selectedLeaderId = value);
            },
          ),
          const SizedBox(height: 12),
          _buildPicker(
            label: 'Tanggal',
            value: _tanggalString(),
            icon: Icons.calendar_today_outlined,
            onTap: _pilihTanggal,
          ),
          const SizedBox(height: 12),
          _buildPicker(
            label: 'Jam Keluar',
            value: _jamString(_jamKeluar),
            icon: Icons.logout_rounded,
            onTap: () => _pilihJam(true),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Kembali ke kantor setelah selesai',
                style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
              ),
              value: _kembaliKeKantor,
              activeThumbColor: AppColors.primary,
              onChanged: (bool value) =>
                  setState(() => _kembaliKeKantor = value),
            ),
          ),
          if (_kembaliKeKantor) ...<Widget>[
            const SizedBox(height: 4),
            _buildPicker(
              label: 'Estimasi Jam Kembali',
              value: _jamString(_jamKembali),
              icon: Icons.login_rounded,
              onTap: () => _pilihJam(false),
            ),
          ],
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _kategori,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Kategori'),
            items: kategoriList
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value != null) setState(() => _kategori = value);
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            label: 'Alasan / Keterangan',
            hint: 'Tulis alasan izin keluar',
            controller: _alasanController,
            maxLines: 3,
            prefixIcon: Icons.notes_rounded,
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: _isSubmitting ? 'Mengirim...' : 'Kirim Pengajuan Izin Keluar',
            icon: Icons.send_rounded,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildPicker({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_error != null) {
      return SectionCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: Text(
              'Belum ada pengajuan izin keluar',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Column(
      children: _items
          .map(
            (IzinKeluarItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildItem(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildItem(IzinKeluarItem item) {
    final String statusLabel = _statusLabel(item.status);
    final Color statusColor = _statusColor(item.status);
    final String jam = item.jamKembaliPendek == '-'
        ? item.jamKeluarPendek
        : '${item.jamKeluarPendek} - ${item.jamKembaliPendek}';

    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${item.tanggal} • $jam',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              StatusBadge(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.kategori,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.alasan,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
          ),
          if (item.targetLeaderName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Ditujukan ke: ${item.targetLeaderName}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (item.approvedByName.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '$statusLabel oleh ${item.approvedByName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ],
          if (item.catatanHr.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Catatan HR: ${item.catatanHr}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusSummary extends StatelessWidget {
  const _StatusSummary({
    required this.menunggu,
    required this.disetujui,
    required this.ditolak,
  });

  final int menunggu;
  final int disetujui;
  final int ditolak;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Status pengajuan',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusCount(
                  label: 'Menunggu',
                  count: menunggu,
                  color: AppColors.pending,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusCount(
                  label: 'Disetujui',
                  count: disetujui,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusCount(
                  label: 'Ditolak',
                  count: ditolak,
                  color: AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
