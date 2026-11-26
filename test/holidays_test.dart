import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/kelola_hari_libur_screen.dart';
import 'package:hris_mobile/screens/layanan_cuti_screen.dart';
import 'package:hris_mobile/screens/settings_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/holidays_service.dart';
import 'package:hris_mobile/services/izin_keluar_service.dart';
import 'package:hris_mobile/services/riwayat_cuti_service.dart';
import 'package:hris_mobile/widgets/holiday_badge.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  test('HolidayItem membaca data dan mengurutkan tanggal', () {
    final HolidayItem nasional = HolidayItem.fromJson(<String, dynamic>{
      'id': 1,
      'holiday_date': '2026-12-25',
      'title': 'Natal',
      'is_national': 1,
    });
    final HolidayItem perusahaan = HolidayItem.fromJson(<String, dynamic>{
      'id': 2,
      'holiday_date': '2026-11-10 00:00:00',
      'title': 'Libur Perusahaan',
      'is_national': 0,
    });

    expect(nasional.jenisLabel, 'Nasional');
    expect(perusahaan.jenisLabel, 'Perusahaan');
    expect(nasional.tanggalRingkas, '25 Des 2026');

    final List<HolidayItem> items = <HolidayItem>[nasional, perusahaan]
      ..sort(HolidayItem.compareByDate);
    expect(items.first.title, 'Libur Perusahaan');
  });

  test('HolidayService GET, POST, dan DELETE ke holidays.php', () async {
    final List<Map<String, dynamic>> posted = <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> deleted = <Map<String, dynamic>>[];
    final http.Client client = _holidayClient(
      posted: posted,
      deleted: deleted,
      holidays: <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'holiday_date': '2026-12-20',
          'title': 'A',
          'is_national': false,
        },
        <String, dynamic>{
          'id': 2,
          'holiday_date': '2026-12-10',
          'title': 'B',
          'is_national': true,
        },
      ],
    );

    final List<HolidayItem> items = await HolidayService.fetch(client: client);
    expect(items.map((HolidayItem item) => item.title).toList(),
        <String>['B', 'A']);

    await HolidayService.add(
      date: DateTime(2026, 12, 25),
      title: 'Natal',
      description: 'Libur nasional',
      isNational: true,
      client: client,
    );
    expect(posted.single, <String, dynamic>{
      'holiday_date': '2026-12-25',
      'title': 'Natal',
      'description': 'Libur nasional',
      'is_national': true,
    });

    await HolidayService.remove(7, client: client);
    expect(deleted.single, <String, dynamic>{'action': 'delete', 'id': 7});
  });

  testWidgets('Kelola Hari Libur menampilkan daftar urut beserta badge', (
    WidgetTester tester,
  ) async {
    AppSession.role = 'super_admin';
    final http.Client client = _holidayClient(
      holidays: _duaLibur(),
    );
    await tester.pumpWidget(
      MaterialApp(home: KelolaHariLiburScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tahun Baru'), findsOneWidget);
    expect(find.text('Libur Perusahaan'), findsOneWidget);
    expect(find.byType(HolidayBadge), findsNWidgets(2));
    expect(find.text('Nasional'), findsOneWidget);
    expect(find.text('Perusahaan'), findsOneWidget);
    expect(_y(tester, 'Libur Perusahaan'), lessThan(_y(tester, 'Tahun Baru')));
  });

  testWidgets('Super admin hanya menghapus libur nasional', (
    WidgetTester tester,
  ) async {
    AppSession.role = 'super_admin';
    final List<Map<String, dynamic>> deleted = <Map<String, dynamic>>[];
    final http.Client client = _holidayClient(
      holidays: _duaLibur(),
      deleted: deleted,
    );
    await tester.pumpWidget(
      MaterialApp(home: KelolaHariLiburScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Hapus hari libur?'), findsOneWidget);

    await tester.tap(find.text('Hapus'));
    await tester.pump();
    await tester.pump();

    expect(deleted.single, <String, dynamic>{'action': 'delete', 'id': 1});
  });

  testWidgets('HR hanya menghapus libur perusahaan', (
    WidgetTester tester,
  ) async {
    AppSession.role = 'hr';
    final http.Client client = _holidayClient(holidays: _duaLibur());
    await tester.pumpWidget(
      MaterialApp(home: KelolaHariLiburScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    final Finder nasional = find.ancestor(
      of: find.text('Tahun Baru'),
      matching: find.byType(ListTile),
    );
    final Finder perusahaan = find.ancestor(
      of: find.text('Libur Perusahaan'),
      matching: find.byType(ListTile),
    );

    expect(
      find.descendant(
        of: nasional,
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: perusahaan,
        matching: find.byIcon(Icons.delete_outline_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Form tambah hari libur mengirim data sesuai wewenang', (
    WidgetTester tester,
  ) async {
    AppSession.role = 'super_admin';
    final List<Map<String, dynamic>> posted = <Map<String, dynamic>>[];
    final http.Client client = _holidayClient(
      posted: posted,
      holidays: const <Map<String, dynamic>>[],
    );
    await tester.pumpWidget(
      MaterialApp(home: KelolaHariLiburScreen(httpClient: client)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tambah Hari Libur'));
    await tester.pumpAndSettle();
    expect(_field('Tanggal Libur'), findsOneWidget);
    expect(_field('Nama Hari Libur'), findsOneWidget);
    expect(_field('Keterangan'), findsOneWidget);

    await tester.tap(_field('Tanggal Libur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(_field('Nama Hari Libur'), 'Hari Kemerdekaan');
    await tester.enterText(_field('Keterangan'), 'Upacara bendera');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    await tester.pump();

    expect(posted, hasLength(1));
    expect(posted.single['title'], 'Hari Kemerdekaan');
    expect(posted.single['description'], 'Upacara bendera');
    expect(posted.single['is_national'], isTrue);
    expect(posted.single['holiday_date'],
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
  });

  testWidgets('Kartu Hari Libur Terdekat membatasi maksimal lima libur', (
    WidgetTester tester,
  ) async {
    _gunakanLayarTinggi(tester);
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    String tanggal(int hari) =>
        HolidayItem.toIsoDate(today.add(Duration(days: hari)));
    final List<HolidayItem> holidays = <HolidayItem>[
      HolidayItem(
        id: 1,
        holidayDate: tanggal(-1),
        title: 'Libur Lalu',
        isNational: true,
      ),
      HolidayItem(
        id: 2,
        holidayDate: tanggal(0),
        title: 'Hari Ini',
        isNational: false,
      ),
      for (int i = 1; i <= 6; i++)
        HolidayItem(
          id: i + 10,
          holidayDate: tanggal(i * 2),
          title: 'Libur $i',
          isNational: i.isOdd,
        ),
    ];
    final http.Client client = MockClient((http.Request request) async {
      if (request.url.path.endsWith('/leave_leaders.php')) {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'leaders': <dynamic>[],
            'eligible_users': <dynamic>[],
          }),
          200,
        );
      }
      return http.Response('', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: LayananCutiScreen(
          httpClient: client,
          cutiLoader: () async => const <RiwayatCutiItem>[],
          izinLoader: () async => const <IzinKeluarItem>[],
          holidayLoader: () async => holidays,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hari Libur Terdekat'), findsOneWidget);
    expect(find.text('Libur Lalu'), findsNothing);
    expect(find.text('Hari Ini'), findsOneWidget);
    expect(find.text('Libur 4'), findsOneWidget);
    expect(find.text('Libur 5'), findsNothing);
    expect(find.byType(HolidayBadge), findsNWidgets(5));
    expect(_y(tester, 'Hari Ini'), lessThan(_y(tester, 'Libur 1')));
  });

  testWidgets('Settings menampilkan menu hari libur sesuai peran', (
    WidgetTester tester,
  ) async {
    _gunakanLayarTinggi(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(
          isHr: false,
          canApprove: false,
          isSuperAdmin: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kelola HR / Admin'), findsOneWidget);
    expect(find.text('Hari Libur Nasional'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(isHr: true, canApprove: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MENU HR'), findsOneWidget);
    expect(find.text('Hari Libur'), findsOneWidget);
  });
}

List<Map<String, dynamic>> _duaLibur() => <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 1,
        'holiday_date': '2027-01-01',
        'title': 'Tahun Baru',
        'description': 'Libur nasional',
        'is_national': true,
      },
      <String, dynamic>{
        'id': 2,
        'holiday_date': '2026-12-10',
        'title': 'Libur Perusahaan',
        'is_national': false,
      },
    ];

http.Client _holidayClient({
  required List<Map<String, dynamic>> holidays,
  List<Map<String, dynamic>>? posted,
  List<Map<String, dynamic>>? deleted,
}) {
  return MockClient((http.Request request) async {
    if (!request.url.path.endsWith('/holidays.php')) {
      return http.Response('', 404);
    }
    if (request.method == 'GET') {
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true, 'holidays': holidays}),
        200,
      );
    }
    if (request.method == 'POST') {
      posted?.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        201,
      );
    }
    if (request.method == 'DELETE') {
      deleted?.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode(<String, dynamic>{'success': true}),
        200,
      );
    }
    return http.Response('', 405);
  });
}

Finder _field(String label) {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is InputDecorator && widget.decoration.labelText == label,
  );
}

void _gunakanLayarTinggi(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double _y(WidgetTester tester, String teks) {
  return tester.getCenter(find.text(teks).first).dy;
}
