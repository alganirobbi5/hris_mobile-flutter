import 'dart:io';

import 'package:flutter/material.dart';

import 'selfie_fullscreen_viewer.dart';

class SelfiePreviewCard extends StatefulWidget {
  const SelfiePreviewCard({
    super.key,
    required this.sudahMasuk,
    required this.sudahPulang,
    required this.jamMasuk,
    required this.jamPulang,
    required this.lokalMasuk,
    required this.lokalPulang,
    required this.urlMasuk,
    required this.urlPulang,
    required this.headers,
    required this.koordinat,
  });

  final bool sudahMasuk;
  final bool sudahPulang;
  final String jamMasuk;
  final String jamPulang;
  final String? lokalMasuk;
  final String? lokalPulang;
  final String? urlMasuk;
  final String? urlPulang;
  final Map<String, String> headers;
  final String koordinat;

  @override
  State<SelfiePreviewCard> createState() => _SelfiePreviewCardState();
}

class _SelfiePreviewCardState extends State<SelfiePreviewCard> {
  String _mode = 'masuk';

  @override
  void initState() {
    super.initState();
    _mode = widget.sudahPulang ? 'pulang' : 'masuk';
  }

  @override
  void didUpdateWidget(covariant SelfiePreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sudahPulang && !oldWidget.sudahPulang) {
      setState(() => _mode = 'pulang');
    }
  }

  static const LinearGradient _latar = LinearGradient(
    colors: <Color>[Color(0xFF23213A), Color(0xFF3A3560)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  bool _adaFoto(String? lokal, String? url) {
    if (url != null && url.trim().isNotEmpty) return true;
    if (lokal != null && lokal.isNotEmpty) return File(lokal).existsSync();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bool masukAda =
        _adaFoto(widget.lokalMasuk, widget.urlMasuk) || widget.sudahMasuk;
    final bool pulangAda =
        _adaFoto(widget.lokalPulang, widget.urlPulang) || widget.sudahPulang;

    if (!masukAda && !pulangAda) return _buildKosong();

    final bool pakaiPulang = _mode == 'pulang' && pulangAda;
    final String? lokal = pakaiPulang ? widget.lokalPulang : widget.lokalMasuk;
    final String? url = pakaiPulang ? widget.urlPulang : widget.urlMasuk;
    final String jam = pakaiPulang ? widget.jamPulang : widget.jamMasuk;
    final String label = pakaiPulang ? 'Selfie Pulang' : 'Selfie Masuk';
    final String judulFoto =
        pakaiPulang ? 'Foto Absen Pulang' : 'Foto Absen Masuk';
    final bool fotoAktifAda = _adaFoto(lokal, url);

    return SizedBox(
      height: 195,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: _latar)),
            Positioned.fill(
              child: GestureDetector(
                onTap: fotoAktifAda
                    ? () => SelfieFullScreenViewer.show(
                          context,
                          title: judulFoto,
                          subtitle: jam,
                          localPath: lokal,
                          networkUrl: url,
                          headers: widget.headers,
                        )
                    : null,
                child: _buildGambar(lokal, url),
              ),
            ),
            if (fotoAktifAda)
              const Positioned(
                right: 12,
                bottom: 12,
                child: Icon(
                  Icons.zoom_out_map_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
            Positioned(
              top: 12,
              left: 12,
              child: _buildBadge('$label • $jam'),
            ),
            if (pulangAda)
              Positioned(
                top: 12,
                right: 12,
                child: _buildToggle(),
              ),
            Positioned(
              left: 12,
              right: fotoAktifAda ? 44 : 12,
              bottom: 12,
              child: Text(
                'Koordinat: ${widget.koordinat}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  shadows: <Shadow>[
                    Shadow(offset: Offset(0, 1), blurRadius: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGambar(String? lokal, String? url) {
    if (lokal != null && lokal.isNotEmpty) {
      final File file = File(lokal);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
    }

    final String? alamat = url?.trim();
    if (alamat != null && alamat.isNotEmpty) {
      return Image.network(
        alamat,
        headers: widget.headers,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (BuildContext context, Widget child, Object? progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _buildTercatat();
        },
      );
    }

    return _buildTercatat();
  }

  Widget _buildTercatat() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_circle_rounded, size: 46, color: Color(0xFF66D19E)),
          SizedBox(height: 10),
          Text(
            'Absensi tercatat',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKosong() {
    return SizedBox(
      height: 195,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(decoration: BoxDecoration(gradient: _latar)),
            const Positioned(
              top: 12,
              left: 12,
              child: Icon(
                Icons.camera_front_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.camera_front_rounded,
                    size: 54,
                    color: Colors.white,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Belum ada foto selfie hari ini',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Tekan tombol di bawah untuk mengambil selfie absen masuk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String teks) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _togglePill('Masuk', _mode == 'masuk'),
          _togglePill('Pulang', _mode == 'pulang'),
        ],
      ),
    );
  }

  Widget _togglePill(String label, bool aktif) {
    return GestureDetector(
      onTap: () => setState(() => _mode = label == 'Pulang' ? 'pulang' : 'masuk'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: aktif ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: aktif ? const Color(0xFF23213A) : Colors.white,
          ),
        ),
      ),
    );
  }
}
