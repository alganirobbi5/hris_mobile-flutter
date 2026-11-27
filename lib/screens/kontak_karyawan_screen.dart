import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/company_config.dart';
import '../services/company_profile.dart';
import '../services/karyawan_service.dart';
import '../theme/app_theme.dart';
import '../utils/whatsapp_helper.dart';
import '../widgets/glass_app_bar.dart';

class KontakKaryawanScreen extends StatefulWidget {
  const KontakKaryawanScreen({super.key, this.httpClient});

  final http.Client? httpClient;

  @override
  State<KontakKaryawanScreen> createState() => _KontakKaryawanScreenState();
}

class _KontakKaryawanScreenState extends State<KontakKaryawanScreen> {
  final TextEditingController _searchController = TextEditingController();

  http.Client? _ownedClient;

  http.Client get _httpClient {
    if (widget.httpClient != null) return widget.httpClient!;
    return _ownedClient ??= http.Client();
  }

  String _query = '';
  String _companyName = CompanyConfig.namaPerusahaan;
  bool _isLoading = true;
  List<KaryawanItem> _karyawan = const <KaryawanItem>[];

  @override
  void initState() {
    super.initState();
    _loadCompany();
    _fetchKaryawan();
  }

  @override
  void dispose() {
    _ownedClient?.close();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompany() async {
    final CompanyProfileData profil = await CompanyProfile.load();
    if (!mounted) return;
    setState(() => _companyName = profil.name);
  }

  Future<void> _fetchKaryawan() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final List<KaryawanItem> hasil =
          await KaryawanService.fetchAll(client: _httpClient);
      if (!mounted) return;
      setState(() {
        _karyawan = hasil;
        _isLoading = false;
      });
    } on KaryawanServiceException {
      if (!mounted) return;
      setState(() {
        _karyawan = const <KaryawanItem>[];
        _isLoading = false;
      });
    }
  }

  List<KaryawanItem> get _filtered {
    final String keyword = _query.trim().toLowerCase();
    if (keyword.isEmpty) return _karyawan;
    return _karyawan
        .where(
          (KaryawanItem item) =>
              item.namaLengkap.toLowerCase().contains(keyword) ||
              item.username.toLowerCase().contains(keyword) ||
              item.mobileNo.toLowerCase().contains(keyword),
        )
        .toList();
  }

  String _initials(String nama) {
    final List<String> bagian = nama
        .trim()
        .split(RegExp(r'\s+'))
        .where((String value) => value.isNotEmpty)
        .toList();
    if (bagian.isEmpty) return 'K';
    if (bagian.length == 1) return bagian.first.substring(0, 1).toUpperCase();
    return '${bagian.first.substring(0, 1)}${bagian.last.substring(0, 1)}'
        .toUpperCase();
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdCard(KaryawanItem item) {
    final bool punyaNoHp = item.mobileNo.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF7B5CFF), Color(0xFF5B4CFF), Color(0xFF3B5BDB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text(
                  'ID CARD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    _companyName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _initials(item.namaLengkap),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.namaLengkap.isEmpty ? 'Tanpa Nama' : item.namaLengkap,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.username.isEmpty ? '@karyawan' : '@${item.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    (item.role.isEmpty ? 'Karyawan' : item.role).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.statusAktif ? 'Aktif' : 'Nonaktif',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _infoRow(Icons.mail_outline_rounded, 'Email', item.email),
                  _infoRow(
                    Icons.phone_outlined,
                    'No. HP',
                    punyaNoHp ? item.mobileNo : 'No. HP belum diisi',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                if (!punyaNoHp)
                  Expanded(
                    child: Text(
                      'No. HP belum diisi',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: punyaNoHp
                      ? () => WhatsAppHelper.openChat(
                          context,
                          phone: item.mobileNo,
                          message: 'Halo ${item.namaLengkap}, ',
                        )
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline, size: 17),
                  label: const Text('Chat WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white54,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.7)),
                    minimumSize: const Size(0, 40),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<KaryawanItem> tampil = _filtered;
    return Scaffold(
      appBar: const GlassAppBar(title: Text('Hubungi Karyawan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _searchController,
                onChanged: (String value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari nama, username, atau No. HP karyawan...',
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
              const SizedBox(height: 12),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (tampil.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      _karyawan.isEmpty
                          ? 'Belum ada karyawan untuk dihubungi.'
                          : 'Tidak ada karyawan yang cocok.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: tampil.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _buildIdCard(tampil[index]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
