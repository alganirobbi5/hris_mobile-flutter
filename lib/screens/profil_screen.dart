import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/avatar_catalog.dart';
import '../config/company_config.dart';
import '../services/app_session.dart';
import '../services/company_profile.dart';
import '../services/employee_request.dart';
import '../services/profile_avatar_store.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import 'login_screen.dart';
import 'tambah_karyawan_screen.dart';
import 'tambah_lokasi_screen.dart';
import 'atur_jam_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  static const String _uploadsBaseUrl = 'http://31.97.199.58/hris/uploads';
  static const String _avatarPrefsKey = 'user_avatar';

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isSavingCompany = false;
  bool _isSavingQuota = false;
  String? _error;
  Map<String, dynamic>? _profil;
  String _roleUser = '';
  int? _userId;
  String? _selectedAvatarId;
  String? _avatarUrl;
  String _companyName = CompanyConfig.namaPerusahaan;
  String _companyCode = CompanyConfig.kodePerusahaan;

  @override
  void initState() {
    super.initState();
    _loadCompany();
    _fetchProfil();
  }

  Future<void> _loadCompany({bool refreshFromApi = true}) async {
    final CompanyProfileData local = await CompanyProfile.load();
    if (!mounted) return;
    setState(() {
      _companyName = local.name;
      _companyCode = local.code;
    });
    if (!refreshFromApi) return;
    final CompanyProfileData? server = await CompanyProfile.fetch();
    if (server == null || !mounted) return;
    setState(() {
      _companyName = server.name;
      _companyCode = server.code;
    });
  }

  Future<void> _fetchProfil() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Ambil data user dari penyimpanan HP
      final prefs = await SharedPreferences.getInstance();
      await AppSession.restore(prefs);
      _userId = await AppSession.resolveUserId(prefs);
      _roleUser = prefs.getString('role') ?? '';
      String? savedAvatar;
      String? savedAvatarImage;
      try {
        savedAvatar = await ProfileAvatarStore.load(_userId);
        savedAvatarImage = await ProfileAvatarStore.loadImage(_userId);
      } catch (_) {
        // Avatar lokal opsional; kegagalan tidak boleh menghalangi profil/logout.
      }
      final String? legacyAvatar = prefs.getString(_avatarPrefsKey);
      final String? savedAvatarFile = savedAvatarImage ?? legacyAvatar;
      if (savedAvatarImage != null) {
        await prefs.setString(_avatarPrefsKey, savedAvatarImage);
      }

      if (!mounted) return;

      setState(() {
        _selectedAvatarId = savedAvatar;
        _avatarUrl = (savedAvatarFile == null || savedAvatarFile.trim().isEmpty)
            ? null
            : _resolveAvatarUrl(savedAvatarFile);
      });

      if (_userId == null) {
        setState(() {
          _error = 'Sesi login tidak ditemukan. Silakan login ulang.';
          _isLoading = false;
        });
        return;
      }

      // 2. Siapkan request ke profil.php dengan otentikasi Bearer Token
      final String? token = await AppSession.resolveToken();

      final int? employeeId = await AppSession.currentEmployeeId();
      if (employeeId == null) {
        // Admin HR dapat belum memiliki data karyawan. Profil dan logout
        // tetap tersedia menggunakan identitas dari response login.
        await _applySessionProfile();
        return;
      }
      final Uri url = EmployeeRequest.profile(employeeId);

      final http.Response response = await http
          .get(url, headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> profil = _parseProfil(response.body);
        final dynamic serverAvatar = profil['avatar'];
        final String serverAvatarText = serverAvatar is String
            ? serverAvatar.trim()
            : '';
        final bool isDataUrl = serverAvatarText.startsWith('data:');

        final bool hasLocalAvatar =
            savedAvatarFile != null && savedAvatarFile.trim().isNotEmpty;
        String? effectiveAvatar = savedAvatarFile;
        if (!hasLocalAvatar && serverAvatarText.isNotEmpty) {
          final String stored = isDataUrl
              ? serverAvatarText
              : _avatarFileName(serverAvatarText);
          await prefs.setString(_avatarPrefsKey, stored);
          effectiveAvatar = stored;
        }

        if (!mounted) return;
        setState(() {
          _profil = profil;
          _avatarUrl =
              (effectiveAvatar == null || effectiveAvatar.trim().isEmpty)
              ? null
              : _resolveAvatarUrl(effectiveAvatar);
          if (_avatarUrl != null && !hasLocalAvatar) _selectedAvatarId = null;
          _isLoading = false;
        });
      } else {
        // Jangan menghalangi halaman profil/logout bila data server gagal dimuat.
        await _applySessionProfile();
      }
    } on FormatException {
      await _applySessionProfile();
    } catch (_) {
      await _applySessionProfile();
    }
  }

  Future<void> _applySessionProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String rawName = (AppSession.name ??
            AppSession.username ??
            prefs.getString('nama_lengkap') ??
            '')
        .toString()
        .trim();
    final String rawUsername = (AppSession.username ??
            prefs.getString('username') ??
            '')
        .toString()
        .trim();
    final String rawRole =
        (AppSession.role ?? prefs.getString('role') ?? '').toString().trim();
    if (!mounted) return;
    setState(() {
      _profil = <String, dynamic>{
        'nama_lengkap': rawName.isEmpty ? 'Pengguna' : rawName,
        'role': rawRole,
        'username': rawUsername.isEmpty ? 'Belum tersedia' : rawUsername,
        'email': 'Belum tersedia',
      };
      _isLoading = false;
      _error = null;
    });
  }

  Map<String, dynamic> _parseProfil(String body) {
    final dynamic decoded = jsonDecode(body);
    dynamic data = decoded;

    if (decoded is Map<String, dynamic>) {
      final dynamic nestedData = decoded['data'];
      if (nestedData is Map<String, dynamic>) {
        data = nestedData;
      } else if (nestedData is List &&
          nestedData.isNotEmpty &&
          nestedData.first is Map<String, dynamic>) {
        data = nestedData.first;
      }
    } else if (decoded is List &&
        decoded.isNotEmpty &&
        decoded.first is Map<String, dynamic>) {
      data = decoded.first;
    }

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Data profil tidak ditemukan.');
    }

    return data;
  }

  String _profileValue(String key) {
    final dynamic value = _profil?[key];
    if (value == null) return 'Belum tersedia';

    final String text = value.toString().trim();
    return text.isEmpty ? 'Belum tersedia' : text;
  }

  String get _name => _profileValue('nama_lengkap');
  String get _role => _profileValue('role');
  String get _email => _profileValue('email');
  String get _username => _profileValue('username');

  String get _leaveQuota {
    final Map<String, dynamic>? data = _profil;
    if (data == null) return 'Belum tersedia';

    final dynamic value =
        data['sisa_kuota_cuti'] ??
        data['sisa_cuti'] ??
        data['kuota_cuti'] ??
        data['leave_quota'] ??
        data['sisa_kuota'];

    if (value == null) return 'Belum tersedia';

    final String text = value.toString().trim();
    return text.isEmpty ? 'Belum tersedia' : text;
  }

  String get _initials {
    final String name = _name;
    if (name == 'Belum tersedia') return '?';

    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    final String first = parts.first.substring(0, 1).toUpperCase();
    if (parts.length == 1) return first;

    final String last = parts.last.substring(0, 1).toUpperCase();
    return '$first$last';
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_isUploadingAvatar) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;

    XFile? photo;
    try {
      photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage('Tidak dapat membuka kamera/galeri.');
      return;
    }
    if (photo == null) return;

    await _uploadAvatar(photo);
  }

  Future<void> _uploadAvatar(XFile photo) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _isUploadingAvatar = true);

    try {
      final List<int> bytes = await photo.readAsBytes();
      final String? photoMime = photo.mimeType;
      final String mime = (photoMime == null || photoMime.isEmpty)
          ? 'image/jpeg'
          : photoMime;
      final String dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

      await prefs.setString(_avatarPrefsKey, dataUrl);
      await ProfileAvatarStore.saveImage(_userId, dataUrl);
      await ProfileAvatarStore.save(_userId, null);

      if (!mounted) return;
      setState(() {
        _avatarUrl = dataUrl;
        _selectedAvatarId = null;
      });
      _showMessage('Avatar berhasil disimpan.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan avatar.');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _uploadCatalogAvatar(String avatarId, String assetPath) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() => _isUploadingAvatar = true);

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final String dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';

      await prefs.setString(_avatarPrefsKey, dataUrl);
      await ProfileAvatarStore.saveImage(_userId, dataUrl);
      await ProfileAvatarStore.save(_userId, avatarId);

      if (!mounted) return;
      setState(() {
        _avatarUrl = dataUrl;
        _selectedAvatarId = avatarId;
      });
      _showMessage('Avatar berhasil disimpan.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan avatar.');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String _avatarFileName(String value) {
    final String trimmed = value.trim();
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed.split('/').last;
  }

  String _resolveAvatarUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.startsWith('data:') ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://')) {
      return trimmed;
    }
    final String fileName = _avatarFileName(trimmed);
    return '$_uploadsBaseUrl/$fileName';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAvatarPicker() async {
    final String? result = await showAvatarPicker(
      context,
      selectedId: _selectedAvatarId,
    );
    if (result == null) return;

    final String? avatarId = result.isEmpty ? null : result;

    if (avatarId == null) {
      await ProfileAvatarStore.save(_userId, null);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_avatarPrefsKey);
      if (!mounted) return;
      setState(() {
        _selectedAvatarId = null;
        _avatarUrl = null;
      });
      return;
    }

    final ProfileAvatarEntry? entry = ProfileAvatarCatalog.byId(avatarId);
    if (entry == null) return;
    await _uploadCatalogAvatar(entry.id, entry.assetPath);
  }

  Widget _avatarImage(String value, Widget fallback) {
    if (value.startsWith('data:image/')) {
      final int comma = value.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(
            base64Decode(value.substring(comma + 1)),
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
          );
        } catch (_) {
          return fallback;
        }
      }
    }
    return Image.network(
      value,
      width: 90,
      height: 90,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }

  Widget _buildAvatar() {
    final ProfileAvatarEntry? avatar = ProfileAvatarCatalog.byId(
      _selectedAvatarId,
    );
    final bool hasImage = _avatarUrl != null || avatar != null;
    final Widget initials = Text(
      _initials,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: Colors.white,
      ),
    );

    return Semantics(
      button: true,
      label: 'Ubah foto profil',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: _openAvatarPicker,
            child: Container(
              width: 96,
              height: 96,
              padding: EdgeInsets.all(hasImage ? 3 : 0),
              decoration: BoxDecoration(
                gradient: hasImage ? null : AppColors.primaryGradient,
                color: hasImage ? AppColors.surface : null,
                shape: BoxShape.circle,
                border: hasImage ? Border.all(color: AppColors.border) : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: _isUploadingAvatar
                  ? CircularProgressIndicator(
                      color: hasImage ? AppColors.primary : Colors.white,
                    )
                  : _avatarUrl != null
                  ? ClipOval(child: _avatarImage(_avatarUrl!, initials))
                  : avatar != null
                  ? ClipOval(
                      child: Image.asset(
                        avatar.assetPath,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    )
                  : initials,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _openAvatarPicker,
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.edit_rounded,
                    size: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCompanyDialog() async {
    final TextEditingController nameController =
        TextEditingController(text: _companyName);
    final TextEditingController codeController =
        TextEditingController(text: _companyCode);
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profil Perusahaan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Perusahaan',
                  ),
                  validator: (String? value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Nama perusahaan wajib diisi'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Perusahaan',
                  ),
                  validator: (String? value) =>
                      (value == null || value.trim().isEmpty)
                          ? 'Kode perusahaan wajib diisi'
                          : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: _isSavingCompany
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final bool saved = await _saveCompany(
                        nameController.text,
                        codeController.text,
                      );
                      if (!mounted) return;
                      if (saved && dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
              child: Text(_isSavingCompany ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    codeController.dispose();
  }

  Future<bool> _saveCompany(String name, String code) async {
    setState(() => _isSavingCompany = true);
    final bool saved = await CompanyProfile.update(name: name, code: code);
    if (!mounted) return saved;
    setState(() => _isSavingCompany = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? 'Profil perusahaan berhasil disimpan.'
              : 'Gagal menyimpan profil perusahaan.',
        ),
      ),
    );
    if (saved) await _loadCompany(refreshFromApi: true);
    return saved;
  }

  static int? _parseEmployeeId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString().trim());
  }

  Future<void> _showAturKuotaCutiDialog() async {
    final int? employeeId = await AppSession.currentEmployeeId() ??
        _parseEmployeeId(_profil?['employee_id']);
    if (!mounted) return;
    if (employeeId == null) {
      _showMessage('employee_id karyawan tidak ditemukan. Silakan login ulang.');
      return;
    }

    final TextEditingController quotaController =
        TextEditingController(text: '12');
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Atur Kuota Cuti'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: quotaController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Total Kuota Tahunan',
                hintText: '12',
              ),
              validator: (String? value) {
                final int? quota = int.tryParse((value ?? '').trim());
                if (quota == null || quota <= 0 || quota > 365) {
                  return 'Masukkan angka antara 1 sampai 365';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: _isSavingQuota
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final int quota =
                          int.parse(quotaController.text.trim());
                      Navigator.of(dialogContext).pop();
                      await _saveKuotaCuti(employeeId, quota);
                    },
              child: Text(_isSavingQuota ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        );
      },
    );

    quotaController.dispose();
  }

  Future<void> _saveKuotaCuti(int employeeId, int quota) async {
    if (!mounted) return;
    setState(() => _isSavingQuota = true);
    try {
      final String? token = await AppSession.resolveToken();
      final http.Response response = await http
          .post(
            ApiConfig.uri('update_kuota_cuti.php'),
            headers: ApiConfig.authHeaders(token),
            body: jsonEncode(<String, dynamic>{
              'employee_id': employeeId,
              'kuota_baru': quota,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      Map<String, dynamic>? decoded;
      try {
        final Object? body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } on FormatException {
        decoded = null;
      }

      final bool success = response.statusCode == 200 &&
          (decoded?['status'] == 'success' || decoded?['success'] == true);
      final Object? serverMessage = decoded?['message'];
      final String message = success
          ? 'Kuota cuti berhasil diperbarui.'
          : (serverMessage != null && serverMessage.toString().isNotEmpty
              ? serverMessage.toString()
              : 'Gagal memperbarui kuota cuti (HTTP ${response.statusCode}).');

      _showMessage(message);
      if (success) await _fetchProfil();
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal terhubung ke server saat menyimpan kuota cuti.');
    } finally {
      if (mounted) setState(() => _isSavingQuota = false);
    }
  }

  void _showLogoutConfirmation() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                await AppSession.clear();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('laporan_tanggal');
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => const LoginScreen(),
                  ),
                  (route) => false,
                );
              },
              child: const Text('Ya', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _fetchProfil,
              tooltip: 'Muat ulang profil',
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
            ),
          IconButton(
            onPressed: _showLogoutConfirmation,
            tooltip: 'Keluar',
            icon: const Icon(
              Icons.logout_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      body: SafeArea(top: false, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text(
              'Memuat profil...',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 46,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 180,
                child: FilledButton.icon(
                  onPressed: _fetchProfil,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await AppSession.clear();
                  if (!mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('Login ulang'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                _buildAvatar(),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  icon: Icon(
                    _isUploadingAvatar
                        ? Icons.hourglass_top_rounded
                        : Icons.add_a_photo_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _isUploadingAvatar ? 'Mengunggah...' : 'Ganti Avatar',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _role,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _openAvatarPicker,
                  child: const Text(
                    'Ketuk foto untuk mengubah',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'INFORMASI KARYAWAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.apartment_rounded,
                  label: 'Nama Perusahaan',
                  value: _companyName,
                ),
                InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Kode Perusahaan',
                  value: _companyCode,
                ),
                InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                  value: _email,
                ),
                InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Username',
                  value: _username,
                ),
                InfoRow(
                  icon: Icons.beach_access_outlined,
                  label: 'Sisa Kuota Cuti',
                  value: _leaveQuota,
                  valueColor: AppColors.primary,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // EDIT PROFIL PERUSAHAAN (Hanya untuk HR)
          if (AppSession.isHrRole(_roleUser)) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSavingQuota
                    ? null
                    : _showAturKuotaCutiDialog,
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Atur Kuota Cuti'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSavingCompany
                    ? null
                    : _showEditCompanyDialog,
                icon: const Icon(Icons.business_center_outlined),
                label: const Text('Edit Profil Perusahaan'),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // TOMBOL TAMBAH KARYAWAN (Hanya muncul jika role == hr)
          if (_roleUser == 'hr') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TambahKaryawanScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Tambah Karyawan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TambahLokasiScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Tambah Lokasi Absensi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AturJamScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.schedule_rounded),
                label: const Text('Atur Jam Kerja'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // TOMBOL KELUAR (Dengan konfirmasi & hapus sesi)
          DangerButton(
            label: 'Keluar',
            icon: Icons.logout_rounded,
            onPressed: _showLogoutConfirmation,
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'HRIS Dignity V1.8',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
