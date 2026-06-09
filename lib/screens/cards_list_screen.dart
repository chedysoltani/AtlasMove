import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/cards_provider.dart';
import '../models/card_models.dart';

class CardsListScreen extends ConsumerStatefulWidget {
  const CardsListScreen({super.key});

  @override
  ConsumerState<CardsListScreen> createState() => _CardsListScreenState();
}

class _CardsListScreenState extends ConsumerState<CardsListScreen>
    with SingleTickerProviderStateMixin {
  // ─── Colors ──────────────────────────────────────────────────────
  static const _navy = Color(0xFF0F172A);
  static const _navyLight = Color(0xFF1E293B);
  static const _orange = Color(0xFFFF6B35);
  static const _orangeLight = Color(0xFFFF8C5A);
  static const _bg = Color(0xFFF8F9FB);
  static const _border = Color(0xFFE8ECF0);
  static const _textPrimary = Color(0xFF1A1F36);
  static const _textSecondary = Color(0xFF9BA3B4);

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    Future.microtask(() async {
      await ref.read(cardsProvider.notifier).loadCards();
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleAddCard() async {
    HapticFeedback.lightImpact();
    await ref.read(cardsProvider.notifier).addCard();
    final state = ref.read(cardsProvider);
    if (state.error != null && mounted) {
      _showSnack(state.error!, success: false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardsProvider);

    return Scaffold(
      backgroundColor: _navy,
      body: Column(
        children: [
          _buildHero(state),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: state.isLoading && state.cards.isEmpty
                  ? _buildLoader()
                  : FadeTransition(
                      opacity: _fadeAnim,
                      child: RefreshIndicator(
                        onRefresh: () => ref.read(cardsProvider.notifier).loadCards(),
                        color: _orange,
                        child: state.cards.isEmpty
                            ? _buildEmpty()
                            : _buildCardList(state),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────

  Widget _buildHero(CardsState state) {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 120,
        child: Stack(
          children: [
            Positioned(
              right: -25, top: -15,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.06), width: 26),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: _iconBtn(Icons.arrow_back_ios_new_rounded),
                      ),
                      Text('payment.cards_title'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      GestureDetector(
                        onTap: state.isLoading ? null : _handleAddCard,
                        child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [_orange, _orangeLight]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: _orange.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: state.isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  ),
                                )
                              : const Icon(Icons.add_rounded,
                                  color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_orange, _orangeLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: _orange.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: const Icon(Icons.credit_card_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('payment.cards_title'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text('payment.cards_subtitle'.tr(),
                          style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.5))),
                    ]),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon) => Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      );

  // ─── Card list ────────────────────────────────────────────────────

  Widget _buildCardList(CardsState state) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      itemCount: state.cards.length,
      itemBuilder: (_, i) => _CardWidget(
        card: state.cards[i],
        onTap: () => _showActions(state.cards[i]),
      ),
    );
  }

  // ─── Actions sheet ────────────────────────────────────────────────

  void _showActions(CardDto card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: _orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.credit_card_rounded,
                      color: _orange, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(card.maskedLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary)),
                  Text('Expire ${card.expiryLabel}',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: _textSecondary)),
                ]),
              ]),
              const SizedBox(height: 20),
              if (!card.isDefault) ...[
                _actionTile(
                  ctx: ctx,
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  label: 'payment.set_default'.tr(),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(cardsProvider.notifier).setDefault(card.id);
                  },
                ),
                const SizedBox(height: 8),
              ],
              _actionTile(
                ctx: ctx,
                icon: Icons.delete_rounded,
                iconColor: const Color(0xFFEF4444),
                label: 'payment.remove_card'.tr(),
                destructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(card);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: destructive
              ? const Color(0xFFEF4444).withOpacity(0.05)
              : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: destructive
                ? const Color(0xFFEF4444).withOpacity(0.15)
                : _border,
          ),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: destructive ? const Color(0xFFEF4444) : _textPrimary)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: destructive ? const Color(0xFFEF4444) : _textSecondary),
        ]),
      ),
    );
  }

  void _confirmDelete(CardDto card) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.delete_rounded,
                  color: Color(0xFFEF4444), size: 28),
            ),
            const SizedBox(height: 16),
            Text('payment.remove_card'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('${card.maskedLabel} sera définitivement supprimée.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: _border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('common.cancel'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: _textSecondary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ref.read(cardsProvider.notifier).removeCard(card.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text('common.delete'.tr(),
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─── States ───────────────────────────────────────────────────────

  Widget _buildLoader() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: _orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const CircularProgressIndicator(
                color: _orange, strokeWidth: 2.5),
          ),
          const SizedBox(height: 14),
          Text('common.loading'.tr(),
              style: GoogleFonts.poppins(fontSize: 13, color: _textSecondary)),
        ]),
      );

  Widget _buildEmpty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: _textSecondary.withOpacity(0.08),
                  shape: BoxShape.circle),
              child: const Icon(Icons.credit_card_off_rounded,
                  color: _textSecondary, size: 36),
            ),
            const SizedBox(height: 16),
            Text('payment.no_cards'.tr(),
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 6),
            Text('payment.cards_subtitle'.tr(), // TODO: add translation key for "Ajoutez une carte pour payer vos courses"
                style: GoogleFonts.poppins(
                    fontSize: 13, color: _textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_orange, _orangeLight]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: _orange.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _handleAddCard,
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
                label: Text('payment.add_card'.tr(),
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ]),
        ),
      );
}

// ─── Credit card widget ───────────────────────────────────────────────────────

class _CardWidget extends StatelessWidget {
  final CardDto card;
  final VoidCallback onTap;

  const _CardWidget({required this.card, required this.onTap});

  LinearGradient _gradient(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'mastercard':
        return const LinearGradient(
          colors: [Color(0xFF1B1B2F), Color(0xFF162447)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E3A5F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _shadowColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':   return const Color(0xFF1A237E);
      case 'mastercard': return const Color(0xFF1B1B2F);
      default:       return const Color(0xFF0F172A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 185,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          gradient: _gradient(card.brand),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: _shadowColor(card.brand).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              right: -30, top: -30,
              child: Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              right: 30, top: 20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.03),
                ),
              ),
            ),
            // Card content
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _brandLogo(card.brand),
                      if (card.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6B35).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFFFF6B35).withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Color(0xFFFF6B35), size: 11),
                              const SizedBox(width: 4),
                              Text('Défaut',
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFFFF6B35),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  // Card number
                  Text(
                    card.maskedLabel,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 3,
                    ),
                  ),
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('EXPIRE',
                            style: GoogleFonts.poppins(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                        const SizedBox(height: 2),
                        Text(card.expiryLabel,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ]),
                      if (card.isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Expirée',
                              style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        )
                      else
                        const Icon(Icons.more_horiz_rounded,
                            color: Colors.white38, size: 22),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _brandLogo(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return Text('VISA',
            style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 2));
      case 'mastercard':
        return Row(children: [
          Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                  color: Color(0xFFEB001B), shape: BoxShape.circle)),
          Transform.translate(
            offset: const Offset(-10, 0),
            child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                    color: const Color(0xFFF79E1B).withOpacity(0.85),
                    shape: BoxShape.circle)),
          ),
        ]);
      default:
        return const Icon(Icons.credit_card_rounded,
            color: Colors.white70, size: 28);
    }
  }
}
