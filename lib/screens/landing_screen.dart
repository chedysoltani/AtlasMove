import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);
  static const _darkCard = Color(0xFF1A2744);

  late final AnimationController _heroCtrl;
  late final AnimationController _pulseCtrl;
  late final List<AnimationController> _itemCtrls;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _itemCtrls = List.generate(6, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      Future.delayed(Duration(milliseconds: 350 + i * 110), () {
        if (mounted) c.forward();
      });
      return c;
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _pulseCtrl.dispose();
    for (final c in _itemCtrls) c.dispose();
    super.dispose();
  }

  Animation<double> _fade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);

  Animation<Offset> _slide(AnimationController c) =>
      Tween(begin: const Offset(0, 0.22), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final heroH = size.height * 0.42;

    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          // ── Hero ──────────────────────────────────────────────────────
          SizedBox(height: heroH, child: _buildHero()),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _animated(0, _buildSectionHeader()),
                    const SizedBox(height: 18),
                    _animated(1, _buildFeatureTile(
                      icon: Icons.person_rounded,
                      title: 'landing.for_clients'.tr(),
                      description: 'landing.for_clients_desc'.tr(),
                      onTap: () => _nav(context, 'client'),
                    )),
                    const SizedBox(height: 10),
                    _animated(2, _buildFeatureTile(
                      icon: Icons.local_shipping_rounded,
                      title: 'landing.for_drivers'.tr(),
                      description: 'landing.for_drivers_desc'.tr(),
                      onTap: () => _nav(context, 'client'),
                    )),
                    const SizedBox(height: 10),
                    _animated(3, _buildFeatureTile(
                      icon: Icons.gps_fixed_rounded,
                      title: 'landing.gps'.tr(),
                      description: 'landing.gps_desc'.tr(),
                      onTap: null,
                    )),
                    const SizedBox(height: 26),
                    _animated(4, _buildButtons(context)),
                    const SizedBox(height: 20),
                    _animated(5, _buildTrustRow()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Section ─────────────────────────────────────────────────────────

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fade(_heroCtrl),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_dark, _darkCard],
              ),
            ),
          ),

          // Decorative rings
          Positioned(top: -50, right: -50,
            child: _ring(200, _orange.withOpacity(0.07))),
          Positioned(bottom: 20, left: -70,
            child: _ring(220, Colors.white.withOpacity(0.03))),
          Positioned(top: 60, left: 30,
            child: _dot(7, _orange.withOpacity(0.4))),
          Positioned(bottom: 60, right: 40,
            child: _dot(5, Colors.white.withOpacity(0.2))),
          Positioned(top: 30, right: 80,
            child: _dot(4, _orange.withOpacity(0.25))),

          // Main hero content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Pulsing icon badge
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) {
                      final glow = 18.0 + _pulseCtrl.value * 12;
                      final scale = 1.0 + _pulseCtrl.value * 0.04;
                      return Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_orange, _orangeLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _orange.withOpacity(0.45),
                                blurRadius: glow,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/new_logo_mobile.png',
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  // Brand name
                  Text(
                    'AtlasMove',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline with accent lines
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _accentLine(),
                      const SizedBox(width: 10),
                      Text(
                        'landing.tagline'.tr(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.55),
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _accentLine(),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Stats row
                  _buildHeroStats(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('500+', 'landing.clients_stat'.tr()),
          _vDivider(),
          _statItem('200+', 'landing.drivers_stat'.tr()),
          _vDivider(),
          _statItem('24/7', 'landing.available_stat'.tr()),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: GoogleFonts.poppins(
          fontSize: 16, fontWeight: FontWeight.w700, color: _orange)),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 10, color: Colors.white.withOpacity(0.5))),
      ],
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 28, color: Colors.white.withOpacity(0.1));

  Widget _accentLine() =>
      Container(width: 22, height: 2,
          decoration: BoxDecoration(
              color: _orange,
              borderRadius: BorderRadius.circular(1)));

  Widget _ring(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: 1),
    ),
  );

  Widget _dot(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  // ── Content Widgets ──────────────────────────────────────────────────────

  Widget _buildSectionHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('landing.how_it_works'.tr(), style: GoogleFonts.poppins(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _orange, letterSpacing: 1.5)),
        const SizedBox(height: 3),
        Text('landing.join_adventure'.tr(), style: GoogleFonts.poppins(
          fontSize: 21, fontWeight: FontWeight.w700,
          color: _dark, height: 1.2)),
      ],
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDisabled
                ? const Color(0xFFE2E6EF)
                : _orange.withOpacity(0.12),
          ),
          boxShadow: isDisabled ? [] : [
            BoxShadow(
              color: _orange.withOpacity(0.07),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDisabled
                    ? const Color(0xFFF1F3F7)
                    : _orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon,
                color: isDisabled ? const Color(0xFF9BA3B4) : _orange,
                size: 22),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: isDisabled ? const Color(0xFF9BA3B4) : _dark)),
                  const SizedBox(height: 2),
                  Text(description, style: GoogleFonts.poppins(
                    fontSize: 12, color: const Color(0xFF9BA3B4),
                    height: 1.4)),
                ],
              ),
            ),
            if (!isDisabled) ...[
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _dark,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Column(
      children: [
        // Primary CTA
        Container(
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
            onPressed: () => _nav(context, 'client'),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('landing.start_now'.tr(),
              style: GoogleFonts.poppins(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: Colors.white)),
          ),
        ),

        const SizedBox(height: 11),

        // Secondary CTA
        SizedBox(
          width: double.infinity,
          height: 54,
          child: OutlinedButton(
            onPressed: () =>
                Navigator.of(context).pushNamed('/driver_register'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _dark, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping_rounded,
                    color: _dark, size: 18),
                const SizedBox(width: 8),
                Text('landing.become_driver'.tr(),
                  style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w600,
                    color: _dark)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _trustBadge(Icons.verified_user_rounded, 'landing.secured'.tr()),
        const SizedBox(width: 24),
        _trustBadge(Icons.bolt_rounded, 'landing.fast'.tr()),
        const SizedBox(width: 24),
        _trustBadge(Icons.star_rounded, 'landing.reliable'.tr()),
      ],
    );
  }

  Widget _trustBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _orange, size: 19),
        ),
        const SizedBox(height: 5),
        Text(label, style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w500,
          color: const Color(0xFF9BA3B4))),
      ],
    );
  }

  Widget _animated(int i, Widget child) {
    if (i >= _itemCtrls.length) return child;
    return SlideTransition(
      position: _slide(_itemCtrls[i]),
      child: FadeTransition(opacity: _fade(_itemCtrls[i]), child: child),
    );
  }

  void _nav(BuildContext context, String role) {
    if (role == 'delivery') {
      Navigator.of(context).pushNamed('/signup_step1');
    } else {
      Navigator.of(context).pushNamed('/login');
    }
  }
}
