import 'dart:async';

import 'package:intl/intl.dart';

import '../services/push_notification_service.dart';
import '../services/rendezvous_service.dart';
import '../services/system_strings.dart';

/// Alerte le chauffeur des NOUVEAUX rendez-vous disponibles.
///
/// Le backend n'a pas (encore) d'évènement temps réel pour les rendez-vous —
/// contrairement aux courses (`new_ride`), il n'y a ni push ni socket dédié.
/// En attendant, on sonde périodiquement `GET /m/rendezvous/available` (déjà
/// utilisé par l'onglet "Disponibles" de [DriverRendezvousScreen]) et on
/// détecte les identifiants jamais vus, pour lesquels on affiche une notification
/// système locale.
///
/// Limite connue : ne fonctionne que tant que le process de l'app est vivant
/// (premier plan ou arrière-plan) — contrairement aux courses, un rendez-vous
/// ne peut pas réveiller l'app si elle est totalement tuée (ça demanderait un
/// vrai évènement backend).
class RendezvousAlertService {
  RendezvousAlertService._();
  static final RendezvousAlertService instance = RendezvousAlertService._();

  static const _pollInterval = Duration(seconds: 45);

  Timer? _timer;
  final Set<String> _seenIds = {};
  bool _baselineEstablished = false;
  bool _polling = false;

  bool get isRunning => _timer != null;

  /// À appeler quand le chauffeur passe en ligne. Sans effet si déjà démarré.
  void start() {
    if (_timer != null) return;
    _baselineEstablished = false;
    _seenIds.clear();
    unawaited(_poll());
    _timer = Timer.periodic(_pollInterval, (_) => unawaited(_poll()));
  }

  /// À appeler quand le chauffeur passe hors ligne ou se déconnecte.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    try {
      final resp = await RendezvousService.getAvailableBookings(page: 1, limit: 20);
      final currentIds = resp.items.map((r) => r.id).toSet();

      if (!_baselineEstablished) {
        // Premier sondage après le passage en ligne : on mémorise l'état sans
        // notifier — sinon chaque connexion déclencherait une alerte pour
        // TOUS les rendez-vous déjà disponibles, pas seulement les nouveaux.
        _seenIds.addAll(currentIds);
        _baselineEstablished = true;
        return;
      }

      final newOnes = resp.items.where((r) => !_seenIds.contains(r.id));
      if (newOnes.isNotEmpty) await SystemStrings.load();
      for (final rdv in newOnes) {
        final time = DateFormat('dd/MM HH:mm').format(rdv.scheduledAt);
        await PushNotificationService.showNewRendezvousNotification(
          id: rdv.id,
          title: SystemStrings.get('rdv_title'),
          body: '${rdv.serviceName} — ${rdv.address} · $time',
        );
      }
      _seenIds.addAll(currentIds);
    } catch (_) {
      // Sondage best-effort : une erreur réseau ne doit pas arrêter le minuteur.
    } finally {
      _polling = false;
    }
  }
}
