import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hris_mobile/screens/layanan_cuti_screen.dart';
import 'package:hris_mobile/screens/main_screen.dart';
import 'package:hris_mobile/services/app_session.dart';
import 'package:hris_mobile/widgets/glass_bottom_nav.dart';
import 'package:hris_mobile/widgets/profile_avatar_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await AppSession.clear();
  });

  testWidgets('tab Cuti & Izin berada tepat di sebelah Absen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    final Finder nav = find.byType(GlassBottomNav);
    expect(nav, findsOneWidget);

    final List<String> labels = tester
        .widgetList<Text>(find.descendant(of: nav, matching: find.byType(Text)))
        .map((Text widget) => widget.data ?? '')
        .toList();

    expect(labels.first, 'Absen');
    expect(labels[1], 'Cuti & Izin');
    expect(labels, contains('Pengumuman'));
    expect(find.byType(ProfileAvatarButton), findsOneWidget);
  });

  testWidgets('halaman Cuti & Izin menyusun tabel, tombol, lalu riwayat', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LayananCutiScreen()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Leader Pemberi Izin Cuti'), findsOneWidget);
    expect(find.text('Pengajuan Cuti'), findsOneWidget);
    expect(find.text('Izin Keluar'), findsOneWidget);
    expect(find.text('Riwayat Cuti'), findsOneWidget);

    final double tabelY = _y(tester, 'Leader Pemberi Izin Cuti');
    final double pengajuanY = _y(tester, 'Pengajuan Cuti');
    final double izinY = _y(tester, 'Izin Keluar');
    final double riwayatY = _y(tester, 'Riwayat Cuti');

    expect(tabelY, lessThan(pengajuanY));
    expect(pengajuanY, closeTo(izinY, 4));
    expect(izinY, lessThan(riwayatY));
  });
}

double _y(WidgetTester tester, String teks) {
  return tester.getCenter(find.text(teks)).dy;
}
