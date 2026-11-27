import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/detail_absensi_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/services/location_name_service.dart';
import 'package:hris_mobile/services/work_duration.dart';
import 'package:hris_mobile/widgets/osm_map_preview.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LocationNameService.clearCache();
  });

  test('format nama tempat dari alamat reverse geocoding', () {
    const String nama = 'Jl. Jend. Sudirman, Menteng, Jakarta Pusat';
    expect(
      LocationNameService.formatNamaTempat(<String, dynamic>{
        'road': 'Jl. Jend. Sudirman',
        'neighbourhood': 'Menteng',
        'city_district': 'Menteng',
        'city': 'Jakarta Pusat',
      }),
      nama,
    );
    expect(
      LocationNameService.formatNamaTempat(<String, dynamic>{
        'building': 'Gedung Dignity',
        'suburb': 'Kebayoran Baru',
        'city': 'Jakarta Selatan',
      }),
      'Gedung Dignity, Kebayoran Baru, Jakarta Selatan',
    );
    expect(
      LocationNameService.formatNamaTempat(
        <String, dynamic>{},
        displayName: 'Jl. Contoh, Kel. Contoh, Kota Contoh, Negara',
      ),
      'Jl. Contoh, Kel. Contoh, Kota Contoh',
    );
    expect(
      LocationNameService.formatNamaTempat(<String, dynamic>{}),
      'Lokasi terdeteksi pada koordinat tersebut',
    );
  });

  test('perhitungan posisi tile peta presisi', () {
    expect(OsmMapPreview.tileX(0, 0), closeTo(0.5, 0.000001));
    expect(OsmMapPreview.tileY(0, 0), closeTo(0.5, 0.000001));
    expect(
      OsmMapPreview.tileX(106.8456, 16),
      greaterThan(OsmMapPreview.tileX(106.0, 16)),
    );
    expect(
      OsmMapPreview.tileY(-6.2088, 16),
      greaterThan(OsmMapPreview.tileY(0, 16)),
    );
  });

  test('format durasi kerja dua digit sampai satuan detik', () {
    expect(
      WorkDuration.format(
        const Duration(hours: 8, minutes: 15, seconds: 32),
      ),
      '08:15:32',
    );
    expect(WorkDuration.format(null), '00:00:00');
    expect(WorkDuration.format(const Duration(seconds: -5)), '00:00:00');
    expect(
      WorkDuration.dariString(
        '2026-11-25 08:00:00',
        '2026-11-25 16:15:32',
      ),
      '08:15:32',
    );
    expect(WorkDuration.dariString('08:00:00', '17:00:00'), '09:00:00');
    expect(WorkDuration.dariString('08:00:00', ''), '00:00:00');
    expect(WorkDuration.dariString('23:30:00', '00:15:00'), '00:45:00');
    expect(WorkDuration.normalize('0'), '00:00:00');
    expect(WorkDuration.normalize('8'), '08:00:00');
  });

  test('reverse geocoding memakai Nominatim dan cache memori', () async {
    int calls = 0;
    final http.Client client = MockClient((http.Request request) async {
      calls++;
      expect(request.url.host, 'nominatim.openstreetmap.org');
      expect(request.url.path, '/reverse');
      expect(request.url.queryParameters['format'], 'jsonv2');
      expect(request.url.queryParameters['lat'], '-6.2088');
      expect(request.url.queryParameters['lon'], '106.8456');
      expect(request.url.queryParameters['accept-language'], 'id');
      expect(request.headers['User-Agent'], 'HRISDignityMobile/1.0');
      return http.Response(
        jsonEncode(<String, dynamic>{
          'display_name': 'Jl. Contoh, Jakarta, Indonesia',
          'address': <String, dynamic>{
            'road': 'Jl. Contoh',
            'city': 'Jakarta',
          },
        }),
        200,
      );
    });

    final String first = await LocationNameService.resolve(
      -6.2088,
      106.8456,
      client: client,
    );
    final String second = await LocationNameService.resolve(
      -6.2088,
      106.8456,
      client: client,
    );

    expect(first, 'Jl. Contoh, Jakarta');
    expect(second, first);
    expect(calls, 1);
    expect(LocationNameService.cached(-6.2088, 106.8456), first);
  });

  testWidgets('Detail Absensi menampilkan nama lokasi dan komponen peta', (
    WidgetTester tester,
  ) async {
    const String namaTempat = 'Jl. Jend. Sudirman, Menteng, Jakarta Pusat';
    final Completer<String> namaLokasi = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: DetailAbsensiScreen(
          nama: 'Andi Pratama',
          tanggal: '25 November 2026',
          jamMasuk: '08:00',
          jamKeluar: '17:00',
          latitude: '-6.2088',
          longitude: '106.8456',
          namaLokasiResolver: (double lat, double lon) => namaLokasi.future,
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Memuat nama lokasi...'), findsNWidgets(2));
    expect(find.text('Nama Tempat'), findsOneWidget);
    expect(find.text('Lokasi'), findsOneWidget);
    expect(find.byType(OsmMapPreview), findsOneWidget);
    expect(find.text('Lihat Peta'), findsOneWidget);

    namaLokasi.complete(namaTempat);
    await tester.pump();
    await tester.pump();

    expect(find.text(namaTempat), findsNWidgets(2));
    expect(find.text('-6.2088,106.8456'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);

    final Text judulLokasi = tester.widget<Text>(
      find.text(namaTempat).last,
    );
    expect(judulLokasi.style?.fontWeight, FontWeight.w800);
    expect(judulLokasi.style?.fontSize, 16);
  });

  testWidgets('Detail Absensi memakai timestamp lengkap untuk durasi kerja', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DetailAbsensiScreen(
          nama: 'Andi Pratama',
          tanggal: '25 November 2026',
          jamMasuk: '08:00',
          jamKeluar: '16:15',
          jamMasukLengkap: '2026-11-25 08:00:00',
          jamPulangLengkap: '2026-11-25 16:15:32',
          totalWork: '0',
          latitude: '-6.2088',
          longitude: '106.8456',
          namaLokasiResolver: (double lat, double lon) async => 'Kantor Pusat',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Durasi Kerja'), findsOneWidget);
    expect(find.text('08:15:32'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Detail Absensi memakai 00:00:00 bila belum ada waktu pulang', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DetailAbsensiScreen(
          nama: 'Andi Pratama',
          tanggal: '25 November 2026',
          jamMasuk: '08:00',
          jamKeluar: '-',
          jamMasukLengkap: '2026-11-25 08:00:00',
          latitude: '-6.2088',
          longitude: '106.8456',
          namaLokasiResolver: (double lat, double lon) async => 'Kantor Pusat',
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Durasi Kerja'), findsOneWidget);
    expect(find.text('00:00:00'), findsOneWidget);
  });

  testWidgets('HR melihat Chat WhatsApp saat nomor HP tersedia', (
    WidgetTester tester,
  ) async {
    AppSession.role = 'hr';
    await tester.pumpWidget(
      MaterialApp(
        home: DetailAbsensiScreen(
          nama: 'Andi Pratama',
          tanggal: '25 November 2026',
          jamMasuk: '08:00',
          jamKeluar: '17:00',
          latitude: '-6.2088',
          longitude: '106.8456',
          noHp: '08123456789',
          namaLokasiResolver: (double lat, double lon) async => 'Kantor Pusat',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chat WhatsApp'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: DetailAbsensiScreen(
          nama: 'Andi Pratama',
          tanggal: '25 November 2026',
          jamMasuk: '08:00',
          jamKeluar: '17:00',
          latitude: '-6.2088',
          longitude: '106.8456',
          namaLokasiResolver: (double lat, double lon) async => 'Kantor Pusat',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Chat WhatsApp'), findsNothing);
  });
}
