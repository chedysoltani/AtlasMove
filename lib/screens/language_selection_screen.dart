import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/locale_provider.dart';
import '../services/onboarding_service.dart';
import '../services/deep_link_service.dart';

class LanguageSelectionScreen extends StatefulWidget {
  /// Premier lancement : pas de bouton retour, la langue s'applique dès qu'on
  /// la touche, puis « Continuer » enchaîne sur la présentation de l'app.
  final bool firstLaunch;

  const LanguageSelectionScreen({super.key, this.firstLaunch = false});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  static const _bg = Color(0xFF0F1017);
  static const _card = Color(0xFF161722);
  static const _orange = Color(0xFFFF6B35);

  late String _selected;

  static const _languages = [
    _LangOption('fr', 'Français', '🇫🇷', 'French'),
    _LangOption('en', 'English', '🇬🇧', 'English'),
    _LangOption('ar', 'العربية', '🇸🇦', 'Arabic'),
    _LangOption('it', 'Italiano', '🇮🇹', 'Italian'),
    _LangOption('de', 'Deutsch', '🇩🇪', 'German'),
    _LangOption('es', 'Español', '🇪🇸', 'Spanish'),
  ];

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _selected = context.locale.languageCode;
    if (widget.firstLaunch) {
      // Au premier lancement, on propose la langue du téléphone si elle est disponible
      final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      if (_languages.any((l) => l.code == device) && device != _selected) {
        _selected = device;
        WidgetsBinding.instance.addPostFrameCallback((_) => _select(device));
      }
    }
  }

  Future<void> _select(String code) async {
    setState(() => _selected = code);
    // Premier lancement : l'écran se traduit tout de suite dans la langue choisie
    if (widget.firstLaunch && mounted) {
      await LocaleProvider.changeLocale(context, Locale(code));
    }
  }

  Future<void> _apply() async {
    await LocaleProvider.changeLocale(context, Locale(_selected));
    if (!mounted) return;
    if (widget.firstLaunch) {
      // Installation depuis un lien d'inscription (campagne) : directement
      // l'écran d'inscription, avec l'accueil en dessous pour le bouton retour.
      final linkRoute = DeepLinkService.instance.takePendingRoute();
      final nav = Navigator.of(context);
      if (linkRoute != null) {
        nav.pushReplacementNamed('/landing');
        nav.pushNamed(linkRoute);
      } else {
        nav.pushReplacementNamed(OnboardingGuide.intro.route);
      }
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.firstLaunch
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'lang.title'.tr(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Text(
              'lang.select'.tr(),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _languages.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final lang = _languages[i];
                final isSelected = _selected == lang.code;
                return _buildLanguageTile(lang, isSelected);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  widget.firstLaunch ? 'common.next'.tr() : 'lang.apply'.tr(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLanguageTile(_LangOption lang, bool isSelected) {
    return GestureDetector(
      onTap: () => _select(lang.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? _orange.withValues(alpha: 0.10) : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _orange.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Flag emoji
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? _orange.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(lang.flag, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 16),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.nativeName,
                    style: TextStyle(
                      color: isSelected ? _orange : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lang.englishName,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Check
            AnimatedOpacity(
              opacity: isSelected ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangOption {
  final String code;
  final String nativeName;
  final String flag;
  final String englishName;

  const _LangOption(this.code, this.nativeName, this.flag, this.englishName);
}
