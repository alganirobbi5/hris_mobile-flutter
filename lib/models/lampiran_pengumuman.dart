import 'dart:convert';
import 'dart:typed_data';

class LampiranPengumuman {
  const LampiranPengumuman({
    required this.dataUrl,
    required this.namaFile,
    required this.mime,
  });

  final String dataUrl;
  final String namaFile;
  final String mime;

  bool get isImage => mime.startsWith('image/');

  Uint8List? decodeBytes() {
    try {
      final String raw = dataUrl.contains(',')
          ? dataUrl.split(',').last
          : dataUrl;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  String toJsonValue() => jsonEncode(<String, String>{
    'dataUrl': dataUrl,
    'namaFile': namaFile,
    'mime': mime,
  });

  static LampiranPengumuman? fromJsonValue(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final String dataUrl = (value['dataUrl'] ?? '').toString();
      if (dataUrl.isEmpty) return null;
      return LampiranPengumuman(
        dataUrl: dataUrl,
        namaFile: (value['namaFile'] ?? 'lampiran').toString(),
        mime: (value['mime'] ?? 'application/octet-stream').toString(),
      );
    }
    final String raw = value.toString().trim();
    if (raw.isEmpty) return null;

    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return fromJsonValue(decoded);
      }
    } catch (_) {}

    final String mime = raw.startsWith('data:') && raw.contains(';base64,')
        ? raw.substring(5, raw.indexOf(';base64,'))
        : 'application/octet-stream';
    return LampiranPengumuman(dataUrl: raw, namaFile: 'lampiran', mime: mime);
  }
}
