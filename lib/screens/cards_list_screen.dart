import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cards_provider.dart';
import '../models/card_models.dart';
import '../utils/app_theme.dart';

class CardsListScreen extends ConsumerStatefulWidget {
  const CardsListScreen({super.key});

  @override
  ConsumerState<CardsListScreen> createState() => _CardsListScreenState();
}

class _CardsListScreenState extends ConsumerState<CardsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cardsProvider.notifier).loadCards());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Cartes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: state.isLoading ? null : () => _handleAddCard(),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => ref.read(cardsProvider.notifier).loadCards(),
            child: _buildContent(state),
          ),
          if (state.isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(CardsState state) {
    if (state.cards.isEmpty && !state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Aucune carte enregistrée'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handleAddCard,
              child: const Text('Ajouter une carte'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.cards.length,
      itemBuilder: (context, index) {
        final card = state.cards[index];
        return _buildCardItem(card);
      },
    );
  }

  Widget _buildCardItem(CardDto card) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Credit Card Design
          Container(
            height: 180,
            decoration: BoxDecoration(
              gradient: _getCardGradient(card.brand),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _getCardColor(card.brand).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Card Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _getBrandIcon(card.brand),
                      if (card.isDefault)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Défaut',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Card Number
                  Text(
                    card.maskedLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  // Card Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EXPIRE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.expiryLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (card.isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Expirée',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Tap overlay
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showActions(card),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActions(CardDto card) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!card.isDefault)
              ListTile(
                leading: const Icon(Icons.star_border),
                title: const Text('Définir par défaut'),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(cardsProvider.notifier).setDefault(card.id);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Supprimer la carte', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(card);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(CardDto card) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la carte'),
        content: Text('Voulez-vous vraiment supprimer la carte ${card.maskedLabel} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(cardsProvider.notifier).removeCard(card.id);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAddCard() async {
    await ref.read(cardsProvider.notifier).addCard();
    final state = ref.read(cardsProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
      );
    }
  }

  Widget _getBrandIcon(String brand) {
    IconData iconData;
    switch (brand.toLowerCase()) {
      case 'visa':
        iconData = Icons.credit_card;
        break;
      case 'mastercard':
        iconData = Icons.credit_card;
        break;
      default:
        iconData = Icons.credit_card;
    }
    return Icon(iconData, size: 32, color: Colors.blueGrey);
  }

  LinearGradient _getCardGradient(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return const LinearGradient(
          colors: [Color.fromARGB(255, 226, 144, 109), Color.fromARGB(255, 229, 102, 17)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'mastercard':
        return const LinearGradient(
          colors: [Color.fromARGB(255, 229, 102, 17), Color.fromARGB(255, 244, 128, 49)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getCardColor(String brand) {
    switch (brand.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      default:
        return const Color(0xFF667EEA);
    }
  }
}
