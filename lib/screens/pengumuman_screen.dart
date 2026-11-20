import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/lampiran_pengumuman.dart';
import '../services/app_session.dart';
import '../services/pengumuman_overlay.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';
import 'detail_pengumuman_screen.dart';
import 'tambah_pengumuman_screen.dart';

class PengumumanScreen extends StatefulWidget {
  const PengumumanScreen({super.key});

  @override
  State<PengumumanScreen> createState() => _PengumumanScreenState();
}

class _PengumumanScreenState extends State<PengumumanScreen> {
  static const String _pengumumanUrl = '${ApiConfig.baseUrl}/pengumuman.php';

  bool _isLoading = true;
  String? _error;
  String _roleUser = '';
  List<_Pengumuman> _daftarPengumuman = const [];

  @override
  void initState() {
    super.initState();
    _loadRole();
    _fetchPengumuman();
  }

  Future<void> _loadRole() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _roleUser = (prefs.getString('role') ?? '').trim().toLowerCase();
      });
    } catch (_) {
      // Abaikan kegagalan membaca preferensi; tombol HR tetap tersembunyi.
    }
  }

  Future<void> _bukaTambahPengumuman() async {
    final bool? berhasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const TambahPengumumanScreen(),
      ),
    );
    if (!mounted) return;
    if (berhasil == true) {
      await _fetchPengumuman();
    }
  }

  Future<void> _bukaDetail(_Pengumuman item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailPengumumanScreen(
          judul: item.judul,
          isi: item.isi,
          tanggal: item.tanggal,
          lampiran: item.lampiran,
        ),
      ),
    );
  }

  Future<void> _editPengumuman(_Pengumuman item) async {
    if (item.id == null) return;
    final bool? berhasil = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => TambahPengumumanScreen(
          id: item.id,
          judulAwal: item.judul,
          isiAwal: item.isi,
          lampiranAwal: item.lampiran,
        ),
      ),
    );
    if (!mounted) return;
    if (berhasil == true) await _fetchPengumuman();
  }

  Future<void> _hapusPengumuman(_Pengumuman item) async {
    if (item.id == null) return;
    final bool? yakin = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Hapus pengumuman?'),
        content: const Text('Pengumuman ini akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    bool serverBerhasil = false;
    try {
      final String? token = AppSession.getToken();

      // Jika token kosong, hentikan request dan tampilkan pesan session invalid
      if (token == null) {
        // Token tidak ada; anggap gagal dan lanjutkan dengan pesan lokal
        serverBerhasil = false;
      } else {
        final http.Response response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/hapus_pengumuman.php'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(<String, dynamic>{'id': item.id}),
        ).timeout(const Duration(seconds: 10));
        serverBerhasil = response.statusCode == 200;
      }
    } catch (_) {}

    if (!serverBerhasil) {
      await PengumumanOverlay.upsert(
        id: item.id!,
        dihapus: true,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          serverBerhasil
              ? 'Pengumuman berhasil dihapus.'
              : 'Pengumuman dihapus di perangkat ini.',
        ),
      ),
    );
    await _fetchPengumuman();
  }

  Future<void> _fetchPengumuman() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final http.Response response = await http
          .get(Uri.parse(_pengumumanUrl))
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<_Pengumuman> dariServer = _parsePengumuman(response.body);
        final List<_Pengumuman> finalList = await _terapkanOverlay(dariServer);
        if (!mounted) return;
        setState(() {
          _daftarPengumuman = finalList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = _apiErrorMessage(
            response,
            'Gagal memuat pengumuman (HTTP ${response.statusCode}).',
          );
          _isLoading = false;
        });
      }
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _error = 'Format data pengumuman tidak valid.';
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

  Future<List<_Pengumuman>> _terapkanOverlay(
    List<_Pengumuman> dariServer,
  ) async {
    final Map<String, Map<String, dynamic>> overlay =
        await PengumumanOverlay.load();
    if (overlay.isEmpty) return dariServer;

    return dariServer.where((_Pengumuman item) {
      final String key = item.id?.toString() ?? '';
      final Map<String, dynamic>? perubahan = overlay[key];
      if (perubahan == null) return true;
      return perubahan['dihapus'] != true;
    }).map((_Pengumuman item) {
      final String key = item.id?.toString() ?? '';
      final Map<String, dynamic>? perubahan = overlay[key];
      if (perubahan == null) return item;
      return _Pengumuman(
        id: item.id,
        judul: (perubahan['judul'] as String?) ?? item.judul,
        isi: (perubahan['isi'] as String?) ?? item.isi,
        tanggal: item.tanggal,
        lampiran: (perubahan['lampiran'] as String?) ?? item.lampiran,
      );
    }).toList();
  }

  List<_Pengumuman> _parsePengumuman(String body) {
    if (body.trim().isEmpty) return const [];

    final dynamic decoded = jsonDecode(body);
    dynamic rawData = decoded;

    if (decoded is Map<String, dynamic>) {
      rawData =
          decoded['data'] ??
          decoded['pengumuman'] ??
          decoded['result'] ??
          decoded['list'];
    }

    if (rawData is! List) return const [];

    return rawData
        .whereType<Map<String, dynamic>>()
        .map(_Pengumuman.fromJson)
        .toList();
  }

  String _apiErrorMessage(http.Response response, String fallback) {
    final String body = response.body.trim();
    if (body.isEmpty) return fallback;

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
      return body.length <= 140 ? body : fallback;
    }

    return body.length <= 140 ? body : fallback;
  }

  String _formatTanggal(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '-') return '-';

    final DateTime? parsed = _parseTanggal(trimmed);
    if (parsed == null) return trimmed;

    return DateFormat('d MMMM yyyy', 'id_ID').format(parsed);
  }

  DateTime? _parseTanggal(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    final int? timestamp = int.tryParse(value);
    if (timestamp == null) return null;

    final bool inSeconds = timestamp.abs() < 100000000000;
    return DateTime.fromMillisecondsSinceEpoch(
      inSeconds ? timestamp * 1000 : timestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengumuman'),
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: _fetchPengumuman,
              tooltip: 'Muat ulang pengumuman',
              icon: const Icon(
                Icons.refresh_rounded,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _fetchPengumuman,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pengumuman',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Informasi dan pengumuman terbaru dari perusahaan.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Daftar Pengumuman',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!_isLoading && _error == null)
                      Text(
                        '${_daftarPengumuman.length} data',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildList(),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _roleUser == 'hr'
          ? Padding(
              padding: const EdgeInsets.only(bottom: 88),
              child: FloatingActionButton(
                onPressed: _bukaTambahPengumuman,
                tooltip: 'Buat pengumuman',
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return SectionCard(
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 32,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchPengumuman,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_daftarPengumuman.isEmpty) {
      return const SectionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: Text(
              'Belum ada pengumuman',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _daftarPengumuman.length,
      itemBuilder: (BuildContext context, int index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildItem(_daftarPengumuman[index]),
        );
      },
    );
  }

  Widget _buildLampiranRingkas(String raw) {
    final LampiranPengumuman? lampiran =
        LampiranPengumuman.fromJsonValue(raw);
    if (lampiran == null) return const SizedBox.shrink();

    if (lampiran.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          base64Decode(lampiran.dataUrl.split(',').last),
          height: 90,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              lampiran.namaFile,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_Pengumuman item) {
    final bool isHr = _roleUser == 'hr';
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () => _bukaDetail(item),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    size: 21,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.judul,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatTanggal(item.tanggal),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isHr)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.primary,
                        tooltip: 'Edit',
                        onPressed: () => _editPengumuman(item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: AppColors.danger,
                        tooltip: 'Hapus',
                        onPressed: () => _hapusPengumuman(item),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(height: 20, color: AppColors.border),
            Text(
              item.isi,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (item.lampiran != null && item.lampiran!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildLampiranRingkas(item.lampiran!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pengumuman {
  const _Pengumuman({
    required this.id,
    required this.judul,
    required this.isi,
    required this.tanggal,
    this.lampiran,
  });

  final int? id;
  final String judul;
  final String isi;
  final String tanggal;
  final String? lampiran;

  factory _Pengumuman.fromJson(Map<String, dynamic> json) {
    final dynamic idValue = json['id'] ?? json['pengumuman_id'];

    return _Pengumuman(
      id: idValue is int ? idValue : int.tryParse(idValue?.toString() ?? ''),
      judul: _textOf(
        json['judul'] ?? json['title'] ?? json['nama_pengumuman'],
        'Tanpa Judul',
      ),
      isi: _textOf(
        json['isi'] ??
            json['pesan'] ??
            json['content'] ??
            json['message'] ??
            json['deskripsi'],
        'Tidak ada isi pengumuman.',
      ),
      tanggal: _textOf(
        json['tanggal'] ??
            json['date'] ??
            json['created_at'] ??
            json['tanggal_post'],
        '-',
      ),
      lampiran: _lampiranDari(json),
    );
  }

  static String? _lampiranDari(Map<String, dynamic> json) {
    final String value = _textOf(
      json['attachment'] ?? json['lampiran'] ?? json['file'],
      '',
    );
    return value.isEmpty ? null : value;
  }

  static String _textOf(dynamic value, String fallback) {
    if (value == null) return fallback;
    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }
}
