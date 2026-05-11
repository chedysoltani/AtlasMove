import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/card_models.dart';
import '../repositories/cards_repository.dart';

final cardsRepositoryProvider = Provider((ref) => CardsRepository());

class CardsState {
  final bool isLoading;
  final List<CardDto> cards;
  final String? error;

  CardsState({
    this.isLoading = false,
    this.cards = const [],
    this.error,
  });

  CardsState copyWith({
    bool? isLoading,
    List<CardDto>? cards,
    String? error,
  }) {
    return CardsState(
      isLoading: isLoading ?? this.isLoading,
      cards: cards ?? this.cards,
      error: error,
    );
  }
}

class CardsNotifier extends StateNotifier<CardsState> {
  final CardsRepository _repository;

  CardsNotifier(this._repository) : super(CardsState());

  Future<void> loadCards() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cards = await _repository.getCards();
      state = state.copyWith(isLoading: false, cards: cards);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addCard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.addCard();
      await loadCards();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setDefault(String cardId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedCards = await _repository.setDefault(cardId);
      state = state.copyWith(isLoading: false, cards: updatedCards);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> removeCard(String cardId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.removeCard(cardId);
      await loadCards();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final cardsProvider = StateNotifierProvider<CardsNotifier, CardsState>((ref) {
  final repository = ref.watch(cardsRepositoryProvider);
  return CardsNotifier(repository);
});
