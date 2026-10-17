import 'package:flutter/foundation.dart';
import '../core/storage/token_storage.dart';
import '../models/service_models.dart';
import 'service_api.dart';

/// Mode de facturation du chauffeur connecté (voir [BillingRule]) :
/// abonnement 90 USD pour Taxi Économique, commission 10 % pour tout le reste.
///
/// Partagé par la barre de navigation, le tableau de bord, les courses et le
/// Programme Privilège. `null` tant que le service du chauffeur est inconnu.
class DriverBillingService {
  DriverBillingService._();
  static final DriverBillingService instance = DriverBillingService._();

  final ValueNotifier<bool?> isSubscription = ValueNotifier<bool?>(null);

  bool get isCommission => isSubscription.value == false;

  Future<void>? _loading;

  /// Charge le service du chauffeur : l'assignation active, sinon la plus
  /// récente (compte créé, assignation encore en attente de validation).
  Future<void> refresh() => _loading ??= _load().whenComplete(() => _loading = null);

  Future<void> _load() async {
    try {
      final token = await TokenStorage.getAccessToken() ?? '';
      if (token.isEmpty) return;
      ServiceAssignment? assignment = await ServiceApi.getCurrentAssignment(token: token);
      if (assignment == null) {
        final history = await ServiceApi.getAssignmentsHistory(token: token);
        history.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        assignment = history.where((a) => !a.isRejected).firstOrNull;
      }
      if (assignment != null) {
        isSubscription.value = assignment.isSubscriptionBilling;
      }
    } catch (e) {
      debugPrint('DriverBillingService: $e');
    }
  }

  /// À la déconnexion : le prochain chauffeur peut avoir un autre service.
  void reset() => isSubscription.value = null;
}
