import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'location_tracking_service.dart';

// Point d'entrée de l'isolate du foreground service — doit être top-level
@pragma('vm:entry-point')
void _foregroundEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_LocationTaskHandler());
}

// Handler minimal : le vrai tracking se passe dans l'isolate principal via LocationTrackingService
class _LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

/// Gère le foreground service Android + background mode iOS pour le tracking GPS livreur.
/// Doit être initialisé une fois au démarrage de l'app (main.dart).
class LocationForegroundService {
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'atlasmove_location_tracking',
        channelName: 'Suivi de position',
        channelDescription: 'Maintient le suivi GPS actif pendant une course',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(10000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Démarre le foreground service + le tracking GPS.
  /// Appeler quand le livreur accepte une course ou se met en ligne.
  static Future<void> start({
    String title = '🚗 AtlasMove — Course active',
    String body  = 'Suivi de position en cours…',
  }) async {
    init();

    await FlutterForegroundTask.requestNotificationPermission();

    if (await FlutterForegroundTask.isRunningService) {
      // Mise à jour du texte de la notification si déjà actif
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: body,
      );
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: title,
      notificationText: body,
      callback: _foregroundEntryPoint,
    );

    // Démarrer le tracking dans l'isolate principal (HttpClient + auto-refresh token)
    await LocationTrackingService().startLocationTracking();
  }

  /// Arrête le foreground service + le tracking GPS.
  /// Appeler quand la course se termine ou le livreur se déconnecte.
  static Future<void> stop() async {
    LocationTrackingService().stopLocationTracking();
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  static Future<bool> get isRunning =>
      FlutterForegroundTask.isRunningService;
}
