import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/notification_model.dart';
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';

class NotificationService extends ChangeNotifier {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Global callback for receiving in-app notification alerts
  static void Function(NotificationItem)? onNewNotificationReceived;

  // Real-time ride tracking callbacks — set by RideStateNotifier for active ride
  static void Function(Map<String, dynamic>)? onDriverLocationReceived;
  static void Function(Map<String, dynamic>)? onTripStatusReceived;

  // Trip cancelled / expired — set by any screen that needs to react
  // Payload: { "tripId": String, "status": "cancelled_by_livreur", "reason": String? }
  static void Function(Map<String, dynamic>)? onTripCancelledReceived;

  // Referral bonus notification callback — set in main.dart to show in-app overlay
  static void Function(int pointsGained, String message)? onReferralBonusReceived;

  // Spec backend — nouveaux événements
  // trip.bid_received : { bid_id, driver_id, driver_name, proposed_fare }
  static void Function(Map<String, dynamic>)? onBidReceived;
  // trip.accepted : { trip_id, status: "accepted" } — côté client et chauffeur
  static void Function(Map<String, dynamic>)? onTripAccepted;
  // trip.created : { trip_id, pickup_address, offered_fare } — chauffeurs uniquement
  static void Function(Map<String, dynamic>)? onTripCreated;
  // chat.new_message : { trip_id, message_id, sender_id, content, created_at }
  static void Function(Map<String, dynamic>)? onChatMessage;

  IO.Socket? _socket;
  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  bool _isConnected = false;
  bool _isLoading = false;

  // Getters
  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;

  /// Initialiser la connexion WebSocket et charger l'historique
  Future<void> initialize() async {
    await fetchNotifications();
    await connectWebSocket();
  }

  /// Connexion WebSocket via Socket.io
  Future<void> connectWebSocket() async {
    // Si déjà connecté, ignorer
    if (_socket != null && _socket!.connected) return;

    try {
      final token = await TokenStorage.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('❌ NotificationService: Impossible de se connecter aux WebSockets. Aucun Token trouvé.');
        return;
      }

      // websocket URL (utilisant le même domaine principal avec le namespace /notifications)
      const socketUrl = 'https://api.atla.business/notifications';
      debugPrint('🔌 NotificationService: Connexion au WebSocket $socketUrl...');

      _socket = IO.io(
        socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setAuth({'token': token})
            .build(),
      );

      _socket!.connect();

      _socket!.onConnect((_) {
        debugPrint('✅ NotificationService: Connecté avec succès aux WebSockets de notifications !');
        _isConnected = true;
        notifyListeners();
      });

      _socket!.onDisconnect((_) {
        debugPrint('❌ NotificationService: Déconnecté du WebSocket.');
        _isConnected = false;
        notifyListeners();
      });

      _socket!.onConnectError((data) {
        debugPrint('⚠️ NotificationService: Erreur de connexion WebSocket: $data');
      });

      // Standard notification events
      _socket!.on('new_notification', (payload) {
        debugPrint('🔔 NotificationService: Nouvelle notification reçue: $payload');
        _handleIncomingNotification(payload);
      });

      // Real-time ride tracking events
      // Anciens noms conservés pour compatibilité
      _socket!.on('driver_location', (payload) {
        final data = _toMap(payload);
        if (data != null) onDriverLocationReceived?.call(data);
      });

      _socket!.on('trip_status_update', (payload) {
        final data = _toMap(payload);
        if (data != null) onTripStatusReceived?.call(data);
      });

      // Spec backend — nouveaux noms d'événements
      _socket!.on('location.updated', (payload) {
        debugPrint('📍 location.updated raw: $payload');
        final data = _toMap(payload);
        if (data != null) onDriverLocationReceived?.call(data);
      });

      _socket!.on('trip.bid_received', (payload) {
        final data = _toMap(payload);
        if (data != null) onBidReceived?.call(data);
      });

      _socket!.on('trip.accepted', (payload) {
        final data = _toMap(payload);
        if (data != null) {
          onTripAccepted?.call(data);
          onTripStatusReceived?.call(data);
        }
      });

      _socket!.on('trip.created', (payload) {
        final data = _toMap(payload);
        if (data != null) onTripCreated?.call(data);
      });

      _socket!.on('chat.new_message', (payload) {
        final data = _toMap(payload);
        if (data != null) onChatMessage?.call(data);
      });

      // Sent by backend when trip is cancelled (all drivers refused or timeout)
      _socket!.on('trip.cancelled', (payload) {
        debugPrint('🚫 NotificationService: trip.cancelled reçu: $payload');
        final raw = _toMap(payload);
        if (raw == null) return;
        // Unwrap { data: {...} } envelope if present
        final data = (raw['data'] is Map)
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : raw;
        // Forward to status notifier (normalise status field)
        final normalized = {
          'tripId': data['tripId'] ?? data['id'],
          'status': data['status'] ?? 'cancelled_by_livreur',
          'reason': data['reason'] ?? data['message'],
        };
        onTripCancelledReceived?.call(normalized);
        // Also forward through onTripStatusReceived so ride_state_provider reacts
        onTripStatusReceived?.call(normalized);
      });

      _socket!.on('referral_bonus_received', (payload) {
        final data = _toMap(payload);
        if (data != null) {
          final points = data['pointsGained'] as int? ?? 25;
          final msg = data['message'] as String? ?? 'Vous avez reçu un bonus de parrainage !';
          onReferralBonusReceived?.call(points, msg);
        }
      });

    } catch (e) {
      debugPrint('💥 NotificationService: Exception de connexion WebSocket: $e');
    }
  }

  /// Gérer les messages entrants depuis le WebSocket
  void _handleIncomingNotification(dynamic payload) {
    try {
      Map<String, dynamic> jsonPayload;
      if (payload is String) {
        jsonPayload = jsonDecode(payload) as Map<String, dynamic>;
      } else if (payload is Map) {
        jsonPayload = Map<String, dynamic>.from(payload);
      } else {
        return;
      }

      final item = NotificationItem.fromJson(jsonPayload);
      
      // Ajouter au début de la liste
      _notifications.insert(0, item);
      
      // Incrémenter si non lu
      if (item.status == NotificationStatus.unread) {
        _unreadCount++;
      }
      
      notifyListeners();

      // Déclencher le callback d'affichage in-app si défini
      if (onNewNotificationReceived != null) {
        onNewNotificationReceived!(item);
      }
    } catch (e) {
      debugPrint('⚠️ NotificationService: Erreur de parsing de la notification entrante: $e');
    }
  }

  /// Déconnexion du WebSocket
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Reconnexion après refresh de token — déconnecte puis reconnecte avec le nouveau token.
  Future<void> reconnect() async {
    disconnect();
    await initialize();
  }

  /// Récupérer l'historique des notifications via l'API REST
  Future<void> fetchNotifications({int limit = 50, int offset = 0}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await HttpClient.get(
        '/notifications',
        queryParams: {
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      if (response.isSuccess) {
        final resJson = response.json;
        List<dynamic> dataList = [];
        int? unread;

        final rawData = resJson['data'] ?? resJson['notifications'];
        if (rawData is List) {
          dataList = rawData;
        } else if (rawData is Map) {
          final nestedData = rawData['data'] ?? rawData['notifications'];
          if (nestedData is List) {
            dataList = nestedData;
          }
          unread = rawData['unreadCount'] ?? rawData['unread_count'] ?? 
              rawData['meta']?['unreadCount'] ?? rawData['meta']?['unread_count'];
        }

        _notifications = dataList
            .map((item) => NotificationItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        // Récupérer le nombre de non lus
        _unreadCount = unread ?? resJson['unreadCount'] ?? resJson['unread_count'] ?? 
            _notifications.where((item) => item.status == NotificationStatus.unread).length;
      }
    } catch (e) {
      debugPrint('❌ NotificationService: Erreur lors du chargement des notifications REST: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marquer une notification comme lue
  Future<void> markAsRead(String id) async {
    // Optimistic Update
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index != -1 && _notifications[index].status == NotificationStatus.unread) {
      _notifications[index] = _notifications[index].copyWith(status: NotificationStatus.read);
      if (_unreadCount > 0) _unreadCount--;
      notifyListeners();
    }

    try {
      await HttpClient.patch('/notifications/$id/read');
    } catch (e) {
      debugPrint('❌ NotificationService: Erreur pour marquer la notification comme lue: $e');
    }
  }

  /// Safely parse a Socket.IO payload (String or Map) to Map<String,dynamic>.
  Map<String, dynamic>? _toMap(dynamic payload) {
    try {
      if (payload is Map) return Map<String, dynamic>.from(payload);
      if (payload is String) return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  /// Marquer toutes les notifications comme lues
  Future<void> markAllAsRead() async {
    // Optimistic Update
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (_notifications[i].status == NotificationStatus.unread) {
        _notifications[i] = _notifications[i].copyWith(status: NotificationStatus.read);
        changed = true;
      }
    }
    if (changed) {
      _unreadCount = 0;
      notifyListeners();
    }

    try {
      await HttpClient.patch('/notifications/read-all');
    } catch (e) {
      debugPrint('❌ NotificationService: Erreur pour marquer toutes les notifications comme lues: $e');
    }
  }
}
