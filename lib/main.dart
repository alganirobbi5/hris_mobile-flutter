import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'services/app_session.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'widgets/app_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await AppNotificationService.initialize();

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await AppSession.restore(prefs);
  final bool isLoggedIn = prefs.containsKey(AppSession.userIdPrefKey);

  runApp(HrisApp(isLoggedIn: isLoggedIn));
}

class HrisApp extends StatelessWidget {
  const HrisApp({super.key, required this.isLoggedIn});

  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HRIS Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (BuildContext context, Widget? child) {
        return Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (BuildContext context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final OverlayState overlay = Overlay.of(context);
                  AppToast.attach(overlay);
                });
                return child ?? const SizedBox.shrink();
              },
            ),
          ],
        );
      },
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
