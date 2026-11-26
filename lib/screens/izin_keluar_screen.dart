import 'package:flutter/material.dart';

import '../widgets/glass_app_bar.dart';

import '../services/app_session.dart';
import '../services/izin_keluar_service.dart';
import '../services/leave_leader_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';

class IzinKeluarScreen extends StatefulWidget {
  const IzinKeluarScreen({
    super.key,
    this.hrMode = false,
    this.embedded = false,
  });

  final bool hrMode;
  final bool embedded;

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

  static const List<MapEntry<String, String>> filterList =
      <MapEntry<String, String>>[
    MapEntry<String, String>('all', 'Semua'),
    MapEntry<String, String>('pending', 'Menunggu'),
    MapEntry<String, String>('approved', 'Disetujui'),
    MapEntry<String, String>('rejected', 'Ditolak'),
  ];

  final TextEditingController _alasanController = TextEditingController();
  final TextEditingController _catatanController = TextEditingController();

  bool _isHr = false;
  bool _isLeader = false;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isDeciding = false;
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
  String _filter = 'all';
  List<LeaveLeader> _leaders = const <LeaveLeader>[];
  int? _selectedLeaderId;

  @override
  void initState() {
    super.initState();
    _resolveRole();
    _fetchLeaders();
  }

  Future<void> _fetchLeaders() async {
    try {
      final LeaveLeadersResult result = await LeaveLeaderService.fetch();
      if (!mounted) return;
      setState(() => _leaders = result.leaders);
    } on LeaveLeaderException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage('Gagal memuat daftar leader.');
    }
  }

  @override
  void dispose() {
    _alasanController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _resolveRole() async {
    final String? role = await AppSession.resolveRole();
    await AppSession.refreshFromMe();
    if (!mounted) return;
    setState(() {
      _isHr = widget.hrMode || AppSession.isHrRole(role);
      _isLeader = !_isHr && AppSession.getLeaveLeaderFlag();
    });
    await _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final bool lihatSemua = _isHr || _isLeader;
      final List<IzinKeluarItem> items = await IzinKeluarService.fetch(
        allScope: lihatSemua,
        status: lihatSemua ? _filter : null,
      );
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

  Future<void> _decide(IzinKeluarItem item, String status) async {
    _catatanController.clear();
    final String? catatan = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(status == 'approved' ? 'Setujui izin keluar?' : 'Tolak izin keluar?'),
        content: TextField(
          controller: _catatanController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Catatan (opsional)',
            hintText: 'Tulis catatan untuk karyawan',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_catatanController.text.trim()),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    if (catatan == null || !mounted) return;

    setState(() => _isDeciding = true);
    try {
      await IzinKeluarService.decide(item.id, status, catatanHr: catatan);
      if (!mounted) return;
      _showMessage(
        status == 'approved'
            ? 'Pengajuan disetujui.'
            : 'Pengajuan ditolak.',
      );
      await _fetchData();
    } on IzinKeluarException catch (e) {
      if (mounted) _showMessage(e.message);
    } catch (_) {
      if (mounted) _showMessage('Gagal terhubung ke server.');
    } finally {
      if (mounted) setState(() => _isDeciding = false);
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
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Disetujui';
      case 'rejected':
        return 'Ditolak';
      default:
        return 'Menunggu';
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = RefreshIndicator(
      onRefresh: () async {
        await _fetchLeaders();
        await _fetchData();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: <Widget>[
          if (!_isHr && !_isLeader) _buildForm(),
          if (!_isHr && !_isLeader) const SizedBox(height: 16),
          if (_isHr || _isLeader) _buildFilter(),
          if (_isHr || _isLeader) const SizedBox(height: 12),
          _buildList(),
        ],
      ),
    );

    if (widget.embedded) return content;

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(
          _isHr || _isLeader ? 'Persetujuan Izin Keluar' : 'Izin Keluar',
        ),
      ),
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
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Kembali ke kantor setelah selesai',
              style: TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
            ),
            value: _kembaliKeKantor,
            activeThumbColor: AppColors.primary,
            onChanged: (bool value) => setState(() => _kembaliKeKantor = value),
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

  Widget _buildFilter() {
    return Row(
      children: filterList.map((MapEntry<String, String> entry) {
        final bool active = _filter == entry.key;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(entry.value),
            selected: active,
            onSelected: _isLoading
                ? null
                : (bool selected) {
                    if (!selected) return;
                    setState(() => _filter = entry.key);
                    _fetchData();
                  },
          ),
        );
      }).toList(),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if ((_isHr || _isLeader) && item.namaKaryawan.isNotEmpty)
                      Text(
                        item.namaKaryawan,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      '${item.tanggal} • $jam',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
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
          if ((_isHr || _isLeader) && item.status.toLowerCase() == 'pending') ...<Widget>[
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isDeciding
                        ? null
                        : () => _decide(item, 'rejected'),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _isDeciding
                        ? null
                        : () => _decide(item, 'approved'),
                    child: const Text('Setujui'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
