import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import '../services/firebase_analytics_service.dart';

/// Choix du type de compte, affiché à la fin du guide de présentation :
/// client (se déplacer / commander) ou chauffeur / livreur.
///
/// L'écran reste dans la pile sous l'inscription choisie : le bouton retour
/// de l'inscription y ramène. Les liens d'inscription des campagnes
/// (voir DeepLinkService) ouvrent l'inscription directement, sans passer ici.
class AccountTypeSelectionScreen extends StatefulWidget {
  const AccountTypeSelectionScreen({super.key});

  /// Route de l'écran. Son `screen_view` Analytics est envoyé sous le nom
  /// `account_type_selection` (voir FirebaseAnalyticsService).
  static const route = '/account_type';

  @override
  State<AccountTypeSelectionScreen> createState() => _AccountTypeSelectionScreenState();
}

class _AccountTypeSelectionScreenState extends State<AccountTypeSelectionScreen> {
  // Même palette que le guide de présentation qui précède cet écran.
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C42);
  static const _dark = Color(0xFF0F172A);
  static const _darkCard = Color(0xFF1A2744);


  void _choose(String type, String route) {
    FirebaseAnalyticsService.instance.logAccountTypeSelected(type);
    Navigator.of(context).pushNamed(route);
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'account_type.title'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'account_type.subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      _AccountTypeCard(
                        icon: Icons.place_rounded,
                        title: 'account_type.client_title'.tr(),
                        description: 'account_type.client_body'.tr(),
                        onTap: () => _choose('client', '/signup'),
                      ),
                      const SizedBox(height: 16),
                      _AccountTypeCard(
                        icon: Icons.local_shipping_rounded,
                        title: 'account_type.driver_title'.tr(),
                        description: 'account_type.driver_body'.tr(),
                        onTap: () => _choose('driver', '/driver_register'),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/login'),
                  child: Text.rich(
                    TextSpan(
                      text: '${'account_type.have_account'.tr()} ',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      children: [
                        TextSpan(
                          text: 'account_type.login'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _orange,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
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
        ],
      ),
    );
  }
}

/// Grande carte cliquable : icône, titre et courte explication.
class _AccountTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const orange = _AccountTypeSelectionScreenState._orange;
    const orangeLight = _AccountTypeSelectionScreenState._orangeLight;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Semantics(
      button: true,
      label: '$title. $description',
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: orange.withValues(alpha: 0.15),
          highlightColor: orange.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: orange.withValues(alpha: 0.25), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [orange, orangeLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: orange.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.65),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
