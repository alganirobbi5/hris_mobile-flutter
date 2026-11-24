import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class SelfieStorage {
  const SelfieStorage._();

  static Future<String> save(
    XFile photo, {
    required String jenis,
    DateTime? takenAt,
    Directory? baseDirectory,
  }) async {
    final File source = File(photo.path);
    if (!await source.exists()) {
      throw const FileSystemException('File selfie tidak ditemukan di perangkat');
    }
    if (await source.length() == 0) {
      throw const FileSystemException('File selfie kosong');
    }

    final Directory base = baseDirectory ?? await getApplicationDocumentsDirectory();
    final DateTime waktu = takenAt ?? DateTime.now();
    final String folder = folderName(jenis, waktu);
    final Directory target = Directory(
      <String>[base.path, ...folder.split('/')].join(Platform.pathSeparator),
    );
    await target.create(recursive: true);

    final String extension = _extension(photo.path);
    final int unique = DateTime.now().microsecondsSinceEpoch;
    final String nonce = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final String name = 'selfie_${jenis}_${unique}_$nonce.$extension';
    final String destination = '${target.path}${Platform.pathSeparator}$name';

    await source.copy(destination);
    final File saved = File(destination);
    if (!await saved.exists() || await saved.length() == 0) {
      throw const FileSystemException('Gagal menyimpan selfie di perangkat');
    }
    return saved.path;
  }

  static String folderName(String jenis, DateTime waktu) {
    final String date = '${waktu.year}-'
        '${waktu.month.toString().padLeft(2, '0')}-'
        '${waktu.day.toString().padLeft(2, '0')}';
    return 'selfies/$date/$jenis';
  }

  static String _extension(String path) {
    final String raw = path.contains('.')
        ? path.substring(path.lastIndexOf('.') + 1).toLowerCase()
        : '';
    return const <String>['jpg', 'jpeg', 'png', 'webp'].contains(raw) ? raw : 'jpg';
  }
}
