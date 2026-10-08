import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/onboarding_service.dart';

/// Guide de première utilisation : pages à faire défiler, avec « Passer »
/// toujours visible. Le même écran sert aux trois guides (voir [OnboardingGuide]).
class OnboardingScreen extends StatefulWidget {
  final OnboardingGuide guide;

  const OnboardingScreen({super.key, required this.guide});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingPage {
  final IconData icon;
  final String key;

  const _OnboardingPage(this.icon, this.key);
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);
  static const _darkCard = Color(0xFF1A2744);

  static const Map<OnboardingGuide, List<_OnboardingPage>> _pagesByGuide = {
    OnboardingGuide.intro: [
      _OnboardingPage(Icons.local_shipping_rounded, 'welcome'),
      _OnboardingPage(Icons.person_add_alt_1_rounded, 'account'),
      _OnboardingPage(Icons.swap_horiz_rounded, 'role'),
      _OnboardingPage(Icons.my_location_rounded, 'permissions'),
    ],
    OnboardingGuide.client: [
      _OnboardingPage(Icons.place_rounded, 'book'),
      _OnboardingPage(Icons.directions_car_rounded, 'transport'),
      _OnboardingPage(Icons.local_offer_rounded, 'price'),
      _OnboardingPage(Icons.navigation_rounded, 'track'),
      _OnboardingPage(Icons.card_giftcard_rounded, 'more'),
    ],
    OnboardingGuide.driver: [
      _OnboardingPage(Icons.badge_rounded, 'profile'),
      _OnboardingPage(Icons.workspace_premium_rounded, 'subscription'),
      _OnboardingPage(Icons.power_settings_new_rounded, 'online'),
      _OnboardingPage(Icons.notifications_active_rounded, 'offers'),
      _OnboardingPage(Icons.account_balance_wallet_rounded, 'earnings'),
    ],
  };

  final PageController _pageCtrl = PageController();
  int _index = 0;

  List<_OnboardingPage> get _pages => _pagesByGuide[widget.guide]!;
  bool get _isLast => _index == _pages.length - 1;
  bool get _isIntro => widget.guide == OnboardingGuide.intro;

  String _t(String page, String field) =>
      'onboarding.${widget.guide.name}.${page}_$field'.tr();

  @override
  void initState() {
    super.initState();
    OnboardingService.instance.markSeen(widget.guide);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  /// Fin du guide (ou « Passer »). [signup] : l'utilisateur veut créer un compte.
  void _finish({bool signup = false}) {
    final nav = Navigator.of(context);
    if (!_isIntro) {
      nav.pop();
      return;
    }
    // La présentation remplace l'accueil au premier lancement : on y revient
    // pour que le bouton retour de l'inscription / connexion y ramène.
    nav.pushReplacementNamed('/landing');
    nav.pushNamed(signup ? '/signup' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_dark, _darkCard],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _buildPage(_pages[i], i),
                ),
              ),
              _buildDots(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _buildButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              'assets/images/new_logo_mobile.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'AtlasMove',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          if (!_isLast)
            TextButton(
              onPressed: _finish,
              child: Text(
                'onboarding.skip'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, int i) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _orange.withOpacity(0.08),
              border: Border.all(color: _orange.withOpacity(0.15)),
            ),
            child: Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_orange, _orangeLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _orange.withOpacity(0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(page.icon, color: Colors.white, size: 46),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'onboarding.step'.tr(namedArgs: {
                'current': '${i + 1}',
                'total': '${_pages.length}',
              }),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _orange,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t(page.key, 'title'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t(page.key, 'body'),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white.withOpacity(0.65),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final active = i == _index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _orange : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildButtons() {
    if (_isLast && _isIntro) {
      return Column(
        children: [
          _primaryButton('onboarding.create_account'.tr(),
              () => _finish(signup: true)),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: _finish,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withOpacity(0.3), width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'onboarding.have_account'.tr(),
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return _primaryButton(
      _isLast ? 'onboarding.start'.tr() : 'common.next'.tr(),
      _isLast ? _finish : _next,
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_orange, _orangeLight],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _orange.withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
