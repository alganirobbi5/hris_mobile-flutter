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
  String _companyCode = CompanyConfig.namaPerusahaan;
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
    setState(() {
      _companyName = profil.name;
      _companyCode = profil.code.trim().isEmpty ? profil.name : profil.code;
    });
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

  Widget _buildClip() {
    return Center(
      child: Container(
        width: 26,
        height: 18,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFE6E8F0), Colors.white, Color(0xFFC7CBD9)],
          ),
          borderRadius: BorderRadius.circular(5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 10,
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFF4436D6),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
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

  Widget _statusBadge(bool aktif) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: aktif ? const Color(0xFF7BE0AD) : const Color(0xFFFF9B9B),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            aktif ? 'Aktif' : 'Nonaktif',
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdCard(KaryawanItem item) {
    final bool punyaNoHp = item.mobileNo.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildClip(),
        Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF7B5CFF),
                  Color(0xFF5B4CFF),
                  Color(0xFF3B5BDB),
                ],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1.4,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.42),
                  blurRadius: 34,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    right: -50,
                    top: -40,
                    child: Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    left: -40,
                    bottom: 30,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'ID CARD',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _companyCode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              width: 78,
                              height: 92,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 2,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              alignment: Alignment.center,
                              child: Text(
                                _initials(item.namaLengkap),
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.namaLengkap.isEmpty
                                        ? 'Tanpa Nama'
                                        : item.namaLengkap,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 9,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.2,
                                          ),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          item.roleLabel,
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.7,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: _statusBadge(item.statusAktif),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _companyName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white.withValues(alpha: 0.82),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _infoRow(
                                Icons.mail_outline_rounded,
                                'Email',
                                item.email,
                              ),
                              const SizedBox(height: 10),
                              _infoRow(
                                Icons.person_outline_rounded,
                                'Username',
                                item.username.isEmpty
                                    ? '-'
                                    : '@${item.username}',
                              ),
                              const SizedBox(height: 10),
                              _infoRow(
                                Icons.phone_outlined,
                                'No. HP',
                                punyaNoHp ? item.mobileNo : 'No. HP belum diisi',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
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
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              minimumSize: const Size(0, 42),
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
      ],
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
