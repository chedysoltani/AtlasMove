import 'dart:convert';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/network/http_client.dart';
import '../core/storage/token_storage.dart';
import '../models/call_models.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  static const String _agoraAppId = 'e6c22e318b1d4256be2d01835c9db292';
  static const String _callingSocketUrl = 'https://api.atla.business/calling';

  IO.Socket? _socket;
  RtcEngine? _rtcEngine;
  bool _isConnected = false;
  String? _activeCallId;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  // Callbacks — set by screens to respond to socket events
  static void Function(CallSession session)? onIncomingCall;
  static void Function(CallSession session)? onCallAccepted;
  static void Function(String callId)? onCallEnded;
  static void Function(String callId)? onCallRejected;

  String? lastError;

  bool get isConnected => _isConnected;
  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  String? get activeCallId => _activeCallId;

  /// Connect to the /calling Socket.io namespace.
  /// Safe to call multiple times — skips if already connected.
  Future<void> connectSocket() async {
    if (_socket != null && _socket!.connected) return;

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint('⚠️ CallService: Pas de token, connexion différée.');
      return;
    }

    _socket = IO.io(
      _callingSocketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token})
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) {
      debugPrint('✅ CallService: Connecté au WebSocket /calling');
      _isConnected = true;
    });

    _socket!.onDisconnect((_) {
      debugPrint('❌ CallService: Déconnecté du WebSocket /calling');
      _isConnected = false;
    });

    _socket!.onConnectError((data) {
      debugPrint('⚠️ CallService: Erreur de connexion: $data');
    });

    _socket!.on('call.incoming', (payload) {
      debugPrint('📞 RAW call.incoming: $payload');
      final raw = _toMap(payload);
      if (raw == null) { debugPrint('⚠️ call.incoming: toMap returned null'); return; }
      // Unwrap { data: { ... } } envelope if present
      final data = (raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      try {
        final session = CallSession.fromJson(data);
        debugPrint('📞 call.incoming parsed: caller=${session.caller.name} channel=${session.channelName} tokenLen=${session.agoraToken.length}');
        onIncomingCall?.call(session);
      } catch (e) {
        debugPrint('⚠️ CallService: Erreur parsing call.incoming: $e | data=$data');
      }
    });

    _socket!.on('call.accepted', (payload) {
      debugPrint('✅ RAW call.accepted: $payload');
      final raw = _toMap(payload);
      if (raw == null) return;
      // Unwrap { data: { ... } } envelope if present
      final data = (raw['data'] is Map)
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      try {
        final session = CallSession.fromJson(data);
        debugPrint('✅ call.accepted parsed: channel=${session.channelName} tokenLen=${session.agoraToken.length}');
        onCallAccepted?.call(session);
      } catch (e) {
        debugPrint('⚠️ CallService: Erreur parsing call.accepted: $e');
      }
    });

    _socket!.on('call.ended', (_) {
      debugPrint('📵 CallService: Appel terminé par l\'autre partie');
      final callId = _activeCallId ?? '';
      onCallEnded?.call(callId);
      _releaseAgoraEngine();
      _activeCallId = null;
    });

    _socket!.on('call.rejected', (_) {
      debugPrint('🚫 CallService: Appel refusé');
      final callId = _activeCallId ?? '';
      onCallRejected?.call(callId);
      _releaseAgoraEngine();
      _activeCallId = null;
    });
  }

  /// Initiate a call for the given trip. Returns the CallSession on success or null on failure.
  Future<CallSession?> initiateCall(String tripId) async {
    lastError = null;
    if (!await _ensureSocketAndPermission()) {
      lastError = 'Permission microphone refusée';
      return null;
    }

    try {
      final response = await HttpClient.post(
        '/calls/initiate',
        body: {'tripId': tripId},
      );

      if (!response.isSuccess) {
        lastError = 'HTTP ${response.statusCode}: ${response.body}';
        debugPrint('❌ CallService: initiateCall $lastError');
        return null;
      }

      final raw = response.json;
      debugPrint('📞 initiateCall response: $raw');
      // API returns: { data: { message: "...", data: { callSessionId, ... } } }
      final outerData = raw['data'];
      final sessionJson = (outerData is Map && outerData['data'] is Map)
          ? Map<String, dynamic>.from(outerData['data'] as Map)
          : outerData is Map
              ? Map<String, dynamic>.from(outerData as Map)
              : raw;

      debugPrint('📞 sessionJson: $sessionJson');
      final session = CallSession.fromJson(sessionJson);
      debugPrint('📞 session: id=${session.callSessionId} channel=${session.channelName} tokenLen=${session.agoraToken.length}');
      _activeCallId = session.callSessionId;
      await _initAgoraAndJoin(session.channelName, session.agoraToken);
      return session;
    } catch (e, st) {
      lastError = e.toString();
      debugPrint('❌ CallService: initiateCall exception: $e\n$st');
      return null;
    }
  }

  /// Accept an incoming call and join the Agora channel.
  Future<bool> acceptCall(String callId, String channelName, String agoraToken) async {
    lastError = null;
    debugPrint('📞 acceptCall: id=$callId channel=$channelName tokenLen=${agoraToken.length}');

    // Step 1 — microphone permission
    final micStatus = await Permission.microphone.request();
    debugPrint('🎤 CallService: mic permission = $micStatus');
    if (!micStatus.isGranted) {
      lastError = 'Permission microphone refusée ($micStatus)';
      debugPrint('❌ $lastError');
      return false;
    }

    // Step 2 — notify backend
    try {
      final resp = await HttpClient.post('/calls/$callId/accept');
      debugPrint('📞 accept response: ${resp.statusCode} ${resp.body}');
      if (!resp.isSuccess) {
        lastError = 'accept HTTP ${resp.statusCode}: ${resp.body}';
        debugPrint('❌ $lastError');
        return false;
      }
      _activeCallId = callId;
    } catch (e) {
      lastError = 'accept HTTP exception: $e';
      debugPrint('❌ CallService: $lastError');
      return false;
    }

    // Step 3 — join Agora
    try {
      if (_socket == null || !_socket!.connected) await connectSocket();
      await _initAgoraAndJoin(channelName, agoraToken);
      debugPrint('✅ CallService: Agora rejoint avec succès');
      return true;
    } catch (e, st) {
      lastError = 'Agora: $e';
      debugPrint('❌ CallService: Agora join exception: $e\n$st');
      return false;
    }
  }

  /// Reject an incoming call without joining audio.
  Future<void> rejectCall(String callId) async {
    try {
      await HttpClient.post('/calls/$callId/reject');
    } catch (e) {
      debugPrint('❌ CallService: rejectCall exception: $e');
    }
  }

  /// End the currently active call and leave the Agora channel.
  Future<void> endCall() async {
    final callId = _activeCallId;
    _activeCallId = null;
    _releaseAgoraEngine();
    if (callId == null) return;
    try {
      await HttpClient.post('/calls/$callId/end');
    } catch (e) {
      debugPrint('❌ CallService: endCall exception: $e');
    }
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _rtcEngine?.muteLocalAudioStream(_isMuted);
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _rtcEngine?.setEnableSpeakerphone(_isSpeakerOn);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _isConnected = false;
  }

  /// Reconnexion après refresh de token — déconnecte puis reconnecte avec le nouveau token.
  Future<void> reconnect() async {
    disconnect();
    await connectSocket();
  }

  // ─── Private helpers ────────────────────────────────────────────────────────

  Future<bool> _ensureSocketAndPermission() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('❌ CallService: Permission microphone refusée');
      return false;
    }
    if (_socket == null || !_socket!.connected) {
      await connectSocket();
    }
    return true;
  }

  Future<void> _initAgoraAndJoin(String channelName, String token) async {
    if (channelName.isEmpty) throw Exception('channelName vide — payload socket incomplet');
    if (token.isEmpty) throw Exception('agoraToken vide — token absent du payload');
    debugPrint('🔧 Agora: channelName=$channelName token=${token.substring(0, token.length.clamp(0, 20))}...');

    // Release previous engine — set null FIRST to avoid race with socket events
    final old = _rtcEngine;
    _rtcEngine = null;
    if (old != null) {
      try { await old.leaveChannel(); } catch (_) {}
      try { await old.release(); } catch (_) {}
    }

    debugPrint('🔧 Agora: createAgoraRtcEngine...');
    final engine = createAgoraRtcEngine();
    _rtcEngine = engine;

    debugPrint('🔧 Agora: initialize appId=$_agoraAppId');
    await engine.initialize(RtcEngineContext(appId: _agoraAppId));
    debugPrint('✅ Agora: initialize OK');

    // If a socket event (call.rejected/ended) fired during await and cancelled us, abort
    if (_rtcEngine != engine) {
      try { await engine.release(); } catch (_) {}
      throw Exception('Appel annulé pendant l\'initialisation Agora');
    }

    engine.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('✅ Agora: Rejoint canal ${connection.channelId} (${elapsed}ms)');
      },
      onError: (err, msg) {
        debugPrint('❌ Agora onError: code=$err msg=$msg');
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('👤 Agora: Utilisateur $remoteUid connecté');
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('👤 Agora: Utilisateur $remoteUid déconnecté: $reason');
      },
      onLeaveChannel: (connection, stats) {
        debugPrint('✅ Agora: Quitté le canal');
      },
    ));

    debugPrint('🔧 Agora: enableAudio...');
    await engine.enableAudio();
    try {
      await engine.setEnableSpeakerphone(_isSpeakerOn);
    } catch (e) {
      // Emulator or some devices don't support speaker routing — non-critical
      debugPrint('⚠️ Agora: setEnableSpeakerphone ignoré: $e');
    }

    debugPrint('🔧 Agora: joinChannel channelId=$channelName uid=0');
    await engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        autoSubscribeAudio: true,
        publishMicrophoneTrack: true,
      ),
    );
    debugPrint('✅ Agora: joinChannel appelé (attente onJoinChannelSuccess)');
  }

  Future<void> _releaseAgoraEngine() async {
    final engine = _rtcEngine;
    if (engine == null) return;
    _rtcEngine = null; // Set null FIRST — prevents race with _initAgoraAndJoin
    _isMuted = false;
    _isSpeakerOn = true;
    try { await engine.leaveChannel(); } catch (_) {}
    try { await engine.release(); } catch (_) {}
  }

  Map<String, dynamic>? _toMap(dynamic payload) {
    try {
      if (payload is Map) return Map<String, dynamic>.from(payload);
      if (payload is String) return jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }
}
