import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/storage/token_storage.dart';
import '../models/call_models.dart';
import '../models/new_ride_offer.dart';
import '../screens/driver_active_ride.dart';
import '../screens/incoming_call_screen.dart';
import 'call_service.dart';
import 'ride_offer_queue.dart';
import 'system_strings.dart';
import 'trip_service.dart';

/// Notifications système pour les évènements qui doivent réveiller l'app :
/// nouvelle course (chauffeur) et appel entrant, quand le socket n'est pas
/// disponible (app en arrière-plan ou fermée).
///
/// Le backend envoie des messages FCM **data-only** (voir le contrat §2/§3) :
/// aucune notification n'apparaît toute seule, l'app doit la construire elle-même.
/// Quand l'app est au premier plan avec le socket connecté, l'évènement arrive
/// aussi par socket (`new_ride`, `call.incoming`) et affiche directement l'écran
/// plein écran correspondant — la notification système sert de filet de sécurité
/// et de réveil quand le socket n'est pas là.
class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  // Getters (et non const) : nom et description dans la langue choisie,
  // relue par SystemStrings.load() avant chaque création de canal.
  static AndroidNotificationChannel get _rideChannel => AndroidNotificationChannel(
    'new_ride_channel',
    SystemStrings.get('ride_channel'),
    description: SystemStrings.get('ride_channel_desc'),
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('new_ride'),
    enableVibration: true,
    vibrationPattern: null,
  );

  static AndroidNotificationChannel get _callChannel => AndroidNotificationChannel(
    'incoming_call_channel',
    SystemStrings.get('call_channel'),
    description: SystemStrings.get('call_channel_desc'),
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('incoming_call'),
    enableVibration: true,
    vibrationPattern: null,
  );

  static AndroidNotificationChannel get _rdvChannel => AndroidNotificationChannel(
    'new_rdv_channel',
    SystemStrings.get('rdv_channel'),
    description: SystemStrings.get('rdv_channel_desc'),
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('new_rdv'),
    enableVibration: true,
  );

  /// Écrans/actions en attente d'un contexte de navigation prêt (boot terminé).
  static Map<String, dynamic>? _pendingAction;

  static bool _initialized = false;

  /// À appeler une fois au démarrage, avant `runApp`.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await SystemStrings.load();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinInit = DarwinInitializationSettings(
      // La permission (son/alerte/badge) est demandée par DeviceTokenService
      // via FirebaseMessaging.requestPermission — pas de second dialogue ici.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        DarwinNotificationCategory(
          'NEW_RIDE',
          actions: [
            DarwinNotificationAction.plain('accept_ride', SystemStrings.get('accept'),
                options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain('refuse_ride', SystemStrings.get('refuse'),
                options: {DarwinNotificationActionOption.destructive}),
          ],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
        DarwinNotificationCategory(
          'INCOMING_CALL',
          actions: [
            DarwinNotificationAction.plain('accept_call', SystemStrings.get('answer'),
                options: {DarwinNotificationActionOption.foreground}),
            DarwinNotificationAction.plain('decline_call', SystemStrings.get('refuse'),
                options: {DarwinNotificationActionOption.destructive}),
          ],
          options: {DarwinNotificationCategoryOption.customDismissAction},
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: _onForegroundResponse,
      onDidReceiveBackgroundNotificationResponse: pushNotificationBackgroundResponseHandler,
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_rideChannel);
    await android?.createNotificationChannel(_callChannel);
    await android?.createNotificationChannel(_rdvChannel);

    // L'app a été ouverte en tapant sur une notification alors qu'elle était tuée.
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true && launchResponse != null) {
      _queueFromResponse(launchResponse);
    }
  }

  // ── Firebase Messaging : premier plan / arrière-plan ────────────────────────

  /// `FirebaseMessaging.onMessage` — app au premier plan.
  ///
  /// Filet de sécurité seulement : quand le socket est connecté, l'évènement
  /// arrive aussi par socket et la carte est déjà dans [RideOfferQueue]/l'appel
  /// déjà affiché ; on évite donc ici tout doublon (double sonnerie) en
  /// vérifiant qu'aucune carte/écran n'existe déjà pour ce tripId/callId.
  static Future<void> handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    switch (data['type']) {
      case 'new_ride':
        final tripId = (data['trip_id'] ?? data['tripId'])?.toString();
        if (tripId != null && !RideOfferQueue.instance.contains(tripId)) {
          await showNewRideNotification(data);
        }
        break;
      case 'ride_taken':
      case 'ride_cancelled':
        await cancelNewRideNotification(data['trip_id']?.toString());
        break;
      case 'incoming_call':
        final callId = (data['call_session_id'] ?? data['callSessionId'])?.toString();
        if (callId != null && CallService().activeCallId != callId) {
          await showIncomingCallNotification(data);
        }
        break;
      case 'call_cancelled':
        await cancelCallNotification(data['call_session_id']?.toString());
        break;
    }
  }

  /// `FirebaseMessaging.onBackgroundMessage` — app en arrière-plan ou tuée.
  /// Tourne dans un isolate neuf : Firebase doit être réinitialisé.
  @pragma('vm:entry-point')
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp();
    } catch (_) {}
    await _ensureLocalNotificationsForIsolate();

    final data = message.data;
    switch (data['type']) {
      case 'new_ride':
        await showNewRideNotification(data);
        break;
      case 'ride_taken':
      case 'ride_cancelled':
        await cancelNewRideNotification(data['trip_id']?.toString());
        break;
      case 'incoming_call':
        await showIncomingCallNotification(data);
        break;
      case 'call_cancelled':
        await cancelCallNotification(data['call_session_id']?.toString());
        break;
    }
  }

  /// Isolate d'arrière-plan neuf : le plugin n'a jamais été initialisé dedans.
  static Future<void> _ensureLocalNotificationsForIsolate() async {
    await SystemStrings.load();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: pushNotificationBackgroundResponseHandler,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_rideChannel);
    await android?.createNotificationChannel(_callChannel);
    await android?.createNotificationChannel(_rdvChannel);
  }

  // ── Construction des notifications ──────────────────────────────────────────

  static int _rideNotifId(String tripId) => ('ride_$tripId').hashCode & 0x7fffffff;
  static int _callNotifId(String callId) => ('call_$callId').hashCode & 0x7fffffff;

  static int? _msUntil(dynamic expiresAtMs) {
    final ms = int.tryParse(expiresAtMs?.toString() ?? '');
    if (ms == null) return null;
    final remaining = ms - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? remaining : null;
  }

  static Future<void> showNewRideNotification(Map<String, dynamic> data) async {
    final tripId = (data['trip_id'] ?? data['tripId'])?.toString();
    if (tripId == null) return;
    final pickup = data['pickup_address']?.toString() ?? '';
    final fare = data['offered_fare']?.toString();
    final currency = data['currency']?.toString() ?? '';
    await SystemStrings.load();
    final pickupLine = SystemStrings.get('ride_pickup', args: {'pickup': pickup});

    await _plugin.show(
      id: _rideNotifId(tripId),
      title: SystemStrings.get('ride_title'),
      body: pickup.isEmpty ? SystemStrings.get('ride_waiting') : pickupLine,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _rideChannel.id,
          _rideChannel.name,
          channelDescription: _rideChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          ticker: SystemStrings.get('ride_ticker'),
          timeoutAfter: _msUntil(data['expires_at']),
          styleInformation: fare != null
              ? BigTextStyleInformation('$pickupLine\n$fare $currency')
              : null,
          actions: [
            AndroidNotificationAction('accept_ride', SystemStrings.get('accept'),
                showsUserInterface: true),
            AndroidNotificationAction('refuse_ride', SystemStrings.get('refuse'),
                showsUserInterface: false, cancelNotification: true),
          ],
        ),
        iOS: DarwinNotificationDetails(
          // iOS n'accepte pas le mp3 pour les sons de notification (seulement
          // aiff/wav/caf) : garder ce .wav (à fournir comme ressource Xcode)
          // tant qu'aucune version convertie du son "nouvelle course" n'existe.
          sound: 'new_ride.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'NEW_RIDE',
          threadIdentifier: 'new_ride',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static Future<void> cancelNewRideNotification(String? tripId) async {
    if (tripId == null) return;
    await _plugin.cancel(id: _rideNotifId(tripId));
  }

  static Future<void> showIncomingCallNotification(Map<String, dynamic> data) async {
    final callId = (data['call_session_id'] ?? data['callSessionId'])?.toString();
    if (callId == null) return;
    await SystemStrings.load();
    final caller = data['caller_name']?.toString() ?? SystemStrings.get('call_default');

    await _plugin.show(
      id: _callNotifId(callId),
      title: caller,
      body: SystemStrings.get('call_body'),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id,
          _callChannel.name,
          channelDescription: _callChannel.description,
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          visibility: NotificationVisibility.public,
          ongoing: true,
          autoCancel: false,
          timeoutAfter: _msUntil(data['expires_at']) ?? 45000,
          actions: [
            AndroidNotificationAction('accept_call', SystemStrings.get('answer'),
                showsUserInterface: true),
            AndroidNotificationAction('decline_call', SystemStrings.get('refuse'),
                showsUserInterface: false, cancelNotification: true),
          ],
        ),
        iOS: DarwinNotificationDetails(
          // Idem : mp3 non supporté par iOS pour un son de notification.
          sound: 'incoming_call.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
          categoryIdentifier: 'INCOMING_CALL',
          threadIdentifier: 'incoming_call',
        ),
      ),
      payload: jsonEncode(data),
    );
  }

  static Future<void> cancelCallNotification(String? callId) async {
    if (callId == null) return;
    await _plugin.cancel(id: _callNotifId(callId));
  }

  /// Nouveau rendez-vous disponible (détecté par sondage — voir
  /// `RendezvousAlertService`, le backend n'a pas encore d'évènement temps réel
  /// pour ça). `id` est l'identifiant du rendez-vous, utilisé comme clé de
  /// notification pour éviter les doublons si le même sondage le revoit.
  static Future<void> showNewRendezvousNotification({
    required String id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id: ('rdv_$id').hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'new_rdv_channel',
          SystemStrings.get('rdv_channel'),
          channelDescription: SystemStrings.get('rdv_channel_desc'),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          // mp3 non supporté par iOS pour un son de notification (voir plus haut) —
          // son par défaut tant qu'un .wav/.caf dédié n'est pas fourni.
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  // ── Réponses (tap corps / actions) ──────────────────────────────────────────

  /// Isolate principal : taps sur le corps + actions marquées
  /// `showsUserInterface: true` (accept_ride, accept_call). Le boot (restauration
  /// de session) peut ne pas être terminé : la navigation réelle est différée
  /// dans [_pendingAction] et rejouée par [consumePendingAction].
  static void _onForegroundResponse(NotificationResponse response) {
    _queueFromResponse(response);
  }

  static void _queueFromResponse(NotificationResponse response) {
    Map<String, dynamic> data;
    try {
      data = response.payload == null
          ? {}
          : Map<String, dynamic>.from(jsonDecode(response.payload!) as Map);
    } catch (_) {
      data = {};
    }
    _pendingAction = {'actionId': response.actionId, 'data': data};
    // Si l'app est déjà lancée et le boot terminé, on rejoue tout de suite.
    unawaited(_tryConsumeNow());
  }

  static GlobalKey<NavigatorState>? _navKeyForAutoConsume;

  static Future<void> _tryConsumeNow() async {
    final key = _navKeyForAutoConsume;
    if (key?.currentState != null) await consumePendingAction(key!);
  }

  /// À appeler après la navigation de démarrage (splash), et à retenir pour les
  /// taps reçus alors que l'app tourne déjà.
  static Future<void> consumePendingAction(GlobalKey<NavigatorState> navigatorKey) async {
    _navKeyForAutoConsume = navigatorKey;
    final action = _pendingAction;
    if (action == null) return;
    _pendingAction = null;

    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final data = Map<String, dynamic>.from(action['data'] as Map? ?? {});
    final actionId = action['actionId'] as String?;
    final type = data['type']?.toString();

    if (type == 'new_ride' || actionId == 'accept_ride') {
      final tripId = (data['trip_id'] ?? data['tripId'])?.toString();
      if (tripId == null) return;
      await cancelNewRideNotification(tripId);
      if (actionId == 'accept_ride') {
        try {
          await TripService.acceptTrip(tripId);
          RideOfferQueue.instance.clear(); // occupé : les autres offres tombent
          final trip = await TripService.getActiveTrip();
          if (trip != null) {
            nav.push(MaterialPageRoute(builder: (_) => DriverActiveRideScreen(trip: trip)));
          }
        } catch (e) {
          debugPrint('PushNotificationService: accept_ride depuis notif: ${e.runtimeType}');
        }
      } else {
        // Tap sur le corps : l'offre rejoint la file, affichée comme une carte
        // parmi d'autres par RideOffersPanel (elle peut avoir déjà été prise
        // entretemps — la carte gère le 409 already_taken au moment d'accepter).
        RideOfferQueue.instance.add(NewRideOffer.fromJson(data));
      }
      return;
    }

    if (type == 'incoming_call' || actionId == 'accept_call') {
      final callId = (data['call_session_id'] ?? data['callSessionId'])?.toString();
      if (callId == null) return;
      await cancelCallNotification(callId);
      final session = CallSession(
        callSessionId: callId,
        channelName: data['channel_name']?.toString() ?? '',
        agoraToken: '', // récupéré par IncomingCallScreen via GET /calls/{id}/token
        caller: CallParticipant(
          id: data['caller_id']?.toString() ?? '',
          name: data['caller_name']?.toString() ?? 'Appel entrant',
        ),
        callee: CallParticipant(id: '', name: ''),
      );
      nav.push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(session: session),
      ));
    }
  }
}

/// Isolate d'arrière-plan : uniquement les actions marquées
/// `showsUserInterface: false` (refuse_ride, decline_call) atterrissent ici —
/// les autres ramènent l'app au premier plan et passent par le callback normal.
/// Doit rester top-level, annotée `vm:entry-point`.
@pragma('vm:entry-point')
void pushNotificationBackgroundResponseHandler(NotificationResponse response) {
  Map<String, dynamic> data;
  try {
    data = response.payload == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(response.payload!) as Map);
  } catch (_) {
    data = {};
  }

  switch (response.actionId) {
    case 'refuse_ride':
      final tripId = (data['trip_id'] ?? data['tripId'])?.toString();
      if (tripId != null) {
        unawaited(TripService.refuseTrip(tripId));
        unawaited(PushNotificationService.cancelNewRideNotification(tripId));
      }
      break;
    case 'decline_call':
      final callId = (data['call_session_id'] ?? data['callSessionId'])?.toString();
      if (callId != null) {
        unawaited(CallService().rejectCall(callId));
        unawaited(PushNotificationService.cancelCallNotification(callId));
      }
      break;
  }
}

/// Top-level requis par `FirebaseMessaging.onBackgroundMessage` — délègue au
/// service pour garder toute la logique au même endroit.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) =>
    PushNotificationService.handleBackgroundMessage(message);

/// Utilisée au démarrage : le rôle stocké détermine si les notifications
/// « nouvelle course » doivent réagir sur cet appareil.
Future<bool> isCurrentUserDriver() async => (await TokenStorage.getUserRole()) == 'delivery';
