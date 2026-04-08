import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'utils/app_theme.dart';
import 'screens/landing_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/client_dashboard.dart';
import 'screens/signup_steps/signup_step1_personal.dart';
import 'screens/signup_steps/signup_step2_documents.dart';
import 'screens/signup_steps/signup_step3_vehicle.dart';
import 'screens/booking_screen.dart';
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
          '/landing': (context) => const LandingScreen(),
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/signup_step1': (context) => const SignupStep1Personal(),
          '/signup_step2': (context) => const SignupStep2Documents(),
          '/signup_step3': (context) => const SignupStep3Vehicle(),
          '/client_dashboard': (context) => const ClientDashboard(),
          '/booking': (context) => const BookingScreen(),
        },
      ),
    );
  }
}
