import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class ClientRewardsScreen extends StatefulWidget {
  const ClientRewardsScreen({super.key});

  @override
  State<ClientRewardsScreen> createState() => _ClientRewardsScreenState();
}

class _ClientRewardsScreenState extends State<ClientRewardsScreen> {
  // Mock data for loyalty tracking
  final int _tripsThisMonth = 14;
  final int _monthlyGoal = 20;
  final int _consecutiveMonths = 4;
  final double _progressTowardCashback = 0.66; // 4/6 months
  final double _progressTowardTravel = 0.33; // 4/12 months
  
  final List<Map<String, String>> _destinations = [
    {'name': 'Santorin, Grèce', 'image': 'https://images.unsplash.com/photo-1570077188670-e3a8d69ac5ff?q=80&w=400', 'tag': 'Méditerranée'},
    {'name': 'Amalfi, Italie', 'image': 'https://images.unsplash.com/photo-1533900298318-6b8da08a523e?q=80&w=400', 'tag': 'Culture'},
    {'name': 'Marrakech, Maroc', 'image': 'https://images.unsplash.com/photo-1539020140153-e479b8c22e70?q=80&w=400', 'tag': 'Exotique'},
    {'name': 'Barcelone, Espagne', 'image': 'https://images.unsplash.com/photo-1583422409516-2895a77efded?q=80&w=400', 'tag': 'Plage & Ville'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),
                  const SizedBox(height: 24),
                  _buildMonthlyGoalCard(),
                  const SizedBox(height: 24),
                  _buildRewardMilestones(),
                  const SizedBox(height: 32),
                  _buildTravelSection(),
                  const SizedBox(height: 24),
                  _buildLoyaltyLevels(),
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
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1A237E), // Deep Indigo for premium feel
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          'Programme Privilège',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(Icons.stars, size: 150, color: Colors.white.withOpacity(0.1)),
              ),
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.white, size: 40),
                    SizedBox(height: 8),
                    Text(
                      'Membre Gold',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fidélité AtlasMove',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'Vous avez $_consecutiveMonths mois de régularité !',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber),
          ),
          child: const Row(
            children: [
              Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
              SizedBox(width: 4),
              Text('Elite', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyGoalCard() {
    double progress = _tripsThisMonth / _monthlyGoal;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Objectif Mensuel',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '$_tripsThisMonth / $_monthlyGoal courses',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey[100],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Plus que ${_monthlyGoal - _tripsThisMonth} courses ce mois-ci pour valider votre étape !',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardMilestones() {
    return Column(
      children: [
        _buildMilestoneItem(
          icon: Icons.account_balance_wallet,
          color: Colors.green,
          title: 'Cashback 100 USD',
          subtitle: 'Après 6 mois consécutifs',
          progress: _progressTowardCashback,
          remaining: 'Encore 2 mois',
        ),
        const SizedBox(height: 16),
        _buildMilestoneItem(
          icon: Icons.flight_takeoff,
          color: Colors.orange,
          title: 'Voyage Privilège (5 jours)',
          subtitle: 'Après 1 an d\'activité',
          progress: _progressTowardTravel,
          remaining: 'Encore 8 mois',
        ),
      ],
    );
  }

  Widget _buildMilestoneItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required double progress,
    required String remaining,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: Colors.grey[100],
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(remaining, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.explore, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Destinations Suggérées',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Basé sur votre localisation actuelle (Afrique du Nord)',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _destinations.length,
            itemBuilder: (context, index) {
              final dest = _destinations[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: DecorationImage(
                    image: NetworkImage(dest['image']!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dest['tag']!,
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dest['name']!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoyaltyLevels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Niveaux de Fidélité',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLevelIcon(Icons.emoji_events, 'Bronze', Colors.brown, false),
            _buildLevelIcon(Icons.emoji_events, 'Silver', Colors.grey, false),
            _buildLevelIcon(Icons.stars, 'Gold', Colors.amber, true),
            _buildLevelIcon(Icons.diamond, 'Platinum', Colors.blue[900]!, false),
          ],
        ),
      ],
    );
  }

  Widget _buildLevelIcon(IconData icon, String label, Color color, bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.1) : Colors.grey[100],
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: color, width: 2) : null,
          ),
          child: Icon(icon, color: isActive ? color : Colors.grey[400], size: 24),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black : Colors.grey,
          ),
        ),
      ],
    );
  }
}
