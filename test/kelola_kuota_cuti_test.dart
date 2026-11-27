import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/kelola_kuota_cuti_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
    AppSession.token = 'token-kuota';
  });

  testWidgets('pencarian dan Select All memfilter karyawan yang tampil', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> terkirim = <Map<String, dynamic>>[];
    final http.Client client = MockClient((http.Request request) async {
      if (request.method == 'GET') {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'employee_id': 1,
                'nama_lengkap': 'Andi Pratama',
                'username': 'andi.hr',
                'sisa_kuota': 12,
              },
              <String, dynamic>{
                'employee_id': 2,
                'nama_lengkap': 'Budi Santoso',
                'username': 'budi.s',
                'sisa_kuota': 8,
              },
            ],
          }),
          200,
        );
      }
      terkirim.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true, 'message': 'OK'}),
        200,
      );
    });

    await tester.pumpWidget(
      MaterialApp(home: KelolaKuotaCutiScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tambah'), findsOneWidget);
    expect(find.text('Kurangi'), findsOneWidget);
    expect(find.text('Select All'), findsOneWidget);
    expect(find.text('Andi Pratama'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);

    final TextField pencarian = tester.widget<TextField>(
      find.byType(TextField).at(1),
    );
    expect(pencarian.decoration!.hintText, contains('Cari nama atau username'));
    expect(
      tester.getTopLeft(find.text('Tambah')).dy,
      lessThan(tester.getTopLeft(find.byType(TextField).at(1)).dy),
    );

    await tester.enterText(find.byType(TextField).at(1), 'budi');
    await tester.pumpAndSettle();
    expect(find.text('Andi Pratama'), findsNothing);
    expect(find.text('Budi Santoso'), findsOneWidget);

    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.tap(find.text('Tambah'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(terkirim, hasLength(1));
    expect(terkirim.single['employee_ids'], <int>[2]);
    expect(terkirim.single['mode'], 'tambah');

    await tester.tap(find.byTooltip('Bersihkan pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('Andi Pratama'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);

    await tester.tap(find.text('Select All'));
    await tester.pumpAndSettle();
    expect(find.text('Deselect All'), findsOneWidget);
  });
}
