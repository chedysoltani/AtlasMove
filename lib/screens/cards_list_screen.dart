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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: card.isDefault 
          ? const BorderSide(color: AppTheme.primaryColor, width: 2)
          : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _getBrandIcon(card.brand),
        title: Text(
          card.maskedLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Expire le ${card.expiryLabel}'),
            if (card.isExpired)
              const Text(
                'Expirée',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
          ],
        ),
        trailing: card.isDefault
            ? const Chip(
                label: Text('Défaut', style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: AppTheme.primaryColor,
              )
            : null,
        onTap: () => _showActions(card),
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
}
