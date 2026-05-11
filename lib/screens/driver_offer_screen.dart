import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../widgets/custom_button.dart';

class DriverOfferScreen extends StatefulWidget {
  const DriverOfferScreen({super.key});

  @override
  State<DriverOfferScreen> createState() => _DriverOfferScreenState();
}

class _DriverOfferScreenState extends State<DriverOfferScreen> {
  // Mock data for progress tracking
  final double _progressPercentage = 0.45; // 45% toward 2 years
  final int _totalWorkedDays = 328;
  final int _currentStreak = 12;
  final int _completedTrips = 1450;
  final double _monthlyRevenue = 4250.00;
  final double _totalRevenue = 58400.00;
  final double _commissionPaid = 1168.00; // 2% of total revenue
  final int _remainingDays = 402; // Remaining of 730 days (2 years)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOfferCard(),
                  const SizedBox(height: 24),
                  _buildProgressSection(),
                  const SizedBox(height: 24),
                  _buildRewardHighlight(),
                  const SizedBox(height: 24),
                  _buildActivitySection(),
                  const SizedBox(height: 24),
                  _buildGamificationSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Partenariat & Succès',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -50,
              top: -50,
              child: CircleAvatar(
                radius: 100,
                backgroundColor: Colors.white.withOpacity(0.1),
              ),
            ),
            const Center(
              child: Icon(
                Icons.workspace_premium,
                color: Colors.white24,
                size: 120,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.handshake, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              const Text(
                'Notre Engagement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildOfferDetailItem(
            icon: Icons.calendar_month,
            title: 'Abonnement mensuel',
            value: '60 USD / mois',
            subtitle: 'Accès illimité à la plateforme',
          ),
          const Divider(height: 24),
          _buildOfferDetailItem(
            icon: Icons.percent,
            title: 'Commission réduite',
            value: '2% seulement',
            subtitle: 'Sur l\'ensemble de vos revenus',
          ),
          const Divider(height: 24),
          _buildOfferDetailItem(
            icon: Icons.card_giftcard,
            title: 'Bonus de Fidélité',
            value: '2500 USD',
            subtitle: 'Récompense après 2 ans d\'activité continue',
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildOfferDetailItem({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    bool highlight = false,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: highlight ? Colors.green[700] : Colors.black,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Votre Progression',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Objectif 2 ans',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${(_progressPercentage * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progressPercentage,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      label: 'Jours restants',
                      value: '$_remainingDays',
                      icon: Icons.timer_outlined,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  Expanded(
                    child: _buildMiniStat(
                      label: 'Total Jours',
                      value: '$_totalWorkedDays',
                      icon: Icons.calendar_today,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildLargeStatRow(
                icon: Icons.trending_up,
                color: Colors.green,
                label: 'Chiffre d\'affaires total',
                value: '${_totalRevenue.toStringAsFixed(0)} USD',
              ),
              const SizedBox(height: 16),
              _buildLargeStatRow(
                icon: Icons.pie_chart,
                color: Colors.orange,
                label: 'Commissions payées (2%)',
                value: '${_commissionPaid.toStringAsFixed(2)} USD',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat({required String label, required String value, required IconData icon}) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildLargeStatRow({required IconData icon, required Color color, required String label, required String value}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardHighlight() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF4CAF50)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 48),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bonus Exceptionnel',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  '2500 USD à l\'arrivée',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Continuez sur cette lancée !',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Activité Récente',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Voir tout'),
            ),
          ],
        ),
        Container(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
              final isActive = index < 5;
              return Container(
                width: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isActive ? AppTheme.primaryColor.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isActive ? AppTheme.primaryColor : Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      days[index],
                      style: TextStyle(
                        color: isActive ? AppTheme.primaryColor : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Icon(
                      isActive ? Icons.check_circle : Icons.circle_outlined,
                      color: isActive ? AppTheme.primaryColor : Colors.grey[300],
                      size: 20,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGamificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Succès & Badges',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildBadge(Icons.bolt, 'Sprinteur', Colors.yellow[700]!, true),
            _buildBadge(Icons.verified, 'Fiable', Colors.blue, true),
            _buildBadge(Icons.star, 'Étoile', Colors.purple, true),
            _buildBadge(Icons.workspace_premium, 'Expert', Colors.grey[400]!, false),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Conseil : Réalisez 5 courses de plus cette semaine pour débloquer le badge "Expert" !',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color, bool unlocked) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: unlocked ? color.withOpacity(0.1) : Colors.grey[200],
            shape: BoxShape.circle,
            border: unlocked ? Border.all(color: color, width: 2) : null,
          ),
          child: Icon(
            icon,
            color: unlocked ? color : Colors.grey[400],
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: unlocked ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }
}
