import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';

import '../models/new_ride_offer.dart';
import 'trip_service.dart';

/// File des offres de course proposées au chauffeur — affichées comme une
/// **liste de cartes** (façon inDrive) plutôt qu'un écran plein écran par
/// offre. Avant, chaque nouvelle course poussait un nouvel écran par-dessus le
/// précédent : avec deux offres simultanées, le chauffeur se retrouvait avec
/// deux plein-écrans empilés, sans pouvoir comparer ni choisir. Ici, toutes
/// les offres actives vivent dans une seule liste ; [RideOffersPanel] les
/// affiche toutes à la fois, triables/comparables, une carte par course.
class RideOfferQueue {
  RideOfferQueue._();
  static final RideOfferQueue instance = RideOfferQueue._();

  /// Offres actuellement proposées, triées par ordre d'arrivée.
  final ValueNotifier<List<NewRideOffer>> offers = ValueNotifier(const []);

  final AudioPlayer _player = AudioPlayer();
  Timer? _tickTimer;
  bool _ringing = false;

  bool contains(String tripId) => offers.value.any((o) => o.tripId == tripId);

  /// Ajoute une offre, ou remplace celle du même `tripId` si elle était déjà
  /// affichée (ex. le push et le socket arrivent tous les deux pour la même course).
  void add(NewRideOffer offer) {
    final current = List<NewRideOffer>.from(offers.value)
      ..removeWhere((o) => o.tripId == offer.tripId)
      ..add(offer);
    offers.value = current;
    unawaited(_ensureRinging());
    _ensureTicker();
  }

  /// Retire une offre (refusée, prise par un autre chauffeur, annulée, expirée).
  void remove(String tripId) {
    final current = List<NewRideOffer>.from(offers.value)
      ..removeWhere((o) => o.tripId == tripId);
    offers.value = current;
    if (current.isEmpty) _stopEverything();
  }

  /// Vide la file (ex. le chauffeur vient d'accepter une course : il n'est
  /// plus disponible pour les autres offres en attente).
  void clear() {
    if (offers.value.isEmpty) return;
    offers.value = const [];
    _stopEverything();
  }

  /// Accepte une offre. Retire TOUTES les offres en cas de succès (le
  /// chauffeur devient occupé) ; retire seulement celle-ci en cas d'échec
  /// (déjà prise, expirée...) pour laisser les autres offres actives.
  Future<void> accept(String tripId) async {
    try {
      await TripService.acceptTrip(tripId);
      clear();
    } catch (e) {
      remove(tripId);
      rethrow;
    }
  }

  /// Refuse une offre — retirée immédiatement (optimiste), l'appel réseau
  /// continue en arrière-plan.
  void refuse(String tripId) {
    remove(tripId);
    unawaited(TripService.refuseTrip(tripId));
  }

  /// Horloge 1 Hz : fait vivre le compte à rebours de chaque carte et purge
  /// localement les offres dont le délai est écoulé (filet de sécurité — le
  /// backend envoie aussi `ride_cancelled` à l'expiration, mais sans lui la
  /// carte resterait affichée avec "0s" indéfiniment).
  void _ensureTicker() {
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final remaining = offers.value.where((o) {
        final exp = o.expiresAt;
        return exp == null || exp.isAfter(now);
      }).toList();
      if (remaining.length != offers.value.length) {
        offers.value = remaining;
        if (remaining.isEmpty) {
          _stopEverything();
          return;
        }
      } else {
        // Force le rebuild pour que le compte à rebours affiché avance.
        offers.value = List.of(offers.value);
      }
    });
  }

  Future<void> _ensureRinging() async {
    if (_ringing) return;
    _ringing = true;
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/universfield-ringtone-048-494664.mp3'));
    } catch (_) {}
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: const [0, 500, 300, 500, 300, 500], repeat: 0);
      }
    } catch (_) {}
  }

  void _stopEverything() {
    _ringing = false;
    unawaited(_player.stop());
    try {
      Vibration.cancel();
    } catch (_) {}
    _tickTimer?.cancel();
    _tickTimer = null;
  }
}
