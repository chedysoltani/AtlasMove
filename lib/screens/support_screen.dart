import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

const _orange = Color(0xFFFF6B35);
const _orangeLight = Color(0xFFFF8C42);
const _dark = Color(0xFF0F172A);
const _darkCard = Color(0xFF1A2744);
const _surface = Color(0xFFF8F9FB);
const _border = Color(0xFFE8ECF0);
const _textPrim = Color(0xFF1A1F36);
const _textSecond = Color(0xFF9BA3B4);
const _red = Color(0xFFEF4444);
const _green = Color(0xFF22C55E);

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final AnimationController _pulseCtrl;
  late final List<AnimationController> _itemCtrls;

  final _msgCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedCategory = 'Compte';
  bool _isSending = false;
  bool _messageSent = false;

  final _categories = ['Compte', 'Paiement', 'Livraison', 'Technique', 'Autre'];

  final _faqItems = const [
    _FaqItem(
      question: 'Comment modifier mes informations personnelles ?',
      answer:
          'Rendez-vous dans Mon Profil → icône édition en haut à droite. Vous pouvez modifier votre nom, téléphone et photo de profil.',
    ),
    _FaqItem(
      question: 'Comment fonctionne la commission ?',
      answer:
          'La commission est de 10 % sur votre chiffre d\'affaires mensuel. Le premier mois est offert. Elle est calculée automatiquement chaque mois dans "Mes Gains".',
    ),
    _FaqItem(
      question: 'Comment payer ma commission ?',
      answer:
          'Depuis "Mes Gains" → bouton "Payer maintenant". Transférez le montant en USDT TRC20 vers l\'adresse affichée, puis collez le hash de transaction pour confirmation.',
    ),
    _FaqItem(
      question: 'Je ne peux pas me connecter à mon compte',
      answer:
          'Vérifiez votre email et mot de passe. Si vous avez oublié votre mot de passe, utilisez "Mot de passe oublié ?" sur la page de connexion. Contactez le support si le problème persiste.',
    ),
    _FaqItem(
      question: 'Comment annuler ou modifier un rendez-vous ?',
      answer:
          'Depuis "Mes Rendez-vous", appuyez sur le rendez-vous concerné. Vous pouvez le modifier ou l\'annuler tant qu\'il n\'est pas en cours.',
    ),
    _FaqItem(
      question: 'Mon paiement de commission n\'a pas été validé',
      answer:
          'La validation prend jusqu\'à 24–48h. Assurez-vous d\'avoir soumis le bon hash de transaction (TXID). Si le délai est dépassé, contactez-nous en indiquant votre hash.',
    ),
    _FaqItem(
      question: 'Comment activer les notifications ?',
      answer:
          'Allez dans les paramètres de votre téléphone → Applications → AtlasMove → Notifications → Activer. Redémarrez l\'application ensuite.',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _itemCtrls = List.generate(6, (i) {
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );
      Future.delayed(Duration(milliseconds: 200 + i * 80), () {
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
    _msgCtrl.dispose();
    super.dispose();
  }

  Animation<double> _fade(AnimationController c) =>
      CurvedAnimation(parent: c, curve: Curves.easeOut);

  Animation<Offset> _slide(AnimationController c) =>
      Tween(begin: const Offset(0, 0.15), end: Offset.zero)
          .animate(CurvedAnimation(parent: c, curve: Curves.easeOut));

  Widget _animated(int i, Widget child) {
    if (i >= _itemCtrls.length) return child;
    return SlideTransition(
      position: _slide(_itemCtrls[i]),
      child: FadeTransition(opacity: _fade(_itemCtrls[i]), child: child),
    );
  }

  Future<void> _sendMessage() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() { _isSending = false; _messageSent = true; });
      _msgCtrl.clear();
      await Future.delayed(const Duration(seconds: 4));
      if (mounted) setState(() => _messageSent = false);
    }
  }

  void _copyToClipboard(String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copié !',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _dark,
      body: Column(
        children: [
          SizedBox(height: size.height * 0.33, child: _buildHero()),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _animated(0, _buildContactSection()),
                    const SizedBox(height: 28),
                    _animated(1, _buildFaqSection()),
                    const SizedBox(height: 28),
                    _animated(2, _buildReportSection()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return FadeTransition(
      opacity: _fade(_heroCtrl),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_dark, _darkCard],
              ),
            ),
          ),
          Positioned(top: -45, right: -45, child: _ring(190, _orange.withOpacity(0.07))),
          Positioned(bottom: 8, left: -65, child: _ring(210, Colors.white.withOpacity(0.03))),
          Positioned(top: 55, left: 30, child: _dot(6, _orange.withOpacity(0.35))),
          Positioned(bottom: 50, right: 40, child: _dot(4, Colors.white.withOpacity(0.18))),
          Positioned(top: 30, right: 80, child: _dot(3, _orange.withOpacity(0.22))),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) {
                            final glow = 12.0 + _pulseCtrl.value * 18;
                            final scale = 1.0 + _pulseCtrl.value * 0.05;
                            return Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 76, height: 76,
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
                                child: const Icon(Icons.support_agent_rounded,
                                    color: Colors.white, size: 38),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Centre d\'aide',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _accentLine(),
                            const SizedBox(width: 10),
                            Text(
                              'Nous sommes là pour vous',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.5),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(width: 10),
                            _accentLine(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Contact Section ────────────────────────────────────────────────────────

  Widget _buildContactSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Contactez-nous', Icons.headset_mic_rounded),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _contactCard(
                icon: Icons.email_rounded,
                label: 'Email',
                value: 'support@atla.business',
                color: const Color(0xFF6366F1),
                onTap: () => _copyToClipboard('support@atla.business', 'Email'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _contactCard(
                icon: Icons.phone_rounded,
                label: 'Téléphone',
                value: '+216 XX XXX XXX',
                color: _green,
                onTap: () => _copyToClipboard('+216XXXXXXXX', 'Téléphone'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _whatsAppCard(),
        const SizedBox(height: 12),
        _availabilityBanner(),
      ],
    );
  }

  Widget _contactCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textSecond,
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _textPrim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.copy_rounded, size: 11, color: color),
                const SizedBox(width: 4),
                Text('Copier',
                    style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _whatsAppCard() {
    return GestureDetector(
      onTap: () => _copyToClipboard('+216XXXXXXXX', 'Numéro WhatsApp'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.chat_rounded,
                  color: Color(0xFF25D366), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WhatsApp Support',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrim)),
                  Text('Réponse en moins d\'1h en horaires ouvrés',
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: _textSecond)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Copier n°',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF25D366))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _availabilityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _orange.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _orange.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.access_time_rounded, color: _orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Support disponible Lun – Sam · 9h00 – 19h00',
              style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _orange,
                  height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ── FAQ Section ────────────────────────────────────────────────────────────

  Widget _buildFaqSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Questions fréquentes', Icons.help_outline_rounded),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: _faqItems.asMap().entries.map((e) {
                final isLast = e.key == _faqItems.length - 1;
                return Column(
                  children: [
                    _FaqTile(item: e.value),
                    if (!isLast)
                      const Divider(
                          height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ── Report Section ─────────────────────────────────────────────────────────

  Widget _buildReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Signaler un problème', Icons.bug_report_rounded),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Catégorie',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrim)),
                const SizedBox(height: 10),
                _buildCategoryChips(),
                const SizedBox(height: 18),
                Text('Message',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrim)),
                const SizedBox(height: 8),
                _buildMessageField(),
                const SizedBox(height: 16),
                if (_messageSent) ...[
                  _buildSentBanner(),
                  const SizedBox(height: 14),
                ],
                _buildSendButton(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((cat) {
        final selected = _selectedCategory == cat;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? _orange : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? _orange : _border,
                width: 1.5,
              ),
            ),
            child: Text(
              cat,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _textSecond,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMessageField() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border, width: 1.2),
        color: const Color(0xFFFAFBFD),
      ),
      child: TextField(
        controller: _msgCtrl,
        maxLines: 4,
        keyboardType: TextInputType.multiline,
        style: GoogleFonts.poppins(fontSize: 13, color: _textPrim),
        decoration: InputDecoration(
          hintText: 'Décrivez votre problème en détail...',
          hintStyle: GoogleFonts.poppins(
              fontSize: 13, color: const Color(0xFFCDD3E0)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        onChanged: (_) {
          if (_messageSent) setState(() => _messageSent = false);
        },
      ),
    );
  }

  Widget _buildSentBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              color: _green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Message envoyé ! Notre équipe vous répondra par email.',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: _green, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_orange, _orangeLight],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _orange.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextButton(
          onPressed: _isSending || _msgCtrl.text.trim().isEmpty
              ? null
              : _sendMessage,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text('Envoyer le message',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _orange, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
              fontSize: 16, fontWeight: FontWeight.w800, color: _textPrim),
        ),
      ],
    );
  }

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

  Widget _accentLine() => Container(
        width: 22, height: 2,
        decoration: BoxDecoration(
          color: _orange, borderRadius: BorderRadius.circular(1)),
      );
}

// ── FAQ Data Model ────────────────────────────────────────────────────────

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

// ── FAQ Tile Widget ───────────────────────────────────────────────────────

class _FaqTile extends StatefulWidget {
  final _FaqItem item;
  const _FaqTile({super.key, required this.item});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _ctrl;
  late final Animation<double> _turn;
  late final Animation<double> _height;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _turn = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _height = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.question,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _textPrim,
                        height: 1.4),
                  ),
                ),
                const SizedBox(width: 12),
                RotationTransition(
                  turns: _turn,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: _orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.expand_more_rounded,
                        color: _orange, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Text(
                widget.item.answer,
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: _textSecond,
                    height: 1.6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
