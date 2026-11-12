import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);

  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.containsKey('user_id');

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
      home: isLoggedIn ? const MainScreen() : const LoginScreen(),
    );
  }
}
