enum CallStatus { idle, outgoingRinging, incomingRinging, active, ended, rejected }

class CallParticipant {
  final String id;
  final String name;
  final String? phone;

  CallParticipant({required this.id, required this.name, this.phone});

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    final firstName = (json['firstName'] ?? json['first_name'] ?? '').toString();
    final lastName = (json['lastName'] ?? json['last_name'] ?? '').toString();
    final fullName = '$firstName $lastName'.trim();
    final nameField = json['name']?.toString() ?? '';
    return CallParticipant(
      id: json['id']?.toString() ?? '',
      name: nameField.isNotEmpty ? nameField : (fullName.isNotEmpty ? fullName : 'Inconnu'),
      phone: json['phone']?.toString(),
    );
  }
}

class CallSession {
  final String callSessionId;
  final String channelName;
  final String agoraToken;
  final CallParticipant caller;
  final CallParticipant callee;

  CallSession({
    required this.callSessionId,
    required this.channelName,
    required this.agoraToken,
    required this.caller,
    required this.callee,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      callSessionId: json['callSessionId']?.toString() ??
          json['call_session_id']?.toString() ??
          json['id']?.toString() ?? '',
      channelName: json['channelName']?.toString() ??
          json['channel_name']?.toString() ?? '',
      agoraToken: json['token']?.toString() ??
          json['agoraToken']?.toString() ??
          json['agora_token']?.toString() ?? '',
      caller: CallParticipant.fromJson(
        json['caller'] is Map ? Map<String, dynamic>.from(json['caller'] as Map) : {},
      ),
      callee: CallParticipant.fromJson(
        json['callee'] is Map ? Map<String, dynamic>.from(json['callee'] as Map) : {},
      ),
    );
  }
}
