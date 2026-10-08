import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Les trois guides de première utilisation.
enum OnboardingGuide {
  /// Présentation générale, avant la connexion.
  intro('/onboarding'),

  /// Après la première connexion d'un client.
  client('/onboarding_client'),

  /// Après la première connexion d'un chauffeur.
  driver('/onboarding_driver');

  const OnboardingGuide(this.route);
  final String route;

  String get _prefKey => 'onboarding_${name}_seen_v1';
}

/// Mémorise quels guides ont déjà été vus (une seule fois par appareil).
/// Les guides restent consultables à tout moment depuis le profil.
class OnboardingService {
  OnboardingService._();
  static final OnboardingService instance = OnboardingService._();

  Future<bool> isSeen(OnboardingGuide guide) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(guide._prefKey) ?? false;
    } catch (_) {
      // En cas d'erreur de stockage, on ne bloque jamais l'utilisateur.
      return true;
    }
  }

  Future<void> markSeen(OnboardingGuide guide) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(guide._prefKey, true);
    } catch (_) {}
  }

  /// À appeler à l'ouverture d'un tableau de bord : affiche le guide par-dessus
  /// s'il n'a jamais été vu.
  Future<void> showIfFirstTime(BuildContext context, OnboardingGuide guide) async {
    if (await isSeen(guide)) return;
    if (!context.mounted) return;
    await markSeen(guide);
    if (!context.mounted) return;
    Navigator.of(context).pushNamed(guide.route);
  }
}
