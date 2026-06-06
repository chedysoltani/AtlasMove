import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

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
import 'screens/driver_offer_screen.dart';
import 'screens/client_rewards_screen.dart';
import 'screens/cards_list_screen.dart';
import 'screens/payment_history_screen.dart';
import 'models/trip_models.dart';
import 'services/notification_service.dart';
import 'widgets/notification_sheet.dart';
import 'models/notification_model.dart';
import 'screens/driver_subscription_screen.dart';
import 'screens/driver_crypto_select_screen.dart';
import 'screens/driver_crypto_recharge_screen.dart';
import 'screens/driver_usdt_payment_screen.dart';
import 'screens/referral_screen.dart';
import 'screens/client_rendezvous_booking_screen.dart';
import 'screens/client_rendezvous_history_screen.dart';
import 'screens/driver_rendezvous_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser les données de localisation française pour DateFormat
  await initializeDateFormatting('fr', null);

  // Charger les variables d'environnement
  await dotenv.load(fileName: ".env");
  
  // Initialiser Stripe
  Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  await Stripe.instance.applySettings();

  // Configurer la réception globale des notifications in-app
  NotificationService.onNewNotificationReceived = (item) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      NotificationSheet.showInAppBanner(context, item);
    }
  };

  // Bonus de parrainage reçu en temps réel
  NotificationService.onReferralBonusReceived = (pointsGained, message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      _showReferralBonusOverlay(context, pointsGained, message);
    }
  };
  
  runApp(const AtlasMoveApp());
}

/// Shows a celebratory dialog when the driver earns a referral bonus in real time.
void _showReferralBonusOverlay(BuildContext context, int points, String message) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1C2A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFF97316), size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Parrainage Réussi !',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Text(
                '+$points points IA',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text('Super !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class AtlasMoveApp extends StatelessWidget {
  const AtlasMoveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: provider.ChangeNotifierProvider(
        create: (context) => AuthProvider(),
        child: MaterialApp(
          navigatorKey: navigatorKey,
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
            '/driver_offer': (context) => const DriverOfferScreen(),
            '/client_rewards': (context) => const ClientRewardsScreen(),
            '/cards': (context) => const CardsListScreen(),
            '/payment_history': (context) => const PaymentHistoryScreen(),
            '/driver_subscription': (context) => const DriverSubscriptionScreen(),
            '/driver_crypto_select': (context) => const DriverCryptoSelectScreen(),
            '/driver_crypto_recharge': (context) => const DriverCryptoRechargeScreen(),
            '/driver_usdt_payment': (context) => const DriverUsdtPaymentScreen(),
            '/referral': (context) => const ReferralScreen(),
            '/client_rendezvous_booking': (context) =>
                const ClientRendezvousBookingScreen(),
            '/client_rendezvous_history': (context) =>
                const ClientRendezvousHistoryScreen(),
            '/driver_rendezvous': (context) =>
                const DriverRendezvousScreen(),
          },
        ),
      ),
    );
  }
}
