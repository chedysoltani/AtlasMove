import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'utils/app_theme.dart';
import 'screens/landing_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/client_dashboard.dart';
import 'screens/booking_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/profile_screen.dart';
import 'examples/auth_example.dart';
import 'screens/driver_main.dart';
import 'screens/driver_dashboard.dart';
import 'screens/driver_rides.dart';
import 'screens/driver_active_ride.dart';
import 'screens/driver_earnings.dart';
import 'screens/driver_profile.dart';
import 'screens/driver_register_screen.dart';
import 'screens/driver_register_test_screen.dart';
import 'screens/client_trip_history_screen.dart';
import 'screens/signup_steps/signup_step1_personal.dart';
import 'screens/signup_steps/signup_step2_documents.dart';
import 'screens/signup_steps/signup_step3_vehicle.dart';
import 'providers/auth_provider.dart';
import 'screens/services_screen.dart';
import 'screens/services_catalogue_screen.dart';
import 'screens/services_assignments_screen.dart';
import 'screens/create_ride_screen.dart';

void main() {
  runApp(const AtlasMoveApp());
}

class AtlasMoveApp extends StatelessWidget {
  const AtlasMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: provider.ChangeNotifierProvider(
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
            '/client_trip_history': (context) => const ClientTripHistoryScreen(),
            '/booking': (context) => const BookingScreen(),
            '/payment': (context) => const PaymentPage(),
            '/otp_verification': (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              return OtpVerificationScreen(
                email: args?['email'] ?? '',
                sessionToken: args?['sessionToken'] ?? '',
              );
            },
            '/profile': (context) => const ProfileScreen(),
            '/test_auth': (context) => const AuthExample(),
            '/driver_main': (context) => const DriverMainScreen(),
            '/driver_dashboard': (context) => const DriverDashboard(),
            '/driver_rides': (context) => const DriverRidesScreen(),
            '/driver_earnings': (context) => const DriverEarningsScreen(),
            '/driver_profile': (context) => const DriverProfileScreen(),
            '/driver_register': (context) => const DriverRegisterScreen(),
            '/driver_register_test': (context) => const DriverRegisterTestScreen(),
            '/services': (context) => const ServicesScreen(),
            '/services_catalogue': (context) => const ServicesCatalogueScreen(),
            '/services_assignments': (context) => const ServicesAssignmentsScreen(),
            '/create_ride': (context) => const CreateRideScreen(),
          },
        ),
      ),
    );
  }
}
