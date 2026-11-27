import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/karyawan_service.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_toast.dart';
import '../widgets/app_text_field.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';

class EditKaryawanScreen extends StatefulWidget {
  const EditKaryawanScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<EditKaryawanScreen> createState() => _EditKaryawanScreenState();
}

class _EditKaryawanScreenState extends State<EditKaryawanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();

  http.Client? _ownedClient;

  http.Client get _httpClient {
    if (widget.httpClient != null) return widget.httpClient!;
    return _ownedClient ??= http.Client();
  }

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _status = '1';
  KaryawanItem? _selected;
  List<KaryawanItem> _karyawan = const <KaryawanItem>[];

  @override
  void initState() {
    super.initState();
    _fetchKaryawan();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    _namaController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _fetchKaryawan() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<KaryawanItem> hasil =
          await KaryawanService.fetchAll(client: _httpClient);
      if (!mounted) return;
      setState(() {
        _karyawan = hasil;
        _isLoading = false;
      });
    } on KaryawanServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _pilihKaryawan() async {
    final KaryawanItem? hasil = await showModalBottomSheet<KaryawanItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _KaryawanPickerSheet(items: _karyawan),
    );
    if (hasil == null || !mounted) return;
    setState(() {
      _selected = hasil;
      _namaController.text = hasil.namaLengkap;
      _usernameController.text = hasil.username;
      _emailController.text = hasil.email;
      _mobileController.text = hasil.mobileNo;
      _status = hasil.statusAktif ? '1' : '0';
    });
  }

  String? _wajib(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label wajib diisi';
    return null;
  }

  Future<void> _simpan() async {
    final KaryawanItem? karyawan = _selected;
    if (karyawan == null) {
      AppToast.error('Pilih karyawan terlebih dahulu.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isSaving = true);
    try {
      final String pesan = await KaryawanService.update(
        employeeId: karyawan.id,
        namaLengkap: _namaController.text.trim(),
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        mobileNo: _mobileController.text.trim(),
        statusAktif: _status == '1',
        client: _httpClient,
      );
      if (!mounted) return;
      AppToast.success(pesan);
    } on KaryawanServiceException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error('Terjadi kesalahan koneksi ke server');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Edit Karyawan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const FormSectionHeader(
                      title: 'Pilih Karyawan',
                      icon: Icons.person_search_rounded,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _fetchKaryawan,
                              child: const Text('Coba lagi'),
                            ),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _pilihKaryawan,
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Pilih Karyawan'),
                    ),
                    if (_selected != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Terpilih: ${_selected!.username} • '
                          '${_selected!.namaLengkap}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const FormSectionHeader(
                      title: 'Data Karyawan',
                      icon: Icons.person_outline_rounded,
                    ),
                    AppTextField(
                      label: 'Nama Lengkap',
                      hint: 'Masukkan nama lengkap',
                      controller: _namaController,
                      maxLength: 60,
                      prefixIcon: Icons.badge_outlined,
                      validator: (String? value) =>
                          _wajib(value, 'Nama Lengkap'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Username',
                      hint: 'Masukkan username',
                      controller: _usernameController,
                      maxLength: 30,
                      prefixIcon: Icons.person_outline_rounded,
                      validator: (String? value) => _wajib(value, 'Username'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Email',
                      hint: 'contoh: budi@perusahaan.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 40,
                      prefixIcon: Icons.mail_outline_rounded,
                      validator: (String? value) => _wajib(value, 'Email'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'No. HP (WhatsApp)',
                      hint: 'Contoh: 08123456789 atau 628123456789',
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      maxLength: 15,
                      prefixIcon: Icons.phone_outlined,
                      validator: WhatsAppHelper.validatePhone,
                    ),
                    const SizedBox(height: 16),
                    AppFormDropdown<String>(
                      label: 'Status Aktif',
                      value: _status,
                      hint: 'Pilih status',
                      prefixIcon: Icons.toggle_on_outlined,
                      items: const <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(
                          value: '1',
                          child: Text('Aktif'),
                        ),
                        DropdownMenuItem<String>(
                          value: '0',
                          child: Text('Nonaktif'),
                        ),
                      ],
                      onChanged: (String? value) =>
                          setState(() => _status = value ?? '1'),
                    ),
                  ],
                ),
              ),
              if (_selected != null && _selected!.mobileNo.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => WhatsAppHelper.openChat(
                    context,
                    phone: _selected!.mobileNo,
                    message: 'Halo ${_selected!.namaLengkap}, terkait data '
                        'karyawan Anda.',
                  ),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Chat WhatsApp'),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Simpan Perubahan',
                icon: Icons.save_rounded,
                isLoading: _isSaving,
                onPressed: _simpan,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KaryawanPickerSheet extends StatefulWidget {
  const _KaryawanPickerSheet({required this.items});

  final List<KaryawanItem> items;

  @override
  State<_KaryawanPickerSheet> createState() => _KaryawanPickerSheetState();
}

class _KaryawanPickerSheetState extends State<_KaryawanPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<KaryawanItem> get _filtered {
    final String keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return widget.items;
    return widget.items
        .where(
          (KaryawanItem item) =>
              item.username.toLowerCase().contains(keyword) ||
              item.namaLengkap.toLowerCase().contains(keyword),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<KaryawanItem> tampil = _filtered;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pilih Karyawan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ketuk username karyawan yang ingin diedit',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (String value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Cari username atau nama karyawan...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Bersihkan pencarian',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: tampil.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            'Tidak ada karyawan yang cocok',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: tampil.length,
                        itemBuilder: (BuildContext context, int index) {
                          final KaryawanItem item = tampil[index];
                          return ListTile(
                            onTap: () => Navigator.of(context).pop(item),
                            title: Text(
                              item.username.isEmpty
                                  ? 'Karyawan'
                                  : item.username,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            subtitle: Text(item.namaLengkap),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
