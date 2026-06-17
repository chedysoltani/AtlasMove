class SupportMessage {
  final String sender; // 'user' | 'admin' | 'system'
  final String message;
  final DateTime timestamp;

  const SupportMessage({
    required this.sender,
    required this.message,
    required this.timestamp,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        sender: json['sender']?.toString() ?? 'system',
        message: json['message']?.toString() ?? '',
        timestamp:
            DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
                DateTime.now(),
      );
}

class SupportTicketChat {
  final String ticketId;
  final String status; // 'open' | 'resolved' | 'closed'
  final List<SupportMessage> messages;

  const SupportTicketChat({
    required this.ticketId,
    required this.status,
    required this.messages,
  });

  factory SupportTicketChat.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List? ?? [])
        .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return SupportTicketChat(
      ticketId: json['ticketId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      messages: msgs,
    );
  }
}
