import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hris_mobile/services/selfie_storage.dart';

void main() {
  test('selfie disalin ke direktori privat sesuai tanggal dan jenis', () async {
    final Directory base = await Directory.systemTemp.createTemp('selfie_storage_');
    try {
      final File source = File('${base.path}${Platform.pathSeparator}source.jpg');
      await source.writeAsBytes(<int>[0xFF, 0xD8, 0xFF, 0xD9]);

      final String saved = await SelfieStorage.save(
        XFile(source.path),
        jenis: 'masuk',
        takenAt: DateTime(2026, 11, 24, 8, 2, 17),
        baseDirectory: base,
      );

      expect(File(saved).existsSync(), isTrue);
      expect(saved, contains('selfies'));
      expect(saved, contains('2026-11-24'));
      expect(saved, contains('masuk'));
      expect(saved, endsWith('.jpg'));
    } finally {
      base.deleteSync(recursive: true);
    }
  });

  test('nama file selfie berbeda untuk dua penyimpanan berturut-turut', () async {
    final Directory base = await Directory.systemTemp.createTemp('selfie_storage_');
    try {
      final File source = File('${base.path}${Platform.pathSeparator}source.png');
      await source.writeAsBytes(<int>[0x89, 0x50, 0x4E, 0x47]);

      final String first = await SelfieStorage.save(
        XFile(source.path),
        jenis: 'pulang',
        takenAt: DateTime(2026, 11, 24, 17, 2, 38),
        baseDirectory: base,
      );
      final String second = await SelfieStorage.save(
        XFile(source.path),
        jenis: 'pulang',
        takenAt: DateTime(2026, 11, 24, 17, 2, 38),
        baseDirectory: base,
      );

      expect(first, isNot(second));
      expect(File(first).existsSync(), isTrue);
      expect(File(second).existsSync(), isTrue);
      expect(second, endsWith('.png'));
    } finally {
      base.deleteSync(recursive: true);
    }
  });
}
