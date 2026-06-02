import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/referral_models.dart';
import '../services/referral_service.dart';
import '../utils/app_theme.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final ReferralService _service = ReferralService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _service.fetchReferrals());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Parrainage',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
            onPressed: () => _service.fetchReferrals(),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          if (_service.isLoading && _service.data == null) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          if (_service.error != null && _service.data == null) {
            return _buildErrorState();
          }

          final data = _service.data;

          return RefreshIndicator(
            onRefresh: _service.fetchReferrals,
            color: AppTheme.primaryColor,
            backgroundColor: const Color(0xFF161722),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Share card
                  _buildShareCard(data?.referralCode ?? ''),
                  const SizedBox(height: 20),

                  // Stat cards
                  _buildStatCards(data),
                  const SizedBox(height: 24),

                  // How it works
                  _buildHowItWorks(),
                  const SizedBox(height: 24),

                  // History
                  _buildHistorySection(data?.referrals ?? []),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.grey.shade600, size: 56),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger les données',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _service.fetchReferrals,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareCard(String code) {
    final displayCode = code.isNotEmpty ? code : 'ATLAS-XXXXXX';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withOpacity(0.18),
            AppTheme.primaryColor.withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.35), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppTheme.primaryColor, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre code de parrainage',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Partagez-le — gagnez +25 pts par filleul actif',
                      style: TextStyle(color: Color(0xFF9E9EA7), fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Code display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1017),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayCode,
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryColor, size: 22),
                  tooltip: 'Copier',
                  onPressed: () => _copyCode(displayCode),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Share button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _shareCode(displayCode),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Partager mon code', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(ReferralData? data) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.people_rounded,
            iconColor: const Color(0xFF4FC3F7),
            label: 'Filleuls inscrits',
            value: '${data?.totalReferred ?? 0}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.check_circle_rounded,
            iconColor: AppTheme.successColor,
            label: 'Bonus débloqués',
            value: '${data?.totalCompleted ?? 0}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star_rounded,
            iconColor: Colors.amber,
            label: 'Points gagnés',
            value: '+${data?.pointsEarned ?? 0}',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 10, height: 1.3),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Comment ça marche ?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
          ),
          const SizedBox(height: 16),
          _buildStep('1', 'Partagez votre code', 'Envoyez votre code unique à un ami via WhatsApp, SMS ou autre.'),
          _buildStep('2', 'Il s\'inscrit', 'Votre ami crée son compte ATLAS et entre votre code à l\'inscription.'),
          _buildStep('3', 'Il complète sa 1ère course', 'Dès sa première course validée, le bonus est automatiquement crédité.'),
          _buildStep('4', 'Vous gagnez +25 points IA', 'Les points s\'ajoutent à votre soleil de fidélité ATLAS.', isLast: true),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String title, String desc, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
              ),
              child: Center(
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 1.5,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(List<ReferralItem> referrals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mes filleuls',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
            Text(
              '${referrals.length} au total',
              style: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (referrals.isEmpty)
          _buildEmptyHistory()
        else
          ...referrals.map((item) => _buildReferralItem(item)),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, color: Colors.grey.shade700, size: 48),
          const SizedBox(height: 12),
          Text(
            'Aucun filleul pour l\'instant',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Partagez votre code pour commencer à gagner des points !',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildReferralItem(ReferralItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isReferralCompleted
              ? AppTheme.successColor.withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: item.isReferralCompleted
                  ? AppTheme.successColor.withOpacity(0.12)
                  : Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.isReferralCompleted ? Icons.check_circle_rounded : Icons.hourglass_empty_rounded,
              color: item.isReferralCompleted ? AppTheme.successColor : Colors.grey.shade600,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.email,
                  style: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.isReferralCompleted
                      ? AppTheme.successColor.withOpacity(0.12)
                      : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  item.isReferralCompleted ? '+25 pts' : 'En attente',
                  style: TextStyle(
                    color: item.isReferralCompleted ? AppTheme.successColor : Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('dd MMM yyyy').format(item.createdAt),
                style: const TextStyle(color: Color(0xFF5E5E6E), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Code copié !', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCode(String code) {
    final message =
        'Rejoignez-moi sur ATLAS ! 🚀\n\nUtilisez mon code de parrainage pour bénéficier d\'avantages exclusifs :\n\n🎁 Code : $code\n\nTéléchargez l\'app ATLAS et entrez ce code à l\'inscription.';
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.share_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Message copié — collez-le où vous voulez !'),
          ],
        ),
        backgroundColor: const Color(0xFF1A1C2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
