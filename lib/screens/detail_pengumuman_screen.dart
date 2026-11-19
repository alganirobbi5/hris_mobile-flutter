import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/lampiran_pengumuman.dart';
import '../theme/app_theme.dart';
import '../widgets/section_card.dart';

class DetailPengumumanScreen extends StatelessWidget {
  const DetailPengumumanScreen({
    super.key,
    required this.judul,
    required this.isi,
    required this.tanggal,
    this.lampiran,
  });

  final String judul;
  final String isi;
  final String tanggal;
  final String? lampiran;

  @override
  Widget build(BuildContext context) {
    final LampiranPengumuman? lampiranData =
        LampiranPengumuman.fromJsonValue(lampiran);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pengumuman')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      judul,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTanggal(tanggal),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SectionCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isi,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (lampiranData != null) ...[
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),
                      const Text(
                        'Lampiran',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (lampiranData.isImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(
                              lampiranData.dataUrl.split(',').last,
                            ),
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Text(
                              'Pratinjau lampiran tidak tersedia',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lampiranData.namaFile,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => _bagikanLampiran(lampiranData),
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Buka / Bagikan Lampiran'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bagikanLampiran(LampiranPengumuman lampiran) async {
    try {
      final List<int> bytes =
          base64Decode(lampiran.dataUrl.split(',').last);
      final Directory dir = await getTemporaryDirectory();
      final String safeName = lampiran.namaFile.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final File file = File('${dir.path}/$safeName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: <XFile>[XFile(file.path)], text: judul),
      );
    } catch (_) {}
  }

  String _formatTanggal(String raw) {
    final DateTime? date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return DateFormat('d MMMM yyyy', 'id_ID').format(date);
  }
}
