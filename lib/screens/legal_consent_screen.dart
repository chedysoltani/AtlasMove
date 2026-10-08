import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/legal_service.dart';
import '../core/storage/token_storage.dart';

class LegalConsentScreen extends StatefulWidget {
  const LegalConsentScreen({super.key});

  @override
  State<LegalConsentScreen> createState() => _LegalConsentScreenState();
}

class _LegalConsentScreenState extends State<LegalConsentScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF0F172A);
  static const _orange  = Color(0xFFFF6B35);
  static const _border  = Color(0xFFE8ECF0);
  static const _textPrimary   = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);

  static const _ppUrl  = 'https://api.atla.business/legal/privacy-policy';
  static const _tocUrl = 'https://api.atla.business/legal/terms-and-conditions';

  late final TabController _tabCtrl;
  late final WebViewController _ppController;
  late final WebViewController _tocController;

  bool _ppLoading  = true;
  bool _tocLoading = true;
  bool _ppAccepted  = false;
  bool _tocAccepted = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _ppController  = _buildWebView(_ppUrl,  onDone: () => setState(() => _ppLoading  = false));
    _tocController = _buildWebView(_tocUrl, onDone: () => setState(() => _tocLoading = false));
  }

  WebViewController _buildWebView(String url, {required VoidCallback onDone}) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => onDone(),
      ))
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _ppAccepted && _tocAccepted && !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      await Future.wait([
        LegalService.acceptPrivacyPolicy(),
        LegalService.acceptTermsAndConditions(),
      ]);
      if (!mounted) return;
      final role = await TokenStorage.getUserRole();
      final isDriver = role == 'livreur' || role == 'delivery';
      final destination = isDriver ? '/driver_main' : '/client_dashboard';
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        destination,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('common.error_detail'.tr(namedArgs: {'error': '$e'}),
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHero(),
          _buildTabBar(),
          Expanded(child: _buildWebViews()),
          _buildBottomPanel(),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 24,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Bouton retour / déconnexion
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                    '/login', (route) => false);
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 20),
              tooltip: 'auth.logout'.tr(),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: _orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _orange.withOpacity(0.3)),
            ),
            child: const Icon(Icons.gavel_rounded, color: _orange, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            'legal.title'.tr(),
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'legal.subtitle'.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF0F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12, fontWeight: FontWeight.w500),
        labelColor: _textPrimary,
        unselectedLabelColor: _textSecondary,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(
            icon: Icon(Icons.privacy_tip_rounded, size: 16),
            text: 'legal.privacy_tab'.tr(),
            iconMargin: EdgeInsets.only(bottom: 3),
          ),
          Tab(
            icon: Icon(Icons.article_rounded, size: 16),
            text: 'legal.terms_tab'.tr(),
            iconMargin: EdgeInsets.only(bottom: 3),
          ),
        ],
      ),
    );
  }

  Widget _buildWebViews() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _webViewPane(_ppController, _ppLoading),
            _webViewPane(_tocController, _tocLoading),
          ],
        ),
      ),
    );
  }

  Widget _webViewPane(WebViewController ctrl, bool loading) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: WebViewWidget(controller: ctrl),
          ),
        ),
        if (loading)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48, height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _orange,
                      backgroundColor: _orange.withOpacity(0.1),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('legal.loading_doc'.tr(),
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: _textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          _buildCheckbox(
            checked: _ppAccepted,
            onChanged: (v) => setState(() => _ppAccepted = v ?? false),
            label: 'legal.accept_the_f'.tr(),
            linkLabel: 'legal.privacy_policy'.tr(),
            onLinkTap: () => _tabCtrl.animateTo(0),
          ),
          const SizedBox(height: 10),
          _buildCheckbox(
            checked: _tocAccepted,
            onChanged: (v) => setState(() => _tocAccepted = v ?? false),
            label: 'legal.accept_the_pl'.tr(),
            linkLabel: 'legal.terms'.tr(),
            onLinkTap: () => _tabCtrl.animateTo(1),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: AnimatedOpacity(
              opacity: _canSubmit ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _canSubmit
                      ? const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFF8C5A)],
                        )
                      : null,
                  color: _canSubmit ? null : _border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _canSubmit
                      ? [
                          BoxShadow(
                            color: _orange.withOpacity(0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          'legal.continue'.tr(),
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _canSubmit ? Colors.white : _textSecondary,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required bool checked,
    required ValueChanged<bool?> onChanged,
    required String label,
    required String linkLabel,
    required VoidCallback onLinkTap,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: checked,
            onChanged: onChanged,
            activeColor: _orange,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!checked),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.poppins(
                      fontSize: 13, color: _textPrimary),
                  children: [
                    TextSpan(text: label),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: onLinkTap,
                        child: Text(
                          linkLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _orange,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: _orange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
