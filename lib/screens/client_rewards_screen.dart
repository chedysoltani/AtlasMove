import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientRewardsScreen extends StatefulWidget {
  const ClientRewardsScreen({super.key});

  @override
  State<ClientRewardsScreen> createState() => _ClientRewardsScreenState();
}

class _ClientRewardsScreenState extends State<ClientRewardsScreen>
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

  // ─── Mock data ────────────────────────────────────────────────────
  final int _tripsThisMonth = 14;
  final int _monthlyGoal = 20;
  final int _consecutiveMonths = 4;
  final double _progressCashback = 0.66;
  final double _progressTravel = 0.33;

  final List<Map<String, String>> _destinations = [
    {'name': 'Santorin, Grèce', 'image': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=400', 'tag': 'Méditerranée'},
    {'name': 'Amalfi, Italie', 'image': 'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?q=80&w=400', 'tag': 'Culture'},
    {'name': 'Marrakech, Maroc', 'image': 'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?q=80&w=400', 'tag': 'Exotique'},
    {'name': 'Barcelone, Espagne', 'image': 'https://images.unsplash.com/photo-1583422409516-2895a77efded?q=80&w=400', 'tag': 'Plage & Ville'},
  ];

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Column(
        children: [
          _buildHero(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusHeader(),
                        const SizedBox(height: 20),
                        _buildGoalCard(),
                        const SizedBox(height: 20),
                        _sectionLabel('Récompenses', Icons.card_giftcard_rounded),
                        const SizedBox(height: 12),
                        _buildMilestone(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: const Color(0xFF22C55E),
                          title: 'Cashback 100 USD',
                          subtitle: 'Après 6 mois consécutifs',
                          progress: _progressCashback,
                          remaining: 'Encore 2 mois',
                          remainingColor: const Color(0xFF22C55E),
                        ),
                        const SizedBox(height: 12),
                        _buildMilestone(
                          icon: Icons.flight_takeoff_rounded,
                          iconColor: _orange,
                          title: 'Voyage Privilège (5 jours)',
                          subtitle: 'Après 1 an d\'activité',
                          progress: _progressTravel,
                          remaining: 'Encore 8 mois',
                          remainingColor: _orange,
                        ),
                        const SizedBox(height: 24),
                        _sectionLabel('Destinations suggérées', Icons.explore_rounded),
                        const SizedBox(height: 6),
                        Text(
                          'Basé sur votre localisation (Afrique du Nord)',
                          style: GoogleFonts.poppins(
                              fontSize: 12, color: _textSecondary),
                        ),
                        const SizedBox(height: 14),
                        _buildDestinations(),
                        const SizedBox(height: 24),
                        _sectionLabel('Niveaux de fidélité', Icons.emoji_events_rounded),
                        const SizedBox(height: 14),
                        _buildLevels(),
                      ],
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

  // ─── Hero ─────────────────────────────────────────────────────────

  Widget _buildHero() {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Stack(
          children: [
            // Rings
            Positioned(
              right: -20, top: -20,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.05), width: 28),
                ),
              ),
            ),
            Positioned(
              left: -30, bottom: -30,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _orange.withOpacity(0.08), width: 20),
                ),
              ),
            ),
            Column(
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                    // Elite badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 5),
                        Text('Elite',
                            style: GoogleFonts.poppins(
                                color: const Color(0xFFF59E0B),
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Center icon + title
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_orange, _orangeLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                          color: _orange.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 6))
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 12),
                Text(
                  'Programme Privilège',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Membre Gold · $_consecutiveMonths mois de régularité',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status header ────────────────────────────────────────────────

  Widget _buildStatusHeader() {
    return Row(
      children: [
        Expanded(
          child: _statMini(
            icon: Icons.route_rounded,
            value: '$_tripsThisMonth',
            label: 'Courses ce mois',
            color: const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statMini(
            icon: Icons.calendar_today_rounded,
            value: '$_consecutiveMonths',
            label: 'Mois consécutifs',
            color: const Color(0xFFF59E0B),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statMini(
            icon: Icons.star_rounded,
            value: 'Gold',
            label: 'Niveau actuel',
            color: _orange,
          ),
        ),
      ],
    );
  }

  Widget _statMini({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 9,
                color: _textSecondary,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
      ]),
    );
  }

  // ─── Monthly goal card ────────────────────────────────────────────

  Widget _buildGoalCard() {
    final progress = _tripsThisMonth / _monthlyGoal;
    final remaining = _monthlyGoal - _tripsThisMonth;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_navy, _navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _navy.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Objectif mensuel',
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$_tripsThisMonth / $_monthlyGoal',
                  style: GoogleFonts.poppins(
                      color: _orangeLight,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Stack(children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [_orange, _orangeLight]),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: _orange.withOpacity(0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          remaining > 0
              ? 'Plus que $remaining courses pour valider votre étape !'
              : 'Objectif atteint ce mois-ci ! 🎉',
          style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.white.withOpacity(0.6)),
        ),
      ]),
    );
  }

  // ─── Milestone ────────────────────────────────────────────────────

  Widget _buildMilestone({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required double progress,
    required String remaining,
    required Color remainingColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: _textSecondary)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: Stack(children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  FractionallySizedBox(
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [iconColor, iconColor.withOpacity(0.6)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Text(remaining,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: remainingColor)),
            ]),
          ]),
        ),
      ]),
    );
  }

  // ─── Destinations ─────────────────────────────────────────────────

  Widget _buildDestinations() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _destinations.length,
        itemBuilder: (_, i) {
          final d = _destinations[i];
          return Container(
            width: 155,
            margin: const EdgeInsets.only(right: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              image: DecorationImage(
                image: NetworkImage(d['image']!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.75),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _orange.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(d['tag']!,
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 5),
                  Text(d['name']!,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Loyalty levels ───────────────────────────────────────────────

  Widget _buildLevels() {
    final levels = [
      {'icon': Icons.emoji_events_rounded, 'label': 'Bronze', 'color': const Color(0xFFCD7F32), 'active': false},
      {'icon': Icons.emoji_events_rounded, 'label': 'Silver', 'color': const Color(0xFF9BA3B4), 'active': false},
      {'icon': Icons.stars_rounded, 'label': 'Gold', 'color': const Color(0xFFF59E0B), 'active': true},
      {'icon': Icons.diamond_rounded, 'label': 'Platinum', 'color': const Color(0xFF3B82F6), 'active': false},
    ];

    return Row(
      children: levels.map((l) {
        final active = l['active'] as bool;
        final color = l['color'] as Color;
        final icon = l['icon'] as IconData;
        final label = l['label'] as String;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: active ? _navy : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: active ? _navy : _border),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: _navy.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Column(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: active
                      ? color.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: active ? color : color.withOpacity(0.5),
                    size: 18),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight:
                          active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? Colors.white : _textSecondary)),
              if (active) ...[
                const SizedBox(height: 4),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      color: _orange, shape: BoxShape.circle),
                ),
              ],
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ─── Section label ────────────────────────────────────────────────

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: _orange),
      const SizedBox(width: 6),
      Text(text,
          style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textSecondary,
              letterSpacing: 0.4)),
    ]);
  }
}
