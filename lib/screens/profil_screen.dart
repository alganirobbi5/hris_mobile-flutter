import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../config/avatar_catalog.dart';
import '../config/company_config.dart';
import '../services/profile_avatar_store.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_card.dart';
import 'login_screen.dart';
import 'tambah_karyawan_screen.dart';
import 'tambah_lokasi_screen.dart';

class ProfilScreen extends StatefulWidget {
  const ProfilScreen({super.key});

  @override
  State<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends State<ProfilScreen> {
  static const String _uploadsBaseUrl = 'http://31.97.199.58/HRM/uploads';

  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  String? _error;
  Map<String, dynamic>? _profil;
  String _roleUser = '';
  int? _userId;
  String? _selectedAvatarId;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfil();
  }

  Future<void> _fetchProfil() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Ambil data user dari penyimpanan HP
      final prefs = await SharedPreferences.getInstance();
      _userId = prefs.getInt('user_id');
      _roleUser = prefs.getString('role') ?? '';
      final String? savedAvatar = await ProfileAvatarStore.load(_userId);

      if (!mounted) return;

      setState(() {
        _selectedAvatarId = savedAvatar;
      });

      if (_userId == null) {
        setState(() {
          _error = 'Sesi login tidak ditemukan. Silakan login ulang.';
          _isLoading = false;
        });
        return;
      }

      // 2. Buat URL dinamis menggunakan _userId
      final String url = '${ApiConfig.baseUrl}/profil.php?employee_id=$_userId';

      final http.Response response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _profil = _parseProfil(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _apiErrorMessage(response);
          _isLoading = false;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Format data profil tidak valid.';
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

  String _apiErrorMessage(http.Response response, {String? fallback}) {
    final String fallbackMessage =
        fallback ?? 'Gagal memuat profil (HTTP ${response.statusCode}).';
    final String body = response.body.trim();
    if (body.isEmpty) return fallbackMessage;

    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final dynamic message =
            decoded['message'] ?? decoded['error'] ?? decoded['pesan'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } on FormatException {
      return body.length <= 140 ? body : fallbackMessage;
    }

    return body.length <= 140 ? body : fallbackMessage;
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
    final prefs = await SharedPreferences.getInstance();
    final int? userId = prefs.getInt('user_id');
    if (userId == null) {
      if (!mounted) return;
      _showMessage('Sesi login tidak ditemukan. Silakan login ulang.');
      return;
    }

    setState(() => _isUploadingAvatar = true);

    try {
      final http.MultipartRequest request =
          http.MultipartRequest(
              'POST',
              Uri.parse('${ApiConfig.baseUrl}/upload_avatar.php'),
            )
            ..fields['employee_id'] = userId.toString()
            ..files.add(
              await http.MultipartFile.fromPath('avatar', photo.path),
            );

      final http.StreamedResponse streamed = await request.send().timeout(
        const Duration(seconds: 60),
      );
      final http.Response response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final String? avatarValue = _extractAvatarValue(response.body);
        if (avatarValue == null) {
          _showMessage('Respons server tidak berisi nama file avatar.');
          return;
        }

        setState(() {
          _avatarUrl = _resolveAvatarUrl(avatarValue);
          _selectedAvatarId = null;
        });
        _showMessage('Avatar berhasil diperbarui.');
      } else {
        _showMessage(
          _apiErrorMessage(
            response,
            fallback: 'Gagal mengunggah avatar (HTTP ${response.statusCode}).',
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal mengunggah avatar. Periksa koneksi Anda.');
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  String? _extractAvatarValue(String body) {
    if (body.trim().isEmpty) return null;

    try {
      final dynamic decoded = jsonDecode(body);
      dynamic data = decoded;

      if (decoded is Map<String, dynamic>) {
        final dynamic nested = decoded['data'];
        if (nested is Map<String, dynamic>) {
          data = nested;
        } else if (nested is List &&
            nested.isNotEmpty &&
            nested.first is Map<String, dynamic>) {
          data = nested.first;
        }
      }

      if (data is Map<String, dynamic>) {
        for (final String key in const <String>[
          'file',
          'filename',
          'file_name',
          'nama_file',
          'avatar',
          'avatar_url',
          'foto',
          'photo',
          'path',
          'url',
        ]) {
          final dynamic value = data[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    } on FormatException {
      return null;
    }

    return null;
  }

  String _resolveAvatarUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final String fileName = trimmed.split('/').last;
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
    await ProfileAvatarStore.save(_userId, avatarId);
    if (!mounted) return;

    setState(() => _selectedAvatarId = avatarId);
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
                  ? ClipOval(
                      child: Image.network(
                        _avatarUrl!,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => initials,
                      ),
                    )
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
                const InfoRow(
                  icon: Icons.apartment_rounded,
                  label: 'Nama Perusahaan',
                  value: CompanyConfig.namaPerusahaan,
                ),
                const InfoRow(
                  icon: Icons.badge_outlined,
                  label: 'Kode Perusahaan',
                  value: CompanyConfig.kodePerusahaan,
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
          ],

          // TOMBOL KELUAR (Dengan konfirmasi & hapus sesi)
          DangerButton(
            label: 'Keluar',
            icon: Icons.logout_rounded,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();

                        if (!context.mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute<void>(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text(
                        'Ya',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'HRIS Mobile v1.0.0',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
