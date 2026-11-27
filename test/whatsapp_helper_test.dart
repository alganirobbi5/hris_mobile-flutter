import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/utils/whatsapp_helper.dart';

void main() {
  test('normalisasi nomor Indonesia ke format 62', () {
    expect(WhatsAppHelper.normalizePhone('08123456789'), '628123456789');
    expect(WhatsAppHelper.normalizePhone('628123456789'), '628123456789');
    expect(WhatsAppHelper.normalizePhone('8123456789'), '628123456789');
    expect(WhatsAppHelper.normalizePhone('08-1234-5678'), '62812345678');
    expect(WhatsAppHelper.normalizePhone('abc'), '');
  });

  test('validasi nomor dan pesan kesalahan', () {
    expect(WhatsAppHelper.isValidPhone('08123456789'), isTrue);
    expect(WhatsAppHelper.isValidPhone('08123'), isFalse);
    expect(WhatsAppHelper.validatePhone(''), isNull);
    expect(
      WhatsAppHelper.validatePhone('12345'),
      'No. HP harus diawali 08 atau 628',
    );
  });

  testWidgets('nomor tidak valid menampilkan SnackBar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => ElevatedButton(
              onPressed: () =>
                  WhatsAppHelper.openChat(context, phone: '123'),
              child: const Text('Buka Chat'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Buka Chat'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Nomor WhatsApp tidak valid.'), findsOneWidget);
  });
}
