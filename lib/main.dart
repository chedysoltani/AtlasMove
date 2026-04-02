import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'providers/auth_provider.dart';

void main() {
  runApp(const AtlasMoveApp());
}

class AtlasMoveApp extends StatelessWidget {
  const AtlasMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MaterialApp(
        title: 'AtlasMove',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
        },
      ),
    );
  }
}
