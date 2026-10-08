import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../utils/app_theme.dart';
import '../core/auth/auth_session.dart';
import '../main.dart' show navigatorKey;
import '../services/push_notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/deep_link_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // La restauration de session (lecture des tokens, refresh silencieux si
  // l'access token est expiré) démarre tout de suite, en parallèle de l'animation.
  late final Future<BootResult> _bootFuture;

  @override
  void initState() {
    super.initState();
    _bootFuture = AuthSession.restore();
    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _logoScale = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ));

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOutBack,
    ));
  }

  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 2000));
    if (mounted) {
      _navigateToLanding();
    }
  }

  Future<void> _navigateToLanding() async {
    final boot = await _bootFuture;
    // Premier lancement sans session : présentation de l'app avant l'accueil.
    final showIntro = boot.destination == BootDestination.landing &&
        !await OnboardingService.instance.isSeen(OnboardingGuide.intro);
    if (!mounted) return;

    final nav = Navigator.of(context);
    nav.pushReplacementNamed(
      // Premier lancement : choix de la langue, puis présentation de l'app
      showIntro ? '/language_first' : boot.route,
      arguments: boot.sessionExpired ? {'sessionExpired': true} : null,
    );

    // Lien d'inscription (campagne) reçu au lancement : ignoré si une session
    // est restaurée ; au premier lancement, c'est l'écran de langue qui l'ouvre.
    final loggedIn = boot.destination == BootDestination.client ||
        boot.destination == BootDestination.driver;
    if (loggedIn) {
      DeepLinkService.instance.takePendingRoute();
    } else if (!showIntro) {
      final linkRoute = DeepLinkService.instance.takePendingRoute();
      if (linkRoute != null) nav.pushNamed(linkRoute);
    }
    DeepLinkService.instance.markReady();

    // Rejoue un tap sur une notification "nouvelle course" / "appel entrant"
    // reçu pendant que l'app était fermée (voir push_notification_service.dart).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.consumePendingAction(navigatorKey);
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/image1.jpg',
              fit: BoxFit.cover,
            ),
            Container(
              color: Colors.black.withOpacity(0.45),
            ),
            Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Animation
              AnimatedBuilder(
                animation: _logoScale,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: AppTheme.textWhite,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/new_logo_mobile.png',
                          width: 90,
                          height: 90,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Text Animation
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          Text(
                            'AtlasMove',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.textWhite,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'landing.tagline'.tr(),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textWhite.withOpacity(0.9),
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 80),

              // Loading Indicator
              AnimatedBuilder(
                animation: _textController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _textOpacity,
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.textWhite),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
}
