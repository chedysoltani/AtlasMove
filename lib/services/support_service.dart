import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../models/support_models.dart';

class SupportService {
  static Future<SupportTicketChat?> getTicketChat(String ticketId) async {
    try {
      final response =
          await HttpClient.get('/m/support/ticket/$ticketId/chat');
      debugPrint('💬 ticket-chat status=${response.statusCode}');
      if (!response.isSuccess) return null;
      final raw = response.json;
      final data =
          raw['data'] is Map ? raw['data'] as Map<String, dynamic> : raw;
      return SupportTicketChat.fromJson(data);
    } catch (e) {
      debugPrint('⚠️ getTicketChat: $e');
      return null;
    }
  }
}

class SupportWebSocketService {
  static IO.Socket? _socket;
  static bool _connected = false;

  static Future<void> connect() async {
    if (_connected && _socket != null) return;
    final token = await TokenStorage.getAccessToken();
    if (token == null) return;

    _socket = IO.io(
      'https://api.atla.business/support',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _connected = true;
        debugPrint('🔌 SupportWS connected');
      })
      ..onDisconnect((_) {
        _connected = false;
        debugPrint('🔌 SupportWS disconnected');
      })
      ..onError((e) => debugPrint('⚠️ SupportWS error: $e'))
      ..connect();
  }

  static void listenForTicketUpdate(
      String ticketId, void Function(SupportTicketChat) onUpdate) {
    _socket?.on('support_ticket_chat_update', (data) {
      try {
        final map = (data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{});
        if (map['ticketId']?.toString() == ticketId) {
          onUpdate(SupportTicketChat.fromJson(map));
        }
      } catch (e) {
        debugPrint('⚠️ SupportWS parse: $e');
      }
    });
  }

  static void removeListeners() => _socket?.off('support_ticket_chat_update');

  static void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }
}
