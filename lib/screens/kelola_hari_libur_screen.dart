import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_session.dart';
import '../services/holidays_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_refresh_indicator.dart';
import '../widgets/app_text_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/holiday_badge.dart';

class KelolaHariLiburScreen extends StatefulWidget {
  const KelolaHariLiburScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<KelolaHariLiburScreen> createState() => _KelolaHariLiburScreenState();
}

class _KelolaHariLiburScreenState extends State<KelolaHariLiburScreen> {
  List<HolidayItem> _items = const <HolidayItem>[];
  bool _isLoading = true;
  String? _error;
  final Set<int> _deletingIds = <int>{};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<HolidayItem> items = await HolidayService.fetch(
        client: widget.httpClient,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } on HolidayException catch (e) {
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

  bool _bolehHapus(HolidayItem item) {
    if (AppSession.isSuperAdmin) return item.isNational;
    if (AppSession.isHr) return !item.isNational;
    return false;
  }

  Future<void> _tambah() async {
    final _HolidayFormResult? hasil = await showDialog<_HolidayFormResult>(
      context: context,
      builder: (BuildContext dialogContext) => const _HolidayFormDialog(),
    );
    if (hasil == null || !mounted) return;
    try {
      await HolidayService.add(
        date: hasil.date,
        title: hasil.title,
        description: hasil.description,
        isNational: AppSession.isSuperAdmin,
        client: widget.httpClient,
      );
      if (!mounted) return;
      AppToast.success('Hari libur berhasil ditambahkan');
      await _fetch();
    } on HolidayException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Gagal terhubung ke server');
    }
  }

  Future<void> _hapus(HolidayItem item) async {
    final bool? konfirmasi = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Hapus hari libur?'),
        content: Text('${item.title} (${item.tanggalRingkas}) akan dihapus.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (konfirmasi != true || !mounted) return;
    setState(() => _deletingIds.add(item.id));
    try {
      await HolidayService.remove(item.id, client: widget.httpClient);
      if (!mounted) return;
      AppToast.success('Hari libur berhasil dihapus');
      await _fetch();
    } on HolidayException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Gagal terhubung ke server');
    } finally {
      if (mounted) setState(() => _deletingIds.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(title: const Text('Kelola Hari Libur')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _tambah,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Hari Libur'),
      ),
      body: SafeArea(
        top: false,
        child: AppRefreshIndicator(
          onRefresh: _fetch,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: <Widget>[
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _fetch,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Belum ada hari libur',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              else
                ..._items.map(
                  (HolidayItem item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        title: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          <String>[
                            item.tanggalRingkas,
                            item.description,
                          ].where((String value) => value.isNotEmpty).join(' • '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            HolidayBadge(isNational: item.isNational),
                            if (_bolehHapus(item))
                              IconButton(
                                onPressed: _deletingIds.contains(item.id)
                                    ? null
                                    : () => _hapus(item),
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: AppColors.danger,
                                tooltip: 'Hapus hari libur',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HolidayFormResult {
  const _HolidayFormResult({
    required this.date,
    required this.title,
    required this.description,
  });

  final DateTime date;
  final String title;
  final String description;
}

class _HolidayFormDialog extends StatefulWidget {
  const _HolidayFormDialog();

  @override
  State<_HolidayFormDialog> createState() => _HolidayFormDialogState();
}

class _HolidayFormDialogState extends State<_HolidayFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _tanggalController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  DateTime? _tanggal;

  @override
  void dispose() {
    _tanggalController.dispose();
    _namaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _pilihTanggal() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tanggal ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Pilih Tanggal Libur',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggal = DateTime(picked.year, picked.month, picked.day);
      _tanggalController.text = HolidayItem.toIsoDate(_tanggal!);
    });
    _formKey.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Hari Libur'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const FormSectionHeader(
                title: 'Detail Hari Libur',
                icon: Icons.event_available_outlined,
              ),
              AppTextField(
                label: 'Tanggal Libur',
                hint: 'Pilih tanggal',
                controller: _tanggalController,
                readOnly: true,
                prefixIcon: Icons.calendar_month_outlined,
                suffixIcon: const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: AppColors.textSecondary,
                ),
                onTap: _pilihTanggal,
                validator: (String? value) =>
                    _tanggal == null ? 'Tanggal libur wajib dipilih' : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Nama Hari Libur',
                hint: 'Contoh: Hari Raya Idul Fitri',
                controller: _namaController,
                prefixIcon: Icons.event_note_outlined,
                validator: (String? value) =>
                    (value == null || value.trim().isEmpty)
                        ? 'Nama hari libur wajib diisi'
                        : null,
              ),
              const SizedBox(height: 14),
              AppTextField(
                label: 'Keterangan (Opsional)',
                hint: 'Tambahkan keterangan',
                controller: _keteranganController,
                prefixIcon: Icons.notes_outlined,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _HolidayFormResult(
                date: _tanggal!,
                title: _namaController.text.trim(),
                description: _keteranganController.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
