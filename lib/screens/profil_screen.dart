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
import '../services/profile_email_store.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import 'login_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  static const String _uploadsBaseUrl = 'http://31.97.199.58/hris/uploads';

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  bool _isSavingEmail = false;
  String? _error;
  Map<String, dynamic>? _profil;
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
      await ProfileAvatarStore.migrateLegacy(_userId);
      String? savedAvatar;
      String? savedAvatarImage;
      try {
        savedAvatar = await ProfileAvatarStore.load(_userId);
        savedAvatarImage = await ProfileAvatarStore.loadImage(_userId);
      } catch (_) {
        // Avatar lokal opsional; kegagalan tidak boleh menghalangi profil/logout.
      }
      final String? savedAvatarFile = savedAvatarImage;

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
      // Admin HR tanpa employee tetap bisa mengambil profil (termasuk email)
      // dari endpoint profil.php tanpa query employee_id.
      final Uri url = employeeId == null
          ? EmployeeRequest.profileSelf()
          : EmployeeRequest.profile(employeeId);

      final http.Response response = await http
          .get(url, headers: ApiConfig.authHeaders(token))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> profil = _parseProfil(response.body);
        final String? cachedEmail = await ProfileEmailStore.load(_userId);
        final String serverEmail = profil['email']?.toString().trim() ?? '';
        if (serverEmail.isEmpty && cachedEmail != null) {
          profil['email'] = cachedEmail;
        }
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
          await ProfileAvatarStore.saveImage(_userId, stored);
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
    final String? cachedEmail = await ProfileEmailStore.load(_userId);
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
        'email': cachedEmail ?? 'Belum tersedia',
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

    final String? pilihan = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                const ListTile(
                  title: Text(
                    'Ubah Foto Profil',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.face_retouching_natural_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Pilih Avatar'),
                  subtitle: const Text('Koleksi avatar bawaan aplikasi'),
                  onTap: () => Navigator.pop(sheetContext, 'catalog'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Kamera'),
                  onTap: () => Navigator.pop(sheetContext, 'camera'),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Galeri'),
                  onTap: () => Navigator.pop(sheetContext, 'gallery'),
                ),
                const SizedBox(height: 8),
              ],
              ),
            ),
          ),
        );
      },
    );
    if (pilihan == null) return;
    if (pilihan == 'catalog') {
      // Tunggu route sheet pertama selesai ditutup agar sheet katalog tidak
      // ikut ter-pop oleh animasi navigasi sebelumnya.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (mounted) await _openAvatarPicker();
      return;
    }
    final ImageSource source = pilihan == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;

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
    _userId ??= await AppSession.resolveUserId();
    setState(() => _isUploadingAvatar = true);

    try {
      final List<int> bytes = await photo.readAsBytes();
      final String? photoMime = photo.mimeType;
      final String mime = (photoMime == null || photoMime.isEmpty)
          ? 'image/jpeg'
          : photoMime;
      final String dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

      await ProfileAvatarStore.saveImage(_userId, dataUrl);
      await ProfileAvatarStore.save(_userId, null);
      ProfileAvatarStore.notify();

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
    _userId ??= await AppSession.resolveUserId();
    setState(() => _isUploadingAvatar = true);

    try {
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final String dataUrl = 'data:image/png;base64,${base64Encode(bytes)}';

      await ProfileAvatarStore.saveImage(_userId, dataUrl);
      await ProfileAvatarStore.save(_userId, avatarId);
      ProfileAvatarStore.notify();

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

  Future<void> _openAvatarPicker() async {
    final String? result = await showAvatarPicker(
      context,
      selectedId: _selectedAvatarId,
    );
    if (result == null) return;

    final String? avatarId = result.isEmpty ? null : result;

    if (avatarId == null) {
      _userId ??= await AppSession.resolveUserId();
      await ProfileAvatarStore.saveImage(_userId, null);
      await ProfileAvatarStore.save(_userId, null);
      ProfileAvatarStore.notify();
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
            onTap: _pickAndUploadAvatar,
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
                onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: _isUploadingAvatar
                      ? const Center(
                          child: SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const Icon(
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

  Widget _buildEmailRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              size: 19,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Email',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isSavingEmail ? null : _showEditEmailDialog,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _isSavingEmail
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditEmailDialog() async {
    final TextEditingController emailController = TextEditingController(
      text: _email == 'Belum tersedia' ? '' : _email,
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    final String? emailBaru = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Ubah Email'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'nama@perusahaan.com',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (String? value) {
                final String text = (value ?? '').trim();
                if (text.isEmpty) return 'Email wajib diisi';
                final RegExp pattern = RegExp(
                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                );
                if (!pattern.hasMatch(text)) return 'Format email tidak valid';
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
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(emailController.text.trim());
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    if (emailBaru == null || emailBaru.isEmpty || !mounted) return;
    await _saveEmail(emailBaru);
    if (mounted) await _fetchProfil();
  }

  Future<bool> _saveEmail(String email) async {
    if (mounted) setState(() => _isSavingEmail = true);
    bool saved = false;
    String message = 'Gagal menyimpan email.';
    try {
      final String? token = await AppSession.resolveToken();
      final String bodyJson = jsonEncode(EmployeeRequest.profileUpdateBody(email));
      http.Response response = await http
          .post(
            EmployeeRequest.profileUpdate(),
            headers: ApiConfig.authHeaders(token),
            body: bodyJson,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 404 || response.statusCode == 405) {
        response = await http
            .post(
              EmployeeRequest.profileUpdateFallback(),
              headers: ApiConfig.authHeaders(token),
              body: bodyJson,
            )
            .timeout(const Duration(seconds: 20));
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        decoded = null;
      }
      final Map<String, dynamic>? body = decoded is Map<String, dynamic>
          ? decoded
          : null;
      final String? serverMessage = body?['message']?.toString();
      final bool httpSukses =
          response.statusCode >= 200 && response.statusCode < 300;
      final String? statusTeks = body?['status']?.toString();
      final bool serverTolak = body?['success'] == false ||
          (statusTeks != null &&
              statusTeks.toLowerCase() != 'success' &&
              statusTeks.toLowerCase() != 'ok');
      saved = httpSukses && !serverTolak;
      if (saved) {
        await ProfileEmailStore.save(_userId, email.trim());
        if (_profil != null) {
          _profil!['email'] = email.trim();
        }
        message = serverMessage?.trim().isNotEmpty == true
            ? serverMessage!.trim()
            : 'Email profil berhasil disimpan.';
      } else {
        message = (serverMessage != null && serverMessage.trim().isNotEmpty)
            ? serverMessage.trim()
            : 'Gagal menyimpan email (HTTP ${response.statusCode}).';
      }
    } catch (e) {
      saved = false;
      message = 'Gagal terhubung ke server: $e';
    }
    if (!mounted) return saved;
    setState(() => _isSavingEmail = false);
    _showMessage(message);
    return saved;
  }

  void _showMessage(String message) {
    AppToast.show(message, type: AppToast.typeFromMessage(message));
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
      appBar: const GlassAppBar(
        title: Text('Profil'),
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

    return RefreshIndicator(
      onRefresh: _fetchProfil,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                _buildAvatar(),
                const SizedBox(height: 12),
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
                _buildEmailRow(),
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
          const SizedBox(height: 14),

          // TOMBOL KELUAR (Dengan konfirmasi & hapus sesi)
          DangerButton(
            label: 'Keluar',
            icon: Icons.logout_rounded,
            onPressed: _showLogoutConfirmation,
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'HRIS Dignity V2.2',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
