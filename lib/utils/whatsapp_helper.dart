import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppHelper {
  const WhatsAppHelper._();

  static String normalizePhone(String value) {
    final String digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('62')) return digits;
    if (digits.startsWith('0')) return '62${digits.substring(1)}';
    if (digits.startsWith('8')) return '62$digits';
    return digits;
  }

  static bool isValidPhone(String value) {
    final String normalized = normalizePhone(value);
    return normalized.startsWith('62') &&
        normalized.length >= 10 &&
        normalized.length <= 16;
  }

  static String? validatePhone(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (!isValidPhone(text)) return 'No. HP harus diawali 08 atau 628';
    return null;
  }

  static Future<bool> openChat(
    BuildContext context, {
    required String phone,
    String? message,
  }) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String normalized = normalizePhone(phone);
    if (!isValidPhone(normalized)) {
      _showMessage(messenger, 'Nomor WhatsApp tidak valid.');
      return false;
    }

    final StringBuffer url = StringBuffer('https://wa.me/$normalized');
    if (message != null && message.trim().isNotEmpty) {
      url.write('?text=${Uri.encodeComponent(message.trim())}');
    }

    try {
      final bool opened = await launchUrl(
        Uri.parse(url.toString()),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        _showMessage(messenger, 'Gagal membuka WhatsApp.');
        return false;
      }
      return true;
    } catch (_) {
      _showMessage(messenger, 'Gagal membuka WhatsApp.');
      return false;
    }
  }

  static void _showMessage(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
