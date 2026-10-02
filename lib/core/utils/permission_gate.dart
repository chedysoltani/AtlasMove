import 'dart:async';

/// File d'attente pour les demandes de permission système.
///
/// Android n'autorise qu'UNE demande de permission à la fois par activité
/// (« Can request only one set of permissions at a time »). Quand deux plugins
/// (notifications FCM, Geolocator, permission_handler…) demandent en même temps,
/// la seconde est annulée et son Future ne se termine JAMAIS : après un login,
/// l'écran restait bloqué sur le spinner alors que le serveur avait déjà répondu.
///
/// Toute demande de permission passe par [run] : elles s'exécutent l'une après
/// l'autre, et un délai maximal évite qu'une demande perdue bloque la file.
class PermissionGate {
  PermissionGate._();

  static Future<void> _tail = Future<void>.value();

  /// Exécute [request] quand les demandes précédentes sont terminées.
  ///
  /// Si elle dépasse [timeout] (dialogue jamais résolu), retourne
  /// [onTimeout] s'il est fourni, sinon lève une [TimeoutException].
  static Future<T> run<T>(
    Future<T> Function() request, {
    Duration timeout = const Duration(seconds: 60),
    T? onTimeout,
  }) {
    final result = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        result.complete(await request().timeout(
          timeout,
          onTimeout: () {
            if (onTimeout != null) return onTimeout;
            throw TimeoutException('Permission request timed out', timeout);
          },
        ));
      } catch (e, st) {
        result.completeError(e, st);
      }
    });
    return result.future;
  }
}
